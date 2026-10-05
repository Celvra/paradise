import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ratex_flutter/ratex_flutter.dart';
import 'package:ratex_flutter/src/ratex_painter.dart';
import 'package:typst_flutter/typst_flutter.dart' as typst;
import 'package:webview_flutter/webview_flutter.dart';

import '../core/anim.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart' show Ic, TgIcon, TypingDots;
import '../data/store.dart';
import '../l10n/x.dart';

/// One log line per card event, tagged `ParaCanvas` so a logcat filtered on
/// the flutter tag reads as the whole story of what the engines did: parse
/// errors, compile diagnostics, package cache state. Rendered cards log a
/// single ok line too, so a missing line is as telling as a present one.
void cardLog(String event, [String detail = '']) {
  debugPrint('ParaCanvas: ${detail.isEmpty ? event : '$event | $detail'}');
}

/// Where a canvas card's content sits on the row. A formula or a drawing is
/// usually narrower than the column, so the model can park it left, right or
/// centered when it is composing several cards into a layout.
enum CardAlign { left, center, right }

/// Reads the tool's `align` argument. Anything unknown falls back to center,
/// so an old message without the field behaves exactly as before.
CardAlign parseCardAlign(Object? v) => switch ('$v'.trim().toLowerCase()) {
      'left' => CardAlign.left,
      'right' => CardAlign.right,
      _ => CardAlign.center,
    };

/// Flattens a Typst compile exception into the few lines that matter: each
/// diagnostic with its source location and hint, ready for the transcript.
String typstError(Object error) {
  if (error is typst.TypstCompileException) {
    final parts = <String>[];
    for (final d in error.diagnostics) {
      final loc = d.spanStart;
      final at = loc != null ? '${loc.line}:${loc.column} ' : '';
      parts.add('${at}${d.message}');
      for (final h in d.hints) {
        parts.add('hint: $h');
      }
    }
    return parts.isEmpty ? error.message : parts.join('; ');
  }
  return '$error';
}

/// A message the model rendered as a live document instead of a bubble.
///
/// Math and drawings are native, no webview: math goes through ratex_flutter
/// (a Rust engine behind Dart FFI that paints with a CustomPainter), drawings
/// through typst_flutter (the Typst compiler embedded over FFI, whose CeTZ
/// package is this generation's TikZ). Both are plain native calls, so neither
/// can hang on a spinner. Html keeps its webview — a plain page with no wasm
/// and no workers loads instantly, and it reports its own height.
///
/// The card lies flat on the wallpaper at full column width, and the long
/// press belongs to the rendered thing itself, which is what opens the
/// message menu.
class CanvasCard extends StatefulWidget {
  const CanvasCard({super.key, required this.source, required this.latex, this.cetz = false, this.align = CardAlign.center, this.onLongPress, this.onFailed, this.initialHeight, this.onHeight});

  /// LaTeX math for [latex] cards, html markup otherwise.
  final String source;
  final bool latex;

  /// True for a CeTZ drawing card (send_cetz), false for plain math.
  final bool cetz;

  /// Horizontal placement of the content inside the full width card.
  final CardAlign align;

  /// Fired with the card's screen rect, the anchor the message menu wants.
  final void Function(Rect rect)? onLongPress;

  /// Fired once when the engine could not render the source. The chat marks
  /// the message so the transcript tells the model; the card itself collapses
  /// to a quiet notice.
  final void Function(String error)? onFailed;

  /// Height the card had last time, from the message row (`data['h']`) or the
  /// in-memory cache. Used as the placeholder so a re-entered chat does not
  /// flash from 40/80/90 up to the real height.
  final double? initialHeight;

  /// Reports the card's real height once known, so the chat can remember it
  /// for the next entry and for a restart.
  final void Function(double h)? onHeight;

  @override
  State<CanvasCard> createState() => _CanvasCardState();
}

class _CanvasCardState extends State<CanvasCard> {
  final GlobalKey _gk = GlobalKey();

  /// A send_cetz card carries its flag from the tool call.
  bool get _isDrawing => widget.latex && widget.cetz;

  Rect _rect() {
    final box = _gk.currentContext!.findRenderObject() as RenderBox;
    final o = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(o.dx, o.dy, box.size.width, box.size.height);
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = widget.latex
        ? (_isDrawing
            ? CetzDoc(source: widget.source, align: widget.align, onFailed: _failed, initialHeight: widget.initialHeight, onHeight: _height)
            : MathDoc(source: widget.source, align: widget.align, onFailed: _failed, initialHeight: widget.initialHeight, onHeight: _height))
        : HtmlDoc(source: widget.source, align: widget.align, onFailed: _failed, initialHeight: widget.initialHeight, onHeight: _height);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!(_rect());
            },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: TgCurves.easeOut,
        alignment: Alignment.topLeft,
        child: SizedBox(
          key: _gk,
          width: double.infinity,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: body),
        ),
      ),
    );
  }

  void _failed(String error) {
    widget.onFailed?.call(error);
  }

  void _height(double h) {
    widget.onHeight?.call(h);
  }
}

/// The quiet notice a failed card collapses to. The failure itself went to
/// the transcript through [CanvasCard.onFailed].
class CanvasNotice extends StatelessWidget {
  const CanvasNotice({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: p.gray.withAlpha(90), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          TgIcon(Ic.info, color: p.subtitle, size: 13, stroke: 2),
          const SizedBox(width: 6),
          Text(context.l.canvasRenderFailed, style: TextStyle(color: p.subtitle, fontSize: 12, height: 1.2, decoration: TextDecoration.none)),
        ]),
      ),
    );
  }
}

/// LaTeX math, painted natively by RaTeX. A formula that fails to parse calls
/// [onFailed]; the card then shows the notice and the transcript tells the
/// model what broke.
class MathDoc extends StatefulWidget {
  const MathDoc({super.key, required this.source, required this.align, required this.onFailed, this.initialHeight, this.onHeight});
  final String source;

  /// Horizontal placement inside the full width card.
  final CardAlign align;

  final void Function(String) onFailed;

  /// Height remembered from the last entry, so a re-entered chat does not
  /// flash from the fixed placeholder up to the real size.
  final double? initialHeight;

  /// Reports the real card height (content + padding) once laid out.
  final void Function(double h)? onHeight;

  /// The model often wraps formulas in the delimiters it was taught for chat
  /// math; the engine wants the expression itself.
  String strip(String s) {
    var t = s.trim();
    if (t.length > 4 && t.startsWith(r'$$') && t.endsWith(r'$$')) {
      t = t.substring(2, t.length - 2);
    } else if (t.length > 4 && t.startsWith(r'\[') && t.endsWith(r'\]')) {
      t = t.substring(2, t.length - 2);
    } else if (t.length > 2 && t.startsWith(r'$') && t.endsWith(r'$')) {
      t = t.substring(1, t.length - 1);
    }
    return t.trim();
  }

  @override
  State<MathDoc> createState() => _MathDocState();
}

class _MathDocState extends State<MathDoc> {
  /// Parsed layouts by stripped source + ink, so a re-entered chat reuses the
  /// last compile instead of flashing through the placeholder again. The ink
  /// rides in the key because the same formula paints a different colour by
  /// theme.
  static final Map<String, DisplayList> _cache = {};

  static String _key(String tex, int colorArgb) => '$colorArgb|$tex';

  DisplayList? _dl;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    cardLog('math parse', '${widget.strip(widget.source)}');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_busy || _dl != null || _error != null) return;
    final p = context.p;
    final color = p.dark ? const Color(0xFFE8EAED) : const Color(0xFF1B1B1B);
    final hit = _cache[_key(widget.strip(widget.source), color.toARGB32())];
    if (hit != null) {
      _dl = hit;
      WidgetsBinding.instance.addPostFrameCallback((_) => _report());
      return;
    }
    _run();
  }

  @override
  void didUpdateWidget(covariant MathDoc old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source) {
      _dl = null;
      _error = null;
      _run();
    }
  }

  Future<void> _run() async {
    if (_busy) return;
    _busy = true;
    final p = context.p;
    final color = p.dark ? const Color(0xFFE8EAED) : const Color(0xFF1B1B1B);
    final tex = widget.strip(widget.source);
    try {
      final cached = _cache[_key(tex, color.toARGB32())];
      if (cached != null) {
        if (!mounted) return;
        setState(() {
          _dl = cached;
          _error = null;
        });
        _report();
        return;
      }
      final dl = await compute(
        ratexParseAndLayoutInIsolate,
        RaTeXParseAndLayoutIsolateArgs(latex: tex, displayMode: true, colorArgb: color.toARGB32()),
      ).timeout(const Duration(seconds: 20));
      _cache[_key(tex, color.toARGB32())] = dl;
      cardLog('math ok', '${dl.width.toStringAsFixed(2)}x${(dl.height + dl.depth).toStringAsFixed(2)}em');
      if (!mounted) return;
      setState(() {
        _dl = dl;
        _error = null;
      });
      _report();
    } catch (e) {
      final msg = e is RaTeXException ? e.message : '$e';
      cardLog('math FAILED', msg);
      if (!mounted) return;
      setState(() => _error = msg);
      widget.onFailed(msg);
    } finally {
      _busy = false;
    }
  }

  /// The card height the list remembers: painter height plus the two paddings
  /// around it (4 above/below the painter, 2 above/below the card).
  void _report() {
    final dl = _dl;
    if (dl == null || !mounted) return;
    final fontSize = context.store.textSize * 1.15;
    final painter = RaTeXPainter(displayList: dl, fontSize: fontSize);
    widget.onHeight?.call(painter.totalHeightPx + 12);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return const CanvasNotice();
    final p = context.p;
    final dl = _dl;
    if (dl == null) {
      return SizedBox(height: widget.initialHeight ?? 40, width: double.infinity, child: Center(child: TypingDots(color: p.subtitle)));
    }
    final fontSize = context.store.textSize * 1.15;
    final painter = RaTeXPainter(displayList: dl, fontSize: fontSize);
    return Align(
      alignment: switch (widget.align) {
        CardAlign.left => Alignment.centerLeft,
        CardAlign.right => Alignment.centerRight,
        CardAlign.center => Alignment.center,
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: SizedBox(
          width: painter.widthPx,
          height: painter.totalHeightPx,
          child: CustomPaint(painter: painter),
        ),
      ),
    );
  }
}

/// html on a canvas card renders in a webview, like it always has: html has no
/// native renderer and needs none — a plain page with no wasm and no workers
/// loads instantly. The page reports its own height through a JS channel so
/// the card grows to fit and scrolls with the list.
class HtmlDoc extends StatefulWidget {
  const HtmlDoc({super.key, required this.source, required this.align, required this.onFailed, this.initialHeight, this.onHeight});
  final String source;

  /// Horizontal placement inside the full width card.
  final CardAlign align;

  final void Function(String) onFailed;

  /// Height remembered from the last entry, so a re-entered chat starts at
  /// the right size instead of flashing from 90 up.
  final double? initialHeight;

  /// Reports the measured content height (plus card padding) once known.
  final void Function(double h)? onHeight;

  @override
  State<HtmlDoc> createState() => _HtmlDocState();
}

class _HtmlDocState extends State<HtmlDoc> {
  static const _channel = 'ParaCardH';

  /// Last measured content height by source, so a re-entered chat starts at
  /// the right size while its own webview is still loading.
  static final Map<String, double> _cache = {};

  static String _key(String source, CardAlign align) => '${align.name}|${source.length}|${source.hashCode}';

  WebViewController? _controller;
  String? _error;
  double? _height;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _height = _cache[_key(widget.source, widget.align)] ?? widget.initialHeight;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(covariant HtmlDoc old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source || old.align != widget.align) {
      _controller = null;
      _height = _cache[_key(widget.source, widget.align)] ?? widget.initialHeight;
      _loaded = false;
      _error = null;
      _load();
    }
  }

  void _load() {
    if (_controller != null) return;
    final dark = context.p.dark;
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..addJavaScriptChannel(_channel, onMessageReceived: _onMessage)
        ..loadHtmlString(_document(widget.source, align: widget.align, dark: dark));
      cardLog('html load', '${widget.source.length} chars');
      setState(() => _controller = controller);
    } catch (e) {
      // no webview implementation (tests, or an unsupported platform): show
      // the quiet notice rather than a raw source dump
      cardLog('html FAILED', '$e');
      _error = '$e';
      widget.onFailed('$e');
    }
  }

  void _onMessage(JavaScriptMessage message) {
    final body = message.message.trim();
    if (body.startsWith('E:')) {
      final err = body.substring(2);
      cardLog('html FAILED', err);
      if (mounted) setState(() => _error = err);
      widget.onFailed(err);
      return;
    }
    final h = double.tryParse(body);
    if (h == null || h <= 0) return;
    // Clamp absurd values from a first layout with no width yet: content
    // measured at ~0 width wraps enormously tall, and scrollHeight would then
    // stick (it is max(content, viewport)), so the card would keep the tall
    // size forever. Content taller than this is a page, not a card.
    if (h > 2000) return;
    if (!_loaded) cardLog('html ok', '${h.toStringAsFixed(0)}px');
    _loaded = true;
    final last = _height;
    if (last != null && (h - last).abs() < 0.5) return;
    _cache[_key(widget.source, widget.align)] = h;
    widget.onHeight?.call(h + 4);
    if (mounted) setState(() => _height = h);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return const CanvasNotice();
    final c = _controller;
    if (c == null) return const SizedBox.shrink();
    return SizedBox(
      height: _height ?? widget.initialHeight ?? 90,
      width: double.infinity,
      child: IgnorePointer(child: WebViewWidget(controller: c)),
    );
  }

  /// A transparent page that measures itself and posts the height back. The
  /// `E:` prefix is the failure protocol the chat reads. A non-center [align]
  /// is served by a one row flex body so the model's fragment lines up to the
  /// side it asked for; center keeps the page untouched.
  String _document(String body, {required CardAlign align, required bool dark}) {
    final t = body.trimLeft().toLowerCase();
    final full = t.startsWith('<!doctype html') || t.startsWith('<html');
    final head = '''
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  html,body{margin:0;padding:0;background:transparent;}
  body{color:${dark ? '#e8eaed' : '#1b1b1b'};font-family:-apple-system,Roboto,'Segoe UI','PingFang SC','Noto Sans CJK SC',sans-serif;word-break:break-word;}
</style>
<script>
(function(){
  function post(){
    try {
      // Content height, not viewport height: scrollHeight is max(content,
      // viewport), so once the card grows it can never shrink back and a
      // first layout at ~0 width (enormously tall wrapping) sticks forever.
      // getBoundingClientRect is the content box and lets the card shrink as
      // well as grow.
      var h = Math.ceil(document.body.getBoundingClientRect().height);
      if (!(h > 0)) h = Math.ceil(document.body.offsetHeight);
      if (h > 0) $_channel.postMessage(String(h));
    } catch(e) { try { $_channel.postMessage('E:' + e); } catch(_) {} }
  }
  window.addEventListener('load', post);
  document.addEventListener('DOMContentLoaded', post);
  try { new ResizeObserver(post).observe(document.body); } catch(_) {}
  setTimeout(post, 60);
  setTimeout(post, 400);
})();
</script>''';
    if (full) return body.replaceFirst(RegExp(r'<head[^>]*>', caseSensitive: false), '<head>$head');
    if (align == CardAlign.center) return '<!DOCTYPE html><html><head>$head</head><body>$body</body></html>';
    final justify = align == CardAlign.left ? 'flex-start' : 'flex-end';
    return '<!DOCTYPE html><html><head>$head</head>'
        '<body style="display:flex;flex-direction:column;align-items:$justify;">$body</body></html>';
  }
}

/// The cetz / cetz-plot / oxifmt sources, unpacked once from the bundle and
/// served to the compiler's virtual file system. The packages' own
/// `@preview/...` imports were rewritten to relative paths, so a drawing
/// costs no network.
class TypstPackageStore {
  TypstPackageStore._();

  static Future<Map<String, Uint8List>>? _loading;
  static Map<String, Uint8List>? _files;

  /// Loads and unpacks the package bundle once. The chat page calls this at
  /// init so it is ready by first use, and a card that mounts first awaits the
  /// same future rather than compiling against an empty file set.
  static Future<Map<String, Uint8List>> ensure() {
    final done = _files;
    if (done != null) return Future.value(done);
    return _loading ??= _load();
  }

  static Future<Map<String, Uint8List>> _load() async {
    try {
      final data = await rootBundle.load('assets/typst/packages.tgz');
      final raw = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final gz = GZipDecoder().decodeBytes(raw);
      final tar = TarDecoder().decodeBytes(gz);
      final out = <String, Uint8List>{};
      for (final f in tar.files) {
        out[f.name] = f.content;
      }
      _files = out;
      cardLog('packages warm', '${out.length} files');
      return out;
    } catch (e) {
      cardLog('packages FAILED', '$e');
      _files = const {};
      return const {};
    }
  }

  /// Warms the cache; safe to call repeatedly. Failures are logged and the
  /// card reports them, so this never throws into a caller's init.
  static Future<void> warm() => ensure();
}

/// A CeTZ drawing, compiled natively by the embedded Typst compiler.
class CetzDoc extends StatefulWidget {
  const CetzDoc({super.key, required this.source, required this.align, required this.onFailed, this.initialHeight, this.onHeight});
  final String source;

  /// Horizontal placement inside the full width card.
  final CardAlign align;

  final void Function(String) onFailed;

  /// Height remembered from the last entry, the placeholder while compiling.
  final double? initialHeight;

  /// Reports the card height once known (page height + padding).
  final void Function(double h)? onHeight;

  @override
  State<CetzDoc> createState() => _CetzDocState();
}

class _CetzDocState extends State<CetzDoc> {
  /// One compiler for the whole app: creating it spins up a Rust isolate, so
  /// every drawing card shares it. Held as a future so two cards mounting at
  /// once still create only one. The WenQuanYi font covers CJK text inside
  /// drawings — the compiler's embedded fonts (Libertinus / NewCM / DejaVu)
  /// have no CJK glyphs, so Chinese labels would render as tofu without it.
  static Future<typst.TypstCompiler>? _shared;

  /// Compiled drawings by source + theme, so a re-entered chat shows the
  /// picture at once instead of flashing through the placeholder and growing.
  /// The value carries the svg plus the page size the log already prints, the
  /// size the card reports as its height.
  static final Map<String, ({String svg, double wPt, double hPt})> _cache = {};

  static String _key(String source, bool dark) => '$dark|${source.length}|${source.hashCode}';

  /// Loads the bundled CJK font once; empty on failure (drawings still
  /// compile, their Chinese labels just fall back to tofu).
  static Future<List<Uint8List>> _cjkFont() async {
    try {
      final data = await rootBundle.load('assets/fonts/wqy-microhei.ttc');
      return [data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)];
    } catch (e) {
      cardLog('cjk font FAILED', '$e');
      return const [];
    }
  }

  String? _svg;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Log the full source: the compile error carries only a line:column, and
    // this is how a bad drawing gets diagnosed from the device log.
    cardLog('cetz compile', '\n${widget.source}');
  }

  @override
  void didUpdateWidget(covariant CetzDoc old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source) {
      _svg = null;
      _error = null;
      _run();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_busy || _svg != null || _error != null) return;
    final hit = _cache[_key(widget.source, context.p.dark)];
    if (hit != null) {
      _svg = hit.svg;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // pt to logical px is ~1.333, plus the paddings around the picture.
        widget.onHeight?.call(hit.hPt * 1.333 + 12);
      });
      return;
    }
    _run();
  }

  Future<void> _run() async {
    if (_busy) return;
    _busy = true;
    final p = context.p;
    typst.TypstDocument? doc;
    final wrapped = wrapCetz(widget.source, dark: p.dark);
    try {
      final hit = _cache[_key(widget.source, p.dark)];
      if (hit != null) {
        if (!mounted) return;
        setState(() {
          _svg = hit.svg;
          _error = null;
        });
        widget.onHeight?.call(hit.hPt * 1.333 + 12);
        return;
      }
      final packages = await TypstPackageStore.ensure();
      if (packages.isEmpty) throw const typst.TypstCompileException('the cetz package bundle did not load');
      final compiler = await (_shared ??= typst.TypstCompiler.create(
        fonts: typst.FontSource.bytes(await _cjkFont()),
      ));
      doc = await compiler
          .compile(
            source: wrapped,
            files: typst.FileSource.bytes(packages),
            allowPackages: false,
          )
          .timeout(const Duration(seconds: 30));
      if (doc.pageCount == 0) throw const typst.TypstCompileException('document has no pages');
      final svg = await doc.renderSvg(0).timeout(const Duration(seconds: 20));
      final info = doc.pageInfo(0);
      _cache[_key(widget.source, p.dark)] = (svg: svg, wPt: info.widthPt, hPt: info.heightPt);
      cardLog('cetz ok', 'page ${info.widthPt.toStringAsFixed(0)}x${info.heightPt.toStringAsFixed(0)}pt, svg ${svg.length} bytes');
      if (!mounted) return;
      setState(() {
        _svg = svg;
        _error = null;
      });
      widget.onHeight?.call(info.heightPt * 1.333 + 12);
    } catch (e) {
      final err = withSourceLine(typstError(e), wrapped);
      cardLog('cetz FAILED', err);
      if (!mounted) return;
      setState(() => _error = err);
      widget.onFailed(err);
    } finally {
      doc?.dispose();
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return const CanvasNotice();
    if (_svg == null) {
      return SizedBox(height: widget.initialHeight ?? 80, width: double.infinity, child: Center(child: TypingDots(color: context.p.subtitle)));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SvgPicture.string(
        _svg!,
        fit: BoxFit.scaleDown,
        alignment: switch (widget.align) {
          CardAlign.left => Alignment.centerLeft,
          CardAlign.right => Alignment.centerRight,
          CardAlign.center => Alignment.center,
        },
      ),
    );
  }
}

/// Appends the offending source line to a `line:column message` Typst error,
/// so the device log and the model both see *what* failed, not just where.
/// `typstError` formats its first diagnostic as `28:26 unknown variable: ...`.
String withSourceLine(String err, String source) {
  final m = RegExp(r'^(\d+):(\d+) ').firstMatch(err);
  final line = m == null ? null : int.tryParse(m.group(1)!);
  if (line == null || line < 1) return err;
  final lines = source.split('\n');
  if (line > lines.length) return err;
  return '$err | line $line: ${lines[line - 1].trim()}';
}

/// The tool sends the inside of a `cetz.canvas` call, but a model sometimes
/// sends a full snippet or a bare `cetz.canvas(...)`. All three land on a page
/// whose text colour follows the chat theme, with the cetz package imported
/// from the bundle. Any `@preview/...` import the model wrote is rewritten to
/// the bundled path, so a drawing costs no network.
String wrapCetz(String source, {required bool dark}) {
  final t = _localizeImports(source.trim());

  final String body;
  if (t.contains('cetz.canvas') || t.contains('#import')) {
    body = t;
  } else {
    body = '#cetz.canvas(length: 1cm, {\n  import cetz.draw: *\n  $t\n})';
  }
  // Bind the package as `cetz` unless the model's own import already did (an
  // import with explicit `: names` or `as cetz` needs no help).
  final bound = RegExp(r'#import\s+"[^"]*cetz[^"]*"\s*(as\s+cetz\b|:)').hasMatch(t);
  final import = bound ? '' : '#import "packages/cetz/0.5.2/src/lib.typ" as cetz\n';
  return '''
#set page(width: auto, height: auto, margin: 8pt, fill: none)
#set text(fill: ${dark ? 'rgb("#e8eaed")' : 'rgb("#1b1b1b")'})
$import$body''';
}

/// Rewrites the model's `@preview/...` imports to the bundled paths. The bare
/// form (`#import "@preview/cetz:0.5.2"`, no `: names`) must become `... as
/// cetz`, since the bundled file is `lib.typ` and would otherwise bind as
/// `lib`.
String _localizeImports(String t) {
  const map = {
    'cetz': 'packages/cetz/0.5.2/src/lib.typ',
    'cetz-plot': 'packages/cetz-plot/0.1.4/src/lib.typ',
    'oxifmt': 'packages/oxifmt/1.0.0/lib.typ',
  };
  for (final e in map.entries) {
    final bare = RegExp('#import\\s+"@preview/' + RegExp.escape(e.key) + r':[^"]+"(?=\s*(?:$|\n))', multiLine: true);
    t = t.replaceAllMapped(bare, (_) => '#import "${e.value}" as ${e.key == 'cetz' ? 'cetz' : e.key}');
    final withNames = RegExp('"@preview/' + RegExp.escape(e.key) + r':[^"]+"');
    t = t.replaceAll(withNames, '"${e.value}"');
  }
  return t;
}
