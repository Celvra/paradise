import 'package:flutter/widgets.dart';

import '../core/overlays.dart';
import '../core/speech.dart';
import '../core/anim.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/ai/provider_model.dart';
import '../data/speech_config.dart';
import '../l10n/x.dart';
import 'ai_widgets.dart';
import 'tg_cells.dart';

/// The voice module's own settings page.
///
/// It is a top level entry rather than a section under the AI list because it
/// configures a different thing: the AI list is a fallback chain that answers
/// messages, this is the one endpoint that turns a line of text into audio.
/// Keeping them apart is what lets a user hear their character talk without
/// first inventing a chat provider for it.
void openSpeechSettings(BuildContext context) {
  Navigator.of(context).push(TgRoute(builder: (_) => const SpeechPage()));
}

class SpeechPage extends StatelessWidget {
  const SpeechPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cfg = SpeechScope.of(context);
    final l = context.l;
    final p = context.p;

    return ColoredBox(
      color: p.bg,
      child: Column(children: [
        _Bar(title: l.speechTitle),
        Expanded(
          child: ListView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 32),
            physics: const ClampingScrollPhysics(),
            children: [
              _Group(
                header: l.speechEngineHeader,
                footer: l.speechEngineFooter,
                children: [
                  TgTextCell(
                    icon: Ic.unmute,
                    title: l.speechEngineSystem,
                    subtitle: l.voiceImageEngineSystemSub,
                    value: cfg.engine == TtsEngine.system ? l.profileOn : null,
                    onTap: () => cfg.setEngine(TtsEngine.system),
                  ),
                  TgTextCell(
                    icon: Ic.globe,
                    title: l.speechEngineApi,
                    subtitle: l.voiceImageEngineApiSub,
                    value: cfg.engine == TtsEngine.api ? l.profileOn : null,
                    divider: false,
                    onTap: () => cfg.setEngine(TtsEngine.api),
                  ),
                ],
              ),
              if (cfg.engine == TtsEngine.api) ...[
                _Group(
                  header: l.speechEndpointHeader,
                  footer: l.speechEndpointFooter,
                  children: [
                    TgTextCell(
                      icon: Ic.link,
                      title: l.speechBaseUrl,
                      subtitle: cfg.baseUrl.isEmpty ? l.speechBaseUrlHint : cfg.baseUrl,
                      onTap: () => _edit(context, l.speechBaseUrl, cfg.baseUrl, l.speechBaseUrlHint, cfg.setBaseUrl),
                    ),
                    TgTextCell(
                      icon: Ic.key,
                      title: l.speechApiKey,
                      subtitle: cfg.apiKey.isEmpty ? l.speechApiKeyHint : _mask(cfg.apiKey),
                      onTap: () => _edit(context, l.speechApiKey, cfg.apiKey, l.speechApiKeyHint, cfg.setApiKey, obscure: true),
                    ),
                    TgTextCell(
                      icon: Ic.lock,
                      title: l.speechAuthStyle,
                      subtitle: _authLabel(cfg.authStyle, l),
                      onTap: () => _pickAuth(context, cfg),
                    ),
                    TgTextCell(
                      icon: Ic.ai,
                      title: l.speechModel,
                      subtitle: cfg.model,
                      onTap: () => _pickModel(context, cfg),
                      divider: false,
                    ),
                  ],
                ),
                _Group(
                  header: l.speechVoiceHeader,
                  footer: l.speechVoiceFooter,
                  children: [
                    TgTextCell(
                      icon: Ic.unmute,
                      title: l.speechVoice,
                      subtitle: cfg.voice,
                      onTap: () => _pickVoice(context, cfg),
                    ),
                    TgTextCell(
                      icon: Ic.music,
                      title: l.speechSpeed,
                      subtitle: '${cfg.speed}x',
                      onTap: () => _pickSpeed(context, cfg),
                    ),
                    TgTextCell(
                      icon: Ic.textSize,
                      title: l.speechInstructions,
                      subtitle: cfg.instructions.isEmpty ? l.speechInstructionsHint : cfg.instructions,
                      divider: false,
                      onTap: () => _edit(context, l.speechInstructions, cfg.instructions, l.speechInstructionsHint, cfg.setInstructions, maxLines: 4),
                    ),
                  ],
                ),
                if (!cfg.apiReady)
                  _Group(children: [
                    TgTextCell(
                      icon: Ic.info,
                      title: l.speechNotReady,
                      color: p.danger,
                      divider: false,
                    ),
                  ]),
                _Group(children: [
                  TgTextCell(
                    icon: Ic.trash,
                    title: l.speechClear,
                    color: p.danger,
                    divider: false,
                    onTap: () => _confirmClear(context, cfg),
                  ),
                ]),
              ] else
                _Group(
                  header: l.speechDeviceHeader,
                  footer: l.speechDeviceFooter,
                  children: [
                    TgTextCell(
                      icon: Ic.unmute,
                      title: l.speechTest,
                      subtitle: l.speechTestSub,
                      divider: false,
                      onTap: () => _test(context, cfg),
                    ),
                  ],
                ),
              if (cfg.engine == TtsEngine.api)
                _Group(children: [
                  TgTextCell(
                    icon: Ic.unmute,
                    title: l.speechTest,
                    subtitle: l.speechTestSub,
                    divider: false,
                    onTap: () => _test(context, cfg),
                  ),
                ]),
            ],
          ),
        ),
      ]),
    );
  }

  static String _mask(String key) {
    if (key.length <= 8) return '••••';
    return '${key.substring(0, 4)}••••${key.substring(key.length - 4)}';
  }

  static String _authLabel(AuthStyle a, AppLocalizations l) => switch (a) {
        AuthStyle.bearer => l.speechAuthBearer,
        AuthStyle.xApiKey => l.speechAuthXApiKey,
        AuthStyle.queryKey => l.speechAuthQuery,
      };

  Future<void> _edit(
    BuildContext context,
    String title,
    String initial,
    String hint,
    void Function(String) save, {
    bool obscure = false,
    int maxLines = 1,
  }) async {
    final v = await showTgInput(context, title: title, initial: initial, hint: hint, obscure: obscure, maxLines: maxLines);
    if (v == null) return;
    save(v);
  }

  Future<void> _pickAuth(BuildContext context, SpeechConfig cfg) async {
    final l = context.l;
    final v = await showAiSelect<String>(
      context,
      title: l.speechAuthStyle,
      value: authWire(cfg.authStyle),
      options: [
        (value: 'bearer', label: l.speechAuthBearer, sub: null),
        (value: 'x-api-key', label: l.speechAuthXApiKey, sub: null),
        (value: 'query-key', label: l.speechAuthQuery, sub: null),
      ],
    );
    if (v == null) return;
    cfg.setAuthStyle(authStyleOf(v));
  }

  Future<void> _pickModel(BuildContext context, SpeechConfig cfg) async {
    final l = context.l;
    final v = await showTgInput(context, title: l.speechModel, initial: cfg.model, hint: 'tts-1');
    if (v == null) return;
    cfg.setModel(v);
  }

  Future<void> _pickVoice(BuildContext context, SpeechConfig cfg) async {
    final l = context.l;
    final typed = TextEditingController(text: cfg.voice);
    final v = await showTgDialog<String>(
      context,
      title: l.speechVoice,
      message: l.speechVoicePickSub,
      content: TgEditCell(controller: typed, hint: 'alloy'),
      actions: [DialogAction(l.actionCancel, null), DialogAction(l.actionSave, '__save__')],
    );
    if (v == null) return;
    cfg.setVoice(typed.text);
  }

  Future<void> _pickSpeed(BuildContext context, SpeechConfig cfg) async {
    final l = context.l;
    final v = await showAiSelect<double>(
      context,
      title: l.speechSpeed,
      value: cfg.speed,
      options: [for (final s in const [0.75, 1.0, 1.25, 1.5, 2.0]) (value: s, label: '${s}x', sub: null)],
    );
    if (v == null) return;
    cfg.setSpeed(v);
  }

  Future<void> _confirmClear(BuildContext context, SpeechConfig cfg) async {
    final l = context.l;
    final ok = await showTgDialog<bool>(
      context,
      title: l.speechClear,
      message: l.speechClearMessage,
      actions: [DialogAction(l.actionCancel, false), DialogAction(l.actionClear, true, danger: true)],
    );
    if (ok != true) return;
    cfg.clear();
  }

  Future<void> _test(BuildContext context, SpeechConfig cfg) async {
    final l = context.l;
    final v = await showTgInput(context, title: l.speechTest, initial: l.speechTestLine, hint: l.speechTestLine);
    if (v == null || v.trim().isEmpty) return;
    try {
      await SpeechService.instance.speak(
        v.trim(),
        engine: cfg.engine,
        endpoint: cfg.engine == TtsEngine.api && cfg.baseUrl.isNotEmpty
            ? TtsEndpoint(provider: cfg.asProvider, apiKey: cfg.apiKey)
            : null,
        voice: cfg.voice,
        model: cfg.model,
        speed: cfg.speed,
        instructions: cfg.instructions,
      );
    } catch (e) {
      if (context.mounted) showBulletin(context, '${l.speechTestFailed}$e');
    }
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: p.bar,
      padding: EdgeInsets.only(top: top),
      child: SizedBox(
        height: 56,
        child: Row(children: [
          const SizedBox(width: 8),
          Tap(
            scale: .88,
            onTap: () => Navigator.of(context).maybePop(),
            child: SizedBox(width: 44, height: 44, child: Center(child: TgIcon(Ic.back, color: p.glassIcon, size: 24))),
          ),
          const SizedBox(width: 4),
          Expanded(child: Text(title, style: TextStyle(color: p.title, fontSize: 20, fontWeight: FontWeight.w600, decoration: TextDecoration.none))),
          const SizedBox(width: 20),
        ]),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children, this.header, this.footer});
  final List<Widget> children;
  final String? header;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (header != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Text(header!, style: TextStyle(color: p.accent, fontSize: 13.5, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
        ),
      Container(color: p.bar, child: Column(children: children)),
      if (footer != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: Text(footer!, style: TextStyle(color: p.subtitle, fontSize: 13, height: 1.3, decoration: TextDecoration.none)),
        ),
      const SizedBox(height: 8),
    ]);
  }
}
