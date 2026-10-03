import 'package:flutter/widgets.dart';

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';

// Ports of the stock Telegram Android list cells (org.telegram.ui.Cells) so the
// settings style screens share one set of metrics:
//   HeaderCell          40 tall, 15sp medium accent, 21 inset, white background
//   TextCell            50 tall, 24 icon at 21, text at 72, 16sp
//   TextCheckCell       50 tall (64 with a value line), switch 21 from the edge
//   TextInfoPrivacyCell 14sp grey note on the window background
//   ShadowSectionCell   12 tall gap between white blocks
// Dividers start at the text column, the last row of a block draws none.

const _none = TextDecoration.none;

/// A white block: optional header inside, rows, then an info note or a plain gap.
class TgSection extends StatelessWidget {
  const TgSection({super.key, this.header, required this.children, this.footer, this.gap = true});

  final String? header;
  final List<Widget> children;
  final String? footer;

  /// draw the 12 tall ShadowSectionCell after a block that has no footer
  final bool gap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Container(
        color: p.bg,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          if (header != null) TgHeaderCell(header!),
          ...children,
        ]),
      ),
      if (footer != null) TgInfoCell(footer!) else if (gap) const SizedBox(height: 12),
    ]);
  }
}

class TgHeaderCell extends StatelessWidget {
  const TgHeaderCell(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(21, 15, 21, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.accent, fontSize: 15, height: 1.2, fontWeight: FontWeight.w600, decoration: _none))),
          if (trailing != null) trailing!,
        ]),
      ),
    );
  }
}

/// TextInfoPrivacyCell, the grey caption under a block.
class TgInfoCell extends StatelessWidget {
  const TgInfoCell(this.text, {super.key, this.center = false});
  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(21, 10, 21, 17),
        child: Text(text, textAlign: center ? TextAlign.center : TextAlign.start, style: TextStyle(color: context.p.subtitle, fontSize: 14, height: 1.35, fontWeight: FontWeight.w400, decoration: _none)),
      );
}

/// TextCell / TextSettingsCell. An accent [color] paints both the icon and the
/// label, which is how Telegram draws "Add ..." and "Set Profile Photo" rows.
class TgTextCell extends StatelessWidget {
  const TgTextCell({
    super.key,
    required this.title,
    this.icon,
    this.leading,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.color,
    this.divider = true,
    this.subtitleColor,
  });

  final String title;
  final Ic? icon;
  final Widget? leading;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final bool divider;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final hasLead = icon != null || leading != null;
    final textLeft = leading != null ? 72.0 : (icon != null ? 72.0 : 21.0);
    final tall = subtitle != null;
    final body = SizedBox(
      height: leading != null && tall ? 64 : (tall ? 60 : 50),
      child: Stack(children: [
        if (hasLead)
          Positioned(
            left: leading != null ? 13 : 21,
            top: 0,
            bottom: 0,
            child: Center(child: leading ?? TgIcon(icon!, color: color ?? p.icon, size: 24, stroke: 1.8)),
          ),
        Positioned.fill(
          left: textLeft,
          child: Row(children: [
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color ?? p.title, fontSize: 16, height: 1.25, fontWeight: FontWeight.w400, decoration: _none)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: subtitleColor ?? p.subtitle, fontSize: 13.5, height: 1.25, fontWeight: FontWeight.w400, decoration: _none)),
                  ),
              ]),
            ),
            if (value != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(value!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.accent, fontSize: 16, fontWeight: FontWeight.w400, decoration: _none)),
                ),
              ),
            if (trailing != null) Padding(padding: const EdgeInsets.only(left: 12), child: trailing!),
            const SizedBox(width: 21),
          ]),
        ),
        if (divider) Positioned(left: textLeft, right: 0, bottom: 0, child: Container(height: .5, color: p.divider)),
      ]),
    );
    if (onTap == null && onLongPress == null) return body;
    return Tap(highlight: true, onTap: onTap, onLongPress: onLongPress, child: body);
  }
}

/// TextCheckCell, the whole row toggles.
class TgCheckCell extends StatelessWidget {
  const TgCheckCell({super.key, required this.title, this.subtitle, this.icon, required this.value, required this.onChanged, this.divider = true});

  final String title;
  final String? subtitle;
  final Ic? icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool divider;

  @override
  Widget build(BuildContext context) => TgTextCell(
        title: title,
        subtitle: subtitle,
        icon: icon,
        divider: divider,
        onTap: () => onChanged(!value),
        trailing: TgSwitch(value: value, onChanged: onChanged),
      );
}

/// EditTextCell: bare 17sp input on white, optional countdown on the right.
/// [label] puts a grey name above the field, for a block that carries several
/// inputs and would otherwise be a column of anonymous hints.
class TgEditCell extends StatelessWidget {
  const TgEditCell({super.key, required this.controller, required this.hint, this.lines = 1, this.max = 0, this.divider = false, this.focusNode, this.label});

  final TextEditingController controller;
  final String hint;
  final int lines;
  final int max;
  final bool divider;
  final FocusNode? focusNode;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Stack(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(21, label == null ? 15 : 10, max > 0 ? 63 : 21, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != null) ...[
              Text(label!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.subtitle, fontSize: 13, height: 1.2, decoration: _none)),
              const SizedBox(height: 4),
            ],
            TgEdit(
              controller: controller,
              hint: hint,
              maxLines: lines,
              focusNode: focusNode,
              style: TextStyle(color: p.title, fontSize: 17, height: 1.3, decoration: _none),
              hintStyle: TextStyle(color: p.hint, fontSize: 17, height: 1.3, decoration: _none),
              cursor: p.accent,
            ),
          ],
        ),
      ),
      if (max > 0)
        Positioned(
          right: 21,
          bottom: 0,
          height: label == null ? 52 : 47,
          child: Center(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, v, __) {
                final left = max - v.text.length;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Text('$left', key: ValueKey(left), style: TextStyle(color: left < 0 ? p.danger : p.hint, fontSize: 15, fontWeight: FontWeight.w400, decoration: _none)),
                );
              },
            ),
          ),
        ),
      if (divider) Positioned(left: 21, right: 0, bottom: 0, child: Container(height: .5, color: p.divider)),
    ]);
  }
}

/// A centred text action, how Telegram stacks "Save" and "Delete" under a
/// profile or a bot: the label is the whole target, no button chrome at all.
/// A null [onTap] greys the label out rather than hiding the row, so the block
/// does not change shape between a dirty card and a clean one.
class TgActionRow extends StatelessWidget {
  const TgActionRow({super.key, required this.label, this.onTap, this.danger = false, this.divider = false});

  final String label;
  final VoidCallback? onTap;
  final bool danger;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Tap(
      highlight: true,
      onTap: onTap,
      child: Stack(children: [
        SizedBox(
          height: 50,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(color: onTap == null ? p.hint : (danger ? p.danger : p.accent), fontSize: 16, fontWeight: FontWeight.w500, decoration: _none),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
        if (divider) Positioned(left: 21, right: 0, bottom: 0, child: Container(height: .5, color: p.divider)),
      ]),
    );
  }
}

/// Small rounded label used inside subtitles, e.g. "reasoning".
class TgChip extends StatelessWidget {
  const TgChip(this.label, {super.key, this.accent = false});
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(color: accent ? p.accent.withAlpha(32) : p.selector, borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: TextStyle(color: accent ? p.accent : p.subtitle, fontSize: 11, height: 1.3, fontWeight: FontWeight.w600, decoration: _none)),
    );
  }
}

/// ActionBar with the elevation shadow Telegram draws once the list scrolls,
/// an optional done check, and an optional tab strip glued underneath.
class TgActionBar extends StatelessWidget {
  const TgActionBar({super.key, required this.title, this.actions = const [], this.raised = false, this.bottom});

  final String title;
  final List<Widget> actions;
  final bool raised;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final top = MediaQuery.of(context).padding.top;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: p.bar,
        boxShadow: [if (raised) BoxShadow(color: p.dark ? const Color(0x40000000) : const Color(0x1A000000), blurRadius: 3, offset: const Offset(0, 1))],
      ),
      padding: EdgeInsets.only(top: top),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 56,
          child: Row(children: [
            Tap(scale: .88, onTap: () => Navigator.of(context).maybePop(), child: SizedBox(width: 56, height: 56, child: Center(child: TgIcon(Ic.back, color: p.icon, size: 24)))),
            const SizedBox(width: 8),
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 20, fontWeight: FontWeight.w600, decoration: _none))),
            ...actions,
            if (actions.isEmpty) const SizedBox(width: 16),
          ]),
        ),
        if (bottom != null) bottom!,
      ]),
    );
  }
}

/// The animated done check: scales in only once something changed.
class TgDoneAction extends StatelessWidget {
  const TgDoneAction({super.key, required this.visible, required this.onTap});
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: visible ? 1 : 0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 220),
          curve: TgCurves.easeOutQuint,
          scale: visible ? 1 : .2,
          child: Tap(scale: .9, onTap: visible ? onTap : null, child: SizedBox(width: 56, height: 56, child: Center(child: TgIcon(Ic.check, color: p.icon, size: 24)))),
        ),
      ),
    );
  }
}

/// ScrollSlidingTextTabStrip: equal width labels with a rounded 3dp indicator
/// that slides under the selected one, as on the Stats and Filters screens.
class TgTabStrip extends StatelessWidget {
  const TgTabStrip({super.key, required this.labels, required this.index, required this.onChange});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return SizedBox(
      height: 44,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth / labels.length;
        return Stack(children: [
          Row(children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Tap(
                  onTap: () => onChange(i),
                  child: SizedBox.expand(
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(color: i == index ? p.accent : p.subtitle, fontSize: 15, fontWeight: FontWeight.w600, decoration: _none),
                        child: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: TgCurves.easeOutQuint,
            left: w * index + w * .2,
            width: w * .6,
            bottom: 0,
            height: 3,
            child: Container(decoration: BoxDecoration(color: p.accent, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))),
          ),
        ]);
      }),
    );
  }
}

/// Scaffold for a settings screen: grey window, action bar that raises its
/// shadow on scroll, and swipe back.
class TgSettingsPage extends StatefulWidget {
  const TgSettingsPage({super.key, required this.title, required this.builder, this.actions = const [], this.bottom});

  final String title;
  final List<Widget> actions;
  final Widget? bottom;

  /// receives a scroll listener, attach it to the page list
  final Widget Function(BuildContext context, ScrollController? controller) builder;

  @override
  State<TgSettingsPage> createState() => _TgSettingsPageState();
}

class _TgSettingsPageState extends State<TgSettingsPage> {
  bool _raised = false;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final r = n.metrics.pixels > 1;
    if (r != _raised) setState(() => _raised = r);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return SwipeBack(
      child: ColoredBox(
        color: p.gray,
        child: Column(children: [
          TgActionBar(title: widget.title, actions: widget.actions, raised: _raised || widget.bottom != null, bottom: widget.bottom),
          Expanded(child: NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.builder(context, null))),
        ]),
      ),
    );
  }
}

/// Global rect of a widget, used to anchor popup menus.
Rect rectOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return Rect.zero;
  return box.localToGlobal(Offset.zero) & box.size;
}
