import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

// Builds the rust cdylib in native/ with cargo. The NDK is found through
// ANDROID_NDK_HOME or the sdkmanager layout flutter installs, a cargo
// toolchain with the android target is assumed present on build machines.

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final code = input.config.code;

    final target = _target(code);
    if (target == null) {
      // desktop still goes through the same bridge but is not wired yet;
      // fail loudly rather than ship a missing asset
      throw UnsupportedError(
          'oii_bridge: no cargo target for ${code.targetOS} ${code.targetArchitecture}');
    }

    final cc = _ccFor(target, code);
    final ar = _arFor(code);
    final tripleVar = target.replaceAll('-', '_');
    // On an ARM64 Linux host the NDK r28 x86_64 lld runs under emulation and
    // crashes while linking this cdylib (free(): invalid next size). The native
    // host lld can cross-link Android objects correctly: NDK clang still
    // supplies its sysroot, only the final linker is replaced. Keep the
    // regular NDK linker on x86_64 builders.
    final hostLld = code.targetOS == OS.android ? _nativeLldForArmHost() : null;
    final env = <String, String>{
      ...Platform.environment,
      if (cc != null) 'CC_$target': cc,
      if (ar != null) 'AR_$target': ar,
      if (cc != null) 'CARGO_TARGET_${tripleVar.toUpperCase()}_LINKER': cc,
      if (hostLld != null)
        'RUSTFLAGS': '${Platform.environment['RUSTFLAGS'] ?? ''} -C link-arg=-fuse-ld=$hostLld'.trim(),
    };

    // CodeConfig has no Flutter build-mode field. Default to fast debug builds;
    // release (with LTO from Cargo.toml) must be explicitly requested with
    // hooks.user_defines.oii_bridge.profile: release.
    final profile = input.userDefines['profile']?.toString() ?? 'debug';
    if (profile != 'debug' && profile != 'release') {
      throw ArgumentError.value(
          profile, 'profile', 'expected debug or release');
    }
    final dir = input.packageRoot.resolve('native/');
    // a fixed target dir keeps the hook's copy step predictable and stops
    // the package root from growing a second target dir when flutter and a
    // manual cargo build share the tree
    final cargoDir = input.userDefines['cargoTargetDir']?.toString() ??
        '${dir.toFilePath()}target';
    final env2 = {
      ...env,
      'CARGO_TARGET_DIR': cargoDir,
    };
    final result = await Process.run(
      _cargo(),
      ['build', '--target', target, if (profile == 'release') '--release'],
      workingDirectory: dir.toFilePath(),
      environment: env2,
      runInShell: Platform.isWindows,
    );
    if (result.exitCode != 0) {
      throw StateError(
          'cargo failed (${result.exitCode}):\n${result.stdout}\n${result.stderr}');
    }

    final libName = 'liboii_bridge.so';
    final built = input.outputDirectoryShared
        .resolve('libbridge/$target/$profile/$libName');
    final cargoOut = File(
        '$cargoDir/$target/${profile == 'release' ? 'release' : 'debug'}/$libName');
    if (!cargoOut.existsSync()) {
      throw StateError('cargo produced no $libName at ${cargoOut.path}');
    }
    final dest = File.fromUri(built);
    await dest.parent.create(recursive: true);
    await cargoOut.copy(dest.path);

    // the rust sources are hook inputs: without this the runner serves the
    // cached asset after a native/ edit and the app links a stale .so
    final nativeDir = Directory(dir.toFilePath());
    await for (final entity
        in nativeDir.list(recursive: true, followLinks: false)) {
      if (entity is File &&
          (entity.path.endsWith('.rs') ||
              entity.path.endsWith('.toml') ||
              entity.path.endsWith('.lock'))) {
        output.dependencies.add(entity.uri);
      }
    }

    output.assets.code.add(
      CodeAsset(
        package: 'oii_bridge',
        name: 'oii_bridge.dart',
        linkMode: DynamicLoadingBundled(),
        file: built,
      ),
    );
  });
}

String? _nativeLldForArmHost() {
  if (!Platform.isLinux) return null;
  final arch = Process.runSync('uname', ['-m']);
  if (arch.exitCode != 0 || '${arch.stdout}'.trim() != 'aarch64') return null;
  const linker = '/usr/bin/ld.lld';
  return File(linker).existsSync() ? linker : null;
}

String? _target(CodeConfig code) {
  if (code.targetOS == OS.android) {
    return switch (code.targetArchitecture) {
      Architecture.arm64 => 'aarch64-linux-android',
      Architecture.arm => 'armv7-linux-androideabi',
      Architecture.x64 => 'x86_64-linux-android',
      _ => null,
    };
  }
  // host builds for tests: cargo targets the running machine
  if (code.targetOS == OS.linux) {
    return switch (code.targetArchitecture) {
      Architecture.arm64 => 'aarch64-unknown-linux-gnu',
      Architecture.x64 => 'x86_64-unknown-linux-gnu',
      _ => null,
    };
  }
  return null;
}

String? _ccFor(String target, CodeConfig code) {
  if (code.targetOS == OS.android) {
    final ndk = _ndkRoot();
    if (ndk == null) return null;
    // api matches what the app declares; the NDK ships a wrapper per api
    final api = code.android.targetNdkApi;
    final triple = switch (target) {
      'aarch64-linux-android' => 'aarch64-linux-android$api',
      'armv7-linux-androideabi' => 'armv7a-linux-androideabi$api',
      'x86_64-linux-android' => 'x86_64-linux-android$api',
      _ => target,
    };
    final hostTag = Platform.isWindows
        ? 'windows-x86_64'
        : (Platform.isMacOS ? 'darwin-x86_64' : 'linux-x86_64');
    return '$ndk/toolchains/llvm/prebuilt/$hostTag/bin/$triple-clang';
  }
  // host toolchain: cargo picks up the system cc on its own
  return null;
}

String? _arFor(CodeConfig code) {
  if (code.targetOS != OS.android) return null;
  final ndk = _ndkRoot();
  if (ndk == null) return null;
  final hostTag = Platform.isWindows
      ? 'windows-x86_64'
      : (Platform.isMacOS ? 'darwin-x86_64' : 'linux-x86_64');
  return '$ndk/toolchains/llvm/prebuilt/$hostTag/bin/llvm-ar';
}

String? _ndkRoot() {
  final env = Platform.environment['ANDROID_NDK_HOME'] ??
      Platform.environment['ANDROID_NDK_ROOT'];
  if (env != null && Directory(env).existsSync()) return env;
  final home = Platform.environment['ANDROID_HOME'] ??
      '${Platform.environment['HOME']}/Android/Sdk';
  final ndkDir = Directory('$home/ndk');
  if (!ndkDir.existsSync()) return null;
  final versions = ndkDir.listSync().whereType<Directory>().toList()
    ..sort((a, b) => b.path.compareTo(a.path));
  return versions.isEmpty ? null : versions.first.path;
}

/// Which cargo to run. Respects the CARGO env convention, then prefers a
/// rustup-managed cargo (which is where the android std targets live) over
/// whatever `cargo` resolves to on PATH. A distro cargo without rustup
/// cannot have android targets installed at all, so falling back to it only
/// makes sense when no rustup exists.
String _cargo() {
  final fromEnv = Platform.environment['CARGO'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  final home = Platform.environment['HOME'];
  if (home != null) {
    final rustupCargo = File('$home/.cargo/bin/cargo');
    try {
      if (rustupCargo.existsSync()) return rustupCargo.path;
    } catch (_) {}
  }
  return 'cargo';
}
