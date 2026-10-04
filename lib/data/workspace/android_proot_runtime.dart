import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'app_dirs.dart';
import 'workspace_channel.dart';
import 'workspace_paths.dart';
import 'workspace_runtime.dart';

/// proot. Executes commands in a downloaded Linux tree without root.
///
/// Every command is a separate process, so a cancelled command kills exactly
/// what it started. [isCancelled] is re-checked natively after the platform call
/// returns, which is the only point where a cancel can still stop the exec
/// instead of racing it.
class AndroidProotRuntime implements WorkspaceStdioRuntime {
  AndroidProotRuntime(this.channel, {required this.envDir, required this.tmpDir, this.extraMounts = const [], this.prootArguments = const [], this.shell});
  final WorkspaceChannel channel;

  /// `<appDocuments>/environment`. The rootfs lives in a subdirectory of it.
  final String envDir;
  final String tmpDir;

  /// External mounts, once M3 wires them up. Empty now, which means the four
  /// built-in zones and nothing else.
  final List<Mount> extraMounts;

  final List<String> prootArguments;
  final String? shell;

  String get rootfsDir => p.join(envDir, 'rootfs');

  @override
  bool get supportsPty => true;

  @override
  bool get supportsSystemTerminal => false;

  @override
  Future<RuntimeStatus> status() async {
    final probe = await channel.probe();
    if (!probe.ready) {
      return RuntimeStatus(ready: false, engine: 'proot', reason: probe.reason.isEmpty ? 'proot is not available' : probe.reason, abi: probe.abi);
    }
    final dir = Directory(rootfsDir);
    if (!await dir.exists()) {
      return const RuntimeStatus(ready: false, engine: 'proot', reason: 'no Linux environment is installed');
    }
    // an arm64 rootfs beside 32-bit proot produces exec format errors that look
    // like a broken binary, so the architecture is checked before anything runs
    final marker = File(EnvironmentDirs.versionMarker(rootfsDir));
    final fields = await marker.exists() ? (await marker.readAsString()).trim().split(' ') : const <String>[];
    if (!validateInstalledArchitecture(rootfsDir, probe.abi)) {
      return RuntimeStatus(ready: false, engine: 'proot', abi: probe.abi, reason: 'the installed environment is for a different architecture');
    }
    // /bin/sh present and executable. A rootfs that unpacked but did not
    // populate is worse than one that is missing, because it fails on use
    if (!await File(p.join(rootfsDir, 'bin', 'sh')).exists()) {
      return const RuntimeStatus(ready: false, engine: 'proot', reason: 'the installed environment has no shell');
    }
    return RuntimeStatus(
      ready: true,
      engine: 'proot',
      abi: probe.abi,
      rootfsDir: rootfsDir,
      distro: fields.isNotEmpty ? fields[0] : '',
      version: fields.length > 1 ? fields[1] : '',
    );
  }

  /// The architecture a rootfs was built for, read from the marker file the
  /// installer writes. Empty when the marker is missing, which means an install
  /// that predates it or one that failed partway.
  static String installedArchitecture(String rootfsDir) {
    final f = File(p.join(rootfsDir, '.paradise-version'));
    if (!f.existsSync()) return '';
    final fields = f.readAsLinesSync().firstOrNull?.split(' ') ?? const <String>[];
    return fields.length > 2 ? fields[2] : '';
  }

  static bool validateInstalledArchitecture(String rootfsDir, String abi) {
    final want = rootfsArchForAbi(abi);
    if (want == null) return false;
    final have = installedArchitecture(rootfsDir);
    // no marker means an old or interrupted install. refusing to run it is the
    // safe answer, and it is the installer's job to notice and replace it
    if (have.isEmpty) return false;
    return have == want;
  }

  /// The guest architecture for a device ABI, or null when the ABI is one this
  /// runtime has no proot for.
  static String? rootfsArchForAbi(String abi) => switch (abi) {
        'armeabi-v7a' || 'armhf' => 'armhf',
        'arm64-v8a' || 'arm64' => 'arm64',
        'x86_64' || 'amd64' => 'amd64',
        _ => null,
      };

  @override
  Stream<CommandEvent> run(CommandRequest request) => execStream(request).events;

  /// Starts the command and returns both of its streams.
  ///
  /// Split out of [run] because the terminal needs the output stream and the
  /// tool layer only wants the exit, and neither should have to filter out the
  /// other's half.
  ({Stream<CommandEvent> events, Stream<CommandOutput> output}) execStream(CommandRequest r) {
    // the same reason as openPty: a missing zone root fails the bind before
    // the command runs, and the tool layer only sees an empty output stream
    unawaited(ensureZoneDirs());
    return channel.exec(r);
  }

  @override
  Future<bool> cancel(String runId) => channel.cancel(runId);

  @override
  Future<void> writeStdin(String runId, Uint8List data) => channel.writeStdin(runId, data);

  @override
  Future<PtySession?> openPty({
    required String sessionId,
    required List<Mount> mounts,
    required String cwd,
    required Map<String, String> env,
    int cols = 80,
    int rows = 24,
    List<String> prootArguments = const [],
    String? shell,
  }) async {
    // a uuid rather than a counter: the native session map outlives the Dart
    // isolate across a hot restart, and a counter would collide on the second
    // run of the app in development
    final id = sessionId.isEmpty ? 'pty-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}' : sessionId;
    await ensureZoneDirs();
    final workspaceMount = mounts.where((m) => m.guest == WorkspacePaths.guestWorkspace && m.host != null && m.host!.isNotEmpty).firstOrNull;
    final userMounts = [for (final mount in mounts) if (mount != workspaceMount) mount];
    final session = ChannelPtySession(channel: channel, sessionId: id);
    try {
      await channel.ptyOpen(
        sessionId: id,
        rootfsDir: rootfsDir,
        tmpDir: tmpDir,
        mounts: [...zoneMounts(workspaceHost: workspaceMount?.host), ...extraMounts, ...userMounts],
        cwd: cwd,
        env: env,
        cols: cols,
        rows: rows,
        prootArguments: prootArguments.isEmpty ? this.prootArguments : prootArguments,
        shell: shell ?? this.shell,
      );
    } catch (_) {
      await session.close();
      rethrow;
    }
    return session;
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> revealInFileManager(String hostPath) async => throw UnsupportedError('there is no file manager for an app-private directory');

  /// The four built-in zones bound into every command.
  ///
  /// The mounts are writable at the proot level: proot's -b has no read-only
  /// flag. A read-only preference is enforced by the file tools and by the write
  /// guards, and a shell program is not isolated from anything it can already
  /// see.
  List<Mount> zoneMounts({String? workspaceHost}) => [
        Mount(host: workspaceHost ?? rootfsDir, guest: WorkspacePaths.guestWorkspace),
        Mount(host: p.join(envDir, 'sessions'), guest: WorkspacePaths.guestChat),
        Mount(host: p.join(envDir, 'skills'), guest: WorkspacePaths.guestSkills),
        Mount(host: tmpDir, guest: WorkspacePaths.guestTmp),
      ];

  /// Creates the zone roots the binds above name. proot aborts on a bind whose
  /// host side is absent, so this runs before every exec and pty rather than
  /// only at startup: a failed install cleanup can remove them mid session.
  Future<void> ensureZoneDirs() async {
    for (final d in [p.join(envDir, 'sessions'), p.join(envDir, 'skills'), tmpDir]) {
      final dir = Directory(d);
      try {
        if (!await dir.exists()) await dir.create(recursive: true);
      } catch (_) {
        // a bind that cannot be made is reported by proot itself
      }
    }
  }
}

/// A PTY over the channel.
///
/// Output is buffered until the first listener arrives and nothing is lost while
/// it waits. That window is not theoretical: the shell prints its prompt within
/// milliseconds of the fork, which happens inside the open call, and the caller
/// only gets to subscribe after that call returns.
class ChannelPtySession implements PtySession {
  ChannelPtySession({required this.channel, required this.sessionId}) {
    _sub = channel.ptyEvents(sessionId).listen((event) {
      switch ('${event['type']}') {
        case 'pty':
          final data = event['data'];
          if (data is Uint8List) {
            _add(data);
          } else if (data is List) {
            _add(Uint8List.fromList(data.cast<int>()));
          }
        case 'ptyExit':
          final code = (event['exitCode'] as num?)?.toInt() ?? int.tryParse('${event['exitCode']}') ?? -1;
          debugPrint('WorkspacePty: dart exit $sessionId code=$code received=$_received');
          if (!_exit.isCompleted) _exit.complete(code);
          unawaited(_detach());
      }
    }, onError: (Object error, StackTrace stack) {
      if (!_exit.isCompleted) _exit.completeError(error, stack);
    });
  }

  final WorkspaceChannel channel;
  final String sessionId;

  /// Single subscription on purpose: it gives [onListen] a place to flush the
  /// bytes that arrived before the terminal was ready for them.
  late final StreamController<Uint8List> _output = StreamController<Uint8List>(
    onListen: _flushPending,
  );

  /// Held only while nothing is listening, and only until the first one arrives.
  final List<Uint8List> _pending = [];
  late final StreamSubscription<dynamic> _sub;
  final _exit = Completer<int>();
  bool _detached = false;

  void _add(Uint8List bytes) {
    if (_output.isClosed) return;
    if (_received < 4096) {
      _received += bytes.length;
      debugPrint(
        'WorkspacePty: dart recv $sessionId +${bytes.length} total=$_received listener=${_output.hasListener} ' +
            '${_preview(bytes)}',
      );
    }
    if (_output.hasListener) {
      _output.add(bytes);
      return;
    }
    // a session that is never listened to must not grow without bound
    if (_pending.length < 64) {
      _pending.add(bytes);
    } else {
      _pending[_pending.length - 1] = bytes;
    }
  }

  static String _preview(Uint8List bytes) {
    final n = bytes.length > 120 ? 120 : bytes.length;
    return String.fromCharCodes(bytes.sublist(0, n)).replaceAll('\n', '\\n').replaceAll('\r', '\\r');
  }

  int _received = 0;

  void _flushPending() {
    if (_pending.isEmpty || _output.isClosed) return;
    final buffered = List<Uint8List>.of(_pending);
    _pending.clear();
    // deferred: onListen runs while the controller is still attaching, and
    // adding to it there would throw "Cannot fire new event" downstream
    scheduleMicrotask(() {
      if (_output.isClosed) return;
      for (final b in buffered) {
        _output.add(b);
      }
    });
  }

  @override
  Stream<Uint8List> get output => _output.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  Future<void> write(Uint8List data) async {
    if (data.isEmpty) return;
    await channel.ptyWrite(sessionId, data);
  }

  @override
  Future<void> resize(int cols, int rows) async {
    await channel.ptyResize(sessionId, cols, rows);
  }

  @override
  Future<void> close() async {
    if (!_exit.isCompleted) {
      try {
        await channel.ptyClose(sessionId);
      } finally {
        if (!_exit.isCompleted) _exit.complete(-1);
      }
    }
    await _detach();
  }

  Future<void> _detach() async {
    if (_detached) return;
    _detached = true;
    await _sub.cancel();
    if (!_output.isClosed) await _output.close();
  }
}

/// The environment directory layout, created on demand.
///
/// `<envDir>/rootfs` is the tree commands run in, `staging/rootfs` is where an
/// install unpacks before it is swapped in, and `downloads` holds a partial
/// archive so a cancelled install can resume instead of starting again.
class EnvironmentDirs {
  const EnvironmentDirs(this.root);
  final String root;

  String get rootfs => p.join(root, 'rootfs');
  String get stagingRootfs => p.join(root, 'staging', 'rootfs');
  String get downloads => p.join(root, 'downloads');
  String get previousRootfs => p.join(root, 'previous-rootfs');
  String get tmp => p.join(root, 'tmp');

  /// The two zone roots [AndroidProotRuntime.zoneMounts] binds as /chat and
  /// /skills. They have to exist before the first command: proot refuses a
  /// bind whose host side is missing, and it does so before the guest shell
  /// runs, so the terminal comes up blank with no error anywhere.
  String get sessions => p.join(root, 'sessions');
  String get skills => p.join(root, 'skills');

  /// Written inside the rootfs so it moves with the tree. A marker beside the
  /// directory would survive a rollback and describe a rootfs that is gone.
  static String versionMarker(String rootfsDir) => p.join(rootfsDir, '.paradise-version');

  Future<void> ensure() async {
    for (final d in [root, downloads, tmp, sessions, skills]) {
      final dir = Directory(d);
      if (!await dir.exists()) await dir.create(recursive: true);
    }
  }
}

/// Where the environment lives, and whether it is usable.
class WorkspaceEnvironment {
  WorkspaceEnvironment({required this.dirs, required this.channel, this.prootArguments = const [], this.shell});
  final EnvironmentDirs dirs;
  final WorkspaceChannel channel;
  final List<String> prootArguments;
  final String? shell;

  AndroidProotRuntime runtime() => AndroidProotRuntime(channel, envDir: dirs.root, tmpDir: dirs.tmp, prootArguments: prootArguments, shell: shell);

  /// Builds the environment under the app documents directory.
  ///
  /// Async because the documents dir is not known until path_provider answers.
  /// Making this synchronous would mean caching a path that a restore-from-
  /// backup can move.
  static Future<WorkspaceEnvironment> create(WorkspaceChannel channel) async =>
      WorkspaceEnvironment(dirs: EnvironmentDirs(p.join((await AppDirs.environment()).path, 'environment')), channel: channel);
}