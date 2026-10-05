import 'package:flutter/widgets.dart';

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/ai_client.dart';
import '../data/store.dart';
import '../l10n/x.dart';

const _langs = ['English', '中文', '日本語', 'Español', 'Français', 'Deutsch', 'Русский', '한국어'];
const _styles = ['Formal', 'Friendly', 'Short', 'Casual', 'Playful', 'Poetic'];
const _tabs = ['Translate', 'Style', 'Fix'];

// AIEditorAlert with translate style and fix tabs
class AiEditorSheet extends StatefulWidget {
  const AiEditorSheet({super.key, required this.text});
  final String text;

  @override
  State<AiEditorSheet> createState() => _AiEditorSheetState();
}

class _AiEditorSheetState extends State<AiEditorSheet> {
  int _tab = 0;
  int _lang = 0;
  int _style = 0;
  bool _loading = false;
  String? _error;
  final Map<String, String> _cache = {};
  int _gen = 0;

  String get _key => '$_tab:${_tab == 0 ? _lang : _style}';
  String? get _result => _cache[_key];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  String _system() {
    switch (_tab) {
      case 0:
        return 'You are a translation engine. Translate the user text to ${_langs[_lang]}. Output only the translation.';
      case 1:
        return 'Rewrite the user text in a ${_styles[_style].toLowerCase()} tone. Keep the meaning and the language. Output only the rewritten text.';
      default:
        return 'Fix spelling grammar and punctuation of the user text. Keep the language and meaning. Output only the corrected text.';
    }
  }

  Future<void> _run() async {
    if (!mounted || _cache.containsKey(_key)) {
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }
    final store = Store.read(context);
    final gen = ++_gen;
    final key = _key;
    if (store.apiKey.isEmpty) {
      setState(() {
        _loading = false;
        _error = L10n.current.aiEditorNoKey;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await store.ai.complete(baseUrl: store.baseUrl, key: store.apiKey, model: store.model, messages: [
        {'role': 'system', 'content': _system()},
        {'role': 'user', 'content': widget.text},
      ], base: store.endpointProvider, settings: store.aiConfig.settings);
      if (!mounted) return;
      _cache[key] = r;
      if (gen == _gen) setState(() => _loading = false);
    } on AiError catch (e) {
      if (mounted && gen == _gen) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  void _pickTab(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    _run();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    final label = TextStyle(color: p.subtitle, fontSize: 13, fontWeight: FontWeight.w500, decoration: TextDecoration.none);
    final body = TextStyle(color: p.title, fontSize: 16, height: 1.3, decoration: TextDecoration.none, fontWeight: FontWeight.w400);
    final res = _result;
    return TgSheet(
      color: p.gray,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TgIcon(Ic.ai, color: p.accent, size: 22),
            const SizedBox(width: 8),
            Text(l.aiEditorTitle, style: TextStyle(color: p.title, fontSize: 19, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
          ]),
          const SizedBox(height: 14),
          _tabsBar(p),
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: TgCurves.easeOutQuint,
            alignment: Alignment.topCenter,
            child: _tab == 2 ? const SizedBox(width: double.infinity) : _chips(p),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Original', style: label),
              const SizedBox(height: 4),
              Text(widget.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: body.copyWith(color: p.msg)),
              Container(margin: const EdgeInsets.symmetric(vertical: 12), height: 1, color: p.divider),
              Text('Result', style: label.copyWith(color: p.accent)),
              const SizedBox(height: 6),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: TgCurves.easeOutQuint,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _loading
                      ? const _Shimmer(key: ValueKey('load'))
                      : _error != null
                          ? Text(_error!, key: const ValueKey('err'), style: body.copyWith(color: p.danger, fontSize: 15))
                          : Text(res ?? '', key: ValueKey(_key), style: body),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          TgButton(label: l.aiEditorApply, enabled: res != null && !_loading, onTap: () => Navigator.of(context).pop(res)),
        ]),
      ),
    );
  }

  Widget _tabsBar(Pal p) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(28)),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth / 3;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: TgCurves.easeOutQuint,
            left: w * _tab,
            width: w,
            top: 0,
            bottom: 0,
            child: Container(decoration: BoxDecoration(color: p.accent.withAlpha(36), borderRadius: BorderRadius.circular(24))),
          ),
          Row(children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Tap(
                  onTap: () => _pickTab(i),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(color: i == _tab ? p.tabSel : p.title, fontSize: 15, fontWeight: FontWeight.w500, decoration: TextDecoration.none),
                      child: Text(_tabs[i]),
                    ),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }

  Widget _chips(Pal p) {
    final items = _tab == 0 ? _langs : _styles;
    final sel = _tab == 0 ? _lang : _style;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => Tap(
            scale: .95,
            onTap: () {
              setState(() => _tab == 0 ? _lang = i : _style = i);
              _run();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: TgCurves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: i == sel ? p.accent : p.bg, borderRadius: BorderRadius.circular(19)),
              child: Text(items[i], style: TextStyle(color: i == sel ? (p.dark ? const Color(0xFF0F1A24) : const Color(0xFFFFFFFF)) : p.title, fontSize: 15, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
            ),
          ),
        ),
      ),
    );
  }
}

// loading lines like LoadingSpan
class _Shimmer extends StatefulWidget {
  const _Shimmer({super.key});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Opacity(
        opacity: .35 + .5 * Curves.easeInOut.transform(_c.value),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final f in [1.0, .92, .55])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: FractionallySizedBox(widthFactor: f, child: Container(height: 8, decoration: BoxDecoration(color: p.divider, borderRadius: BorderRadius.circular(4)))),
            ),
        ]),
      ),
    );
  }
}
