import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/core/ui_kit.dart';
import 'package:paradise/data/ai_config.dart';
import 'package:paradise/data/oii/backup_archive.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// Long enough for the bulletin's own two second dismissal, which otherwise
/// outlives the test and is reported as a leaked timer.
Future<void> settleBulletin(WidgetTester t) => settle(t, 2600);

Finder icon(Ic ic) => find.byWidgetPredicate((w) => w is TgIcon && w.ic == ic);

/// The backup rows, on the storage page of settings.
///
/// The import side is exercised in backup_store_test.dart against a real store;
/// what matters here is that the rows sit where the user expects and that
/// export goes through the system save dialog rather than into the app's own
/// private directory, which a backup nobody can reach is not a backup.
void main() {
  late _FakePicker picker;

  setUp(() {
    picker = _FakePicker();
    FilePickerPlatform.instance = picker;
  });

  Future<(Store, AiConfig)> boot(WidgetTester t) async {
    SharedPreferences.setMockInitialValues({'chats': '[]'});
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 2.75;
    final store = await Store.load();
    final ai = await AiConfig.load();
    store.attachAi(ai);
    // the tests drive in-app screens, not the wizard
    store.onboarded = true;
    await t.pumpWidget(TgApp(store: store, ai: ai));
    await settle(t);
    return (store, ai);
  }

  Future<void> openStorage(WidgetTester t) async {
    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('Data and Storage'));
    await settle(t, 700);
  }

  testWidgets('the storage page offers both backup rows', (t) async {
    await boot(t);
    await openStorage(t);

    expect(find.text('Backup'), findsOneWidget, reason: 'the section header');
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Import from file'), findsOneWidget);
    expect(find.text('Conversations, cards, stickers and settings'), findsOneWidget);
    expect(find.text('From a file you exported before'), findsOneWidget);
  });

  testWidgets('export asks the system where to save and writes a real backup', (t) async {
    final (store, _) = await boot(t);
    store.createChat('Her', 'a persona').msgs.add(Msg(id: 'm1', out: false, text: 'hello', time: 1));

    await openStorage(t);
    await t.tap(find.text('Export'));
    await settleBulletin(t);

    expect(picker.calls, 1, reason: 'the save dialog was actually opened');
    expect(picker.fileName, matches(RegExp(r'^paradise-[0-9]{8}-[0-9]{4}[.]zip$')));
    expect(picker.mimeType, 'application/zip');

    final archive = parseBackupArchive(picker.bytes!);
    expect(archive.docs.keys.where((k) => k.startsWith('chats/')), hasLength(1));
    final chat = archive.docs.values.firstWhere((v) => v['id'] is String);
    expect(chat['msgs'], hasLength(1));
  });

  testWidgets('export with nothing to export still hands over a valid file', (t) async {
    await boot(t);
    await openStorage(t);
    await t.tap(find.text('Export'));
    await settleBulletin(t);

    expect(picker.calls, 1);
    expect(parseBackupArchive(picker.bytes!).docs.keys.where((k) => k.startsWith('chats/')), isEmpty);
  });

  testWidgets('backing out of the save dialog is not an error', (t) async {
    await boot(t);
    picker.result = null;
    await openStorage(t);
    await t.tap(find.text('Export'));
    await settleBulletin(t);

    expect(picker.calls, 1);
    // nothing claimed failure, and nothing said it was saved either
    expect(find.text('Backup saved'), findsNothing);
    expect(find.text('Could not save the file'), findsNothing);
  });
}

/// Records what the save dialog was handed and hands back a uri.
///
/// The bytes are kept rather than written anywhere, because the whole point of
/// the change is that the app no longer decides where a backup lands.
class _FakePicker extends FilePickerPlatform {
  int calls = 0;
  String? fileName;
  String? mimeType;
  Uint8List? bytes;

  /// null to simulate the user backing out of the dialog
  Uri? result = Uri.parse('content://com.android.providers.downloads.documents/document/backup');

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    calls++;
    this.fileName = fileName;
    this.mimeType = mimeType;
    this.bytes = bytes;
    return result;
  }

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async =>
      const <PlatformFile>[];
}
