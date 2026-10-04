import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/anim.dart';
import '../../../../core/overlays.dart';
import '../../../../core/theme.dart';
import '../../../../core/ui_kit.dart';
import '../../../../l10n/x.dart';
import 'terminal_session_manager.dart';

/// the row of open shells above the terminal
///
/// only shown with more than one session. a single shell needs no strip and
/// the new shell button lives in the top bar
class TerminalTabStrip extends StatefulWidget {
  const TerminalTabStrip(
      {super.key,
      required this.sessions,
      required this.activeId,
      required this.onSelect,
      required this.onAdd,
      required this.onRename,
      required this.onClose});

  final List<TerminalSession> sessions;
  final String? activeId;
  final void Function(String id) onSelect;
  final VoidCallback onAdd;
  final void Function(String id) onRename;
  final void Function(String id) onClose;

  @override
  State<TerminalTabStrip> createState() => _TerminalTabStripState();
}

class _TerminalTabStripState extends State<TerminalTabStrip> {
  final _keys = <String, GlobalKey>{};

  @override
  void didUpdateWidget(TerminalTabStrip old) {
    super.didUpdateWidget(old);
    _keys.removeWhere((id, _) => !widget.sessions.any((s) => s.id == id));
  }

  /// scrolls the active tab into view when it changes
  ///
  /// skipped when already visible: a scroll that is not needed still animates
  /// and a strip that jitters every time output arrives is worse than one
  /// that lags by a tab
  void _ensureVisible() {
    final id = widget.activeId;
    if (id == null) return;
    final box = _keys[id]?.currentContext;
    if (box == null || !box.mounted) return;
    final scroll = Scrollable.maybeOf(box);
    if (scroll != null && scroll.position.hasViewportDimension) {
      final obj = box.findRenderObject() as RenderBox?;
      if (obj != null) {
        final view = RenderAbstractViewport.maybeOf(obj);
        if (view != null) {
          final origin = view.getOffsetToReveal(obj, 0).offset;
          final pixels = scroll.position.pixels;
          final span = scroll.position.viewportDimension;
          if (origin >= pixels - .5 &&
              origin + obj.size.width <= pixels + span + .5) return;
        }
      }
    }
    Scrollable.ensureVisible(box,
        alignment: 0.5,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic);
  }

  Future<void> _menu(TerminalSession s, Offset at) async {
    final ctx = context;
    await showTgMenu(
      ctx,
      anchor: at & const Size(1, 1),
      items: [
        MenuItem(ctx.l.actionEdit, Ic.pencil, () => widget.onRename(s.id)),
        MenuItem(ctx.l.actionClose, Ic.close, () => widget.onClose(s.id),
            danger: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible());
    return Container(
      height: 42,
      color: context.p.gray,
      child: Row(children: [
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            itemCount: widget.sessions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 5),
            itemBuilder: (c, i) {
              final s = widget.sessions[i];
              return KeyedSubtree(
                key: _keys.putIfAbsent(s.id, GlobalKey.new),
                child: _Tab(
                  session: s,
                  active: s.id == widget.activeId,
                  onTap: () => widget.onSelect(s.id),
                  onLongPress: (at) => unawaited(_menu(s, at)),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab(
      {required this.session,
      required this.active,
      required this.onTap,
      required this.onLongPress});
  final TerminalSession session;
  final bool active;
  final VoidCallback onTap;
  final void Function(Offset at) onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Tap(
      onTap: onTap,
      onLongPress: () {
        final box = context.findRenderObject() as RenderBox?;
        final at = box == null || !box.hasSize
            ? Offset.zero
            : box.localToGlobal(box.size.center(Offset.zero));
        onLongPress(at);
      },
      child: Container(
        constraints: const BoxConstraints(minWidth: 90, maxWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? p.bg : p.selector.withAlpha(p.dark ? 70 : 50),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          // a live shell gets a dot rather than a coloured tab: a tab that
          // changes colour is a tab the user has to look at twice
          if (session.isAlive)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFF3FB950), shape: BoxShape.circle),
            ),
          Flexible(
              child: Text(session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: active ? p.title : p.subtitle,
                      fontSize: 13,
                      decoration: TextDecoration.none))),
          // a pill rather than bare digits so an exit code reads as a state
          // and not as part of the name
          if (session.isExited) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: session.exitCode == 0
                    ? p.selector.withAlpha(p.dark ? 90 : 60)
                    : p.danger.withAlpha(28),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                session.exitCode == 0 ? '✓' : '${session.exitCode}',
                style: TextStyle(
                    color: session.exitCode == 0 ? p.subtitle : p.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
