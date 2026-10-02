import 'package:flutter/widgets.dart';

import '../core/overlays.dart';
import '../core/ui_kit.dart';
import '../data/store.dart';
import '../l10n/x.dart';
import 'human_data_pages.dart' show ToolsPage;
import 'human_pages.dart';
import 'tg_cells.dart';

// Settings > AI replies. The two switches that decide what the model is allowed
// to do and how much of it the user gets to see. Both are global defaults; a
// persona card can take either one over for itself, which is why the footer
// says so out loud.

void openAiReplySettings(BuildContext c) => Navigator.of(c).push(TgRoute(builder: (_) => const AiReplyPage()));

class AiReplyPage extends StatelessWidget {
  const AiReplyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.store;
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
                divider: false,
                onChanged: st.setAgentMode,
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
