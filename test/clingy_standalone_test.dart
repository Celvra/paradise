import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/ai/adapter.dart';
import 'package:paradise/data/ai/adapters.dart';
import 'package:paradise/data/ai/provider_model.dart';
import 'package:paradise/data/ai_config.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/store.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Standalone clingy: the check-in must fire for a normal (non-humanized)
/// chat when the silence runs past the persona's interval, honour the cap,
/// and rest the clock after firing. This is the "粘人度 never speaks" report.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory device;
  late _CountingAdapter rec;

  setUp(() async {
    device = await Directory.systemTemp.createTemp('clingy_standalone_test');
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({
      'base': 'https://example.test/v1',
      'key': 'k1',
      'model': 'vision-model',
    });
    rec = _CountingAdapter();
    adapterOverride = (kind) => rec;
  });

  tearDown(() async {
    adapterOverride = null;
    try {
      await device.delete(recursive: true);
    } catch (_) {}
  });

  Future<Store> boot() async {
    final s = await Store.load(dbPath: p.join(device.path, 'paradise.db'));
    final ai = await AiConfig.load();
    ai.update((s) {
      final node = s.chain.isEmpty ? null : s.chain.firstWhere((n) => n.enabled, orElse: () => s.chain.first);
      final target = node?.providerId ?? '';
      final models = [
        ModelMeta(id: 'vision-model', name: 'vision-model', contextWindow: 1000000, maxOutput: 8192, vision: true, textToImage: false, reasoning: false, source: ModelSource.manual),
      ];
      return s.copyWith(providers: [
        for (final p in s.providers)
          if (p.id == target)
            Provider.defaults(id: p.id, name: p.name, kind: p.kind, baseUrl: p.baseUrl, models: models)
          else
            p,
      ]);
    });
    s.attachAi(ai);
    return s;
  }

  ({Store store, Chat chat}) quietChat(Store s, {bool cap = false, int max = 3}) {
    final chat = Chat(
      id: 'c1',
      persona: Persona(name: 'Her', prompt: 'x', color: 0, clingy: true, clingySilentMin: 1, clingyCap: cap, clingyMax: max),
    );
    s.chats.add(chat);
    chat.msgs.add(Msg(id: 'm1', out: true, text: 'hi', time: DateTime.now().millisecondsSinceEpoch - 61000));
    // the standalone path is what a normal (non-humanized) chat runs on
    s.human!.settings.enabled = false;
    return (store: s, chat: chat);
  }

  test('a quiet clingy chat gets one check-in per silence period', () async {
    final s = await boot();
    final r = quietChat(s);

    await s.humanTick();

    await rec.done.future;
    var waited = 0;
    while (!r.chat.msgs.any((m) => !m.out && !m.service && m.text.isNotEmpty) && waited < 5000) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      waited += 100;
    }
    expect(rec.streams, 1, reason: 'exactly one model run for the check-in');
    expect(r.chat.msgs.any((m) => !m.out && !m.service && m.text.isNotEmpty), isTrue, reason: 'the check-in landed');
    expect(r.chat.human.lastAiAt, greaterThan(0), reason: 'the marker that paces the next check-in');

    // the marker restarts the silence clock: another tick right away fires nothing
    await s.humanTick();
    expect(rec.streams, 1);
  });

  test('the cap blocks further proactive bubbles until the user speaks', () async {
    final s = await boot();
    final r = quietChat(s, cap: true, max: 1);

    await s.humanTick();
    await rec.done.future;
    var waited = 0;
    while (!r.chat.msgs.any((m) => !m.out && !m.service && m.text.isNotEmpty) && waited < 5000) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      waited += 100;
    }
    expect(rec.streams, 1);

    // simulate a reboot that lost the marker but kept the transcript: the cap
    // alone must still stop a second nudge while the user stays silent
    r.chat.human.lastAiAt = 0;
    r.chat.msgs
      ..clear()
      ..add(Msg(id: 'm1', out: true, text: 'hi', time: DateTime.now().millisecondsSinceEpoch - 61000))
      ..add(Msg(id: 'm2', out: false, text: 'missed you', time: DateTime.now().millisecondsSinceEpoch - 60000));
    await s.humanTick();
    expect(rec.streams, 1, reason: 'one proactive bubble is the cap');
  });
}

class _CountingAdapter implements ProviderAdapter {
  final done = Completer<void>();
  var streams = 0;

  @override
  Stream<StreamChunk> stream(StreamRequest req) async* {
    streams++;
    yield const StreamChunk.text('missed you');
    if (!done.isCompleted) done.complete();
  }
}
