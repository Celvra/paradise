import 'dart:async';

import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:terminal_view/terminal_view.dart';

import '../../../data/workspace/workspace_runtime.dart' show Mount;
import '../../../core/anim.dart';
import '../../../core/overlays.dart';
import '../../../core/theme.dart';
import '../../../core/ui_kit.dart';
import '../../../l10n/x.dart';
import '../../tg_cells.dart' show rectOf;
import '../workspace_prompts.dart' show TgIconButton;
import '../environment_page.dart';
import 'terminal_key_bar.dart';
import 'terminal_session_manager.dart';
import 'terminal_tab_strip.dart';

/// the terminal page: a strip of shells, the emulator and a key row
///
/// one page owns all of a chat's shells rather than one page per shell, so
/// switching is instant and a shell keeps running while the user looks at
/// another
class TerminalPage extends StatefulWidget {
  const TerminalPage(
      {super.key,
      this.sessionManager,
      this.cwd = '/workspace',
      this.title,
      this.workspaceId,
      this.chatId,
      this.mounts = const []});
  final TerminalSessionManager? sessionManager;

  /// model vocabulary. the first shell starts here and every later one reuses
  /// it, so the directory does not silently reset when the user adds a tab
  final String cwd;
  final String? title;
  final String? workspaceId;
  final String? chatId;
  final List<Mount> mounts;

  @override
  State<TerminalPage> createState() => TerminalPageState();
}

class TerminalPageState extends State<TerminalPage> {
  late final TerminalSessionManager _manager;
  // keyed by session id. an index keyed list desyncs the moment a session in
  // the middle is closed and then the selection clipboard belongs to the
  // wrong shell
  final Map<String, TerminalController> _controllers = {};
  final Map<String, VoidCallback> _selectionListeners = {};
  final Map<String, Timer> _copyTimers = {};
  String? _activeId;
  bool _opening = false;
  bool _checkingEnvironment = true;
  bool _environmentReady = false;
  String _statusReason = '';
  double _pinchBase = defaultTerminalFontSize;
  // anchors the overflow menu to the more button. held on the state because a
  // key minted inside build is new every rebuild and measures nothing
  final GlobalKey _moreKey = GlobalKey();

  TerminalSession? get session =>
      _activeId == null ? null : _manager.byId(_activeId!);

  @override
  void initState() {
    super.initState();
    _manager = widget.sessionManager ?? TerminalSessionManager.shared;
    _manager.addListener(_onChanged);
    unawaited(_checkEnvironment());
  }

  @override
  void dispose() {
    _manager.removeListener(_onChanged);
    for (final t in _copyTimers.values) {
      t.cancel();
    }
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // one rebuild path for everything the manager owns: sessions opening and
  // closing, a shell exiting, a modifier toggle, a rename
  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkEnvironment() async {
    final runtime = _manager.runtime();
    if (runtime == null || !runtime.supportsPty) {
      if (mounted) setState(() => _checkingEnvironment = false);
      return;
    }
    final status = await runtime.status();
    if (!mounted) return;
    setState(() {
      _checkingEnvironment = false;
      _environmentReady = status.ready;
      _statusReason = status.reason;
    });
    if (status.ready) unawaited(_openFirst());
  }

  Future<void> _openFirst() async {
    final existing = _manager.findReusable(
        chatId: widget.chatId,
        workspaceId: widget.workspaceId,
        cwd: widget.cwd,
        mounts: widget.mounts);
    if (existing != null) {
      _select(existing.id);
      return;
    }
    await _open();
  }

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final s = await _manager.open(
        chatId: widget.chatId,
        workspaceId: widget.workspaceId,
        cwd: widget.cwd,
        mounts: widget.mounts,
        title: widget.title,
      );
      if (!mounted) return;
      _select(s.id);
    } catch (e) {
      if (mounted)
        showBulletin(context, '${L10n.current.termOpenFailedShort}: $e');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _select(String id) {
    setState(() {
      _activeId = id;
      _controllerFor(id);
    });
  }

  Future<void> _close(String id) async {
    final s = _manager.byId(id);
    if (s == null) return;
    // a shell with a process behind it is worth a confirmation, a dead one is
    // not
    if (s.isAlive) {
      final ok = await showTgDialog<bool>(
        context,
        title: context.l.actionClose,
        message: context.l.termCloseConfirm,
        actions: [
          DialogAction(context.l.actionCancel, false),
          DialogAction(context.l.actionClose, true, danger: true)
        ],
      );
      if (ok != true || !mounted) return;
    }
    await _manager.close(id);
    if (!mounted) return;
    _dropSession(id);
    final rest = _manager.sessions;
    if (rest.isEmpty) {
      // closing the last shell goes back. reopening a fresh one behind the
      // user's back reads as a shell that refuses to die
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _activeId = rest.last.id);
  }

  /// per session controller, created on first use
  TerminalController _controllerFor(String id) {
    return _controllers.putIfAbsent(id, () {
      final c = TerminalController();
      // selection follows the desktop convention: lift the finger, the text
      // is on the clipboard. debounced because a drag emits a change a frame
      void listener() {
        _copyTimers[id]?.cancel();
        _copyTimers[id] = Timer(const Duration(milliseconds: 350), () {
          final s = _manager.byId(id);
          final range = c.selection;
          if (s == null || range == null) return;
          final text = s.terminal.buffer.getText(range);
          if (text.trim().isEmpty) return;
          Clipboard.setData(ClipboardData(text: text));
        });
      }

      c.addListener(listener);
      _selectionListeners[id] = listener;
      return c;
    });
  }

  void _dropSession(String id) {
    _copyTimers.remove(id)?.cancel();
    final listener = _selectionListeners.remove(id);
    if (listener != null) _controllers.remove(id)?.removeListener(listener);
  }

  /// copies the selection if there is one, the whole scrollback if not
  void _copy() {
    final s = session;
    if (s == null) return;
    final controller = _controllers[s.id];
    final range = controller?.selection;
    final text =
        range == null ? s.getAllText() : s.terminal.buffer.getText(range);
    if (text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    showBulletin(context, L10n.current.termCopied);
  }

  Future<void> _paste() async {
    final s = session;
    if (s == null) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) s.pasteText(text);
  }

  Future<void> _rename(String id) async {
    final s = _manager.byId(id);
    if (s == null) return;
    final l = context.l;
    final ok = await showTgInput(context,
        title: l.termRename, initial: s.title, hint: l.termRename);
    if (ok == null || ok.trim().isEmpty || !mounted) return;
    _manager.rename(id, ok);
  }

  /// the emulator with a two finger scale for the font
  Widget _emulator(TerminalSession s) {
    final controller = _controllerFor(s.id);
    final mq = MediaQuery.of(context);
    return ColoredBox(
      color: pEmulator(context.p),
      child: GestureDetector(
        onScaleStart: (_) => _pinchBase = s.fontSize,
        onScaleUpdate: (d) {
          // two fingers only. a one finger vertical drag is how the emulator
          // scrolls, and stealing it for zoom would break scrolling
          if (d.pointerCount < 2) return;
          _manager.setFontSize(s.id, _pinchBase * d.scale);
        },
        child: TerminalView(
          s.terminal,
          controller: controller,
          autofocus: true,
          deleteDetection: true,
          backgroundOpacity: 0,
          keyboardAppearance: mq.platformBrightness,
          textStyle: TerminalStyle(fontSize: s.fontSize),
          theme: terminalTheme(context.p),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    if (_checkingEnvironment || !_environmentReady) {
      return _emptyEnvironment(context);
    }
    final mq = MediaQuery.of(context);
    final kb = mq.viewInsets.bottom;
    final active = session;
    // the keyboard lifts the whole page, emulator included. the view relayouts
    // to fewer rows and autoResize turns that into a TIOCSWINSZ, so vim or
    // htop redraw at the size the user can see rather than under the keyboard
    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: ColoredBox(
        color: p.gray,
        child: Column(children: [
          _bar(context, p, active),
          Container(height: .5, color: p.divider),
          if (_manager.sessions.length > 1)
            TerminalTabStrip(
              sessions: _manager.sessions,
              activeId: active?.id,
              onSelect: _select,
              onAdd: () => unawaited(_open()),
              onRename: (id) => unawaited(_rename(id)),
              onClose: (id) => unawaited(_close(id)),
            ),
          Expanded(
            child: active == null
                ? Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: p.subtitle)))
                : _emulator(active),
          ),
          if (active != null)
            TerminalKeyBar(
                session: active,
                onCopy: _copy,
                onPaste: () => unawaited(_paste())),
        ]),
      ),
    );
  }

  Widget _emptyEnvironment(BuildContext context) {
    final p = context.p;
    return ColoredBox(
      color: p.gray,
      child: Column(children: [
        _bar(context, p, null),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TgIcon(Ic.terminal, color: p.subtitle, size: 42),
                const SizedBox(height: 16),
                Text(context.l.termNoEnvironment,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: p.title,
                        fontSize: 17,
                        decoration: TextDecoration.none)),
                // the runtime's own refusal, shown verbatim: proot missing,
                // wrong architecture or no marker each need a different fix
                if (_statusReason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(_statusReason,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: p.subtitle,
                          fontSize: 12,
                          decoration: TextDecoration.none)),
                ],
                const SizedBox(height: 8),
                Text(context.l.termInstallEnvironment,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: p.subtitle,
                        fontSize: 14,
                        height: 1.35,
                        decoration: TextDecoration.none)),
                const SizedBox(height: 20),
                TgButton(
                    label: context.l.termOpenSettings,
                    onTap: () => openEnvironmentSettings(context)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _bar(BuildContext context, Pal p, TerminalSession? s) {
    return Container(
      color: p.bar,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: SizedBox(
        height: 56,
        child: Row(children: [
          Tap(
              scale: .88,
              onTap: () => Navigator.of(context).maybePop(),
              child: SizedBox(
                  width: 56,
                  height: 56,
                  child:
                      Center(child: TgIcon(Ic.back, color: p.icon, size: 24)))),
          Expanded(
            child: Text(
              s?.title ?? L10n.current.termTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: p.title,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none),
            ),
          ),
          if (s != null) ...[
            TgIconButton(
                icon: Ic.plus,
                tooltip: L10n.current.termNewShell,
                onTap: () => unawaited(_open())),
            TgIconButton(
              key: _moreKey,
              icon: Ic.more,
              onTap: () => unawaited(_overflow()),
            ),
          ],
        ]),
      ),
    );
  }

  Future<void> _overflow() async {
    final l = context.l;
    final s = session;
    if (s == null) return;
    await showTgMenu(
      context,
      anchor: rectOf(_moreKey.currentContext ?? context),
      items: [
        MenuItem(l.actionEdit, Ic.pencil, () => unawaited(_rename(s.id))),
        MenuItem(l.termCopyAll, Ic.copy, _copy),
        MenuItem(l.termClear, Ic.wrap, () => s.clearScreen()),
        MenuItem(l.termFontSmaller, Ic.minus,
            () => _manager.setFontSize(s.id, s.fontSize - 1)),
        MenuItem(l.termFontBigger, Ic.plus,
            () => _manager.setFontSize(s.id, s.fontSize + 1)),
        MenuItem(l.actionClose, Ic.close, () => unawaited(_close(s.id)),
            danger: true),
      ],
    );
  }
}

/// surface behind the glyphs, one step off the page so the terminal reads as
/// its own thing in both modes
Color pEmulator(Pal p) =>
    p.dark ? const Color(0xFF0E1116) : const Color(0xFFF7F8FA);

/// the emulator palette, derived from the app's own so a terminal is not a
/// bright block in a dark ui
///
/// the ansi sixteen are desaturated a little in light mode: the stock set is
/// tuned for a black background and its dark blues vanish on white
TerminalTheme terminalTheme(Pal p) {
  final dark = p.dark;
  Color ansi(double h, double s, double l) =>
      HSLColor.fromAHSL(1, h, s, dark ? l : l * .92).toColor();
  return TerminalTheme(
    foreground: dark ? const Color(0xFFD5D9DE) : const Color(0xFF24292F),
    background: pEmulator(p),
    cursor: p.accent,
    cursorAccent: pEmulator(p),
    selection: p.accent.withAlpha(dark ? 90 : 70),
    minimumContrastRatio: 1.4,
    drawBoldTextInBrightColors: true,
    black: ansi(0, 0, dark ? .16 : .18),
    red: ansi(0, .74, dark ? .58 : .45),
    green: ansi(120, .55, dark ? .58 : .34),
    yellow: ansi(45, .78, dark ? .66 : .42),
    blue: ansi(215, .82, dark ? .64 : .42),
    magenta: ansi(300, .62, dark ? .64 : .44),
    cyan: ansi(190, .58, dark ? .6 : .38),
    white: ansi(0, 0, dark ? .72 : .62),
    brightBlack: ansi(0, 0, .48),
    brightRed: ansi(0, .82, dark ? .74 : .55),
    brightGreen: ansi(120, .64, dark ? .74 : .42),
    brightYellow: ansi(45, .86, dark ? .8 : .52),
    brightBlue: ansi(215, .88, dark ? .78 : .52),
    brightMagenta: ansi(300, .72, dark ? .78 : .54),
    brightCyan: ansi(190, .7, dark ? .74 : .46),
    brightWhite: ansi(0, 0, dark ? .94 : .8),
    searchHitBackground:
        dark ? const Color(0xFFFFE082) : const Color(0xFFFFC107),
    searchHitBackgroundCurrent:
        dark ? const Color(0xFFFF8A80) : const Color(0xFFFF7043),
    searchHitForeground: const Color(0xFF101418),
  );
}
