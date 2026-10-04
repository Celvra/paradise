import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Tooltip;

import '../../core/anim.dart';
import '../../core/overlays.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../l10n/x.dart';

/// The prompts the file browser needs: a name, a confirmation, a destination.
///
/// They live in one file because they are three variations on the same dialog
/// and three copies of the dialog is how they drift apart.

/// One line. [initial] is offered as the starting text, which is what makes
/// "new file" suggest `untitled.md` rather than an empty box.
Future<String?> askName(BuildContext context,
    {required String title,
    String hint = '',
    String initial = '',
    String? ok,
    bool validate = true}) async {
  final l = context.l;
  final ctl = TextEditingController(text: initial);
  String? error;
  final r = await showTgDialog<bool>(
    context,
    title: title,
    content: StatefulBuilder(
      builder: (c, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TgNameField(
                controller: ctl,
                hint: hint,
                onChanged:
                    validate ? (_) => setState(() => error = null) : null),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(error!,
                      style: TextStyle(
                          color: c.p.danger,
                          fontSize: 13,
                          height: 1.3,
                          decoration: TextDecoration.none))),
          ]),
    ),
    actions: [
      DialogAction(l.actionCancel, false),
      DialogAction(ok ?? l.actionOk, true, danger: validate),
    ],
  );
  // read before dispose: the dialog closed before this returns
  final text = ctl.text.trim();
  ctl.dispose();
  if (r != true) return null;
  if (!validate) return text.isEmpty ? null : text;
  return _checkName(text, context) == null ? text : null;
}

/// The dialog's own field, so the error line can sit under it without a second
/// column. [TgField] is the plain one, which cannot report anything back.
class TgNameField extends StatelessWidget {
  const TgNameField(
      {super.key, required this.controller, this.hint = '', this.onChanged});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TgEdit(
        controller: controller,
        hint: hint,
        maxLines: 1,
        onChanged: onChanged,
        onSubmitted: (_) => onChanged?.call(controller.text),
        style: TextStyle(
            color: context.p.title,
            fontSize: 16,
            decoration: TextDecoration.none),
      );
}

String? _checkName(String name, BuildContext context) {
  if (name.isEmpty) return context.l.wsNameEmpty;
  // a separator would put the new entry somewhere other than where it was
  // typed, and a leading dot hides the thing the user just made
  if (name.contains('/') || name.contains('\\')) return context.l.wsNameSlash;
  if (name == '.' || name == '..') return context.l.wsNameDot;
  if (name.startsWith('.')) return context.l.wsNameLeadingDot;
  return null;
}

/// A destructive confirm, kept to two buttons so there is no third default to
/// press by accident.
Future<bool> askConfirm(BuildContext context,
    {required String title,
    required String message,
    required String confirmLabel,
    bool destructive = true}) async {
  final l = context.l;
  final r = await showTgDialog<bool>(
    context,
    title: title,
    message: message,
    actions: [
      DialogAction(l.actionCancel, false),
      DialogAction(confirmLabel, true, danger: destructive)
    ],
  );
  return r == true;
}

// typed delete for the actions that cannot be undone
Future<bool> askTypeDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final l = context.l;
  final ctl = TextEditingController();
  final armed = ValueNotifier(false);
  final r = await showTgDialog<bool>(
    context,
    title: title,
    message: message,
    listenable: armed,
    content: TgEdit(
      controller: ctl,
      autofocus: true,
      // what the field wants, or the arm gesture is a guess: an empty grey box
      // tells nobody it is waiting for the word delete
      hint: l.actionTypeDeleteHint,
      style: TextStyle(
          color: context.p.title,
          fontSize: 16,
          decoration: TextDecoration.none),
      onChanged: (v) => armed.value = v.trim().toLowerCase() == 'delete',
    ),
    actions: [
      DialogAction(l.actionCancel, false),
      // read at pop time so the last keystroke still counts
      DialogAction(l.actionDelete, true, danger: true, enabled: () => armed.value),
    ],
  );
  ctl.dispose();
  armed.dispose();
  return r == true;
}

/// Copies [text] and says so, because a silent clipboard write looks like the
/// tap did nothing.
void copyWithToast(BuildContext context, String text, String message) {
  Clipboard.setData(ClipboardData(text: text));
  showBulletin(context, message);
}

/// A dismissible sheet with a title bar and a body that scrolls, which is what
/// every sheet in the browser needs and what [showTgSheet] does not have.
class WsSheet extends StatelessWidget {
  const WsSheet(
      {super.key,
      required this.title,
      required this.child,
      this.actions = const [],
      this.heightFactor = 0.7});

  final String title;
  final Widget child;
  final List<Widget> actions;
  final double heightFactor;

  /// Opens one. Returns whatever the body pops.
  static Future<T?> open<T>(
          BuildContext context, Widget Function(BuildContext) builder,
          {String? title, double heightFactor = 0.7}) =>
      showTgSheet<T>(
        context,
        (c) => WsSheet(
          title: title ?? '',
          heightFactor: heightFactor,
          actions: [
            TgIconButton(
                icon: Ic.close, onTap: () => Navigator.of(c).maybePop())
          ],
          child: builder(c),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final mq = MediaQuery.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: mq.size.height * heightFactor,
        decoration: BoxDecoration(
            color: p.sheet,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(14))),
        child: Column(children: [
          SizedBox(
            height: 52,
            child: Row(children: [
              const SizedBox(width: 16),
              Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: p.title,
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none))),
              ...actions,
              const SizedBox(width: 8),
            ]),
          ),
          Container(height: .5, color: p.divider),
          Expanded(child: child),
        ]),
      ),
    );
  }
}

/// An icon button sized for a finger. Material rather than [TgIcon] because the
/// file browser uses Material icons throughout and mixing the two draws at two
/// different weights.
class TgIconButton extends StatelessWidget {
  const TgIconButton(
      {super.key,
      required this.icon,
      this.onTap,
      this.color,
      this.size = 22,
      this.tooltip,
      this.active = false});
  final Ic icon;
  final VoidCallback? onTap;
  final Color? color;
  final double size;
  final String? tooltip;

  /// tints the glyph with the accent, which is how a toolbar says it is on
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final tint = color ?? (active ? p.accent : p.icon);
    final button = SizedBox(
        width: 44,
        height: 44,
        child:
            Center(child: TgIcon(icon, color: tint, size: size, stroke: 1.8)));
    final tappable =
        onTap == null ? button : Tap(scale: .88, onTap: onTap, child: button);
    return tooltip == null
        ? tappable
        : Tooltip(message: tooltip!, child: tappable);
  }
}

/// Empty state with an icon, a line and an optional second line. Three callers
/// already needed exactly this.
class WsEmpty extends StatelessWidget {
  const WsEmpty(
      {super.key,
      this.icon = Ic.folderOpen,
      required this.title,
      this.hint,
      this.action});
  final Ic icon;
  final String title;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final base = TextStyle(
        color: p.subtitle,
        fontSize: 15,
        height: 1.4,
        decoration: TextDecoration.none);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TgIcon(icon, color: p.subtitle.withAlpha(120), size: 44, stroke: 1.4),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: base.copyWith(color: p.title, fontSize: 16)),
          if (hint != null)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(hint!, textAlign: TextAlign.center, style: base)),
          if (action != null)
            Padding(padding: const EdgeInsets.only(top: 18), child: action!),
        ]),
      ),
    );
  }
}
