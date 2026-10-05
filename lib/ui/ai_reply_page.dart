import 'package:flutter/widgets.dart';

import '../core/overlays.dart';
import '../core/ui_kit.dart';
import '../data/ai/provider_model.dart' show ReplyMode;
import '../data/ai_config.dart';
import '../data/store.dart';
import '../l10n/x.dart';
import 'ai_model_picker.dart' show AiScope;
import 'ai_widgets.dart';
import 'human_data_pages.dart' show ToolsPage;
import 'human_pages.dart';
import 'tg_cells.dart';

// Settings > AI replies. The switches that decide what the model is allowed
// to do, how much of it the user gets to see, and how the bubbles read. All
// are global defaults; a persona card can take either one over for itself,
// which is why the footer says so out loud.
//
// The pacing knobs live here too, not in the AI advanced tab: a user who feels
// the assistant replies too fast looks in the reply settings, not behind two
// tabs of provider plumbing.

void openAiReplySettings(BuildContext c) => Navigator.of(c).push(TgRoute(builder: (_) => const AiReplyPage()));

class AiReplyPage extends StatelessWidget {
  const AiReplyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.store;
    final ai = AiScope.of(context);
    final l = context.l;
    final mcpTools = st.human?.mcp.tools.length ?? 0;
    return TgSettingsPage(
      title: l.aiReplyTitle,
      builder: (c, _) => ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const SizedBox(height: 12),
          TgSection(
            header: l.aiReplyStyleHeader,
            footer: l.aiRepliesFooter,
            children: [
              TgTextCell(
                icon: Ic.chats,
                title: l.aiReplyStyle,
                value: ai.settings.replyMode == ReplyMode.full ? l.aiReplyStyleFull : l.aiReplyStyleCharacter,
                onTap: () => _pickReplyMode(context, ai),
              ),
              // both only act in character mode, the plain mode streams one bubble
              TgTextCell(
                icon: Ic.send,
                title: l.aiFirstBubbleDelay,
                value: ai.settings.firstBubbleDelayMs == 0 ? l.aiPacingOff : L10n.number('#,##0').format(ai.settings.firstBubbleDelayMs) + ' ms',
                onTap: () => _pickFirstBubbleDelay(context, ai),
              ),
              TgTextCell(
                icon: Ic.bell,
                title: l.aiBubbleGapScale,
                value: '×' + ai.settings.bubbleGapScale.toStringAsFixed(2),
                onTap: () => _pickBubbleGapScale(context, ai),
              ),
              TgTextCell(
                icon: Ic.regen,
                title: l.aiPacingJitter,
                value: _jitterLabel(ai.settings.pacingJitter, l),
                divider: false,
                onTap: () => _pickPacingJitter(context, ai),
              ),
            ],
          ),
          TgSection(
            header: l.aiReplyVisibleHeader,
            footer: l.aiReplyVisibleFooter,
            children: [
              TgCheckCell(
                icon: Ic.ai,
                title: l.aiReplyShowThinking,
                subtitle: l.aiReplyShowThinkingSub,
                value: st.showThinking,
                onChanged: st.setShowThinking,
              ),
              TgCheckCell(
                icon: Ic.gear,
                title: l.aiReplyAgentMode,
                subtitle: l.aiReplyAgentModeSub,
                value: st.agentMode,
                onChanged: st.setAgentMode,
              ),
              // 0 means no cap, the loop runs while the model keeps asking
              TgTextCell(
                icon: Ic.regen,
                title: l.aiReplyAgentPass,
                subtitle: l.aiReplyAgentPassSub,
                value: st.agentMaxPass <= 0 ? l.aiReplyAgentPassUnlimited : l.aiReplyAgentPassRounds(st.agentMaxPass),
                onTap: () => _pickAgentMaxPass(context, st),
              ),
              // stored as "strip markdown in character mode", shown the way
              // the user thinks about it: Markdown on means the bubbles keep
              // their bold, fences and headings
              TgCheckCell(
                icon: Ic.palette,
                title: l.aiReplyMarkdown,
                subtitle: l.aiReplyMarkdownSub,
                value: !ai.settings.stripMarkdownInCharacterMode,
                divider: false,
                onChanged: (v) => ai.update((x) => x.copyWith(stripMarkdownInCharacterMode: !v)),
              ),
            ],
          ),
          TgSection(
            header: l.aiReplyToolsHeader,
            footer: l.aiReplyToolsFooter,
            children: [
              TgTextCell(
                icon: Ic.list,
                title: l.aiReplyToolsRow,
                subtitle: l.aiReplyToolsCount(mcpTools),
                divider: false,
                onTap: () => hOpen(c, const ToolsPage()),
              ),
            ],
          ),
          TgInfoCell(l.aiReplyPersonaFooter),
        ],
      ),
    );
  }

  Future<void> _pickAgentMaxPass(BuildContext context, Store st) async {
    final l = context.l;
    const steps = [2, 4, 8, 16, 32, 64];
    final v = await showAiSelect<int>(
      context,
      title: l.aiReplyAgentPass,
      value: st.agentMaxPass,
      options: [
        for (final n in steps) (value: n, label: l.aiReplyAgentPassRounds(n), sub: null),
        (value: 0, label: l.aiReplyAgentPassUnlimited, sub: l.aiReplyAgentPassUnlimitedSub),
      ],
    );
    if (v == null || v == st.agentMaxPass) return;
    st.setAgentMaxPass(v);
  }

  Future<void> _pickReplyMode(BuildContext context, AiConfig ai) async {
    final l = context.l;
    final v = await showAiSelect<ReplyMode>(
      context,
      title: l.aiReplyStyle,
      value: ai.settings.replyMode,
      options: [
        (value: ReplyMode.full, label: l.aiReplyStyleFull, sub: l.aiReplyStyleFullSub),
        (value: ReplyMode.character, label: l.aiReplyStyleCharacter, sub: l.aiReplyStyleCharacterSub),
      ],
    );
    if (v == null) return;
    ai.update((s) => s.copyWith(replyMode: v));
  }

  Future<void> _pickFirstBubbleDelay(BuildContext context, AiConfig ai) async {
    final l = context.l;
    const options = [0, 500, 1000, 2000, 4000, 8000];
    final v = await showAiSelect<int>(
      context,
      title: l.aiFirstBubbleDelay,
      value: ai.settings.firstBubbleDelayMs,
      options: [
        for (final o in options) (value: o, label: o == 0 ? l.aiPacingOff : o < 1000 ? '$o ms' : '${o ~/ 1000} s', sub: o == 0 ? l.aiPacingDelayHint : null),
      ],
    );
    if (v == null) return;
    ai.update((s) => s.copyWith(firstBubbleDelayMs: v));
  }

  Future<void> _pickBubbleGapScale(BuildContext context, AiConfig ai) async {
    const options = [0.5, 0.75, 1.0, 1.5, 2.0, 3.0];
    final v = await showAiSelect<double>(
      context,
      title: context.l.aiBubbleGapScale,
      value: ai.settings.bubbleGapScale,
      options: [for (final o in options) (value: o, label: '×${o.toStringAsFixed(2)}', sub: null)],
    );
    if (v == null) return;
    ai.update((s) => s.copyWith(bubbleGapScale: v));
  }

  String _jitterLabel(double v, AppLocalizations l) {
    if (v <= 0) return l.aiPacingOff;
    if (v <= 0.15) return l.aiPacingJitterLow;
    if (v <= 0.35) return l.aiPacingJitterNormal;
    return l.aiPacingJitterWild;
  }

  Future<void> _pickPacingJitter(BuildContext context, AiConfig ai) async {
    final l = context.l;
    const options = [0.0, 0.15, 0.35, 0.6];
    final v = await showAiSelect<double>(
      context,
      title: l.aiPacingJitter,
      value: ai.settings.pacingJitter,
      options: [
        for (final o in options)
          (
            value: o,
            label: _jitterLabel(o, l),
            sub: o <= 0 ? l.aiPacingJitterHintOff : (o <= 0.15 ? l.aiPacingJitterHintLow : (o <= 0.35 ? l.aiPacingJitterHintNormal : l.aiPacingJitterHintWild)),
          ),
      ],
    );
    if (v == null) return;
    ai.update((s) => s.copyWith(pacingJitter: v));
  }
}

/// One line for the entry row in the settings tab, naming whatever is on.
String aiReplySummary(Store st) {
  final l = L10n.current;
  final on = [
    if (st.showThinking) l.aiReplySummaryThinking,
    if (st.agentMode) l.aiReplySummaryAgent,
  ];
  return on.isEmpty ? l.aiReplySummaryNone : on.join(' · ');
}
