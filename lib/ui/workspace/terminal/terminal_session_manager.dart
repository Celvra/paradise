import 'dart:async';
import 'package:path/path.dart' as p;
// prefixed: terminal_view exports its own Utf8Decoder for the guest side and the
// two would otherwise be ambiguous at every use
import 'dart:convert' as conv;

import 'package:flutter/foundation.dart';
import 'package:terminal_view/terminal_view.dart';

import '../../../data/workspace/workspace_bootstrap.dart';
import '../../../data/workspace/workspace_runtime.dart';
import '../../../data/workspace/workspace_paths.dart';

/// what the guest shell is told about itself
const terminalGuestEnv = {
  'TERM': 'xterm-256color',
  'LANG': 'C.UTF-8',
  'COLORTERM': 'truecolor',
  'HOME': '/root',
};

const defaultTerminalFontSize = 13.0;
const minTerminalFontSize = 8.0;
const maxTerminalFontSize = 26.0;

double clampTerminalFontSize(double v) =>
    v.clamp(minTerminalFontSize, maxTerminalFontSize);

/// one open shell
///
/// holds the emulator the pty behind it and the two byte directions. input
/// leaves through onOutput where the sticky ctrl alt toggles are folded in
/// output comes back through a utf8 decoder and a resize has to travel all the
/// way to a TIOCSWINSZ in the guest
class TerminalSession {
  TerminalSession({
    required this.id,
    required this.terminal,
    required this.pty,
    required this.title,
    required this.cwd,
    required this.mounts,
    required this.onChanged,
    this.workspaceId,
    this.chatId,
  });

  final String id;
  final Terminal terminal;
  final PtySession pty;

  /// tells the owning manager that a chip or a tab has to redraw
  final void Function() onChanged;

  /// mutable: the tab strip renames sessions
  String title;

  /// kept for the reuse check and for reopening the same shell
  final String cwd;
  final List<Mount> mounts;
  final String? workspaceId;
  final String? chatId;

  double fontSize = defaultTerminalFontSize;

  // sticky modifiers. a phone keyboard has no ctrl key so the toggle applies
  // to exactly one input and then drops
  bool ctrlModifier = false;
  bool altModifier = false;

  bool _exited = false;
  int _exitCode = -1;

  bool get isExited => _exited;
  bool get isAlive => !_exited;
  int get exitCode => _exitCode;

  void markExited(int code) {
    if (_exited) return;
    _exited = true;
    _exitCode = code;
    // printed into the emulator rather than shown as an overlay: a shell that
    // exited with nothing else on screen would otherwise look like the
    // terminal simply stopped working
    terminal.write(
        '\r\n\x1b[2m[exited ${code == 0 ? '' : 'with code $code '}]\x1b[0m\r\n');
    onChanged();
  }

  /// typed characters straight through
  void sendText(String text) {
    if (text.isEmpty || _exited) return;
    terminal.textInput(text);
  }

  /// clipboard content. bracketed when the guest asked for bracketed paste so
  /// a multiline paste does not fire line by line
  void pasteText(String text) {
    if (text.isEmpty || _exited) return;
    terminal.paste(text);
  }

  /// a named key with the sticky modifiers folded in and then dropped
  void sendKey(TerminalKey key, {bool applyModifiers = true}) {
    if (_exited) return;
    final ctrl = applyModifiers && ctrlModifier;
    final alt = applyModifiers && altModifier;
    // escape and tab read ctrl as themselves
    final effective =
        (key == TerminalKey.escape || key == TerminalKey.tab) ? false : ctrl;
    terminal.keyInput(key, ctrl: effective, alt: alt);
    if (applyModifiers) clearModifiers();
  }

  void toggleCtrl() {
    ctrlModifier = !ctrlModifier;
    onChanged();
  }

  void toggleAlt() {
    altModifier = !altModifier;
    onChanged();
  }

  void clearModifiers() {
    if (!ctrlModifier && !altModifier) return;
    ctrlModifier = false;
    altModifier = false;
    onChanged();
  }

  void setFontSize(double v) {
    final next = clampTerminalFontSize(v);
    if (next == fontSize) return;
    fontSize = next;
    onChanged();
  }

  /// the whole scrollback for the copy all action
  String getAllText() => terminal.buffer.getText();

  /// wipe the screen and home the cursor. scrollback stays reachable by
  /// scrolling up which is what the shells own clear does
  void clearScreen() {
    terminal.eraseDisplay();
    terminal.setCursor(0, 0);
    terminal.notifyListeners();
  }

  Future<void> dispose() => pty.close();
}

/// owns the open sessions
///
/// a ChangeNotifier because the tab strip and the page both rebuild when a
/// session opens closes exits or renames
class TerminalSessionManager extends ChangeNotifier {
  final Map<String, TerminalSession> _sessions = {};
  final WorkspaceRuntime? Function() runtime;

  TerminalSessionManager({required this.runtime});

  /// the one manager the app has
  ///
  /// a shell outlives the page that opened it, so a manager per page would mean
  /// a session the user cannot get back to
  static final TerminalSessionManager shared =
      TerminalSessionManager(runtime: () => workspaceRuntimeProvider.runtime);

  /// font size for the next shell. pinch zoom moves it so a new shell starts
  /// where the user left the last one
  double defaultFontSize = defaultTerminalFontSize;

  List<TerminalSession> get sessions => _sessions.values.toList();
  TerminalSession? byId(String id) => _sessions[id];

  /// a session that can be reused rather than a second shell in the same place
  ///
  /// reuse is keyed on the target and the mounts, not just the cwd: two
  /// sessions in one directory but with different mounts are different shells
  TerminalSession? findReusable(
      {String? chatId,
      String? workspaceId,
      required String cwd,
      required List<Mount> mounts}) {
    final guestCwd = _normalizeCwd(cwd);
    TerminalSession? best;
    for (final s in _sessions.values) {
      if (!s.isAlive) continue;
      if (s.chatId != chatId || s.workspaceId != workspaceId) continue;
      if (s.cwd != guestCwd) continue;
      if (!_sameMounts(s.mounts, mounts)) continue;
      if (best == null || s.id.compareTo(best.id) > 0) best = s;
    }
    return best;
  }

  static bool _sameMounts(List<Mount> a, List<Mount> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// a session target key for the reuse check
  static String targetKey(
          {String? chatId, String? workspaceId, required String cwd}) =>
      chatId != null
          ? 'conversation:$chatId|$cwd'
          : (workspaceId != null ? 'workspace:$workspaceId|$cwd' : 'cwd:$cwd');

  Future<TerminalSession> open({
    String? chatId,
    String? workspaceId,
    required String cwd,
    List<Mount> mounts = const [],
    Map<String, String> env = const {},
    String? title,
    String initialCommand = '',
    int cols = 80,
    int rows = 24,
  }) async {
    final rt = runtime();
    if (rt == null || !rt.supportsPty)
      throw StateError('the workspace runtime has no terminal');
    final status = await rt.status();
    if (!status.ready)
      throw StateError(status.reason.isEmpty
          ? 'the Linux environment is not ready'
          : status.reason);
    final guestCwd = _normalizeCwd(cwd);
    // time based rather than a counter: the native pty map outlives the dart
    // isolate across a hot restart, so a counter collides on the second run
    final id =
        'pty-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_seq++}';

    final terminal =
        Terminal(maxLines: 10000, platform: TerminalTargetPlatform.android);

    final pty = await rt.openPty(
      sessionId: id,
      mounts: mounts,
      cwd: guestCwd,
      env: {...terminalGuestEnv, ...env},
      cols: cols,
      rows: rows,
    );
    if (pty == null) throw StateError('the runtime refused to open a terminal');

    final session = TerminalSession(
      id: id,
      terminal: terminal,
      pty: pty,
      title: uniqueTitle(title ?? guestCwd.split('/').last,
          _sessions.values.map((e) => e.title)),
      cwd: guestCwd,
      mounts: mounts,
      chatId: chatId,
      workspaceId: workspaceId,
      onChanged: notifyListeners,
    )..setFontSize(defaultFontSize);

    // every input path ends at onOutput, so the sticky ctrl alt toggles are
    // folded in here. the soft keyboard types through textInput and never
    // passes sendKey at all, which is why the fold cannot live in the key bar
    terminal.onOutput = (data) {
      if (session.isExited) return;
      final payload = _applyModifiers(session, data);
      if (payload.isEmpty) return;
      unawaited(
          session.pty.write(Uint8List.fromList(conv.utf8.encode(payload))));
    };

    // a font or ime change reports a new grid through onResize and that has to
    // reach the guest as a real TIOCSWINSZ or full screen programs draw at the
    // old size
    terminal.onResize = (w, h, pw, ph) => unawaited(session.pty.resize(w, h));

    // subscribes to the pty. whatever the shell printed while open was in
    // flight is still in the stream, so the prompt is not lost here
    _wire(session);
    _sessions[id] = session;
    notifyListeners();

    // typed onto the shell input line rather than exec'd, so the user sees it
    // and can edit it before the newline
    if (initialCommand.isNotEmpty) {
      session.sendText(initialCommand);
      session.sendKey(TerminalKey.enter, applyModifiers: false);
    }
    return session;
  }

  /// folds the sticky toggles into the next single character
  static String _applyModifiers(TerminalSession session, String data) {
    var out = data;
    if (session.ctrlModifier && out.length == 1) {
      final mapped = _ctrlChar(out.codeUnitAt(0));
      if (mapped != null) {
        out = mapped;
        session.ctrlModifier = false;
        session.onChanged();
      }
    }
    if (session.altModifier && out.length == 1) {
      final unit = out.codeUnitAt(0);
      if (unit >= 32 && unit != 0x7f) {
        out = '\x1b$out';
        session.altModifier = false;
        session.onChanged();
      }
    }
    return out;
  }

  // a to z and bracket to underscore, the two ctrl tables every terminal uses
  static String? _ctrlChar(int unit) {
    if (unit >= 97 && unit <= 122) return String.fromCharCode(unit - 96);
    if (unit >= 64 && unit <= 95) return String.fromCharCode(unit - 64);
    return null;
  }

  static String _normalizeCwd(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value == '.') return WorkspacePaths.guestWorkspace;
    final guest = value.startsWith('/')
        ? value
        : p.posix.join(WorkspacePaths.guestWorkspace, value);
    final normalized = p.posix.normalize(guest);
    if (!normalized.startsWith('${WorkspacePaths.guestWorkspace}/') &&
        normalized != WorkspacePaths.guestWorkspace) {
      return WorkspacePaths.guestWorkspace;
    }
    return normalized;
  }

  /// the two byte directions, decoded
  ///
  /// Utf8Decoder as a stream transformer rather than a chunked conversion sink:
  /// the decoder keeps a partial rune across reads so a multibyte character
  /// split between two pty reads is not turned into two replacement
  /// characters. it also emits each decoded chunk as it arrives
  void _wire(TerminalSession session) {
    final sub = session.pty.output
        .cast<List<int>>()
        .transform(const conv.Utf8Decoder(allowMalformed: true))
        .listen((text) {
      if (text.isNotEmpty) session.terminal.write(text);
    }, onError: (Object _) {});

    unawaited(session.pty.exitCode.then((code) {
      sub.cancel();
      session.markExited(code);
    }));
  }

  int _seq = 0;

  Future<void> close(String id) async {
    final s = _sessions.remove(id);
    if (s == null) return;
    await s.dispose();
    notifyListeners();
  }

  Future<void> closeAll() async {
    final all = _sessions.values.toList();
    _sessions.clear();
    for (final s in all) {
      await s.dispose();
    }
    notifyListeners();
  }

  void rename(String id, String title) {
    final s = _sessions[id];
    if (s == null || title.trim().isEmpty) return;
    s.title = title.trim();
    notifyListeners();
  }

  /// clamps and remembers the size for the next shell too
  void setFontSize(String id, double size) {
    defaultFontSize = clampTerminalFontSize(size);
    final s = _sessions[id];
    if (s == null) {
      notifyListeners();
      return;
    }
    s.setFontSize(defaultFontSize);
  }

  /// `demo`, `demo 2`, `demo 3` for shells opened into the same directory
  static String uniqueTitle(String wanted, Iterable<String> taken) {
    final base = wanted.trim().isEmpty ? 'terminal' : wanted.trim();
    if (!taken.contains(base)) return base;
    for (var i = 2; i < 1000; i++) {
      final n = '$base $i';
      if (!taken.contains(n)) return n;
    }
    return '$base ${DateTime.now().millisecondsSinceEpoch}';
  }
}
