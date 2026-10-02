import 'package:flutter/widgets.dart';

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/models.dart';
import '../l10n/x.dart';
import 'ai_editor.dart';

// glass input like ChatActivityEnterView emoji button left attach button right
// the send circle only exists while there is something to do
class InputBar extends StatelessWidget {
  const InputBar({
    super.key,
    required this.ctl,
    required this.focus,
    required this.busy,
    required this.reply,
    required this.replyName,
    required this.onCancelReply,
    required this.onSend,
    required this.onStop,
    required this.onAttach,
    required this.onEmoji,
    required this.emojiOpen,
    this.canStop = true,
  });
  final TextEditingController ctl;
  final FocusNode focus;
  final bool busy;

  /// False hides the stop state: the circle stays a send button even while the
  /// assistant is busy, so sending the next line is the only way to interrupt.
  /// An assistant that is just chatting back has no job to cancel, and cutting
  /// it off mid sentence is not something the reader gets to do anyway.
  final bool canStop;
  final Msg? reply;
  final String replyName;
  final VoidCallback onCancelReply;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onAttach;
  final VoidCallback onEmoji;
  final bool emojiOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctl,
      builder: (context, v, _) {
        final has = v.text.trim().isNotEmpty;
        // without the stop state the circle only exists when there is text to
        // send, otherwise it is a dead button that does nothing on tap
        final show = (busy && canStop) || has;
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: TgCurves.easeOutQuint,
              alignment: Alignment.bottomCenter,
              child: reply == null ? const SizedBox(width: double.infinity) : Padding(padding: const EdgeInsets.only(bottom: 6), child: _replyPanel(p)),
            ),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: _pill(context, p, v.text)),
              _sendButton(p, show),
            ]),
          ]),
        );
      },
    );
  }

  Widget _replyPanel(Pal p) {
    final r = reply!;
    return Glass(
      radius: 18,
      child: SizedBox(
        height: 48,
        child: Row(children: [
          const SizedBox(width: 14),
          TgIcon(Ic.reply, color: p.accent, size: 22),
          const SizedBox(width: 10),
          Container(width: 2, height: 32, decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(1))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(replyName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.accent, fontSize: 14, fontWeight: FontWeight.w500, height: 1.2, decoration: TextDecoration.none)),
              Text(r.preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.title, fontSize: 14, height: 1.2, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
            ]),
          ),
          Tap(onTap: onCancelReply, scale: .85, child: SizedBox(width: 44, height: 48, child: Center(child: TgIcon(Ic.close, color: p.glassIcon, size: 20)))),
        ]),
      ),
    );
  }

  Widget _pill(BuildContext context, Pal p, String text) {
    final style = TextStyle(color: p.title, fontSize: 17, height: 1.25, decoration: TextDecoration.none, fontWeight: FontWeight.w400);
    return Glass(
      radius: 22,
      child: LayoutBuilder(builder: (context, box) {
        final tp = TextPainter(text: TextSpan(text: text.isEmpty ? ' ' : text, style: style), textDirection: TextDirection.ltr)..layout(maxWidth: (box.maxWidth - 88).clamp(10, 4000));
        final showAi = tp.computeLineMetrics().length > 2 && text.trim().isNotEmpty;
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Stack(children: [
            AnimatedPadding(
              duration: const Duration(milliseconds: 220),
              curve: TgCurves.easeOutQuint,
              padding: EdgeInsets.fromLTRB(44, 10, showAi ? 84 : 44, 10),
              child: TgEdit(controller: ctl, focusNode: focus, hint: L10n.current.inputMessageHint, maxLines: 8, style: style),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: Tap(
                scale: .86,
                onTap: onEmoji,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (c, a) => RotationTransition(turns: Tween(begin: .85, end: 1.0).animate(a), child: ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c))),
                      child: TgIcon(emojiOpen ? Ic.keyboard : Ic.smile, key: ValueKey(emojiOpen), color: p.glassIcon, size: 26, stroke: 1.8),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Tap(scale: .86, onTap: onAttach, child: SizedBox(width: 44, height: 44, child: Center(child: TgIcon(Ic.attach, color: p.glassIcon, size: 25, stroke: 1.8)))),
            ),
            Positioned(
              right: 40,
              bottom: 0,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: showAi ? 1.0 : 0.0),
                duration: const Duration(milliseconds: 420),
                curve: TgCurves.easeOutQuint,
                builder: (_, t, child) => t < .01
                    ? const SizedBox(width: 44, height: 44)
                    : Opacity(opacity: t.clamp(0.0, 1.0), child: Transform.scale(scale: .6 + .4 * t, child: child)),
                child: Tap(
                  scale: .88,
                  onTap: () async {
                    final res = await showTgSheet<String>(context, (_) => AiEditorSheet(text: ctl.text.trim()));
                    if (res != null && res.isNotEmpty) {
                      ctl.value = TextEditingValue(text: res, selection: TextSelection.collapsed(offset: res.length));
                    }
                  },
                  child: SizedBox(width: 44, height: 44, child: Center(child: TgIcon(Ic.ai, color: p.glassIcon, size: 24))),
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }

  // scale 0.1 to 1 and fade over 220ms quint like the mic to send switch
  Widget _sendButton(Pal p, bool show) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: show ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 220),
      curve: TgCurves.easeOutQuint,
      builder: (_, t, __) {
        final w = 52 * t;
        if (t < .005) return const SizedBox(width: 0, height: 44);
        return SizedBox(
          width: w,
          height: 44,
          child: OverflowBox(
            alignment: Alignment.centerRight,
            minWidth: 0,
            maxWidth: 52,
            child: Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: .1 + .9 * t,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Tap(
                    scale: .9,
                    onTap: busy && canStop ? onStop : onSend,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: p.send, shape: BoxShape.circle),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
                        child: TgIcon(busy && canStop ? Ic.stop : Ic.send, key: ValueKey(busy && canStop), color: const Color(0xFFFFFFFF), size: 26),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
