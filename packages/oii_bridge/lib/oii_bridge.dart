import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart' as ffi;

// Dart side of the oii bridge. One [OiiEngine] owns one rust engine handle
// living in a worker isolate. Host functions are registered by name; when a
// script calls one the rust side parks the eval on a channel, the native
// callback lands on the isolate that created the engine, dart computes a
// result, and the reply unlocks the eval.
//
// Evals are serialized through the worker, so an engine never runs two
// scripts at once and the global pending-call slot cannot collide within one
// engine. Two engines would still share the slot, which the rust side
// refuses with E199 rather than mixing up replies.

typedef _EngineNewC = Pointer<Void> Function();
typedef _EngineFreeC = Void Function(Pointer<Void>);
typedef _EngineHostRegC = Void Function(Pointer<Void>, Pointer<ffi.Utf8>);
typedef _EngineLimitsC = Void Function(Pointer<Void>, Uint64, Uint32);
typedef _ParseC = Pointer<ffi.Utf8> Function(Pointer<Void>, Pointer<ffi.Utf8>);
typedef _EvalC = Pointer<ffi.Utf8> Function(Pointer<Void>, Pointer<ffi.Utf8>, Pointer<ffi.Utf8>);
typedef _HostReplyC = Int32 Function(Pointer<ffi.Utf8>);
typedef _HostSetCbC = Void Function(Pointer<NativeFunction<_HostCbC>>);
typedef _HostCbC = Void Function(Pointer<ffi.Utf8>, Pointer<ffi.Utf8>);
typedef _DescribeC = Pointer<ffi.Utf8> Function(Pointer<ffi.Utf8>);

typedef _EngineNewD = Pointer<Void> Function();
typedef _EngineFreeD = void Function(Pointer<Void>);
typedef _EngineHostRegD = void Function(Pointer<Void>, Pointer<ffi.Utf8>);
typedef _EngineLimitsD = void Function(Pointer<Void>, int, int);
typedef _ParseD = Pointer<ffi.Utf8> Function(Pointer<Void>, Pointer<ffi.Utf8>);
typedef _EvalD = Pointer<ffi.Utf8> Function(Pointer<Void>, Pointer<ffi.Utf8>, Pointer<ffi.Utf8>);
typedef _HostReplyD = int Function(Pointer<ffi.Utf8>);
typedef _HostSetCbD = void Function(Pointer<NativeFunction<_HostCbC>>);
typedef _DescribeD = Pointer<ffi.Utf8> Function(Pointer<ffi.Utf8>);

final DynamicLibrary _lib = _open();

DynamicLibrary _open() {
  // the hook bundles the asset and flutter loads it into the process at
  // startup, so process() finds the symbols everywhere the code asset was
  // linked; open() is the fallback for a plain dart vm without the asset
  try {
    DynamicLibrary.process().lookup('oii_bridge_describe');
    return DynamicLibrary.process();
  } catch (_) {
    return DynamicLibrary.open('liboii_bridge.so');
  }
}

final _engineNew = _lib.lookupFunction<_EngineNewC, _EngineNewD>('oii_bridge_engine_new');
final _engineFree = _lib.lookupFunction<_EngineFreeC, _EngineFreeD>('oii_bridge_engine_free');
final _hostReg = _lib.lookupFunction<_EngineHostRegC, _EngineHostRegD>('oii_bridge_engine_host_register');
final _hostUnreg = _lib.lookupFunction<_EngineHostRegC, _EngineHostRegD>('oii_bridge_engine_host_unregister');
final _limits = _lib.lookupFunction<_EngineLimitsC, _EngineLimitsD>('oii_bridge_engine_limits');
final _parse = _lib.lookupFunction<_ParseC, _ParseD>('oii_bridge_parse');
final _eval = _lib.lookupFunction<_EvalC, _EvalD>('oii_bridge_eval');
final _hostReply = _lib.lookupFunction<_HostReplyC, _HostReplyD>('oii_bridge_host_reply');
final _hostSetCb = _lib.lookupFunction<_HostSetCbC, _HostSetCbD>('oii_bridge_host_set_callback');
final _describe = _lib.lookupFunction<_DescribeC, _DescribeD>('oii_bridge_describe');

Pointer<ffi.Utf8> _toUtf8(String s) => s.toNativeUtf8(allocator: ffi.malloc);

String _fromUtf8(Pointer<ffi.Utf8> p) => p == nullptr ? '' : p.toDartString();

void _freeUtf8(Pointer<ffi.Utf8> p) {
  if (p != nullptr) ffi.malloc.free(p);
}

/// Result of one eval.
class OiiEvalResult {
  const OiiEvalResult({required this.ok, this.value, this.output = const [], this.steps = 0, this.error = ''});
  final bool ok;
  final Object? value;
  final List<String> output;
  final int steps;
  final String error;

  @override
  String toString() => ok ? 'OiiEvalResult($value)' : 'OiiEvalResult(error: $error)';
}

/// Parse result with oii's rendered diagnostics.
class OiiParseResult {
  const OiiParseResult({required this.ok, this.diagnostics = const []});
  final bool ok;
  final List<String> diagnostics;
}

/// What `plugin [...]` declares: package attributes, the `tool` and `resource`
/// children, plus every func in the file. Stateless: no engine, no host calls,
/// safe on any isolate.
class OiiDescribeResult {
  const OiiDescribeResult({
    required this.ok,
    this.diagnostics = const [],
    this.plugin = const {},
    this.tools = const [],
    this.resources = const [],
    this.funcs = const [],
  });
  final bool ok;
  final List<String> diagnostics;
  final Map<String, Object?> plugin;
  final List<Map<String, Object?>> tools;
  final List<Map<String, Object?>> resources;
  final List<Map<String, Object?>> funcs;

  factory OiiDescribeResult.fromJson(Map<String, dynamic> j) => OiiDescribeResult(
        ok: j['ok'] == true,
        diagnostics: [for (final d in (j['diagnostics'] as List? ?? const [])) '$d'],
        plugin: j['plugin'] is Map ? Map<String, Object?>.from(j['plugin'] as Map) : const {},
        tools: [for (final t in (j['tools'] as List? ?? const [])) if (t is Map) Map<String, Object?>.from(t)],
        resources: [for (final r in (j['resources'] as List? ?? const [])) if (r is Map) Map<String, Object?>.from(r)],
        funcs: [for (final f in (j['funcs'] as List? ?? const [])) if (f is Map) Map<String, Object?>.from(f)],
      );
}

/// Describes oii source without an engine. Pure parse, so it runs inline on
/// the calling isolate.
OiiDescribeResult oiiDescribe(String source) {
  final sp = _toUtf8(source);
  final out = _describe(sp);
  final text = _fromUtf8(out);
  _freeUtf8(out);
  _freeUtf8(sp);
  try {
    return OiiDescribeResult.fromJson(Map<String, dynamic>.from(jsonDecode(text.isEmpty ? '{}' : text) as Map));
  } catch (_) {
    return const OiiDescribeResult(ok: false);
  }
}

/// Result of validating one backup document.
///
/// [data] is the folded document: the same value the app's own decoder
/// produces, so the two can be compared field by field. A failure in [error]
/// is meant to be shown to a person, so it carries oii's own rendered
/// diagnostics with the offending line quoted.
class OiiBackupValidation {
  const OiiBackupValidation({required this.ok, this.name = '', this.data = const {}, this.error = ''});

  final bool ok;

  /// The document's node name, e.g. `chat` or `manifest`'s `backup`.
  final String name;

  /// Fields of the top level node, with `(map)` tags folded to objects.
  final Map<String, Object?> data;
  final String error;

  factory OiiBackupValidation.fromJson(Map<String, dynamic> j) => OiiBackupValidation(
        ok: j['ok'] == true,
        name: '${j['name'] ?? ''}',
        data: j['data'] is Map ? Map<String, Object?>.from(j['data'] as Map) : const {},
        error: '${j['error'] ?? ''}',
      );

  @override
  String toString() => ok ? 'OiiBackupValidation($name, ${data.length} fields)' : 'OiiBackupValidation(error: $error)';
}

final _validateBackup = _lib.lookupFunction<_DescribeC, _DescribeD>('oii_bridge_backup_validate');

/// Checks that [source] is real oii and folds it to data.
///
/// This is the independent reader for backup files the app writes. The app's
/// own decoder is deliberately pure dart, so on its own it can only prove it
/// agrees with itself; this one goes through the oii parser, which is what
/// makes "these files are oii" a fact rather than a claim.
///
/// Stateless like [oiiDescribe], so it runs inline on the calling isolate.
OiiBackupValidation oiiValidateBackupDoc(String source) {
  final sp = _toUtf8(source);
  final out = _validateBackup(sp);
  final text = _fromUtf8(out);
  _freeUtf8(out);
  _freeUtf8(sp);
  try {
    return OiiBackupValidation.fromJson(Map<String, dynamic>.from(jsonDecode(text.isEmpty ? '{}' : text) as Map));
  } catch (_) {
    return const OiiBackupValidation(ok: false, error: 'the bridge returned something unreadable');
  }
}

/// A host function a script may call. Runs on the isolate the engine was
/// created on; the return value must be json encodable. May be async: the
/// rust eval parks on its reply channel until the future completes, so a
/// slow host call stalls that engine but never the UI.
typedef OiiHostFn = FutureOr<Object?> Function(List<Object?> args);

/// One embedded oii interpreter.
class OiiEngine {
  OiiEngine._(this._commands) : _hostFns = {};

  final SendPort _commands;
  final Map<String, OiiHostFn> _hostFns;

  static Future<OiiEngine> spawn({int maxSteps = 1000000, int maxDepth = 256}) async {
    final ready = ReceivePort();
    await Isolate.spawn(_workerMain, (ready.sendPort, maxSteps, maxDepth));
    final commands = await ready.first as SendPort;
    final engine = OiiEngine._(commands);
    _engines.add(engine);
    // the bridge keeps one callback slot; the first engine on this isolate
    // installs it and every later dispatch reads the pending call, whose
    // name routes to the right engine
    _hostSetCb(_cb.nativeFunction);
    return engine;
  }

  // The callback fires on this isolate while the rust eval thread blocks on
  // the reply, which is the whole handshake. Created once, alive as long as
  // any engine is.
  static late final NativeCallable<Void Function(Pointer<ffi.Utf8>, Pointer<ffi.Utf8>)> _cb = NativeCallable<Void Function(Pointer<ffi.Utf8>, Pointer<ffi.Utf8>)>.listener(_onHostCall);

  static void _onHostCall(Pointer<ffi.Utf8> name, Pointer<ffi.Utf8> args) {
    final nameStr = _fromUtf8(name);
    final argsStr = _fromUtf8(args);
    _freeUtf8(name);
    _freeUtf8(args);
    // find whichever engine registered the name; the fn registry is per
    // engine, the pending call carries its own name
    for (final engine in _engines) {
      final fn = engine._hostFns[nameStr];
      if (fn == null) continue;
      List<Object?> decoded;
      try {
        final raw = jsonDecode(argsStr);
        decoded = raw is List ? List<Object?>.from(raw) : <Object?>[];
      } catch (_) {
        decoded = <Object?>[];
      }
      FutureOr<Object?> result;
      try {
        result = fn(decoded);
      } catch (_) {
        _reply(null);
        return;
      }
      // async hosts answer later; the rust side waits on the channel either
      // way, so from its side sync and async are the same call
      if (result is Future<Object?>) {
        result.then(_reply, onError: (_) => _reply(null));
      } else {
        _reply(result);
      }
      return;
    }
    _reply(null);
  }

  static void _reply(Object? result) {
    Pointer<ffi.Utf8> reply;
    try {
      reply = _toUtf8(jsonEncode(result ?? null));
    } catch (_) {
      reply = _toUtf8('null');
    }
    _hostReply(reply);
    _freeUtf8(reply);
  }

  static final List<OiiEngine> _engines = [];

  /// Registers a host function. Scripts call it by this exact name. The
  /// registry rides the worker command queue because the handle lives there;
  /// the dart side registry is what dispatch actually reads.
  void registerHost(String name, OiiHostFn fn) {
    _hostFns[name] = fn;
    _commands.send([{'op': 'host_register', 'name': name}, null]);
  }

  void unregisterHost(String name) {
    _hostFns.remove(name);
    _commands.send([{'op': 'host_unregister', 'name': name}, null]);
  }

  /// Parses [source] into the engine. A failed parse keeps the previous doc,
  /// and the diagnostics ride back rendered.
  Future<OiiParseResult> parse(String source) async {
    final r = await _call({'op': 'parse', 'source': source});
    return OiiParseResult(
      ok: r['ok'] == true,
      diagnostics: [for (final d in (r['diagnostics'] as List? ?? const [])) '$d'],
    );
  }

  /// Calls a func in the engine's current doc.
  Future<OiiEvalResult> eval(String func, [List<Object?> args = const []]) async {
    final r = await _call({'op': 'eval', 'name': func, 'args': args});
    return OiiEvalResult(
      ok: r['ok'] == true,
      value: r['value'],
      output: [for (final o in (r['output'] as List? ?? const [])) '$o'],
      steps: (r['steps'] as num?)?.toInt() ?? 0,
      error: '${r['error'] ?? ''}',
    );
  }

  Future<Map<String, dynamic>> _call(Map<String, dynamic> command) async {
    final reply = ReceivePort();
    _commands.send([command, reply.sendPort]);
    final result = await reply.first;
    reply.close();
    return Map<String, dynamic>.from(result as Map);
  }

  void dispose() {
    _engines.remove(this);
    _commands.send(const [
      {'op': 'exit'},
      null,
    ]);
  }
}

// ------------------------------------------------------------------ worker

void _workerMain((SendPort, int, int) init) {
  final (ready, maxSteps, maxDepth) = init;
  final handle = _engineNew();
  _limits(handle, maxSteps, maxDepth);
  final commands = ReceivePort();
  ready.send(commands.sendPort);
  commands.listen((message) {
    // maps cross the port as <String, String?>; unpack defensively because
    // records do not survive the send round trip as records. a null reply
    // port marks a fire and forget command
    final record = message! as List;
    final command = Map<String, dynamic>.from(record[0] as Map);
    final reply = record[1] as SendPort?;
    final op = '${command['op']}';
    if (op == 'exit') {
      _engineFree(handle);
      Isolate.current.kill();
      return;
    }
    if (op == 'host_register' || op == 'host_unregister') {
      final n = _toUtf8('${command['name']}');
      if (op == 'host_register') {
        _hostReg(handle, n);
      } else {
        _hostUnreg(handle, n);
      }
      _freeUtf8(n);
      reply?.send({'ok': true});
      return;
    }
    final src = op == 'parse' ? (command['source'] as String) : '';
    final name = op == 'eval' ? (command['name'] as String) : '';
    final args = jsonEncode(command['args'] ?? const []);
    final sp = _toUtf8(src);
    final np = _toUtf8(name);
    final ap = _toUtf8(args);
    final out = op == 'parse' ? _parse(handle, sp) : _eval(handle, np, ap);
    final text = _fromUtf8(out);
    _freeUtf8(out);
    _freeUtf8(sp);
    _freeUtf8(np);
    _freeUtf8(ap);
    reply?.send(jsonDecode(text.isEmpty ? '{}' : text));
  });
}
