import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/services.dart';

import 'workspace_runtime.dart';

/// Thrown for anything the Dart side can name. [code] is what the workspace
/// layer branches on and what the user is shown.
class WorkspaceChannelException implements Exception {
  WorkspaceChannelException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

/// The Dart client for `app.workspace`.
///
/// Two channels: a method channel for commands and an event channel for their
/// output. The event channel is broadcast and never closed, so one subscription
/// serves every run and a late run still gets its events.
class WorkspaceChannel {
  WorkspaceChannel({MethodChannel? method, EventChannel? events}) {
    _method = method ?? const MethodChannel('app.workspace');
    _events = events ?? const EventChannel('app.workspace/events');
  }

  late final MethodChannel _method;
  late final EventChannel _events;
  Stream<dynamic>? _raw;

  /// Where the rootfs lives and whether proot can be exec'd at all.
  Future<RuntimeStatus> probe() async {
    try {
      return RuntimeStatus.fromWire(await _method.invokeMapMethod<String, dynamic>('probe'));
    } on MissingPluginException {
      // a build without the native side, which is what flutter test and a
      // desktop run look like. Not an error, just no environment.
      return const RuntimeStatus(ready: false, reason: 'the native workspace is not available on this build');
    } on PlatformException catch (e) {
      return RuntimeStatus(ready: false, reason: e.message ?? 'probe failed');
    }
  }

  /// Refuses every exec and pty while the rootfs is being replaced. Without
  /// this a command that starts during an install runs against a tree that is
  /// half written and fails in a way nobody can read.
  Future<void> setEnvironmentBusy(bool busy) async => _invoke<void>('setEnvironmentBusy', {'busy': busy});

  Future<void> keepScreenOn(bool enabled) async => _invoke<void>('keepScreenOn', {'enabled': enabled});

  Future<Map<String, dynamic>> inspectRootfs(String rootfsDir, String arch) =>
      _invokeMap('inspectRootfs', {'rootfsDir': rootfsDir, 'arch': arch}, 'invalid_rootfs');

  /// Fires extraction and returns at once.
  ///
  /// It takes minutes and reports progress on the event channel, so the caller
  /// watches `extract` events and awaits this only to catch a failure that
  /// happened before the native side got going.
  Future<void> extractRootfs({required String archivePath, required String destDir, required String format}) async {
    await _invoke<void>('extractRootfs', {'archivePath': archivePath, 'destDir': destDir, 'format': format});
  }
  Future<void> patchRootfs({required String rootfsDir, required String arch, List<String> dnsServers = const [], String hostname = '', String? aptMirrorBaseUrl, String ubuntuCodename = ''}) =>
      _invoke('patchRootfs', {
        'rootfsDir': rootfsDir,
        'arch': arch,
        'dnsServers': dnsServers,
        'hostname': hostname,
        if (aptMirrorBaseUrl != null) 'aptMirrorBaseUrl': aptMirrorBaseUrl,
        'ubuntuCodename': ubuntuCodename,
      });

  /// Deletes an extracted tree. Tarballs carry directories the app user cannot
  /// list or unlink from, and Dart has no chmod, so this has to be native.
  Future<void> removeRootfs(String path) => _invoke('removeRootfs', {'path': path});

  Future<String> sha256File(String path) async {
    final v = await _invoke('sha256File', {'path': path});
    return '$v';
  }

  Future<({int free, int total})> freeSpace(String path) async {
    final m = await _invokeMap('freeSpace', {'path': path});
    return (free: (m['freeBytes'] as num?)?.toInt() ?? 0, total: (m['totalBytes'] as num?)?.toInt() ?? 0);
  }

  /// Starts a command. The events and the output come back as two streams
  /// because a caller wants them apart: an error line is not a log line.
  ({Stream<CommandEvent> events, Stream<CommandOutput> output}) exec(CommandRequest r) {
    final events = StreamController<CommandEvent>();
    final stdout = StreamController<List<int>>.broadcast();
    final stderr = StreamController<List<int>>.broadcast();
    late StreamSubscription<dynamic> sub;

    sub = _eventStream().listen((e) {
      if (e is! Map) return;
      final id = '${e['runId'] ?? ''}';
      if (id != r.runId) return;
      switch ('${e['type'] ?? ''}') {
        case 'started':
          events.add(CommandStarted((e['pid'] as num?)?.toInt() ?? -1));
        case 'stdout':
          final d = e['data'];
          if (d is Uint8List && !stdout.isClosed) stdout.add(d);
        case 'stderr':
          final d = e['data'];
          if (d is Uint8List && !stderr.isClosed) stderr.add(d);
        case 'exit':
          events.add(CommandExited(
            exitCode: (e['exitCode'] as num?)?.toInt() ?? -1,
            timedOut: _flag(e['timedOut']),
            cancelled: _flag(e['cancelled']),
            duration: Duration(milliseconds: (e['durationMs'] as num?)?.toInt() ?? 0),
          ));
          sub.cancel();
          stdout.close();
          stderr.close();
          events.close();
      }
    });

    // The native side answers a map ("started" to true) rather than a bare
    // bool, and invokeMethod<bool> would cast that map to bool and throw on
    // every shell call. The answer is not read anyway: failure is delivered by
    // the catchError below, success by the exit event.
    unawaited(_invoke<Object?>('exec', {
      'runId': r.runId,
      'rootfsDir': r.rootfsDir,
      'tmpDir': r.tmpDir,
      'cwd': r.cwd,
      'command': r.command,
      'env': r.env,
      'timeoutMs': r.timeout.inMilliseconds,
      'keepStdinOpen': r.keepStdinOpen,
      'binds': [for (final m in r.mounts) if (m.host != null) m.toWire()],
      if (r.prootArguments.isNotEmpty) 'prootArguments': r.prootArguments,
      if (r.shell != null) 'shell': r.shell,
    }).catchError((Object e) {
      // the command never started, so there will be no exit event to close
      // this stream. without this the caller waits on a stream that never ends
      if (!events.isClosed) {
        events.addError(e);
        events.close();
      }
      return false;
    }));

    return (
      events: events.stream,
      output: _mergeTagged(stdout.stream, stderr.stream),
    );
  }

  Future<bool> cancel(String runId) async {
    try {
      return await _method.invokeMethod<bool>('cancel', {'runId': runId}) ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> writeStdin(String runId, Uint8List data) async => _invoke<void>('stdinWrite', {'runId': runId, 'data': data});

  Future<int> ptyOpen({
    required String sessionId,
    required String rootfsDir,
    required String tmpDir,
    required List<Mount> mounts,
    required String cwd,
    required Map<String, String> env,
    int cols = 80,
    int rows = 24,
    List<String> prootArguments = const [],
    String? shell,
  }) async {
    final m = await _invokeMap('ptyOpen', {
      'sessionId': sessionId,
      'rootfsDir': rootfsDir,
      'tmpDir': tmpDir,
      'cwd': cwd,
      'env': env,
      'cols': cols,
      'rows': rows,
      'binds': [for (final m in mounts) if (m.host != null) m.toWire()],
      if (prootArguments.isNotEmpty) 'prootArguments': prootArguments,
      if (shell != null) 'shell': shell,
    });
    return (m['pid'] as num?)?.toInt() ?? -1;
  }

  Future<void> ptyWrite(String sessionId, Uint8List data) async => _invoke<void>('ptyWrite', {'sessionId': sessionId, 'data': data});

  Future<void> ptyResize(String sessionId, int cols, int rows) async => _invoke<void>('ptyResize', {'sessionId': sessionId, 'cols': cols, 'rows': rows});

  Future<void> ptyClose(String sessionId) async => _invoke<void>('ptyClose', {'sessionId': sessionId});

  /// Extraction progress, as it happens. Fires for every entry of a rootfs,
  /// which is a hundred thousand of them, so a caller throttles rather than
  /// repainting on each.
  void onExtract(void Function(int entries, int bytes, String currentEntry) onEvent) {
    _extractSub ??= _eventStream().listen((e) {
      if (e is! Map || '${e['type']}' != 'extract') return;
      onEvent((e['entries'] as num?)?.toInt() ?? 0, (e['bytes'] as num?)?.toInt() ?? 0, '${e['currentEntry'] ?? ''}');
    });
  }

  StreamSubscription<dynamic>? _extractSub;

  /// The raw output of one pty session, demultiplexed out of the shared event
  /// stream. Taken as a stream rather than a callback so a session has one owner
  /// and cannot end up with two listeners fighting over the same bytes.
  Stream<Map<dynamic, dynamic>> ptyEvents(String sessionId) => _eventStream()
      .where((e) => e is Map && '${e['sessionId']}' == sessionId)
      .cast<Map<dynamic, dynamic>>();

  Stream<Uint8List> ptyOutput(String sessionId) => ptyEvents(sessionId)
      .where((e) => '${e['type']}' == 'pty')
      .map((e) => e['data'] is Uint8List ? e['data'] as Uint8List : Uint8List.fromList((e['data'] as List?)?.cast<int>() ?? const []));

  Stream<dynamic> _eventStream() {
    // one subscription for the whole app. re-listening per run would drop
    // events that arrive between two runs
    return _raw ??= _events.receiveBroadcastStream().asBroadcastStream();
  }

  /// NSNumber decodes as a number and a JS bridge would decode as a string, so
  /// every boolean flag is normalised in one place.
  static bool _flag(dynamic v) => v == true || v == 1 || v == 'true' || v == '1';

  static Stream<CommandOutput> _mergeTagged(Stream<List<int>> out, Stream<List<int>> err) async* {
    final channels = <Stream<CommandOutput>>[
      out.map((b) => CommandOutput(Uint8List.fromList(b), isStderr: false)),
      err.map((b) => CommandOutput(Uint8List.fromList(b), isStderr: true)),
    ];
    yield* StreamGroup.merge(channels);
  }

  /// Calls a method whose return value nobody reads. [returnValue] is for the
  /// odd case where the native side answers with something worth keeping.
  Future<T?> _invoke<T>(String method, Map<String, dynamic> args) async {
    try {
      return await _method.invokeMethod<T>(method, args);
    } on MissingPluginException {
      throw WorkspaceChannelException('native_missing', 'the native workspace is not available on this build');
    } on PlatformException catch (e) {
      throw WorkspaceChannelException(e.code, e.message ?? '$method failed');
    }
  }

  Future<Map<String, dynamic>> _invokeMap(String method, Map<String, dynamic> args, [String code = 'workspace']) async {
    try {
      final m = await _method.invokeMapMethod<String, dynamic>(method, args);
      return m ?? const {};
    } on MissingPluginException {
      throw WorkspaceChannelException('native_missing', 'the native workspace is not available on this build');
    } on PlatformException catch (e) {
      throw WorkspaceChannelException(e.code == 'workspace' ? code : e.code, e.message ?? '$method failed');
    }
  }
}
