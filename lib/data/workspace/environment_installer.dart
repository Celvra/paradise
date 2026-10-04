import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'android_proot_runtime.dart';
import 'workspace_channel.dart';

/// Where a rootfs comes from. Kept as data rather than as URLs scattered
/// through the installer so a version bump is one edit and the sha256 that goes
/// with it cannot get separated from it.
class RootfsImage {
  const RootfsImage({required this.id, required this.distro, required this.version, required this.codename, required this.urls, required this.sha256, required this.format, required this.minFreeMb});
  final String id;
  final String distro;
  final String version;
  final String codename;
  final Map<String, String> urls;
  final Map<String, String> sha256;
  final String format;

  /// Enough room for the extracted tree. Ubuntu needs far more than the
  /// compressed size suggests; a check that used the archive size would let the
  /// install fail halfway through unpacking.
  final int minFreeMb;

  String get label => '${distroName(distro)} $version';

  /// The file the publisher serves. Debian uses the same name for every release,
  /// which is why the cache name carries the id and this does not.
  String get fileName => 'rootfs.tar.xz';

  String get cacheName => '$id.$format';
}

String distroName(String id) => switch (id) {
      'ubuntu' => 'Ubuntu',
      _ => id,
    };

const _ubuntu = 'https://cdimage.ubuntu.com/ubuntu-base/releases/';

// ubuntu only, one image one door
const rootfsCatalog = <RootfsImage>[
  RootfsImage(
    id: 'ubuntu24044',
    distro: 'ubuntu',
    version: '24.04.4',
    codename: 'noble',
    urls: {
      'armhf': '${_ubuntu}24.04/release/ubuntu-base-24.04.4-base-armhf.tar.gz',
      'arm64': '${_ubuntu}24.04/release/ubuntu-base-24.04.4-base-arm64.tar.gz',
      'amd64': '${_ubuntu}24.04/release/ubuntu-base-24.04.4-base-amd64.tar.gz',
    },
    sha256: {
      'armhf': '991520b47f6586f38a78505cf016e300b6191bb8ff86a0723481ec23a37ab7f4',
      'arm64': '04207713ece899c3740823d33690441ad3a7f0ded1101aca744e2b0f37ac7ff2',
      'amd64': 'c1e67ef7b17a6300e136118bd1dc04725009cb376c1aad10abcf8cd453628d58',
    },
    format: 'tar.gz',
    minFreeMb: 600,
  ),
];

/// Which phase an install is in. Persisted, because an app killed mid install
/// has to be able to say so on the next launch instead of looking ready.
enum EnvPhase { notInstalled, downloading, verifying, extracting, patching, ready, error }

/// One past or current install, and everything the UI shows about it.
class EnvState {
  const EnvState({
    this.phase = EnvPhase.notInstalled,
    this.distro = '',
    this.version = '',
    this.arch = '',
    this.error = '',
    this.bytesDone = 0,
    this.bytesTotal = 0,
    this.entries = 0,
    this.currentEntry = '',
    this.availableVersion = '',
    this.rootfsDir = '',
  });

  final EnvPhase phase;
  final String distro;
  final String version;
  final String arch;

  /// A code from [EnvError], never a raw exception. The UI maps codes to
  /// sentences and a sentence containing a FileSystemException is not one.
  final String error;

  final int bytesDone;
  final int bytesTotal;
  final int entries;
  final String currentEntry;

  /// Set when the catalog has something newer than what is installed.
  final String availableVersion;
  final String rootfsDir;

  bool get busy => phase == EnvPhase.downloading || phase == EnvPhase.verifying || phase == EnvPhase.extracting || phase == EnvPhase.patching;

  /// 0 to 1. Null when the total is unknown, which the UI shows as an
  /// indeterminate bar rather than as zero.
  double? get progress {
    if (bytesTotal <= 0) return null;
    return (bytesDone / bytesTotal).clamp(0.0, 1.0);
  }

  EnvState copyWith({EnvPhase? phase, String? distro, String? version, String? arch, String? error, int? bytesDone, int? bytesTotal, int? entries, String? currentEntry, String? availableVersion, String? rootfsDir, bool clearError = false, bool clearAvailable = false}) =>
      EnvState(
        phase: phase ?? this.phase,
        distro: distro ?? this.distro,
        version: version ?? this.version,
        arch: arch ?? this.arch,
        error: clearError ? '' : (error ?? this.error),
        bytesDone: bytesDone ?? this.bytesDone,
        bytesTotal: bytesTotal ?? this.bytesTotal,
        entries: entries ?? this.entries,
        currentEntry: currentEntry ?? this.currentEntry,
        availableVersion: clearAvailable ? '' : (availableVersion ?? this.availableVersion),
        rootfsDir: rootfsDir ?? this.rootfsDir,
      );

  Map<String, dynamic> toJson() => {
        'phase': phase.name,
        'distro': distro,
        'version': version,
        'arch': arch,
        'error': error,
        'availableVersion': availableVersion,
      };

  factory EnvState.fromJson(Map<String, dynamic> j) => EnvState(
        phase: EnvPhase.values.firstWhere((e) => e.name == j['phase'], orElse: () => EnvPhase.notInstalled),
        distro: j['distro'] as String? ?? '',
        version: j['version'] as String? ?? '',
        arch: j['arch'] as String? ?? '',
        error: j['error'] as String? ?? '',
        availableVersion: j['availableVersion'] as String? ?? '',
      );
}

/// Failure codes the UI turns into sentences.
abstract final class EnvError {
  static const unsupportedAbi = 'unsupported_abi';
  static const architectureMismatch = 'architecture_mismatch';
  static const prootMissing = 'proot_missing';
  static const insufficientDisk = 'insufficient_disk';
  static const network = 'network';
  static const checksumMismatch = 'checksum_mismatch';
  static const extractFailed = 'extract_failed';
  static const patchFailed = 'patch_failed';
  static const cancelled = 'cancelled';
  static const invalidRootfs = 'invalid_rootfs';
}

/// Downloads, unpacks and repairs a Linux tree for proot to run in.
///
/// Deliberately not a ChangeNotifier: the workspace pages listen to this
/// through a notifier they own, and a service that notifies as well would
/// repaint the chat list on every progress tick.
class EnvironmentInstaller {
  EnvironmentInstaller({required this.channel, required this.dirs});

  final WorkspaceChannel channel;
  final EnvironmentDirs dirs;

  final _state = StreamController<EnvState>.broadcast();
  EnvState _current = const EnvState();

  /// Progress and phase changes. Broadcast because several pages can be open at
  /// once and a late subscriber still wants the next one.
  Stream<EnvState> get states => _state.stream;
  EnvState get state => _current;

  bool _installing = false;
  http.Client? _client;

  /// Cancellation stops the active HTTP request and is checked at step boundaries.
  Completer<void>? _abort;
  bool _cancelled = false;
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _state.close();
  }

  void _set(EnvState next) {
    if (_disposed) return;
    _current = next;
    if (!_state.isClosed) _state.add(next);
  }

  /// Inline everywhere rather than behind a helper: a helper typed void makes
  /// the analyzer read every call site as a statement and then flag the throw
  /// inside it as a worth keeping.
  Future<T> _run<T>(Future<T> Function() body) async {
    if (_installing) throw StateError('an install is already running');
    _installing = true;
    _cancelled = false;
    _abort = Completer<void>();
    // kelivo: the previous ready state survives a failed install, so a bad
    // download does not turn an installed environment into a broken one
    _previous = _current.phase == EnvPhase.ready ? _current : null;
    try {
      await channel.setEnvironmentBusy(true);
      await channel.keepScreenOn(true);
      return await body();
    } on _Cancelled {
      _fail(EnvError.cancelled);
      rethrow;
    } catch (e) {
      final code = switch (e) {
        WorkspaceChannelException(:final code) => switch (code) {
            EnvError.unsupportedAbi || EnvError.architectureMismatch || EnvError.prootMissing || EnvError.insufficientDisk || EnvError.checksumMismatch || EnvError.network || EnvError.patchFailed || EnvError.extractFailed => code,
            _ => _phaseError(),
          },
        HttpException() || SocketException() || TimeoutException() => EnvError.network,
        _ => _phaseError(),
      };
      _fail(code);
      rethrow;
    } finally {
      _client?.close();
      if (identical(_client, client())) _client = null;
      try {
        // never retain a half extracted image
        final staging = Directory(dirs.stagingRootfs);
        if (await staging.exists()) await staging.delete(recursive: true);
      } catch (_) {}
      try {
        await channel.setEnvironmentBusy(false);
        await channel.keepScreenOn(false);
      } catch (_) {}
      _installing = false;
      _abort = null;
    }
  }

  http.Client? client() => _client;

  EnvState? _previous;

  void _fail(String code) {
    // kelivo: restore the previous ready state instead of dropping the user
    // into an error that looks like nothing is installed
    final base = _previous ?? _current;
    final phase = _previous?.phase == EnvPhase.ready ? EnvPhase.ready : EnvPhase.error;
    _set(base.copyWith(phase: phase, error: code, clearError: false));
  }

  String _phaseError() => switch (_current.phase) {
        EnvPhase.downloading => EnvError.network,
        EnvPhase.verifying => EnvError.checksumMismatch,
        EnvPhase.patching => EnvError.patchFailed,
        _ => EnvError.extractFailed,
      };

  /// Stops a running download. The install then fails with [EnvError.cancelled]
  /// and the partial archive is left in place so the next attempt resumes.
  void cancel() {
    if (!_installing) return;
    _cancelled = true;
    _client?.close();
    _abort?.complete();
  }

  /// A snapshot of what is on disk, read from the marker file rather than from
  /// the saved state, so an app killed mid install reports the truth.
  Future<EnvState> refresh() async {
    await recoverInterrupted();
    final rootfs = dirs.rootfs;
    if (!await Directory(rootfs).exists()) {
      _set(const EnvState());
      return _current;
    }
    await _adopt();
    return _current;
  }

  /// Reads the marker and publishes the ready state it describes. The single
  /// place that turns an on-disk tree into an installed environment, shared by
  /// the startup recovery and the page refresh.
  Future<void> _adopt() async {
    final rootfs = dirs.rootfs;
    final probe = await channel.probe();
    final marker = File(EnvironmentDirs.versionMarker(rootfs));
    if (!await marker.exists()) {
      // a rootfs with no marker is one that failed before the swap, or one from
      // a build that predates the marker. either way it cannot be trusted
      _set(EnvState(phase: EnvPhase.error, error: EnvError.invalidRootfs, rootfsDir: rootfs));
      return;
    }
    final fields = (await marker.readAsString()).trim().split(' ');
    if (fields.length >= 4 && !AndroidProotRuntime.validateInstalledArchitecture(rootfs, probe.abi)) {
      // refused rather than deleted: the user may want to switch back to a
      // build for the other architecture instead of downloading 600 MB again
      _set(EnvState(phase: EnvPhase.error, error: EnvError.architectureMismatch, distro: fields[0], version: fields[1], arch: fields[2], rootfsDir: rootfs));
      return;
    }
    final image = fields.isNotEmpty ? catalogFor(fields[0]) : null;
    _set(EnvState(
      phase: EnvPhase.ready,
      distro: fields.isNotEmpty ? fields[0] : '',
      version: fields.length > 1 ? fields[1] : '',
      arch: fields.length > 2 ? fields[2] : '',
      rootfsDir: rootfs,
      availableVersion: _newerVersion(fields.length > 1 ? fields[1] : '', image) ?? '',
    ));
  }

  /// Deletes an extracted tree through the native remover. Tarballs carry
  /// directories the app user cannot unlink from and Dart has no chmod, so
  /// every recursive delete of an extracted tree goes through here.
  Future<void> _removeTree(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return;
    await channel.removeRootfs(path);
  }

  /// Kelivo: recover a process exit between the two directory renames on
  /// replacement. Only the marker knows whether rootfs or previous-rootfs is
  /// the live one, and a missing rootfs beside a previous one means the crash
  /// landed in the middle of the swap.
  Future<void> recoverInterrupted() async {
    final saved = _savedState();
    final live = Directory(dirs.rootfs);
    final previous = Directory(dirs.previousRootfs);
    if (!await live.exists() && await previous.exists()) {
      await previous.rename(live.path);
    }
    if (!saved.busy) return;
    final marker = File(EnvironmentDirs.versionMarker(dirs.rootfs));
    if (await marker.exists()) {
      await _adopt();
    } else {
      _set(const EnvState());
    }
  }

  EnvState _savedState() {
    final s = _persisted;
    return s ?? const EnvState();
  }

  EnvState? _persisted;

  /// Loads the last saved phase. Called once by the workspace bootstrap, before
  /// anything touches the environment.
  void adoptSaved(Map<String, dynamic> json) {
    _persisted = EnvState.fromJson(json);
  }

  /// Downloads and installs [image] for [arch].
  ///
  /// The whole thing is staged into `staging/rootfs` and swapped in with a
  /// rename at the end. Without that, a kill halfway through leaves a rootfs
  /// that exists and does not work, and the only repair is another full download.
  Future<void> install(RootfsImage image, String arch) => _run(() async {
        final url = image.urls[arch];
        if (url == null) {
          _fail(EnvError.unsupportedAbi);
          throw StateError('no $arch build of ${image.label}');
        }
        await dirs.ensure();

        final probe = await channel.probe();
        if (!probe.ready) {
          _fail(EnvError.prootMissing);
          throw StateError(probe.reason);
        }
        if (AndroidProotRuntime.rootfsArchForAbi(probe.abi) != arch) {
          _fail(EnvError.architectureMismatch);
          throw StateError('the app is ${probe.abi} and ${image.label} is $arch');
        }

        final need = image.minFreeMb * 1024 * 1024;
        final free = await channel.freeSpace(dirs.root);
        if (free.free < need) {
          _fail(EnvError.insufficientDisk);
          throw StateError('need $need bytes, have ${free.free}');
        }

        final archive = File(p.join(dirs.downloads, image.cacheName));
        _set(EnvState(phase: EnvPhase.downloading, distro: image.distro, version: image.version, arch: arch, bytesTotal: 0));
        await _download(url, archive, image, arch);

        if (_cancelled) throw _Cancelled();
        _set(_current.copyWith(phase: EnvPhase.verifying));
        final want = image.sha256[arch];
        if (want != null && want.isNotEmpty && !_looksReal(want)) {
          // a placeholder in the catalog would otherwise fail here as a checksum
          // mismatch and look like a corrupt download rather than a bug
          _fail(EnvError.checksumMismatch);
          throw StateError('the catalog has no real checksum for ${image.id}/$arch');
        }
        if (want != null && want.isNotEmpty) {
          final got = await channel.sha256File(archive.path);
          if (got.toLowerCase() != want.toLowerCase()) {
            // the archive is deleted so the next attempt does not resume onto a
            // file that will never verify
            if (await archive.exists()) await archive.delete();
            _fail(EnvError.checksumMismatch);
            throw StateError('sha256 $got does not match');
          }
        }

        if (_cancelled) throw _Cancelled();
        _set(_current.copyWith(phase: EnvPhase.extracting));
        final staging = dirs.stagingRootfs;
        final stageDir = Directory(staging);
        // the native remover, not delete(recursive): a previous failed install
        // can leave modes this user cannot unlink through
        await _removeTree(p.join(dirs.root, 'staging'));
        await stageDir.create(recursive: true);
        // kelivo: the native side blocks on this call, so when it returns the
        // extraction is actually done and failures arrive as channel errors
        await channel.extractRootfs(archivePath: archive.path, destDir: staging, format: image.format);

        if (_cancelled) throw _Cancelled();
        // kelivo: inspect what actually landed on disk before patching. an
        // archive that unpacked half its entries is caught here as invalid
        // rootfs instead of producing a tree that dies on its first shell
        final Map<String, dynamic> info;
        try {
          info = await channel.inspectRootfs(staging, arch);
        } catch (_) {
          _fail(EnvError.invalidRootfs);
          throw StateError('the extracted tree is not a usable rootfs');
        }
        if (info['distro'] != image.distro) {
          _fail(EnvError.invalidRootfs);
          throw StateError('the archive is ${info['distro']}, not ${image.distro}');
        }

        _set(_current.copyWith(phase: EnvPhase.patching));
        try {
          await channel.patchRootfs(rootfsDir: staging, arch: arch, ubuntuCodename: image.codename);
        } on WorkspaceChannelException catch (e) {
          _fail(EnvError.patchFailed);
          throw StateError('patch: ${e.message}');
        }
        // kelivo: an imported archive can carry a guest-absolute link at the
        // marker path, so the link is removed before the app-owned marker
        final markerPath = EnvironmentDirs.versionMarker(staging);
        final versionLink = Link(markerPath);
        if (await versionLink.exists()) await versionLink.delete();
        try {
          await File(markerPath).writeAsString('${info['distro']} ${info['version'] ?? image.version} $arch ${image.codename}\n', flush: true);
        } catch (e) {
          _fail(EnvError.extractFailed);
          throw StateError('marker: $e');
        }

        // kelivo: keep the old rootfs until the new one is fully in place
        final live = Directory(dirs.rootfs);
        final previous = Directory(dirs.previousRootfs);
        await _removeTree(dirs.previousRootfs);
        final hadPrevious = await live.exists();
        try {
          if (hadPrevious) await live.rename(previous.path);
        } catch (e) {
          _fail(EnvError.extractFailed);
          throw StateError('swap: $e');
        }
        try {
          await stageDir.rename(live.path);
        } catch (_) {
          if (hadPrevious && !await live.exists()) await previous.rename(live.path);
          _fail(EnvError.extractFailed);
          throw StateError('swap: staging rename failed');
        }
        _set(_current.copyWith(phase: EnvPhase.ready, rootfsDir: dirs.rootfs, distro: '${info['distro']}', version: '${info['version'] ?? image.version}', arch: arch, clearError: true));
        await _removeTree(dirs.previousRootfs);
        if (await archive.exists()) await archive.delete();
        await refresh();
      });

  /// Downloads to [target], resuming a partial file with a Range request.
  ///
  /// A 416 with a matching total means the file is already complete, so it falls
  /// through to verification. A 200 on a resume means the server ignored the
  /// range and is sending the whole thing again, so the partial is truncated and
  /// started over rather than appended to.
  Future<void> _download(String url, File target, RootfsImage image, String arch) async {
    await target.parent.create(recursive: true);
    var existing = await target.exists() ? await target.length() : 0;
    final head = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 20)).then((r) => r.headers).catchError((_) => <String, String>{});
    final total = int.tryParse(head['content-length'] ?? '') ?? 0;

    if (existing > 0 && total > 0 && existing >= total) {
      _set(_current.copyWith(bytesDone: existing, bytesTotal: total));
      return;
    }

    final req = http.Request('GET', Uri.parse(url));
    if (existing > 0) req.headers['Range'] = 'bytes=$existing-';
    final client = _client = http.Client();
    final res = await client.send(req).timeout(const Duration(seconds: 60));
    if (res.statusCode == 416 && total > 0 && existing == total) {
      _set(_current.copyWith(bytesDone: existing, bytesTotal: total));
      return;
    }
    if (res.statusCode == 416) {
      if (await target.exists()) await target.delete();
      throw HttpException('HTTP 416 for incomplete archive $url');
    }
    if (res.statusCode != 200 && res.statusCode != 206) {
      _fail(EnvError.network);
      throw HttpException('HTTP ${res.statusCode} for $url');
    }
    var append = res.statusCode == 206 && existing > 0;
    if (res.statusCode == 200 && existing > 0) {
      // the server ignored the range, so this is a fresh body not a tail
      append = false;
      existing = 0;
    }
    final sink = target.openWrite(mode: append ? FileMode.append : FileMode.write);
    var done = existing;
    var length = total > 0 ? total : (int.tryParse(res.headers['content-length'] ?? '') ?? 0);
    try {
      await for (final chunk in res.stream) {
        if (_cancelled) {
          // the sink is closed in the finally and the partial archive is left
          // behind on purpose, so the next attempt resumes instead of starting
          break;
        }
        sink.add(chunk);
        done += chunk.length;
        _set(_current.copyWith(bytesDone: done, bytesTotal: length));
      }
    } finally {
      await sink.flush();
      await sink.close();
      client.close();
      if (identical(_client, client)) _client = null;
    }
    if (_cancelled) throw _Cancelled();
  }

  /// A checksum that is obviously a placeholder rather than a real sha256.
  ///
  /// The catalog is hand written and a half filled row is easy to miss. Failing
  /// here says so, instead of reporting a mismatch and sending the user off to
  /// redownload an archive that was never corrupt.
  static bool _looksReal(String sha) {
    if (sha.length != 64) return false;
    // a repeated single character is what an unfilled template row looks like
    if (RegExp(r'^(.)\1+$').hasMatch(sha)) return false;
    return true;
  }

  /// Deletes the installed tree and every partial file. [busy] stops commands
  /// first so nothing is running against a directory that is disappearing.
  Future<void> reset({bool notifyNative = true}) async {
    if (notifyNative) await channel.setEnvironmentBusy(true);
    try {
      // kelivo: recovery data goes first, so a later startup cannot resurrect
      // an install whose rootfs is already gone
      await _removeTree(dirs.previousRootfs);
      await _removeTree(dirs.rootfs);
      await _removeTree(p.join(dirs.root, 'staging'));
      await _removeTree(dirs.downloads);
      _set(const EnvState());
    } finally {
      if (notifyNative) await channel.setEnvironmentBusy(false);
    }
  }

  /// Re-runs the patch step on the installed tree. For a network change or a
  /// mirror move, which do not need the tree replaced.
  Future<void> repair(String arch, {String ubuntuCodename = ''}) => _run(() async {
        final rootfs = Directory(dirs.rootfs);
        if (!await rootfs.exists()) {
          _fail(EnvError.invalidRootfs);
          throw StateError('no installed Linux environment');
        }
        final marker = File(EnvironmentDirs.versionMarker(dirs.rootfs));
        if (!await marker.exists()) {
          _fail(EnvError.invalidRootfs);
          throw StateError('the installed environment has no version marker');
        }
        final fields = (await marker.readAsString()).trim().split(' ');
        final distro = fields.isNotEmpty ? fields.first : '';
        final codename = ubuntuCodename.isNotEmpty ? ubuntuCodename : (fields.length > 3 ? fields[3] : '');
        _set(_current.copyWith(phase: EnvPhase.patching, distro: distro, arch: arch, clearError: true));
        await channel.setEnvironmentBusy(true);
        try {
          await channel.patchRootfs(rootfsDir: dirs.rootfs, arch: arch, ubuntuCodename: codename);
        } finally {
          await channel.setEnvironmentBusy(false);
        }
        await refresh();
      });

  static RootfsImage? catalogFor(String distro) {
    for (final i in rootfsCatalog) {
      if (i.distro == distro) return i;
    }
    return null;
  }

  /// Numeric dot compare, so 24.04.10 sorts above 24.04.9 rather than below it.
  static String? _newerVersion(String installed, RootfsImage? image) {
    if (image == null || installed.isEmpty) return null;
    return _versionNewer(image.version, installed) ? image.version : null;
  }

  static bool _versionNewer(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

/// Reads and writes the install phase, kept out of the installer because the
/// installer itself has no business knowing about preferences.
abstract final class EnvStore {
  static const key = 'w_env';

  static Map<String, dynamic>? read(Map<String, dynamic> all) {
    final raw = all[key];
    if (raw is! String || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static String encode(EnvState s) => jsonEncode(s.toJson());
}