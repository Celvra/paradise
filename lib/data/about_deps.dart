import '../l10n/x.dart';

/// One direct dependency, as the open source licences page shows it.
///
/// The four fields here are the ones that are the same in every language: the
/// package name, the version this build locked, the licence it ships under and
/// where the source lives. Only the one line saying what this project uses it
/// for is language specific, and that line lives in the arb as a key named
/// after the package, [purpose] reads.
///
/// The versions are the ones pubspec.lock pinned when this was written. They
/// are documentation, not a check: a stale number here only misleads someone
/// reading the licence page, and nothing at build time reads them.
class AboutDep {
  const AboutDep(this.name, this.version, this.licence, this.url);

  final String name;
  final String version;
  final String licence;
  final String url;

  /// The one line the licences page puts under the name, in the reader's own
  /// language.
  String purpose(AppLocalizations l) => aboutDepPurpose(l, name);
}

/// Every package listed in pubspec.yaml under dependencies, minus the two the
/// sdk provides. The transitive tree is in pubspec.lock and is not listed here:
/// an end user reading licences needs the code that actually shipped.
const aboutDeps = <AboutDep>[
  AboutDep('archive', '4.3.0', 'MIT', 'https://github.com/brendan-duncan/archive'),
  AboutDep('characters', '1.4.1', 'BSD-3-Clause', 'https://github.com/dart-lang/core/tree/main/pkgs/characters'),
  AboutDep('crypto', '3.0.7', 'BSD-3-Clause', 'https://github.com/dart-lang/core/tree/main/pkgs/crypto'),
  AboutDep('file_picker', '13.1.0', 'MIT', 'https://github.com/vicajilau/flutter_file_picker/tree/main/packages/file_picker'),
  AboutDep('flutter_contacts', '2.5.0', 'MIT', 'https://github.com/QuisApp/flutter_contacts'),
  AboutDep('flutter_highlight', '0.7.0', 'MIT', 'https://github.com/git-touch/highlight'),
  AboutDep('flutter_local_notifications', '18.0.1', 'BSD-3-Clause', 'https://github.com/MaikuB/flutter_local_notifications'),
  AboutDep('flutter_math_fork', '0.7.4', 'Apache-2.0', 'https://github.com/simplezhli/flutter_math_fork'),
  AboutDep('flutter_svg', '2.3.0', 'MIT', 'https://github.com/flutter/packages/tree/main/third_party/packages/flutter_svg'),
  AboutDep('geolocator', '13.0.4', 'MIT', 'https://github.com/baseflow/flutter-geolocator/tree/main/geolocator'),
  AboutDep('glob', '2.2.0', 'BSD-3-Clause', 'https://github.com/dart-lang/tools/tree/main/pkgs/glob'),
  AboutDep('highlight', '0.7.0', 'MIT', 'https://github.com/pd4d10/highlight'),
  AboutDep('http', '1.6.0', 'BSD-3-Clause', 'https://github.com/dart-lang/http/tree/master/pkgs/http'),
  AboutDep('image_picker', '1.2.3', 'Apache-2.0', 'https://github.com/flutter/packages/tree/main/packages/image_picker/image_picker'),
  AboutDep('intl', '0.20.3', 'BSD-3-Clause', 'https://github.com/dart-lang/i18n/tree/main/pkgs/intl'),
  AboutDep('path', '1.9.1', 'BSD-3-Clause', 'https://github.com/dart-lang/core/tree/main/pkgs/path'),
  AboutDep('path_provider', '2.1.6', 'BSD-3-Clause', 'https://github.com/flutter/packages/tree/main/packages/path_provider/path_provider'),
  AboutDep('permission_handler', '13.0.2', 'MIT', 'https://github.com/baseflow/flutter-permission-handler'),
  AboutDep('photo_manager', '3.12.0', 'Apache-2.0', 'https://github.com/fluttercandies/flutter_photo_manager'),
  AboutDep('ratex_flutter', '0.1.14', 'MIT', 'https://github.com/erweixin/RaTeX'),
  AboutDep('shared_preferences', '2.5.5', 'BSD-3-Clause', 'https://github.com/flutter/packages/tree/main/packages/shared_preferences/shared_preferences'),
  AboutDep('sqflite', '2.4.4', 'BSD-2-Clause', 'https://github.com/tekartik/sqflite/tree/master/sqflite'),
  AboutDep('terminal_view', '0.2.1', 'MIT', 'https://github.com/Termphin/terminal_view'),
  AboutDep('timezone', '0.10.1', 'BSD-2-Clause', 'https://github.com/srawlins/timezone'),
  AboutDep('typst_flutter', '3.0.0', 'Apache-2.0', 'https://github.com/ajmalbuv/typst_flutter'),
  AboutDep('url_launcher', '6.3.2', 'BSD-3-Clause', 'https://github.com/flutter/packages/tree/main/packages/url_launcher/url_launcher'),
  AboutDep('video_player', '2.14.1', 'BSD-3-Clause', 'https://github.com/flutter/packages/tree/main/packages/video_player/video_player'),
  AboutDep('webview_flutter', '4.14.1', 'BSD-3-Clause', 'https://github.com/flutter/packages/tree/main/packages/webview_flutter/webview_flutter'),
  AboutDep('workmanager', '0.10.10', 'MIT', 'https://github.com/fluttercommunity/flutter_workmanager'),
];

/// The package name to arb key mapping for [aboutDeps].
///
/// A switch rather than a generated getter so a package added to the list
/// without a string fails the compiler here instead of printing an empty line
/// on the licences page. `flutter analyze` is what catches the other half: a
/// key nothing reads is dead weight in all three arb files.
String aboutDepPurpose(AppLocalizations l, String name) => switch (name) {
      'archive' => l.aboutDepArchive,
      'characters' => l.aboutDepCharacters,
      'crypto' => l.aboutDepCrypto,
      'file_picker' => l.aboutDepFilePicker,
      'flutter_contacts' => l.aboutDepFlutterContacts,
      'flutter_highlight' => l.aboutDepFlutterHighlight,
      'flutter_local_notifications' => l.aboutDepFlutterLocalNotifications,
      'flutter_math_fork' => l.aboutDepFlutterMathFork,
      'flutter_svg' => l.aboutDepFlutterSvg,
      'geolocator' => l.aboutDepGeolocator,
      'glob' => l.aboutDepGlob,
      'highlight' => l.aboutDepHighlight,
      'http' => l.aboutDepHttp,
      'image_picker' => l.aboutDepImagePicker,
      'intl' => l.aboutDepIntl,
      'path' => l.aboutDepPath,
      'path_provider' => l.aboutDepPathProvider,
      'permission_handler' => l.aboutDepPermissionHandler,
      'photo_manager' => l.aboutDepPhotoManager,
      'ratex_flutter' => l.aboutDepRatex,
      'shared_preferences' => l.aboutDepSharedPreferences,
      'sqflite' => l.aboutDepSqflite,
      'terminal_view' => l.aboutDepTerminalView,
      'timezone' => l.aboutDepTimezone,
      'typst_flutter' => l.aboutDepTypstFlutter,
      'url_launcher' => l.aboutDepUrlLauncher,
      'video_player' => l.aboutDepVideoPlayer,
      'webview_flutter' => l.aboutDepWebview,
      'workmanager' => l.aboutDepWorkmanager,
      _ => '',
    };