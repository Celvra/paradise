import 'package:flutter/material.dart';

import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/ai/compaction.dart';
import '../data/ai/errors.dart';
import '../data/ai/tokenizer.dart';
import '../data/ai_config.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../l10n/errors.dart';
import '../l10n/x.dart';
import 'ai_model_picker.dart';
import 'tg_cells.dart';

/// Settings > AI > Context compaction > Test. Runs one compaction on a chat of
/// your choosing and shows what it cost, because compaction otherwise happens
/// where the user sees nothing: the request either fits or the provider says
/// so, and the summary length the settings asked for is never checked against
/// anything.
void openCompactionTest(BuildContext c) => Navigator.of(c).push(TgRoute(builder: (_) => const CompactionTestPage()));

class CompactionTestPage extends StatefulWidget {
  const CompactionTestPage({super.key});

  @override
  State<CompactionTestPage> createState() => _CompactionTestPageState();
}

/// A failure the app has no copy for is shown as it arrived: this screen
/// exists to tell someone why their compaction did not work, and "something
/// went wrong" is the one answer that never does.
String _reason(Object error) {
  final kind = toAiError(error);
  return kind.kind == AiErrorKind.unknown ? '$error' : describeErrorL10n(kind);
}

class _CompactionTestPageState extends State<CompactionTestPage> {
  String? _running;
  CompactionReport? _report;

  Future<void> _run(Store st, Chat c) async {
    setState(() => _running = c.id);
    final report = await st.compactForTest(c);
    if (!mounted) return;
    setState(() {
      _running = null;
      _report = report;
    });
  }

  /// Drops the checkpoint and runs again, which is the only way back to a chat
  /// that has already been summarized once.
  Future<void> _clear(Store st, AiConfig cfg) async {
    final id = _report?.chatId;
    if (id == null) return;
    cfg.setCompaction(id, null);
    final chat = st.chats.where((e) => e.id == id).firstOrNull;
    if (chat != null) await _run(st, chat);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return TgSettingsPage(
      title: l.aiCompactTestTitle,
      builder: (c, _) {
        final st = Store.of(c);
        final cfg = AiScope.of(c);
        return ListenableBuilder(
          listenable: Listenable.merge([st, cfg]),
          builder: (c, _) {
            final chats = st.sorted;
            return ListView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                TgSection(
                  header: l.aiCompactTestChats,
                  footer: l.aiCompactTestFooter,
                  children: [
                    if (chats.isEmpty)
                      TgTextCell(title: l.aiCompactTestNoChats, divider: false)
                    else
                      for (var i = 0; i < chats.length; i++)
                        _chatRow(st, cfg, chats[i], running: _running == chats[i].id, busy: _running != null, last: i == chats.length - 1),
                  ],
                ),
                if (_report != null) ..._reportSection(st, cfg, _report!),
              ],
            );
          },
        );
      },
    );
  }

  Widget _chatRow(Store st, AiConfig cfg, Chat c, {required bool running, required bool busy, required bool last}) {
    final l = context.l;
    final p = context.p;
    final real = c.msgs.where((m) => !m.service && m.text.isNotEmpty).length;
    final done = cfg.compactionOf(c.id) != null;
    return TgTextCell(
      title: c.persona.name,
      icon: Ic.user,
      subtitle: '${l.pluralMessages(real)}${done ? ' · ${l.aiCompactTestCompacted}' : ''}',
      subtitleColor: done ? p.accent : null,
      divider: !last,
      trailing: running ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.accent)) : null,
      onTap: busy ? null : () => _run(st, c),
    );
  }

  List<Widget> _reportSection(Store st, AiConfig cfg, CompactionReport r) {
    final l = context.l;
    final p = context.p;
    // the picture the whole feature exists for: what the window cost before,
    // what it costs after, and what the summary itself weighs against its budget
    String weigh(int chars, int tokens) => '${l.pluralChars(chars)} · ${formatTokens(tokens)}';
    final saved = r.beforeTokens - r.afterTokens;
    Widget row(String title, String? value, {String? subtitle, bool last = false, bool accent = false}) => TgTextCell(
          title: title,
          subtitle: subtitle,
          value: value,
          subtitleColor: accent ? p.accent : null,
          divider: !last,
        );

    return [
      TgSection(
        header: l.aiCompactTestReport,
        footer: r.ok ? l.aiCompactTestReportFooter : null,
        gap: r.ok,
        children: [
          row(l.aiCompactTestBefore, weigh(r.beforeChars, r.beforeTokens)),
          row(l.aiCompactTestAfter, weigh(r.afterChars, r.afterTokens), subtitle: saved > 0 ? '−${l.pluralTokens(saved)}' : null),
          row(l.aiCompactTestSummary, weigh(r.summaryChars, r.summaryTokens), subtitle: l.aiCompactTestTarget('${r.targetChars}'), last: r.ok),
          row(l.aiCompactTestFolded, '${l.pluralMessages(r.folded)} → ${l.pluralMessages(r.kept)}', subtitle: l.aiCompactTestKeptNote, last: !r.ok),
          row(l.aiCompactTestModel, r.model, subtitle: r.contextWindow > 0 ? l.aiCompactTestWindow(formatTokens(r.contextWindow)) : null, last: !r.ok),
          row(l.aiCompactTestDuration, formatDuration(r.ms), last: !r.ok),
          if (r.ok) row(l.aiCompactTestTrigger, r.wouldFire ? l.aiCompactTestFired : l.aiCompactTestIdle, last: true, accent: r.wouldFire),
          if (!r.ok)
            Container(
              color: p.bg,
              padding: const EdgeInsets.fromLTRB(21, 12, 21, 12),
              child: Text(l.aiCompactTestFailed(_reason(r.error!)), style: TextStyle(color: p.danger, fontSize: 14, height: 1.3, decoration: TextDecoration.none)),
            ),
          if (r.ok)
            Container(
              color: p.bg,
              padding: const EdgeInsets.fromLTRB(21, 12, 21, 14),
              child: SelectableText(r.summary, style: TextStyle(color: p.title, fontSize: 14, height: 1.4, decoration: TextDecoration.none)),
            ),
        ],
      ),
      if (r.ok)
        TgSection(
          footer: l.aiCompactTestClearFooter,
          children: [
            TgTextCell(
              title: l.aiCompactTestClear,
              icon: Ic.trash,
              iconColor: p.danger,
              divider: false,
              onTap: _running == null ? () => _clear(st, cfg) : null,
            ),
          ],
        ),
    ];
  }
}