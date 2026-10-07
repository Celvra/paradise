import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/backup_archive.dart' show BackupAsset, buildBackupZip;
import 'package:paradise/data/human/sticker_lib.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/oii/backup_archive.dart';
import 'package:paradise/data/store.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'fake_paths.dart';

/// End to end over the v2 archive: referenced asset files ride in the zip,
/// paths are rewritten to relative entries on export and back to real files
/// on import, and the previously unbacked state (wallet, tasks, stickers)
/// survives the trip.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory device;

  setUp(() async {
    device = await Directory.systemTemp.createTemp('backup_archive_store');
    PathProviderPlatform.instance = FakePathProvider(device.path);
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    try {
      await device.delete(recursive: true);
    } catch (_) {}
  });

  Future<Store> boot(String name, String docsName) async {
    final s = await Store.load(dbPath: p.join(device.path, '$name.db'));
    s.debugBackupDocsDir = Directory(p.join(device.path, docsName));
    await s.debugBackupDocsDir!.create(recursive: true);
    return s;
  }

  Future<String> putFile(Directory docs, String name, List<int> bytes) async {
    final f = File(p.join(docs.path, name));
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  test('export packs assets, import restores them onto a fresh device', () async {
    final a = await boot('a', 'docsA');
    final docsA = a.debugBackupDocsDir!;

    // every previously unbacked asset kind, each a real file on disk
    final avatarPath = await putFile(docsA, 'her.png', [10, 20, 30]);
    final wallPath = await putFile(docsA, 'wall.png', [40, 50]);
    final picPath = await putFile(docsA, 'pic.jpg', [60, 70, 80]);
    final stickerPath = await putFile(docsA, 'meme.png', [90]);
    final thumbPath = await putFile(docsA, 'meme_thumb.png', [91]);

    final chat = Chat(
      id: 'c1',
      persona: Persona(name: 'Her', prompt: 'x', color: 0, avatarPath: avatarPath),
    );
    chat.msgs.add(Msg(id: 'm1', out: true, text: '', time: 1, kind: MsgKind.photo, data: {'path': picPath, 'name': 'pic.jpg'}));
    chat.msgs.add(Msg(id: 'm2', out: true, text: '', time: 2, kind: MsgKind.gift, data: {'item': 'energy', 'title': '能量饮料', 'effect': '+30'}));
    a.chats.add(chat);
    a.setWallpaper(wallPath);
    a.human!.stickers.add(kind: StickerKind.image, value: stickerPath, name: 'meme', thumb: thumbPath);
    a.human!.wallet.balance = 88.5;
    a.human!.scheduler.schedule(chatId: 'c1', delayMs: 60000, prompt: 'check in');

    final bytes = await a.exportBackupArchive();
    expect(looksLikeZip(bytes), isTrue);

    final parsed = parseBackupArchive(bytes);
    expect(parsed.missing, isEmpty, reason: 'every referenced file exists');
    expect(parsed.assets.length, 5, reason: 'avatar, wallpaper, photo, sticker, thumb');
    final chatDoc = parsed.docs['chats/${safeChatFileName('c1')}.oii']!;
    expect((chatDoc['persona'] as Map)['avatarPath'], startsWith('files/'));
    final firstMsgData = ((chatDoc['msgs'] as List).first as Map)['data'] as Map;
    expect(firstMsgData['path'], startsWith('files/'));
    expect(parsed.docs['settings.oii']!['wallpaperPath'], startsWith('files/'));
    expect(parsed.docs['human.oii'], isNotNull);
    expect((parsed.docs['human.oii']!['wallet'] as Map)['balance'], 88.5);

    // a fresh device: new database, new docs dir, wiped prefs
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final b = await boot('b', 'docsB');
    final report = await b.importBackupArchive(bytes, overwrite: true);
    expect(report.warnings, isEmpty);
    expect(report.chats, 1);
    expect(report.files, 5);

    final rc = b.chats.singleWhere((c) => c.id == 'c1');
    expect(rc.msgs.where((m) => m.kind == MsgKind.gift), hasLength(1));
    final photo = rc.msgs.firstWhere((m) => m.kind == MsgKind.photo);
    final restoredPic = photo.data['path'] as String;
    expect(restoredPic, startsWith(p.join(device.path, 'docsB')));
    expect(await File(restoredPic).readAsBytes(), [60, 70, 80]);
    expect(await File(rc.persona.avatarPath).readAsBytes(), [10, 20, 30]);
    expect(b.wallpaperPath, startsWith(p.join(device.path, 'docsB')));
    expect(b.human!.stickers.items.any((s) => s.name == 'meme'), isTrue);
    final restoredSticker = b.human!.stickers.items.firstWhere((s) => s.name == 'meme');
    expect(await File(restoredSticker.value).exists(), isTrue);
    expect(b.human!.wallet.balance, 88.5);
    expect(b.human!.scheduler.tasks, hasLength(1));
  });

  test('missing files are warnings, not failures', () async {
    final a = await boot('a', 'docsA');
    a.chats.add(Chat(id: 'c1', persona: Persona(name: 'Her', prompt: 'x', color: 0, avatarPath: '/gone/avatar.png')));
    final bytes = await a.exportBackupArchive();
    final parsed = parseBackupArchive(bytes);
    expect(parsed.missing, ['/gone/avatar.png']);

    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final b = await boot('b', 'docsB');
    final report = await b.importBackupArchive(bytes, overwrite: true);
    expect(report.chats, 1);
    expect(report.warnings.any((w) => w.contains('/gone/avatar.png')), isTrue);
    // the dangling path stays as-is, exactly like the v1 behaviour
    expect(b.chats.single.persona.avatarPath, '/gone/avatar.png');
  });

  test('mainline backup.json ZIP and its assets still import', () async {
    final a = await boot('legacy', 'docsLegacy');
    const avatar = '/old-phone/picture.png';
    a.chats.add(Chat(id: 'c1', persona: Persona(name: 'Her', prompt: 'x', color: 0, avatarPath: avatar)));
    final oldZip = buildBackupZip(json: a.exportBackupString(), assets: [BackupAsset(orig: avatar, data: Uint8List.fromList([5, 6, 7]))]);
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final b = await boot('fresh', 'docsFresh');
    final report = await b.importBackupArchive(oldZip, overwrite: true);
    expect(report.chats, 1);
    expect(await File(b.chats.single.persona.avatarPath).readAsBytes(), [5, 6, 7]);
  });

  test('v1 json bytes still import', () async {
    final a = await boot('a', 'docsA');
    a.chats.add(Chat(id: 'c1', persona: Persona(name: 'Her', prompt: 'x', color: 0)));
    final legacy = a.exportBackupString();
    expect(looksLikeZip(Uint8List.fromList(utf8.encode(legacy))), isFalse);

    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    final b = await boot('b', 'docsB');
    final report = await b.importBackupArchive(Uint8List.fromList(utf8.encode(legacy)), overwrite: true);
    expect(report.chats, 1);
    expect(b.chats.where((c) => c.id == 'c1'), hasLength(1));
  });
}
