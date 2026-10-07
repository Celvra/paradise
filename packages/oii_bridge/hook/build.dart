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

    final cc = _ccFor(target, code, input.packageRoot);
    final ar = _arFor(code, input.packageRoot);
    final tripleVar = target.replaceAll('-', '_');
    // On an ARM64 Linux host the NDK r28 x86_64 lld runs under emulation and
    // crashes while linking this cdylib (free(): invalid next size). The native
    // host lld can cross-link Android objects correctly: NDK clang still
    // supplies its sysroot, only the final linker is replaced. Keep the
    // regular NDK linker on x86_64 builders.
    final hostLld = code.targetOS == OS.android ? _nativeLldForArmHost() : null;
    final tripleU = tripleVar.toUpperCase();
    final clangFlag = _clangTargetFlag(target, code);
    final env = <String, String>{
      ...Platform.environment,
      // cc-rs looks the compiler up under the underscored triple; the dashed
      // form survives on POSIX shells but never reaches build scripts on
      // Windows, where the environment block is rebuilt per process.
      if (cc != null) 'CC_$target': cc,
      if (cc != null) 'CC_$tripleVar': cc,
      if (clangFlag != null) 'CFLAGS_$tripleVar': clangFlag,
      if (ar != null) 'AR_$target': ar,
      if (ar != null) 'AR_$tripleVar': ar,
      if (cc != null) 'CARGO_TARGET_${tripleU}_LINKER': cc,
      if (clangFlag != null)
        'CARGO_TARGET_${tripleU}_RUSTFLAGS': '-Clink-arg=$clangFlag',
      if (hostLld != null)
        'RUSTFLAGS': '${Platform.environment['RUSTFLAGS'] ?? ''} -C link-arg=-fuse-ld=$hostLld'.trim(),
    };

    // CodeConfig carries no Flutter build mode, and hooks run with almost the
    // whole environment stripped, so nothing at build time can tell a debug
    // build from a release one. The only channel is this user-define, which
    // means the default has to be the safe choice for a shipped library: cargo
    // release, which is what Cargo.toml optimises hardest for.
    //
    // That used to be unaffordable -- oii's default features drag in lsp-server
    // and clap, and linking those for three ABIs took the better part of an
    // hour. With default-features = false it is about forty seconds a target,
    // so `hooks.user_defines.oii_bridge.profile: debug` is the opt-in fast
    // path rather than the default.
    final profile = input.userDefines['profile']?.toString() ?? 'release';
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
      // Windows hosts without Visual Studio have no MSVC link.exe; the one
      // that resolves from a stripped PATH is GNU coreutils link. Host build
      // scripts still need to link for x86_64-pc-windows-msvc, so point cargo
      // at a rust-lld copy named lld-link (the name rustc maps to the msvc
      // flavor) and hand it the Windows SDK library search paths.
      if (Platform.isWindows) ...?_windowsHostLinkEnv(),
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

Map<String, String>? _windowsHostLinkEnv() {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home == null) return null;
  final toolchains = Directory('$home/.rustup/toolchains');
  if (!toolchains.existsSync()) return null;
  String? rustLld;
  for (final tc in toolchains.listSync().whereType<Directory>()) {
    final candidate = File(
        '${tc.path}/lib/rustlib/x86_64-pc-windows-msvc/bin/rust-lld.exe');
    if (candidate.existsSync()) {
      rustLld = candidate.path;
      break;
    }
  }
  if (rustLld == null) return null;
  // rustc picks the msvc flavor from the 'lld-link' file name and adds no
  // further flags, so ship the copy under that name.
  final cacheDir = Directory(
      '${Platform.environment['TEMP'] ?? toolchains.parent.path}/oii_bridge_link');
  if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);
  final lldLink = File('${cacheDir.path}/lld-link.exe');
  if (!lldLink.existsSync()) File(rustLld).copySync(lldLink.path);

  String? sdkLib;
  final kits = Directory(r'C:\Program Files (x86)\Windows Kits\10\Lib');
  if (kits.existsSync()) {
    final versions = kits.listSync().whereType<Directory>().toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final v in versions) {
      final um = Directory('${v.path}/um/x64');
      final ucrt = Directory('${v.path}/ucrt/x64');
      if (um.existsSync() && ucrt.existsSync()) {
        sdkLib = '${um.path};${ucrt.path}';
        break;
      }
    }
  }
  // msvcrt.lib and the compiler runtime live with the VC toolset, not the
  // Windows SDK. Any installed year/edition copy works.
  String? vcLib;
  final vsRoot = Directory(r'C:\Program Files (x86)\Microsoft Visual Studio');
  if (vsRoot.existsSync()) {
    outer:
    for (final year in vsRoot.listSync().whereType<Directory>()) {
      for (final edition in year.listSync().whereType<Directory>()) {
        final root = Directory(
            '${edition.path}/VC/Tools/MSVC');
        if (!root.existsSync()) continue;
        final versions = root.listSync().whereType<Directory>().toList()
          ..sort((a, b) => b.path.compareTo(a.path));
        for (final v in versions) {
          final lib = Directory('${v.path}/lib/x64');
          if (lib.existsSync()) {
            vcLib = lib.path;
            break outer;
          }
        }
      }
    }
  }
  final lib = [if (vcLib != null) vcLib!, if (sdkLib != null) sdkLib!].join(';');
  final env = <String, String>{
    'CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_LINKER': lldLink.path,
    if (sdkLib != null) 'LIB': sdkLib,
  };
  return env;
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

String? _ccFor(String target, CodeConfig code, Uri packageRoot) {
  if (code.targetOS == OS.android) {
    final ndk = _ndkRoot(packageRoot);
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
    final bin = '$ndk/toolchains/llvm/prebuilt/$hostTag/bin';
    // The NDK clang wrappers are .cmd batch files: cc-rs can shell out to
    // them, but rustc invokes the linker with CreateProcess and cannot.
    // Use clang.exe directly and hand every consumer its --target flag.
    if (Platform.isWindows) return '$bin/clang.exe';
    return '$bin/$triple-clang';
  }
  // host toolchain: cargo picks up the system cc on its own
  return null;
}

/// `--target=<ndk triple>` for direct clang.exe use; null where the NDK
/// wrapper script already carries the triple.
String? _clangTargetFlag(String target, CodeConfig code) {
  if (code.targetOS != OS.android || !Platform.isWindows) return null;
  final api = code.android.targetNdkApi;
  final triple = switch (target) {
    'aarch64-linux-android' => 'aarch64-linux-android$api',
    'armv7-linux-androideabi' => 'armv7a-linux-androideabi$api',
    'x86_64-linux-android' => 'x86_64-linux-android$api',
    _ => target,
  };
  return '--target=$triple';
}

String? _arFor(CodeConfig code, Uri packageRoot) {
  if (code.targetOS != OS.android) return null;
  final ndk = _ndkRoot(packageRoot);
  if (ndk == null) return null;
  final hostTag = Platform.isWindows
      ? 'windows-x86_64'
      : (Platform.isMacOS ? 'darwin-x86_64' : 'linux-x86_64');
  return '$ndk/toolchains/llvm/prebuilt/$hostTag/bin/llvm-ar';
}

String? _ndkRoot(Uri packageRoot) {
  final env = Platform.environment['ANDROID_NDK_HOME'] ??
      Platform.environment['ANDROID_NDK_ROOT'];
  if (env != null && Directory(env).existsSync()) return env;
  var home = Platform.environment['ANDROID_HOME'];
  // Hook runners hand hooks a stripped environment where ANDROID_HOME is
  // gone; the Flutter Gradle build already resolved the SDK, so read it back
  // from the checked-in local.properties next to the app module.
  if (home == null || !Directory('$home/ndk').existsSync()) {
    // input.packageRoot is the oii_bridge package itself; the app module
    // (and its local.properties) lives at the repo root one level up. URI
    // resolution treats a trailing-slash-less base as a file, so walk the
    // filesystem instead of resolving '../' by string.
    final pkgDir = Directory(packageRoot.toFilePath());
    var base = pkgDir;
    for (var i = 0; i < 6; i++) {
      final props = File('${base.path}/android/local.properties');
      if (props.existsSync()) {
        for (final line in props.readAsStringSync().split('\n')) {
          if (line.startsWith('sdk.dir=')) {
            home = line.substring('sdk.dir='.length).trim();
            break;
          }
        }
        if (home != null && Directory('$home/ndk').existsSync()) break;
      }
      final parent = base.parent;
      if (parent.path == base.path) break;
      base = parent;
    }
  }
  if (home == null) {
    home = '${Platform.environment['HOME']}/Android/Sdk';
  }
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
    // Windows installs cargo.exe; File.existsSync does no PATHEXT lookup, so
    // a bare 'cargo' check misses it and the fallback below silently degrades.
    for (final name in ['cargo', 'cargo.exe']) {
      final rustupCargo = File('$home/.cargo/bin/$name');
      try {
        if (rustupCargo.existsSync()) return rustupCargo.path;
      } catch (_) {}
    }
  }
  return 'cargo';
}
