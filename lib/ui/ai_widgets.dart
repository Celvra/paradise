import 'package:flutter/widgets.dart';

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../l10n/x.dart';
import 'ai_model_picker.dart';

// gradient pairs for the ai settings rows
const aiRowColors = [Color(0xFF8B7BDB), Color(0xFF6A5ACD)];

/// Shared row shape for the AI screens: gradient icon, title, subtitle, optional
/// trailing value or switch, chevron when tappable.
class AiRow extends StatelessWidget {
  const AiRow({
    super.key,
    required this.icon,
    required this.iconColors,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.last = false,
    this.danger = false,
  });

  final Ic icon;
  final List<Color> iconColors;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool last;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final tappable = onTap != null;
    final height = subtitle == null ? 52.0 : 60.0;

    final row = SizedBox(
      height: height,
      child: Row(children: [
        const SizedBox(width: 16),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: iconColors)),
          child: Center(child: TgIcon(icon, color: const Color(0xFFFFFFFF), size: 19, stroke: 1.7)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: p.divider, width: .5))),
            child: Row(children: [
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: danger ? p.danger : p.title, fontSize: 16, height: 1.2, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                  if (subtitle != null) Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.subtitle, fontSize: 13, height: 1.3, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
                ]),
              ),
              if (value != null) Text(value!, style: TextStyle(color: p.subtitle, fontSize: 15, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
              if (trailing != null) trailing!,
              if (tappable && trailing == null && value == null) TgIcon(Ic.chevron, color: p.subtitle, size: 18),
              const SizedBox(width: 16),
            ]),
          ),
        ),
      ]),
    );

    return tappable ? Tap(highlight: true, onTap: onTap, child: row) : row;
  }
}

/// Section header plus a white card of rows, the iOS grouped list shape.
class TgGroup extends StatelessWidget {
  const TgGroup({super.key, this.header, required this.children});

  final String? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (header != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(header!, style: TextStyle(color: p.accent, fontSize: 15, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
        ),
      Container(color: p.bg, child: Column(children: children)),
    ]);
  }
}

class TgFootnote extends StatelessWidget {
  const TgFootnote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Text(text, style: TextStyle(color: context.p.subtitle, fontSize: 13, height: 1.45, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
      );
}

class AiTag extends StatelessWidget {
  const AiTag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: p.selector, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: p.subtitle, fontSize: 10, height: 1.3, decoration: TextDecoration.none, fontWeight: FontWeight.w500)),
    );
  }
}

/// Segmented control with a sliding highlight, same motion as the tab bar.
class TgSegmented extends StatelessWidget {
  const TgSegmented({super.key, required this.labels, required this.index, required this.onChange});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: p.gray, borderRadius: BorderRadius.circular(10)),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth / labels.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: TgCurves.easeOutQuint,
            left: w * index,
            width: w,
            top: 0,
            bottom: 0,
            child: Container(decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(8))),
          ),
          Row(children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Tap(
                  onTap: () => onChange(i),
                  child: SizedBox(
                    height: 34,
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        style: TextStyle(color: i == index ? p.accent : p.subtitle, fontSize: 13.5, fontWeight: i == index ? FontWeight.w700 : FontWeight.w500, decoration: TextDecoration.none),
                        child: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}

/// Full screen sub page with the standard Telegram bar and a swipe back gesture.
class TgSubPage extends StatelessWidget {
  const TgSubPage({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final mq = MediaQuery.of(context);
    // the config store must be reachable from the whole subtree
    AiScope.of(context);
    return SwipeBack(
      child: ColoredBox(
        color: p.gray,
        child: Column(children: [
          Container(
            color: p.bar,
            padding: EdgeInsets.only(top: mq.padding.top),
            height: mq.padding.top + 56,
            child: Row(children: [
              Tap(scale: .88, onTap: () => Navigator.of(context).maybePop(), child: SizedBox(width: 56, height: 56, child: Center(child: TgIcon(Ic.back, color: p.icon, size: 24)))),
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 20, fontWeight: FontWeight.w500, decoration: TextDecoration.none))),
              const SizedBox(width: 16),
            ]),
          ),
          Expanded(child: child),
        ]),
      ),
    );
  }
}

/// Single choice list presented as a sheet, used for every enum picker.
Future<T?> showAiSelect<T>(
  BuildContext context, {
  required String title,
  required T value,
  required List<({T value, String label, String? sub})> options,
}) =>
    showTgSheet<T>(
      context,
      (_) => _SelectSheet<T>(title: title, value: value, options: options),
    );

class _SelectSheet<T> extends StatelessWidget {
  const _SelectSheet({required this.title, required this.value, required this.options});

  final String title;
  final T value;
  final List<({T value, String label, String? sub})> options;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final mq = MediaQuery.of(context);
    return TgSheet(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.7),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Text(title, style: TextStyle(color: p.title, fontSize: 17, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                for (final o in options)
                  Tap(
                    scale: .99,
                    onTap: () => Navigator.of(context).pop(o.value),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                      decoration: BoxDecoration(
                        color: o.value == value ? p.accent.withAlpha(30) : p.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: o.value == value ? p.accent : const Color(0x00000000), width: .6),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(o.label, style: TextStyle(color: p.title, fontSize: 16, decoration: TextDecoration.none, fontWeight: FontWeight.w500)),
                            if (o.sub != null) Text(o.sub!, style: TextStyle(color: p.subtitle, fontSize: 13, height: 1.3, decoration: TextDecoration.none)),
                          ]),
                        ),
                        if (o.value == value) TgIcon(Ic.check, color: p.accent, size: 20, stroke: 2.2),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// Multiline editor with confirm and cancel, used for the global override.
class TgTextArea extends StatefulWidget {
  const TgTextArea({
    super.key,
    required this.initial,
    required this.onSubmit,
    required this.onCancel,
    this.hint = '',
    this.minHeight = 120,
  });

  final String initial;
  final String hint;
  final int minHeight;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;

  @override
  State<TgTextArea> createState() => _TgTextAreaState();
}

class _TgTextAreaState extends State<TgTextArea> {
  late final TextEditingController _ctl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        constraints: BoxConstraints(minHeight: widget.minHeight.toDouble()),
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(10)),
        child: TgEdit(
          controller: _ctl,
          hint: widget.hint,
          maxLines: 12,
          style: TextStyle(color: p.title, fontSize: 15, height: 1.35, decoration: TextDecoration.none),
        ),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Tap(
          scale: .96,
          onTap: widget.onCancel,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), child: Text(l.actionCancel, style: TextStyle(color: p.accent, fontSize: 15, fontWeight: FontWeight.w500, decoration: TextDecoration.none))),
        ),
        Tap(
          scale: .96,
          onTap: () => widget.onSubmit(_ctl.text),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), child: Text(l.actionSave, style: TextStyle(color: p.accent, fontSize: 15, fontWeight: FontWeight.w600, decoration: TextDecoration.none))),
        ),
      ]),
    ]);
  }
}