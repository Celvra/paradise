import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Points path_provider at a directory the test owns.
///
/// The alternative is the method channel, which needs the real channel name
/// from whichever platform implementation happens to be in the tree. This is
/// the seam the interface exists for.
class FakePathProvider extends PathProviderPlatform {
  FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationCachePath() async => '$root/cache';

  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';

  @override
  Future<String?> getExternalStoragePath() async => root;
}

/// Installs [provider] for the duration of the test and returns the directory it
/// was pointed at, created if missing.
Future<Directory> useTempDocsDir(String name) async {
  final dir = await Directory.systemTemp.createTemp(name);
  PathProviderPlatform.instance = FakePathProvider(dir.path);
  return dir;
}