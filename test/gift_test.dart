import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/ai/adapter.dart';
import 'package:paradise/data/ai/adapters.dart';
import 'package:paradise/data/ai/content.dart';
import 'package:paradise/data/ai_config.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/store.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A shop purchase must do two things at once: the effect really lands on the
/// persona state, and a gift card goes out as the user's message so the model
/// hears about it and answers it instead of the purchase being silent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory device;
  late _RecorderAdapter rec;

  setUp(() async {
    device = await Directory.systemTemp.createTemp('gift_test');
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({
      'base': 'https://example.test/v1',
      'key': 'k1',
      'model': 'm1',
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

  Future<Store> boot() async {
    final s = await Store.load(dbPath: p.join(device.path, 'paradise.db'));
    final ai = await AiConfig.load();
    s.attachAi(ai);
    return s;
  }

  test('sendGift applies the effect, posts a gift card and the model is told', () async {
    final s = await boot();
    final chat = Chat(id: 'c1', persona: Persona(name: 'Her', prompt: 'x', color: 0));
    s.chats.add(chat);
    final before = chat.human.affection;

    s.sendGift(chat, itemId: 'affection', title: '心动加速器', effect: '+10 affection');

    expect(chat.human.affection, before + 10, reason: 'the effect must land on the persona state');
    final gift = chat.msgs.where((m) => m.kind == MsgKind.gift).toList();
    expect(gift, hasLength(1), reason: 'one gift card goes out');
    expect(gift.single.out, isTrue);
    expect(gift.single.data['title'], '心动加速器');

    await rec.done.future;
    expect(rec.error, isNull, reason: 'run failed: ${rec.error}');
    expect(rec.seenText.join(), contains('[Gift: 心动加速器'), reason: 'the model must be told what arrived');
    expect(rec.seenText.join(), contains('+10 affection'));

    var waited = 0;
    while (!chat.msgs.any((m) => !m.out && !m.service && m.text.isNotEmpty) && waited < 3000) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      waited += 100;
    }
    expect(chat.msgs.any((m) => !m.out && !m.service && m.text.isNotEmpty), isTrue, reason: 'the model answers the gift');
  });

  test('gift preview carries the item title without needing text', () {
    final m = Msg(
      id: 'g1',
      out: true,
      text: '',
      time: 0,
      kind: MsgKind.gift,
      data: {'title': '能量饮料', 'effect': '+30 energy'},
    );
    expect(m.preview, '能量饮料');
  });

  test('gift survives a json round trip, so a restart keeps the card', () {
    final m = Msg(
      id: 'g1',
      out: true,
      text: '',
      time: 123,
      kind: MsgKind.gift,
      data: {'item': 'energy', 'title': '能量饮料', 'effect': '+30 energy'},
    );
    final back = Msg.fromJson(Map<String, dynamic>.from(m.toJson()));
    expect(back.kind, MsgKind.gift, reason: 'fromJson must not downgrade gift to text');
    expect(back.preview, '能量饮料');
    expect(back.data['effect'], '+30 energy');
  });

  test('gift survives a store reload from the same database', () async {
    final dbPath = p.join(device.path, 'paradise.db');
    final s = await boot();
    final chat = Chat(id: 'c1', persona: Persona(name: 'Her', prompt: 'x', color: 0));
    s.chats.add(chat);
    s.sendGift(chat, itemId: 'energy', title: '能量饮料', effect: '+30 energy');
    await rec.done.future;
    // let the debounced save land, then boot again from the same file
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final s2 = await Store.load(dbPath: dbPath);
    final reloaded = s2.chats.where((c) => c.id == 'c1').toList();
    expect(reloaded, hasLength(1));
    final gifts = reloaded.single.msgs.where((m) => m.kind == MsgKind.gift).toList();
    expect(gifts, hasLength(1), reason: 'the gift card must still be a gift after restart');
    expect(gifts.single.preview, '能量饮料');
  });
}

class _RecorderAdapter implements ProviderAdapter {
  final done = Completer<void>();
  final seenText = <String>[];
  Object? error;

  @override
  Stream<StreamChunk> stream(StreamRequest req) async* {
    try {
      for (final t in req.messages) {
        for (final part in t.content) {
          if (part is TextPart) seenText.add(part.text);
        }
      }
      yield const StreamChunk.text('thank you!');
    } catch (e) {
      error = e;
      rethrow;
    } finally {
      if (!done.isCompleted) done.complete();
    }
  }
}
