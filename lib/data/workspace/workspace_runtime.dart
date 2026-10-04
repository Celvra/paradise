import 'dart:async';
import 'package:flutter/foundation.dart';

/// Which roots a command can see, and where they live on the device.
///
/// The guest side is what the model is told about and the host side is what the
/// path layer maps onto. Carried together because a command that binds one
/// without the other produces a guest that silently sees an empty directory.
class Mount {
  const Mount({this.host, required this.guest, this.readOnly = false, this.externalId});
  final String? host;
  final String guest;
  final bool readOnly;

  /// Null for the built-in zones, set for something the user linked.
  final String? externalId;

  Map<String, dynamic> toWire() => {
        'host': host,
        'guest': guest,
        // omitted rather than sent false: the native side defaults it either way
        // and a shorter map is a smaller channel message
        if (readOnly) 'readOnly': true,
      };

  static Mount? fromWire(Map<dynamic, dynamic> m) {
    final host = m['host'] as String?;
    final guest = m['guest'] as String?;
    if (host == null || guest == null || host.isEmpty || guest.isEmpty) return null;
    return Mount(host: host, guest: guest, readOnly: m['readOnly'] == true);
  }

  @override
  bool operator ==(Object other) => other is Mount && other.host == host && other.guest == guest && other.readOnly == readOnly;

  @override
  int get hashCode => Object.hash(host, guest, readOnly);

  @override
  String toString() => 'Mount($host -> $guest${readOnly ? ' ro' : ''})';
}

/// One command to run.
///
/// [isCancelled] is checked by the native side after the platform call returns
/// and before exec, which is the only window where a cancel can still be
/// honoured without a race against the process actually starting.
class CommandRequest {
  CommandRequest({
    required this.runId,
    required this.command,
    required this.rootfsDir,
    required this.tmpDir,
    this.cwd = '/workspace',
    this.timeout = const Duration(seconds: 60),
    this.env = const {},
    this.mounts = const [],
    this.keepStdinOpen = false,
    this.prootArguments = const [],
    this.shell,
    this.isCancelled,
  });

  final String runId;
  final String command;

  /// Where the installed Linux tree is, and where proot may keep its temporary
  /// files. Both are host paths and both are decided by the installer rather
  /// than by the caller: a request is built long before the environment exists.
  final String rootfsDir;
  final String tmpDir;

  final String cwd;
  final Duration timeout;
  final Map<String, String> env;
  final List<Mount> mounts;

  /// Left open for a protocol server such as an MCP stdio client. A normal
  /// shell command has stdin closed immediately so a command that reads it
  /// fails fast instead of hanging until the timeout.
  final bool keepStdinOpen;

  final List<String> prootArguments;
  final String? shell;
  final bool Function()? isCancelled;
}

/// stdout or stderr. One type rather than two because the only difference is
/// which stream it came from and nothing branches on that.
class CommandOutput {
  const CommandOutput(this.bytes, {required this.isStderr});
  final Uint8List bytes;
  final bool isStderr;
}

sealed class CommandEvent {
  const CommandEvent();
}

class CommandStarted extends CommandEvent {
  const CommandStarted(this.pid);
  final int pid;
}

class CommandExited extends CommandEvent {
  const CommandExited({required this.exitCode, required this.timedOut, required this.cancelled, required this.duration});
  final int exitCode;
  final bool timedOut;
  final bool cancelled;
  final Duration duration;
}

/// How the environment is doing. [ready] false with a [reason] is what the
/// workspace page shows and what every tool checks before touching anything.
class RuntimeStatus {
  const RuntimeStatus({required this.ready, this.engine = 'none', this.reason = '', this.abi = '', this.rootfsDir = '', this.distro = '', this.version = ''});
  final bool ready;
  final String engine;
  final String reason;
  final String abi;
  final String rootfsDir;
  final String distro;
  final String version;

  factory RuntimeStatus.fromWire(Map<dynamic, dynamic>? m) => m == null
      ? const RuntimeStatus(ready: false, reason: 'the workspace runtime did not answer')
      : RuntimeStatus(
          ready: m['supported'] == true,
          engine: '${m['engine'] ?? 'proot'}',
          reason: '${m['reason'] ?? ''}',
          abi: '${m['abi'] ?? ''}',
          rootfsDir: '${m['rootfsDir'] ?? ''}',
          distro: '${m['distro'] ?? ''}',
          version: '${m['version'] ?? ''}',
        );
}

/// An interactive session. Separate from a command because it has a tty, a
/// window size and no exit until someone closes it.
abstract class PtySession {
  Stream<Uint8List> get output;
  Future<void> write(Uint8List data);
  Future<void> resize(int cols, int rows);

  /// The shell's exit code, or a negative number if it never reported one.
  Future<int> get exitCode;
  Future<void> close();
}

/// Everything a workspace can be run by.
///
/// One interface rather than a switch on platform so the tool layer has nothing
/// to know about proot, and so a future runtime is one more implementation.
abstract class WorkspaceRuntime {
  Future<RuntimeStatus> status();

  /// Starts [request] and returns the stream of its events, already correlated
  /// by runId. Cancelling is [cancel], not closing the stream: the caller wants
  /// to see the exit that a kill produced.
  Stream<CommandEvent> run(CommandRequest request);

  Future<bool> cancel(String runId);

  /// An interactive shell. Null on a runtime with no pty, which is why this is
  /// nullable rather than throwing.
  Future<PtySession?> openPty({
    required String sessionId,
    required List<Mount> mounts,
    required String cwd,
    required Map<String, String> env,
    int cols = 80,
    int rows = 24,
    List<String> prootArguments = const [],
    String? shell,
  }) async =>
      null;

  bool get supportsPty => false;

  /// Whether this runtime can hand the directory to a terminal outside the app.
  bool get supportsSystemTerminal => false;

  /// Opens the host's own file manager at [hostPath]. Unsupported by default so
  /// a caller does not have to check the platform.
  Future<void> revealInFileManager(String hostPath) async => throw UnsupportedError('no file manager on this platform');

  Future<void> dispose() async {}
}

/// A runtime that can also be written to after the command has started, which is
/// what a stdio MCP server needs.
abstract class WorkspaceStdioRuntime implements WorkspaceRuntime {
  Future<void> writeStdin(String runId, Uint8List data);
}

/// Holds the one runtime the app has.
///
/// A singleton slot rather than a field on the store: the workspace pages, the
/// terminal and the tool layer all need it and threading it through each of them
/// is how one of them ends up with a different instance.
class WorkspaceRuntimeProvider extends ChangeNotifier {
  WorkspaceRuntime? _runtime;
  RuntimeStatus? _lastStatus;

  /// In flight the first probe, so three callers at startup do not three probes.
  Future<void>? _initialization;

  WorkspaceRuntime? get runtime => _runtime;
  RuntimeStatus? get lastStatus => _lastStatus;

  void register(WorkspaceRuntime runtime) {
    _runtime = runtime;
    notifyListeners();
  }

  /// Pins the status without a runtime behind it.
  ///
  /// A test needs to know what the tool table offers when an environment is
  /// present, and installing a 600 MB rootfs to find that out is not a test.
  /// Not part of the app's API on purpose: nothing in lib/ calls it, and the
  /// only caller is a test that says so by name.
  void debugSetStatus(RuntimeStatus? status) {
    _lastStatus = status;
    notifyListeners();
  }

  Future<void> refresh() async {
    final r = _runtime;
    if (r == null) {
      _lastStatus = const RuntimeStatus(ready: false, reason: 'no workspace runtime is registered');
    } else {
      try {
        _lastStatus = await r.status();
      } catch (e) {
        _lastStatus = RuntimeStatus(ready: false, reason: '$e');
      }
    }
    notifyListeners();
  }

  /// Idempotent and safe to call from anywhere; the result is a no-op once the
  /// first one has run.
  Future<void> ensureLoaded() {
    return _initialization ??= _doLoad();
  }

  Future<void> _doLoad() async {
    await refresh();
    if (_runtime != null) {
      try {
        await _runtime!.status();
      } catch (_) {
        // a runtime that cannot even be asked is the same as no runtime, and
        // refresh already recorded that
      }
    }
  }
}
