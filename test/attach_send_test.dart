import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/ai/adapter.dart';
import 'package:paradise/data/ai/adapters.dart';
import 'package:paradise/data/ai/content.dart';
import 'package:paradise/data/ai/provider_model.dart';
import 'package:paradise/data/ai_config.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/store.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Reproduction: sending a photo together with a caption must reach the model
/// as one request and finish the run. A timeout here is the "sends then the
/// app hangs" report; the fake adapter captures exactly what the wire sees.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory device;

  late _RecorderAdapter rec;

  setUp(() async {
    device = await Directory.systemTemp.createTemp('attach_send_test');
    SharedPreferences.resetStatic();
    // the legacy triple migrates into one provider plus a one node chain, the
    // same seam the app itself boots through
    SharedPreferences.setMockInitialValues({
      'base': 'https://example.test/v1',
      'key': 'k1',
      'model': 'vision-model',
    });
    rec = _RecorderAdapter();
    adapterOverride = (kind) => rec;
  });

  tearDown(() async {
    adapterOverride = null;
    try {
      await device.delete(recursive: true);
    } catch (_) {}
  });

  /// 1x1 red dot png
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );

  Future<Store> boot({bool blind = false}) async {
    final s = await Store.load(dbPath: p.join(device.path, 'paradise.db'));
    final ai = await AiConfig.load();
    // the chain model must advertise what it can take or the history rebuild
    // now (correctly) strips the bytes for a blind chain
    ai.update((s) {
      final node = s.chain.isEmpty ? null : s.chain.firstWhere((n) => n.enabled, orElse: () => s.chain.first);
      final target = node?.providerId ?? '';
      final models = [
        ModelMeta(id: 'vision-model', name: 'vision-model', contextWindow: 1000000, maxOutput: 8192, vision: !blind, textToImage: false, reasoning: false, source: ModelSource.manual, video: !blind),
      ];
      final providers = [
        for (final p in s.providers)
          if (p.id == target)
            Provider.defaults(id: p.id, name: p.name, kind: p.kind, baseUrl: p.baseUrl, models: models)
          else
            p,
      ];
      return s.copyWith(providers: providers);
    });
    s.attachAi(ai);
    return s;
  }

  ({Store store, Chat chat}) rig(Store s) {
    final chat = Chat(id: 'c1', persona: Persona(name: 'Her', prompt: 'x', color: 0));
    s.chats.add(chat);
    return (store: s, chat: chat);
  }

  test('photo with caption reaches the model and the run finishes', () async {
    final s = await boot();
    final r = rig(s);
    final img = File(p.join(device.path, 'pic.png'))..writeAsBytesSync(png);

    s.sendBatch(r.chat, [
      (kind: MsgKind.photo, data: {'path': img.path, 'name': 'pic.png'}, text: 'look at this'),
    ]);

    await rec.done.future;
    expect(rec.error, isNull, reason: 'run failed: ${rec.error} ${rec.log.join(' | ')}');
    expect(rec.seenText.join(), contains('look at this'), reason: rec.log.join('\n'));
    expect(rec.imageParts, 1, reason: 'the model must receive the image');
    var waited = 0;
    while (!r.chat.msgs.any((m) => !m.out && !m.service && m.text.isNotEmpty) && waited < 3000) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      waited += 100;
    }
    for (final m in r.chat.msgs) {
      // ignore: avoid_print
      print('FINAL kind=${m.kind} out=${m.out} state=${m.state} svc=${m.service} text=${m.text}');
    }
    expect(r.chat.msgs.any((m) => !m.out && !m.service && m.text.isNotEmpty), isTrue, reason: 'an answer landed');
  });

  test('video with caption reaches the model and the run finishes', () async {
    final s = await boot();
    final r = rig(s);
    final clip = File(p.join(device.path, 'clip.mp4'))..writeAsBytesSync(List<int>.filled(64 * 1024, 7));

    s.sendBatch(r.chat, [
      (kind: MsgKind.video, data: {'path': clip.path, 'name': 'clip.mp4', 'size': 64 * 1024, 'duration': 3}, text: 'watch this'),
    ]);

    await rec.done.future;
    var waited = 0;
    while (!r.chat.msgs.any((m) => !m.out && !m.service && m.text.isNotEmpty) && waited < 5000) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      waited += 100;
    }
    expect(rec.error, isNull, reason: 'run failed: ${rec.error} ${rec.log.join(' | ')}');
    expect(rec.seenText.join(), contains('watch this'));
    expect(rec.videoParts, 1, reason: 'the model must receive the video');
    expect(r.chat.msgs.any((m) => !m.out && !m.service && m.text.isNotEmpty), isTrue, reason: 'an answer landed');
  });

  test('photo without caption still works', () async {
    final s = await boot();
    final r = rig(s);
    final img = File(p.join(device.path, 'pic.png'))..writeAsBytesSync(png);

    s.sendBatch(r.chat, [
      (kind: MsgKind.photo, data: {'path': img.path, 'name': 'pic.png'}, text: ''),
    ]);

    await rec.done.future;
    expect(rec.error, isNull);
    expect(rec.imageParts, 1, reason: 'ran=${rec.streamRan} log=${rec.log.join(' | ')}');
  });

  test('a blind chain gets the placeholder text without the image bytes', () async {
    final s = await boot(blind: true);
    final r = rig(s);
    final img = File(p.join(device.path, 'pic.png'))..writeAsBytesSync(png);

    s.sendBatch(r.chat, [
      (kind: MsgKind.photo, data: {'path': img.path, 'name': 'pic.png'}, text: 'look at this'),
    ]);

    await rec.done.future;
    expect(rec.error, isNull);
    expect(rec.imageParts, 0, reason: 'a text-only chain must not receive image bytes');
    expect(rec.seenText.join(), contains('[Photo attached]'), reason: 'the placeholder line still describes the picture');
    expect(rec.seenText.join(), contains('look at this'));
  });
}

class _RecorderAdapter implements ProviderAdapter {
  final done = Completer<void>();
  final seenText = <String>[];
  final log = <String>[];
  var imageParts = 0;
  var videoParts = 0;
  var streamRan = false;
  Object? error;

  @override
  Stream<StreamChunk> stream(StreamRequest req) async* {
    streamRan = true;
    try {
      log.add('model=${req.model} turns=${req.messages.length} system=${req.system.length}');
      for (final t in req.messages) {
        log.add('turn ${t.role}: ${t.content.map((p) => p.runtimeType.toString()).join(',')}');
        for (final part in t.content) {
          switch (part) {
            case TextPart(:final text):
              seenText.add(text);
            case ImagePart():
              imageParts++;
            case VideoPart():
              videoParts++;
            default:
              break;
          }
        }
      }
      yield const StreamChunk.text('ok');
    } catch (e) {
      error = e;
      rethrow;
    } finally {
      if (!done.isCompleted) done.complete();
    }
  }
}
