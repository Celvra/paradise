import 'dart:convert';

import 'package:flutter/material.dart' show SelectionArea;
import 'package:flutter/widgets.dart';

import '../../core/anim.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../data/workspace/workspace_tools.dart';
import '../../l10n/x.dart';
import 'workspace_prompts.dart';

/// The confirmation sheet's answer.
enum WsVerdict { allowOnce, allowAll, refuse }

/// Asks before a write lands, with the diff on screen.
///
/// A sheet that only says "the assistant wants to change a file" is a speed
/// bump the user learns to dismiss; one that shows the bytes is a decision they
/// can make. That is the whole reason this exists rather than relying on the
/// tool permission page, which is a standing yes or no set once.
///
/// Returns true when the write may proceed. [allowAll] is called instead when
/// the user asked not to be asked again for this conversation.
/// A null [context] means there is no navigator to raise a sheet on, which is
/// the headless case, and the caller treats that as allowed rather than as a
/// refusal: a proactive message that could not write would do nothing at all.
Future<bool> askWorkspaceWrite(BuildContext? context, WsPendingWrite write, {required void Function() allowAll}) async {
  if (context == null) return true;
  final r = await WsSheet.open<WsVerdict>(
    context,
    (_) => _WriteReview(write: write),
    title: context.l.wsWriteTitle,
    heightFactor: 0.72,
  );
  final v = r ?? WsVerdict.refuse;
  if (v == WsVerdict.allowAll) allowAll();
  return v != WsVerdict.refuse;
}

class _WriteReview extends StatelessWidget {
  const _WriteReview({required this.write});
  final WsPendingWrite write;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    return Column(children: [
      _header(p, l),
      Container(height: .5, color: p.divider),
      // no diff means the previous content was binary or unreadable, and
      // showing something that is not what will land would be worse than saying
      // so
      Expanded(child: write.diff.isEmpty ? WsEmpty(icon: Ic.info, title: l.wsWriteNoPreview) : _DiffView(diff: write.diff)),
      _footer(context, p, l),
    ]);
  }

  Widget _header(Pal p, AppLocalizations l) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(children: [
          TgIcon(write.created ? Ic.plus : Ic.pencil, color: p.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                write.created ? l.wsWriteNew : (write.strategy.isEmpty ? l.wsWriteReplace : l.wsWriteEdit(write.added + write.removed)),
                style: TextStyle(color: p.title, fontSize: 15.5, fontWeight: FontWeight.w500, decoration: TextDecoration.none),
              ),
              const SizedBox(height: 2),
              Text(write.modelPath, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.subtitle, fontSize: 12.5, fontFamily: 'monospace', height: 1.35, decoration: TextDecoration.none)),
            ]),
          ),
          const SizedBox(width: 10),
          Text(l.wsWriteCounts(write.added, write.removed), style: TextStyle(color: p.subtitle, fontSize: 13, decoration: TextDecoration.none)),
        ]),
      );

  Widget _footer(BuildContext context, Pal p, AppLocalizations l) {
    // a strategy other than exact means the model did not reproduce the text it
    // said it was replacing, and that is worth saying rather than hiding
    final loose = write.strategy.isNotEmpty && write.strategy != 'exact';
    return Container(
      color: p.bg,
      padding: EdgeInsets.fromLTRB(16, loose ? 8 : 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (loose)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('${l.wsWriteLoose} · ${write.strategy}', style: TextStyle(color: p.subtitle, fontSize: 12.5, decoration: TextDecoration.none)),
          ),
        Row(children: [
          Expanded(child: _button(context, l.wsWriteRefuse, p.danger, () => Navigator.of(context).pop(WsVerdict.refuse))),
          const SizedBox(width: 8),
          Expanded(child: _button(context, l.wsWriteAllowAll, p.accent, () => Navigator.of(context).pop(WsVerdict.allowAll))),
          const SizedBox(width: 8),
          Expanded(child: _button(context, l.wsWriteAllow, p.accent, () => Navigator.of(context).pop(WsVerdict.allowOnce))),
        ]),
      ]),
    );
  }

  Widget _button(BuildContext c, String label, Color color, VoidCallback onTap) => Tap(
        scale: .97,
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withAlpha(90))),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 14.5, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
        ),
      );
}

/// The diff, line by line.
///
/// The header lines are dropped: the path is already above and the counts are
/// beside it, so repeating them costs a third of the height on a phone.
class _DiffView extends StatelessWidget {
  const _DiffView({required this.diff});
  final String diff;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final kept = <String>[
      for (final l in const LineSplitter().convert(diff))
        if (!l.startsWith('--- ') && !l.startsWith('+++ ') && !l.startsWith('@@')) l,
    ];
    if (kept.isEmpty) return WsEmpty(icon: Ic.check, title: context.l.wsWriteNoChange);
    final base = TextStyle(color: p.msg, fontSize: 12.5, fontFamily: 'monospace', height: 1.45, decoration: TextDecoration.none);
    return SelectionArea(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: kept.length,
        itemBuilder: (c, i) {
          final line = kept[i];
          final added = line.startsWith('+');
          final removed = line.startsWith('-');
          return Container(
            color: added ? const Color(0x2E3FB950) : (removed ? const Color(0x2EE5534B) : const Color(0x00000000)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(line, style: base.copyWith(color: added || removed ? p.title : p.subtitle)),
          );
        },
      ),
    );
  }
}