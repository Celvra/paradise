import 'dart:convert';
import 'dart:typed_data';


import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/ui/tg_cells.dart';
import 'package:paradise/data/ai_config.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// Past the bulletin's own two second dismissal, which otherwise outlives the
/// test and is reported as a leaked timer.
Future<void> settleBulletin(WidgetTester t) => settle(t, 2600);

/// The sticker and memory exports.
///
/// They were written into the app's private documents directory, which the user
/// cannot reach: a file they cannot open, attach or sync is not a backup. This
/// checks they now go through the system save dialog instead.
void main() {
  late _FakePicker picker;

  setUp(() {
    picker = _FakePicker();
    FilePickerPlatform.instance = picker;
  });

  Future<Store> boot(WidgetTester t) async {
    SharedPreferences.setMockInitialValues({'chats': '[]'});
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 2.75;
    final store = await Store.load();
    final ai = await AiConfig.load();
    store.attachAi(ai);
    await t.pumpWidget(TgApp(store: store, ai: ai));
    await settle(t);
    await t.tap(find.text('Settings').last);
    await settle(t, 800);
    await t.tap(find.text('Humanize'));
    await settle(t, 800);
    return store;
  }

  Future<void> openBackup(WidgetTester t) async {
    final row = find.text('Backup and import');
    // the row sits below the fold on a short test viewport
    await t.ensureVisible(row);
    await settle(t, 400);
    await t.tap(row);
    await settle(t, 800);
  }

  Finder exportRow() => find.widgetWithText(TgTextCell, 'Export');

  testWidgets('the page offers an export for stickers and one for memory', (t) async {
    await boot(t);
    await openBackup(t);
    expect(exportRow(), findsNWidgets(2));
  });

  testWidgets('the sticker export goes through the save dialog', (t) async {
    await boot(t);
    await openBackup(t);

    await t.tap(exportRow().first);
    await settleBulletin(t);

    expect(picker.calls, 1);
    expect(picker.fileName, matches(RegExp(r'^stickers-\d{8}-\d{4}\.json$')));
    expect(picker.mimeType, 'application/json');
    expect(utf8.decode(picker.bytes!), contains('lib3.stickers'));
  });

  testWidgets('the memory export goes through the save dialog', (t) async {
    await boot(t);
    await openBackup(t);

    await t.tap(exportRow().at(1));
    await settleBulletin(t);

    expect(picker.calls, 1);
    expect(picker.fileName, matches(RegExp(r'^memory-\d{8}-\d{4}\.json$')));
    expect(utf8.decode(picker.bytes!), contains('lib3.memory'));
  });

  testWidgets('backing out of the save dialog says nothing', (t) async {
    await boot(t);
    picker.result = null;
    await openBackup(t);

    await t.tap(exportRow().first);
    await settleBulletin(t);

    expect(picker.calls, 1);
    expect(find.text('Saved and copied'), findsNothing);
    expect(find.text('Copied to the clipboard'), findsNothing);
  });
}

/// Records what the save dialog was handed instead of letting it reach Android.
class _FakePicker extends FilePickerPlatform {
  int calls = 0;
  String? fileName;
  String? mimeType;
  Uint8List? bytes;

  /// null to simulate the user backing out of the dialog
  Uri? result = Uri.parse('content://com.android.providers.downloads.documents/document/export');

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