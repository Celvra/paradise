import 'package:flutter/widgets.dart';

import 'package:flutter/services.dart';
import 'package:terminal_view/terminal_view.dart' show TerminalKey;

import '../../../../core/anim.dart';
import '../../../../core/theme.dart';
import '../../../../core/ui_kit.dart';

import 'terminal_session_manager.dart';

/// the key row under the terminal
///
/// a phone keyboard has no ctrl no esc and no arrows, and a shell without
/// those is barely a shell. everything here sends the real vt sequence rather
/// than a character, which is why it exists at all
class TerminalKeyBar extends StatelessWidget {
  const TerminalKeyBar(
      {super.key,
      required this.session,
      required this.onCopy,
      required this.onPaste});

  final TerminalSession session;
  final VoidCallback onCopy;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final mq = MediaQuery.of(context);
    // when the keyboard is up the page itself has been lifted by the ime
    // inset, so padding the safe area here again would leave the bar floating
    // a nav bar height above it
    final keyboardUp = mq.viewInsets.bottom > 0;
    final bar = Container(
      height: 40,
      color: p.bg,
      child: Row(children: [
        Expanded(
          child: Stack(children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(children: [
                _key(
                    context,
                    'Esc',
                    () => session.sendKey(TerminalKey.escape,
                        applyModifiers: false)),
                _key(
                    context,
                    'Tab',
                    () => session.sendKey(TerminalKey.tab,
                        applyModifiers: false)),
                _key(context, 'Ctrl', () => session.toggleCtrl(),
                    active: session.ctrlModifier, sticky: true),
                _key(context, 'Alt', () => session.toggleAlt(),
                    active: session.altModifier, sticky: true),
                _sep(p),
                _key(
                    context, '←', () => session.sendKey(TerminalKey.arrowLeft)),
                _key(context, '↑', () => session.sendKey(TerminalKey.arrowUp)),
                _key(
                    context, '↓', () => session.sendKey(TerminalKey.arrowDown)),
                _key(context, '→',
                    () => session.sendKey(TerminalKey.arrowRight)),
                _sep(p),
                _key(context, 'Home', () => session.sendKey(TerminalKey.home)),
                _key(context, 'End', () => session.sendKey(TerminalKey.end)),
                _key(
                    context, 'PgUp', () => session.sendKey(TerminalKey.pageUp)),
                _key(context, 'PgDn',
                    () => session.sendKey(TerminalKey.pageDown)),
                _sep(p),
                // literals rather than named keys: the pipes and slashes are
                // what a command line is made of and a name for each would be
                // unreadable
                for (final ch in ['-', '/', '|', '~'])
                  _key(context, ch, () => session.sendText(ch)),
              ]),
            ),
            // fade so the row ends instead of being cut by the edge
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 16,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient:
                          LinearGradient(colors: [p.bg.withAlpha(0), p.bg])),
                ),
              ),
            ),
          ]),
        ),
        _icon(context, Ic.copy, onCopy),
        _icon(context, Ic.keyboard, onPaste),
      ]),
    );
    return keyboardUp ? bar : SafeArea(top: false, child: bar);
  }

  Widget _sep(Pal p) => Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: p.divider);

  Widget _key(BuildContext context, String label, VoidCallback onTap,
      {bool active = false, bool sticky = false}) {
    final p = context.p;
    return Tap(
      scale: .96,
      onTap: () {
        onTap();
        if (sticky) HapticFeedback.selectionClick();
      },
      child: Container(
        constraints: const BoxConstraints(minWidth: 40),
        height: 32,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: active
              ? p.accent.withAlpha(38)
              : p.selector.withAlpha(p.dark ? 70 : 50),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: active ? p.accent.withAlpha(120) : p.divider,
              width: active ? 1 : .5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? p.accent : p.title,
            fontSize: 13,
            fontFamily: 'monospace',
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _icon(BuildContext context, Ic ic, VoidCallback onTap) => Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Tap(
            scale: .96,
            onTap: onTap,
            child: Center(child: TgIcon(ic, color: context.p.icon, size: 18))),
      );
}
