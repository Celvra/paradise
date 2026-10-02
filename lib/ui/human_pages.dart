import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/human/hub.dart';
import '../data/human/human_models.dart';
import '../data/human/scheduler.dart';
import '../data/store.dart';
import '../l10n/x.dart';
import 'human_data_pages.dart';
import 'tg_cells.dart';

// Settings > Humanize. Every screen is built from the same Telegram cells the
// rest of the settings use (HeaderCell, TextCell, TextCheckCell, SlideChoose).

void hOpen(BuildContext c, Widget page) => Navigator.of(c).push(TgRoute(builder: (_) => page));

TextStyle hStyle(Pal p, {double size = 16, Color? color, FontWeight weight = FontWeight.w400}) => TextStyle(color: color ?? p.title, fontSize: size, fontWeight: weight, height: 1.25, decoration: TextDecoration.none);

/// Rebuilds when the hub changes, the hub is not part of the store notifier.
class HLive extends StatelessWidget {
  const HLive({super.key, required this.builder});
  final Widget Function(BuildContext c, HumanHub h, Pal p) builder;

  @override
  Widget build(BuildContext context) {
    final h = Store.of(context).human!;
    return ListenableBuilder(listenable: h, builder: (c, _) => builder(c, h, c.p));
  }
}

class HPage extends StatelessWidget {
  const HPage({super.key, required this.title, required this.body, this.actions = const []});
  final String title;
  final List<Widget> Function(BuildContext c, HumanHub h, Pal p) body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return TgSettingsPage(
      title: title,
      actions: actions,
      builder: (c, _) => HLive(builder: (c, h, p) => ListView(physics: const ClampingScrollPhysics(), padding: const EdgeInsets.only(bottom: 40), children: body(c, h, p))),
    );
  }
}

/// slider row, value text on the right
Widget hSlider(Pal p, String title, double value, double min, double max, ValueChanged<double> onChanged, {String Function(double v)? fmt, bool divider = true}) {
  // A 0 to 1 probability and a 0 to 12 count are both sliders, but the first
  // only means something with a hundredth of resolution. Deriving the step from
  // the span keeps every call site unchanged and keeps the thumb reachable
  // across the whole range.
  final span = max - min;
  final step = span > 1 ? 1.0 : (span >= 0.1 ? 0.01 : (span >= 0.01 ? 0.001 : span));
  return Container(
    color: p.bg,
    padding: const EdgeInsets.fromLTRB(21, 10, 21, 4),
    child: Column(children: [
      Row(children: [
        Expanded(child: Text(title, style: hStyle(p))),
        Text(fmt != null ? fmt(value) : value.toStringAsFixed(2), style: hStyle(p, size: 15, color: p.accent, weight: FontWeight.w500)),
      ]),
      SizedBox(height: 32, child: TgSlider(value: value.clamp(min, max).toDouble(), min: min, max: max, step: step, onChanged: onChanged)),
    ]),
  );
}

Future<String?> hAsk(BuildContext c, String title, String hint, {String initial = '', int lines = 1, String? ok}) async {
  final l = c.l;
  final ctl = TextEditingController(text: initial);
  final r = await showTgDialog<bool>(c, title: title, content: TgField(controller: ctl, hint: hint, maxLines: lines, autofocus: true), actions: [DialogAction(l.actionCancel, false), DialogAction(ok ?? l.actionOk, true)]);
  final text = ctl.text;
  ctl.dispose();
  return r == true ? text : null;
}

String hClock(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

// ------------------------------------------------------------------ root

void openHumanSettings(BuildContext c) => hOpen(c, const HumanSettingsPage());

class HumanSettingsPage extends StatelessWidget {
  const HumanSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return HPage(
      title: l.humanTitle,
      body: (c, h, p) {
        final s = h.settings;
        return [
          TgSection(footer: l.humanFooter, children: [
            TgCheckCell(title: l.humanEnabled, icon: Ic.ai, value: s.enabled, divider: false, onChanged: (v) {
              s.enabled = v;
              h.changed();
            }),
          ]),
          TgSection(header: l.humanBehaviour, children: [
            TgTextCell(title: l.humanBehaviourRow, icon: Ic.pencil, onTap: () => hOpen(c, const HumanBehaviorPage())),
            TgTextCell(title: l.humanProactive, icon: Ic.send, value: s.proactive ? l.profileOn : l.profileOff, onTap: () => hOpen(c, const HumanProactivePage())),
            TgTextCell(title: l.humanStickersRow, icon: Ic.sticker, value: '${h.stickers.items.length}', onTap: () => hOpen(c, const StickerSettingsPage())),
            TgTextCell(title: l.humanMemoryRow, icon: Ic.list, value: '${h.memory.items.where((m) => !m.forgotten).length}', onTap: () => hOpen(c, const MemoryPage())),
            TgTextCell(title: l.humanChatsRow, icon: Ic.user, divider: false, onTap: () => hOpen(c, const HumanChatsPage())),
          ]),
          TgSection(header: l.humanToolsHeader, children: [
            TgTextCell(title: l.humanToolsRow, icon: Ic.gear, value: '${h.mcp.tools.length} MCP', onTap: () => hOpen(c, const ToolsPage())),
            TgTextCell(title: l.humanVoiceRow, icon: Ic.music, onTap: () => hOpen(c, const HumanVoicePage())),
            TgTextCell(title: l.humanWalletRow, icon: Ic.crown, value: h.wallet.balance.toStringAsFixed(2), divider: false, onTap: () => hOpen(c, const WalletPage())),
          ]),
          TgSection(header: l.humanDataHeader, children: [
            TgTextCell(title: l.humanRatingsRow, icon: Ic.check2, onTap: () => hOpen(c, const HumanRatingsPage())),
            TgTextCell(title: l.humanBackupRow, icon: Ic.storage, onTap: () => hOpen(c, const HumanBackupPage())),
            TgTextCell(title: l.humanSchedDebugRow, icon: Ic.list, divider: false, onTap: () => hOpen(c, const SchedulerDebugPage())),
          ]),
        ];
      },
    );
  }
}

// -------------------------------------------------------------- behaviour

class HumanBehaviorPage extends StatefulWidget {
  const HumanBehaviorPage({super.key});
  @override
  State<HumanBehaviorPage> createState() => _BehaviorState();
}

class _BehaviorState extends State<HumanBehaviorPage> {
  final _seed = TextEditingController();

  @override
  void initState() {
    super.initState();
    final hub = Store.read(context).human!;
    _seed.text = hub.settings.seed?.toString() ?? '';
    _seed.addListener(() {
      hub.settings.seed = int.tryParse(_seed.text.trim());
      hub.save();
    });
  }

  @override
  void dispose() {
    _seed.dispose();
    super.dispose();
  }

  String _pct(double v) => '${(v * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return HPage(
      title: l.humanBehaviourTitle,
      body: (c, h, p) {
        final s = h.settings;
        void set(void Function() f) {
          f();
          h.changed();
        }

        return [
          TgSection(header: l.humanBrHeader, footer: l.humanBrFooter, children: [
            TgCheckCell(title: l.humanBrToggle, value: s.br, onChanged: (v) => set(() => s.br = v)),
            hSlider(p, l.humanBrPause, s.brDefaultMs.toDouble(), 100, 3000, (v) => set(() => s.brDefaultMs = (v / 50).round() * 50), fmt: (v) => '${v.round()} ms'),
          ]),
          TgSection(header: l.humanRandomHeader, footer: l.humanRandomFooter, children: [
            hSlider(p, l.humanTypingSpread, s.randomRange, 0, 0.6, (v) => set(() => s.randomRange = v), fmt: (v) => '±${_pct(v)}'),
            hSlider(p, l.humanTypoChance, s.typoProb, 0, 0.5, (v) => set(() => s.typoProb = v), fmt: _pct),
            hSlider(p, l.humanParticleChance, s.particleProb, 0, 1, (v) => set(() => s.particleProb = v), fmt: _pct),
            hSlider(p, l.humanSplitChance, s.splitProb, 0, 1, (v) => set(() => s.splitProb = v), fmt: _pct),
            TgTextCell(title: l.humanPunctStyle, value: [l.humanPunctNormal, l.humanPunctLoose, l.humanPunctMinimal][s.punct.clamp(0, 2)], onTap: () => set(() => s.punct = (s.punct + 1) % 3)),
            TgEditCell(controller: _seed, hint: l.humanSeedHint),
          ]),
          TgSection(header: l.humanRecallHeader, footer: l.humanRecallFooter, children: [
            TgCheckCell(title: l.humanRecallToggle, value: s.recall, onChanged: (v) => set(() => s.recall = v)),
            hSlider(p, l.humanRecallPerHour, s.recallPerHour.toDouble(), 0, 12, (v) => set(() => s.recallPerHour = v.round()), fmt: (v) => '${v.round()}'),
            hSlider(p, l.humanRecallWindow, s.recallWindowSec.toDouble(), 30, 600, (v) => set(() => s.recallWindowSec = (v / 30).round() * 30), fmt: (v) => '${v.round()} s'),
          ]),
          TgSection(header: l.humanStickerHeader, children: [
            hSlider(p, l.humanStickerFreq, s.stickerFreq, 0, 1, (v) => set(() => s.stickerFreq = v), fmt: _pct),
            TgCheckCell(title: l.humanAiSaveSticker, value: s.aiSaveSticker, onChanged: (v) => set(() => s.aiSaveSticker = v)),
            TgCheckCell(title: l.humanStickerOnly, value: s.stickerOnly, divider: false, onChanged: (v) => set(() => s.stickerOnly = v)),
          ]),
        ];
      },
    );
  }
}

// --------------------------------------------------------------- proactive

class HumanProactivePage extends StatelessWidget {
  const HumanProactivePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return HPage(
      title: l.humanProactive,
      body: (c, h, p) {
        final s = h.settings;
        void set(void Function() f) {
          f();
          h.changed();
        }

        Widget time(String title, int value, ValueChanged<int> on) => hSlider(p, title, value.toDouble(), 0, 1410, (v) => on((v / 30).round() * 30), fmt: (v) => hClock(v.round()));
        return [
          TgSection(footer: l.proactiveFooter, children: [
            TgCheckCell(title: l.proactiveToggle, value: s.proactive, divider: false, onChanged: (v) => set(() => s.proactive = v)),
          ]),
          TgSection(header: l.proactiveLimits, children: [
            hSlider(p, l.proactiveMaxConsecutive, s.maxConsecutive.toDouble(), 1, 10, (v) => set(() => s.maxConsecutive = v.round()), fmt: (v) => '${v.round()}'),
            TgCheckCell(title: l.proactiveDnd, value: s.dnd, onChanged: (v) => set(() => s.dnd = v)),
            TgCheckCell(title: l.proactiveQuiet, value: s.quiet, onChanged: (v) => set(() => s.quiet = v)),
            if (s.quiet) time(l.proactiveQuietFrom, s.quietStart, (v) => set(() => s.quietStart = v)),
            if (s.quiet) time(l.proactiveQuietUntil, s.quietEnd, (v) => set(() => s.quietEnd = v)),
            TgCheckCell(title: l.proactiveUrgent, value: s.allowUrgent, divider: false, onChanged: (v) => set(() => s.allowUrgent = v)),
          ]),
          TgSection(header: l.proactiveTriggers, footer: l.proactiveTriggersFooter, children: [
            TgCheckCell(title: l.proactiveGreetMorning, value: s.greetMorning, onChanged: (v) => set(() => s.greetMorning = v)),
            if (s.greetMorning) time(l.proactiveMorningAt, s.morningAt, (v) => set(() => s.morningAt = v)),
            TgCheckCell(title: l.proactiveGreetEvening, value: s.greetEvening, onChanged: (v) => set(() => s.greetEvening = v)),
            if (s.greetEvening) time(l.proactiveEveningAt, s.eveningAt, (v) => set(() => s.eveningAt = v)),
            hSlider(p, l.proactiveIcebreak, s.icebreakDays.toDouble(), 1, 30, (v) => set(() => s.icebreakDays = v.round()), fmt: (v) => l.proactiveIcebreakUnit(v.round())),
          ]),
          TgSection(header: l.proactiveServer, footer: l.proactiveServerFooter, children: [
            TgTextCell(title: l.proactiveServerUrl, value: s.serverUrl.isEmpty ? l.humanNotSet : s.serverUrl, divider: false, onTap: () async {
              final r = await hAsk(c, l.proactiveServerUrl, 'https://example.com', initial: s.serverUrl);
              if (r != null) set(() => s.serverUrl = r.trim());
            }),
          ]),
          TgSection(children: [
            TgTextCell(title: l.proactiveDebugPanel, icon: Ic.list, divider: false, onTap: () => hOpen(c, const SchedulerDebugPage())),
          ]),
        ];
      },
    );
  }
}

// ------------------------------------------------------------------- debug

class SchedulerDebugPage extends StatelessWidget {
  const SchedulerDebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final st = Store.of(context);
    return HPage(
      title: l.schedTitle,
      body: (c, h, p) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final open = h.scheduler.open();
        final recent = h.scheduler.tasks.where((t) => !t.open).toList().reversed.take(12).toList();
        String chatName(String id) => st.chats.where((e) => e.id == id).firstOrNull?.persona.name ?? '?';
        Widget task(ScheduledTask t, {bool live = true}) {
          final left = t.fireAt - now;
          final when = left <= 0 ? l.schedDue : l.schedRemaining(left ~/ 60000, (left ~/ 1000) % 60);
          return TgTextCell(
            title: '${chatName(t.chatId)} · ${proactiveWire(t.type)}',
            subtitle: '${t.id} · ${t.status.name}${live ? ' · $when' : ''}\n${l.schedCondition}: ${t.condition} · ${l.schedFailures}: ${t.failures}${t.urgent ? ' · ${l.schedUrgent}' : ''}\n${t.prompt}${t.note.isEmpty ? '' : '\n→ ${t.note}'}',
            trailing: live
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    Tap(scale: .85, onTap: () => st.triggerTaskNow(t.id), child: Padding(padding: const EdgeInsets.all(8), child: TgIcon(Ic.send, color: p.accent, size: 22))),
                    Tap(
                        scale: .85,
                        onTap: () {
                          h.scheduler.cancel(t.id, reason: 'cancelled from the debug panel');
                          h.changed();
                        },
                        child: Padding(padding: const EdgeInsets.all(8), child: TgIcon(Ic.trash, color: p.danger, size: 22))),
                  ])
                : null,
          );
        }

        String joined(List<String> l) => l.isEmpty ? L10n.current.schedEmptyLog : l.reversed.take(30).join('\n');
        return [
          TgSection(header: l.schedPending(open.length), footer: l.schedPendingFooter, children: [
            if (open.isEmpty) TgTextCell(title: l.schedEmpty, divider: false) else ...open.map(task),
          ]),
          TgSection(header: l.schedFinished, children: [
            if (recent.isEmpty) TgTextCell(title: '—', divider: false) else ...recent.map((t) => task(t, live: false)),
          ]),
          TgSection(children: [
            TgTextCell(
              title: l.schedTestTask,
              icon: Ic.plus,
              divider: false,
              onTap: () {
                if (st.chats.isEmpty) return;
                final ch = st.sorted.first;
                h.scheduler.schedule(chatId: ch.id, delayMs: 60000, prompt: 'Debug: say hi and mention the time.', type: ProactiveType.custom);
                h.changed();
              },
            ),
          ]),
          TgSection(header: l.schedGate, children: [Padding(padding: const EdgeInsets.all(16), child: Text(joined(h.gateLog), style: hStyle(p, size: 12.5, color: p.subtitle)))]),
          TgSection(header: l.schedToolCalls, children: [Padding(padding: const EdgeInsets.all(16), child: Text(joined(h.toolLog), style: hStyle(p, size: 12.5, color: p.subtitle)))]),
        ];
      },
    );
  }
}

// ----------------------------------------------------------------- ratings

class HumanRatingsPage extends StatelessWidget {
  const HumanRatingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return HPage(
      title: l.humanRatingsTitle,
      body: (c, h, p) {
        final s = h.settings;
        void set(void Function() f) {
          f();
          h.changed();
        }

        String f(double v) => v.toStringAsFixed(1);
        return [
          TgSection(footer: l.humanRatingsFooter, children: [
            hSlider(p, l.humanRatingHuman, s.humanScore, 1, 5, (v) => set(() => s.humanScore = v), fmt: f),
            hSlider(p, l.humanRatingAnnoy, s.annoyScore, 1, 5, (v) => set(() => s.annoyScore = v), fmt: f),
            hSlider(p, l.humanRatingSatisfaction, s.satisfaction, 1, 5, (v) => set(() => s.satisfaction = v), fmt: f),
            TgCheckCell(title: l.humanRatingAuto, value: s.autoRate, divider: false, onChanged: (v) => set(() => s.autoRate = v)),
          ]),
          TgInfoCell('${l.humanRatingTuning}: ×${s.tuning.toStringAsFixed(2)}'),
        ];
      },
    );
  }
}

// ------------------------------------------------------------------- voice

class HumanVoicePage extends StatelessWidget {
  const HumanVoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return HPage(
      title: l.humanVoiceTitle,
      body: (c, h, p) {
        final s = h.settings;
        void set(void Function() f) {
          f();
          h.changed();
        }

        Future<void> edit(String title, String cur, void Function(String) apply, {bool secret = false}) async {
          final r = await hAsk(c, title, title, initial: cur);
          if (r != null) set(() => apply(r.trim()));
        }

        return [
          TgSection(footer: l.humanVoiceFooter, children: [
            TgTextCell(title: l.humanVoiceEndpoint, value: s.ttsUrl.isEmpty ? l.humanNotSet : s.ttsUrl, onTap: () => edit(l.humanVoiceEndpoint, s.ttsUrl, (v) => s.ttsUrl = v)),
            TgTextCell(title: l.provApiKey, value: s.ttsKey.isEmpty ? l.humanNotSet : '••••••', onTap: () => edit(l.provApiKey, s.ttsKey, (v) => s.ttsKey = v, secret: true)),
            TgTextCell(title: l.humanVoiceModel, value: s.ttsModel, onTap: () => edit(l.humanVoiceModel, s.ttsModel, (v) => s.ttsModel = v)),
            TgTextCell(title: l.humanVoiceVoice, value: s.ttsVoice, onTap: () => edit(l.humanVoiceVoice, s.ttsVoice, (v) => s.ttsVoice = v)),
            hSlider(p, l.humanVoiceSpeed, s.ttsSpeed, 0.5, 2, (v) => set(() => s.ttsSpeed = double.parse(v.toStringAsFixed(2))), fmt: (v) => '${v.toStringAsFixed(2)}×'),
            TgCheckCell(title: l.humanVoiceSystem, value: s.ttsSystem, divider: false, onChanged: (v) => set(() => s.ttsSystem = v)),
          ]),
        ];
      },
    );
  }
}

// ------------------------------------------------------------------ backup

Future<String> _exportDir() async {
  final base = await getApplicationDocumentsDirectory();
  final d = Directory('${base.path}/exports');
  if (!d.existsSync()) d.createSync(recursive: true);
  return d.path;
}

class HumanBackupPage extends StatelessWidget {
  const HumanBackupPage({super.key});

  Future<void> _export(BuildContext c, String name, String json) async {
    final l = c.l;
    Clipboard.setData(ClipboardData(text: json));
    try {
      final dir = await _exportDir();
      final f = File('$dir/$name-${DateTime.now().millisecondsSinceEpoch}.json');
      await f.writeAsString(json);
      if (c.mounted) showBulletin(c, '${l.humanSavedCopied}: ${f.path}');
    } catch (_) {
      if (c.mounted) showBulletin(c, l.humanCopiedClipboard);
    }
  }

  Future<String?> _read(BuildContext c, bool fromFile) async {
    if (!fromFile) return (await Clipboard.getData('text/plain'))?.text;
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    final f = files.firstOrNull;
    if (f == null) return null;
    final path = f.path;
    if (path != null) return File(path).readAsString();
    return null;
  }

  Future<void> _import(BuildContext c, bool fromFile, int Function(String raw, bool overwrite) apply) async {
    final l = c.l;
    final raw = await _read(c, fromFile);
    if (raw == null || raw.trim().isEmpty || !c.mounted) return;
    final mode = await showTgDialog<String>(c, title: l.humanImportTitle, message: l.humanImportFooter, actions: [DialogAction(l.actionCancel, null), DialogAction(l.humanOverwrite, 'o', danger: true), DialogAction(l.humanMerge, 'm')]);
    if (mode == null || !c.mounted) return;
    try {
      final n = apply(raw, mode == 'o');
      if (c.mounted) showBulletin(c, l.humanImported(n));
    } catch (e) {
      if (c.mounted) showBulletin(c, l.humanInvalidFile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final st = Store.of(context);
    return HPage(
      title: l.humanBackupTitle,
      body: (c, h, p) {
        Widget group(String header, String name, String Function() exp, int Function(String, bool) imp) => TgSection(header: header, children: [
              TgTextCell(title: l.humanExport, icon: Ic.share, onTap: () => _export(c, name, exp())),
              TgTextCell(title: l.humanImportFile, icon: Ic.file, onTap: () => _import(c, true, imp)),
              TgTextCell(title: l.humanImportClipboard, icon: Ic.copy, divider: false, onTap: () => _import(c, false, imp)),
            ]);
        return [
          group(l.humanStickersGroup, 'stickers', h.exportStickers, (r, o) => h.importStickers(r, overwrite: o)),
          group(l.humanMemoryGroup, 'memory', h.exportMemory, (r, o) => h.importMemory(r, overwrite: o)),
          TgSection(header: l.humanCardsGroup, footer: l.humanCardsFooter, children: [
            for (final ch in st.sorted) TgTextCell(title: ch.persona.name, icon: Ic.user, onTap: () => hOpen(c, HumanChatPage(chatId: ch.id))),
          ]),
        ];
      },
    );
  }
}

// ----------------------------------------------------------- per chat page

class HumanChatsPage extends StatelessWidget {
  const HumanChatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final st = Store.of(context);
    return HPage(
      title: l.humanChatsTitle,
      body: (c, h, p) => [
        TgSection(children: [
          for (final ch in st.sorted)
            TgTextCell(
              title: ch.persona.name,
              subtitle: '${statusWire(ch.human.effective(DateTime.now().millisecondsSinceEpoch, dnd: h.settings.dnd))} · ${ch.human.stage.name} · ${l.humanChatFeelingsMood} ${ch.human.mood.round()} · ${l.humanChatFeelingsEnergy} ${ch.human.energy.round()}',
              leading: Avatar(name: ch.persona.emoji.isEmpty ? ch.persona.name : ch.persona.emoji, color: ch.persona.color, size: 40, path: ch.persona.avatarPath),
              onTap: () => hOpen(c, HumanChatPage(chatId: ch.id)),
            ),
        ]),
      ],
    );
  }
}

class HumanChatPage extends StatefulWidget {
  const HumanChatPage({super.key, required this.chatId});
  final String chatId;
  @override
  State<HumanChatPage> createState() => _HumanChatState();
}

class _HumanChatState extends State<HumanChatPage> {
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final store = Store.of(context);
    final chat = store.chats.where((c) => c.id == widget.chatId).firstOrNull;
    if (chat == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) => HPage(
        title: chat.persona.name,
        body: (c, h, p) {
          final st = chat.human;
          final now = DateTime.now().millisecondsSinceEpoch;
          void set(void Function() f) {
            f();
            chat.touch();
            h.changed();
          }

          Future<void> field(String title, String cur, void Function(String) apply, {int lines = 1}) async {
            final r = await hAsk(c, title, title, initial: cur, lines: lines);
            if (r != null) set(() => apply(r.trim()));
          }

          final card = st.card;
          return [
            TgSection(header: l.humanChatState, footer: '${l.humanChatStage}: ${st.stage.name} · ${l.humanChatMessages}: ${st.userMsgs} · ${l.humanChatMinutes}: ${st.interactionMin}', children: [
              TgTextCell(title: l.humanChatStatus, value: statusWire(st.effective(now, dnd: h.settings.dnd)), onTap: () {
                final order = [StatusKind.online, StatusKind.away, StatusKind.dnd, StatusKind.readNoReply];
                set(() => st.status = order[(order.indexOf(st.status) + 1) % order.length]);
              }),
              hSlider(p, l.humanChatFeelingsMood, st.mood, 0, 100, (v) => set(() => st.mood = v), fmt: (v) => v.round().toString()),
              hSlider(p, l.humanChatFeelingsAffection, st.affection, 0, 100, (v) => set(() {
                    st.affection = v;
                    st.evaluateStage(now);
                  }), fmt: (v) => v.round().toString()),
              hSlider(p, l.humanChatFeelingsEnergy, st.energy, 0, 100, (v) => set(() => st.energy = v), fmt: (v) => v.round().toString()),
              TgTextCell(title: l.humanChatClearTasks, divider: false, color: p.danger, onTap: () {
                for (final t in h.scheduler.open(chatId: chat.id)) {
                  h.scheduler.cancel(t.id, reason: 'cleared by the user');
                }
                h.changed();
              }),
            ]),
            TgSection(header: l.humanChatCardHeader, footer: l.humanChatCardFooter, children: [
              TgTextCell(title: l.humanChatSpeechStyle, subtitle: card.speechStyle.isEmpty ? null : card.speechStyle, onTap: () => field(l.humanChatSpeechStyle, card.speechStyle, (v) => card.speechStyle = v, lines: 3)),
              TgTextCell(title: l.humanChatCatchphrases, subtitle: card.catchphrases.isEmpty ? null : card.catchphrases.join(' / '), onTap: () => field(l.humanChatCatchphrasesHint, card.catchphrases.join(', '), (v) => card.catchphrases = v.split(RegExp(r'[,，、]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList())),
              TgTextCell(title: l.humanChatValues, subtitle: card.values.isEmpty ? null : card.values, onTap: () => field(l.humanChatValues, card.values, (v) => card.values = v, lines: 3)),
              TgTextCell(title: l.humanChatTaboos, subtitle: card.taboos.isEmpty ? null : card.taboos, onTap: () => field(l.humanChatTaboos, card.taboos, (v) => card.taboos = v, lines: 3)),
              TgTextCell(title: l.humanChatAddressStranger, value: card.addressStranger, onTap: () => field(l.humanChatAddressStranger, card.addressStranger, (v) => card.addressStranger = v)),
              TgTextCell(title: l.humanChatAddressAcquaintance, value: card.addressAcquaintance, onTap: () => field(l.humanChatAddressAcquaintance, card.addressAcquaintance, (v) => card.addressAcquaintance = v)),
              TgTextCell(title: l.humanChatAddressClose, value: card.addressClose, onTap: () => field(l.humanChatAddressClose, card.addressClose, (v) => card.addressClose = v)),
              TgTextCell(title: l.humanChatExportCard, icon: Ic.share, onTap: () {
                final j = const JsonEncoder.withIndent('  ').convert(card.toTavern(name: chat.persona.name, description: chat.persona.prompt, firstMes: chat.persona.greeting));
                Clipboard.setData(ClipboardData(text: j));
                showBulletin(c, l.humanChatCardCopied);
              }),
              TgTextCell(title: l.humanChatImportCard, icon: Ic.copy, divider: false, onTap: () async {
                final raw = (await Clipboard.getData('text/plain'))?.text ?? '';
                try {
                  final j = Map<String, dynamic>.from(jsonDecode(raw) as Map);
                  final mode = await showTgDialog<String>(c, title: l.humanChatImportCardTitle, message: l.humanChatImportCardFooter, actions: [DialogAction(l.actionCancel, null), DialogAction(l.humanOverwrite, 'o', danger: true), DialogAction(l.humanMerge, 'm')]);
                  if (mode == null) return;
                  final inc = CharacterCard.fromTavern(j);
                  set(() {
                    if (mode == 'o') {
                      st.card = inc;
                    } else {
                      if (card.speechStyle.isEmpty) card.speechStyle = inc.speechStyle;
                      if (card.values.isEmpty) card.values = inc.values;
                      if (card.taboos.isEmpty) card.taboos = inc.taboos;
                      if (card.catchphrases.isEmpty) card.catchphrases = inc.catchphrases;
                      if (card.addressStranger.isEmpty) card.addressStranger = inc.addressStranger;
                      if (card.addressAcquaintance.isEmpty) card.addressAcquaintance = inc.addressAcquaintance;
                      if (card.addressClose.isEmpty) card.addressClose = inc.addressClose;
                    }
                  });
                } catch (_) {
                  if (c.mounted) showBulletin(c, l.humanChatInvalidCard);
                }
              }),
            ]),
            TgSection(header: l.humanChatSchedule, footer: l.humanChatScheduleFooter, children: [
              for (final e in st.life)
                TgTextCell(
                  title: e.title,
                  subtitle: '${hClock(DateTime.fromMillisecondsSinceEpoch(e.start).hour * 60 + DateTime.fromMillisecondsSinceEpoch(e.start).minute)} – ${hClock(DateTime.fromMillisecondsSinceEpoch(e.end).hour * 60 + DateTime.fromMillisecondsSinceEpoch(e.end).minute)} · ${e.kind.name} · ${e.by}${e.activeAt(now) ? ' · ${l.humanChatScheduleNow}' : ''}',
                  trailing: Tap(scale: .85, onTap: () => set(() => st.life.remove(e)), child: Padding(padding: const EdgeInsets.all(8), child: TgIcon(Ic.trash, color: p.danger, size: 22))),
                ),
              TgTextCell(title: l.humanChatScheduleAdd, icon: Ic.plus, divider: false, onTap: () async {
                final r = await hAsk(c, l.humanChatScheduleWhat, l.humanChatScheduleExample);
                if (r == null || r.trim().isEmpty) return;
                set(() => st.life.add(LifeEntry(id: 'life_$now', title: r.trim(), start: now, end: now + 60 * 60000, by: 'user')));
              }),
            ]),
            TgSection(header: l.humanChatFeelings, children: [
              Padding(padding: const EdgeInsets.all(16), child: Text(st.feelingLog.isEmpty ? '—' : st.feelingLog.reversed.take(12).join('\n'), style: hStyle(p, size: 12.5, color: p.subtitle))),
            ]),
          ];
        },
      ),
    );
  }
}
