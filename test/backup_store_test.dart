import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/ai_config.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Export then import, against a real store.
///
/// The format itself is covered in backup_test.dart. This is the half that can
/// only go wrong against a store: whether a restored chat is actually wired to
/// the store's change listener, and whether a credential leaks into the file.
void main() {
  // Store.load drives the theme controller, which schedules a frame
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A blank store.
  ///
  /// The default is not an empty set of chats: with no chats preference at all
  /// the store seeds its starter conversations, which is right for a real first
  /// launch and wrong for a test that wants nothing in the way. An explicit
  /// empty list is what a user who deleted everything would actually have.
  Future<(Store, AiConfig)> boot([Map<String, Object> prefs = const {'chats': '[]'}]) async {
    // Two things stand between a clean boot and a stale one. The store saves on
    // a debounce, so a store built a moment ago can still have a save in flight
    // that would land in the next mock. And getInstance hands back the same
    // cached instance for the life of the test, so setMockInitialValues on its
    // own changes nothing once anything has read a preference.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues(Map<String, Object>.from(prefs));
    final store = await Store.load();
    final ai = await AiConfig.load();
    store.attachAi(ai);
    return (store, ai);
  }

  test('a chat survives a round trip with its messages', () async {
    final (s, _) = await boot();
    final c = s.createChat('Her', 'a persona', bio: 'hello');
    c.msgs.add(Msg(id: 'm1', out: false, text: 'first', time: 1));
    c.msgs.add(Msg(id: 'm2', out: true, text: 'second', time: 2));
    c.pinned = true;
    c.draft = 'unsent';

    final raw = await s.exportBackupString();

    // a second install, nothing carried over
    final (fresh, _) = await boot({'dark': true, 'textSize': 22.0, 'chats': '[]'});
    expect(fresh.chats, isEmpty);

    final report = await fresh.importBackupString(raw, overwrite: true);
    expect(report.chats, 1);
    expect(report.messages, 2);
    expect(fresh.chats.single.persona.name, 'Her');
    expect(fresh.chats.single.persona.bio, 'hello');
    expect(fresh.chats.single.msgs.map((m) => m.text), ['first', 'second']);
    expect(fresh.chats.single.pinned, isTrue);
    expect(fresh.chats.single.draft, 'unsent');
  });

  test('settings come across, including the wallpaper colour', () async {
    final (s, _) = await boot();
    s.setTextSize(21);
    s.setRadius(24);
    s.setHaptics(false);
    s.setWallpaper('/docs/wallpapers/1_photo.jpg');
    s.setWallpaperColor(0xFFE91E63);
    s.setWallpaperBubbleGrad(2);
    final raw = await s.exportBackupString();

    final (fresh, _) = await boot();
    expect(fresh.textSize, 16, reason: 'a fresh install is at its own defaults');

    await fresh.importBackupString(raw, overwrite: true);
    expect(fresh.textSize, 21);
    expect(fresh.bubbleRadius, 24);
    expect(fresh.haptics, isFalse);
    expect(fresh.wallpaperPath, '/docs/wallpapers/1_photo.jpg');
    expect(fresh.wallpaperColor, 0xFFE91E63);
    expect(fresh.wallpaperBubbleGrad, 2);
  });

  test('a colour of zero in the file clears rather than setting black', () async {
    // the store treats 0 as absent on the way in, so a file written by a build
    // that stored it that way must not turn the accent black
    final (s, _) = await boot();
    final raw = (await s.exportBackupString()).replaceFirst('"wallpaperColor": null', '"wallpaperColor": 0');
    await s.importBackupString(raw, overwrite: true);
    expect(s.wallpaperColor, isNull);
  });

  test('an api key travels in the secrets section and comes back', () async {
    final (s, ai) = await boot();
    final provider = ai.settings.providers.first;
    ai.saveApiKey(provider.id, 'sk-secret-value-1234');
    s.setSetting(key: 'sk-secret-value-1234');

    final raw = await s.exportBackupString();
    expect(raw, contains('sk-secret-value-1234'));
    expect(raw, contains('"secrets"'));
    // the provider itself does come back too
    expect(raw, contains('apiKeyRef'));
  });

  test('the model configuration comes back with its keys', () async {
    final (s, ai) = await boot();
    ai.saveApiKey(ai.settings.providers.first.id, 'sk-abc');
    final raw = await s.exportBackupString();

    final (fresh, freshAi) = await boot();
    final report = await fresh.importBackupString(raw, overwrite: true);
    expect(report.ai, isTrue);
    expect(freshAi.settings.providers.map((p) => p.id), ai.settings.providers.map((p) => p.id));
    expect(freshAi.settings.chain.length, ai.settings.chain.length);
    expect(freshAi.apiKeys.values.where((k) => k == 'sk-abc'), isNotEmpty);
  });

  test('without overwrite an existing chat is not replaced', () async {
    final (s, _) = await boot();
    final c = s.createChat('Her', 'p');
    c.msgs.add(Msg(id: 'm1', out: false, text: 'original', time: 1));
    final raw = await s.exportBackupString();

    // the same conversation has moved on since the backup was taken
    c.msgs.add(Msg(id: 'm2', out: false, text: 'newer', time: 2));
    final report = await s.importBackupString(raw, overwrite: false);

    expect(report.chats, 0);
    expect(report.warnings.single, contains('already here'));
    expect(s.chats.single.msgs.map((m) => m.text), ['original', 'newer']);
  });

  test('a chat that will not parse costs only itself', () async {
    // the loader this replaces wrapped the whole list in one try and cleared it,
    // so one bad record used to cost every conversation in the file
    final (s, _) = await boot();
    s.createChat('Keep', 'p').msgs.add(Msg(id: 'm1', out: false, text: 'safe', time: 1));

    // valid json throughout, and a persona that is a string where an object
    // belongs, so the record only fails when it is turned back into a Chat
    final doc = jsonDecode(await s.exportBackupString()) as Map<String, dynamic>;
    final sections = doc['sections'] as Map<String, dynamic>;
    sections['chats'] = [
      ...(sections['chats'] as List),
      {'id': 'broken', 'persona': 'not an object', 'msgs': <dynamic>[]},
    ];

    final (fresh, _) = await boot();
    final report = await fresh.importBackupString(jsonEncode(doc), overwrite: true);

    expect(report.chats, 1, reason: 'the good conversation still arrived');
    expect(report.warnings.single, contains('broken'));
    expect(fresh.chats.single.persona.name, 'Keep');
    expect(fresh.chats.single.msgs.single.text, 'safe');
  });

  test('a restored chat is wired to the store so later edits are saved', () async {
    // a chat without the store's change listener changes on screen and never
    // reaches storage, which is exactly what createChat guards against
    final (s, _) = await boot();
    s.createChat('Her', 'p');
    final (fresh, _) = await boot();
    await fresh.importBackupString(await s.exportBackupString(), overwrite: true);

    final restored = fresh.chats.single;
    restored.msgs.add(Msg(id: 'm9', out: false, text: 'after restore', time: 9));

    // the store persists through the debounce
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chats') ?? '';
    expect(raw, contains('after restore'));
  });

  test('the wallet and the assistant settings ride along', () async {
    final (s, _) = await boot();
    s.human!.wallet.balance = 4321;
    s.human!.settings.enabled = false;
    s.human!.changed();
    final raw = s.exportBackupString();

    final (fresh, _) = await boot();
    expect(fresh.human!.wallet.balance, 1000, reason: 'a fresh install starts at its own default');

    final report = fresh.importBackupString(raw, overwrite: true);
    expect(report.wallet, isTrue);
    expect(report.human, isTrue);
    expect(fresh.human!.wallet.balance, 4321);
    expect(fresh.human!.settings.enabled, isFalse, reason: 'the assistant settings came back too');
  });
}