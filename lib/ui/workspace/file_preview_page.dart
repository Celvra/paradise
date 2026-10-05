import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart'
    show CircularProgressIndicator, SelectableText;
import 'package:flutter/widgets.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:path/path.dart' as path;

import '../../core/anim.dart';
import '../../core/overlays.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../data/models.dart' show fileSize;
import '../../data/workspace/host_file_tools.dart';
import '../../l10n/x.dart';
import 'preview_file_type.dart';
import 'preview_kind.dart';
import 'html_svg_view.dart';
import 'workspace_prompts.dart';

/// Opens a file, routed by what it is.
///
/// [modelPathOf] is what the copy item uses; the preview itself does not care
/// where the file came from.
Future<void> showFilePreview(BuildContext context, File file,
    {String? Function(String hostPath)? modelPathOf, String? title}) async {
  if (!await file.exists()) {
    showBulletin(context, context.l.wsPreviewMissing);
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(TgRoute(
      builder: (_) =>
          FilePreviewPage(file: file, modelPathOf: modelPathOf, title: title)));
}

/// The preview page: a header with the file's actions and one of six bodies.
class FilePreviewPage extends StatefulWidget {
  const FilePreviewPage(
      {super.key, required this.file, this.modelPathOf, this.title});
  final File file;
  final String? Function(String hostPath)? modelPathOf;
  final String? title;

  @override
  State<FilePreviewPage> createState() => _FilePreviewPageState();
}

class _FilePreviewPageState extends State<FilePreviewPage> {
  late PreviewKind _kind;

  /// An html or svg file opens rendered; the reader can flip to the source.
  bool _rendered = true;

  @override
  void initState() {
    super.initState();
    _kind = previewKindFor(widget.file.path);
    // an extensionless file is only binary if the bytes say so, and that needs
    // a read. Done here rather than in the constructor because it is async and
    // initState cannot be.
    if (_kind == PreviewKind.code &&
        previewLanguage(widget.file.path) == null) {
      _sniff();
    }
  }

  Future<void> _sniff() async {
    final text = await HostFileTools.sniffsAsText(widget.file);
    if (!mounted) return;
    setState(() => _kind = text ? PreviewKind.code : PreviewKind.binary);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final mq = MediaQuery.of(context);
    final name = path.basename(widget.file.path);
    return SwipeBack(
      child: ColoredBox(
        color: p.bg,
        child: Column(children: [
          Container(
            color: p.bar,
            padding: EdgeInsets.only(top: mq.padding.top),
            child: SizedBox(
              height: 56,
              child: Row(children: [
                Tap(
                    scale: .88,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Center(
                            child: TgIcon(Ic.back, color: p.icon, size: 24)))),
                TgIcon(fileTypeIcon(name), color: p.icon, size: 20),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(widget.title ?? name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: p.title,
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none))),
                if (_kind == PreviewKind.html || _isSvg)
                  TgIconButton(
                      icon: _rendered ? Ic.fileCode : Ic.eye,
                      size: 20,
                      tooltip: context.l.wsPreviewRendered,
                      onTap: () => setState(() => _rendered = !_rendered)),
                TgIconButton(
                    icon: Ic.link,
                    size: 20,
                    onTap: () {
                      final m = widget.modelPathOf?.call(widget.file.path) ??
                          widget.file.path;
                      copyWithToast(context, m, context.l.wsCopiedPath);
                    }),
              ]),
            ),
          ),
          Container(height: .5, color: p.divider),
          Expanded(child: _body()),
        ]),
      ),
    );
  }

  Widget _body() {
    switch (_kind) {
      case PreviewKind.image:
        return _ImageBody(file: widget.file);
      case PreviewKind.binary:
        return _BinaryBody(file: widget.file);
      case PreviewKind.markdown:
        return _TextBody(file: widget.file, language: 'markdown');
      case PreviewKind.html:
        if (_rendered) return _RenderedBody(file: widget.file);
        return _TextBody(
            file: widget.file,
            language: previewLanguage(widget.file.path) ?? 'plaintext');
      case PreviewKind.csv:
        return _TextBody(
            file: widget.file,
            language: previewLanguage(widget.file.path) ?? 'plaintext');
      case PreviewKind.code:
        return _CodeBody(file: widget.file);
    }
  }

  /// A `.svg` routes to the html kind and previews as a rendered image, but
  /// only while the bytes really are markup; the flip to source is always
  /// available, so a broken file can still be read.
  bool get _isSvg =>
      widget.file.path.toLowerCase().endsWith('.svg');

  /// The rendered half of an html or svg file, reading the file itself.
  Widget _RenderedBody({required File file}) {
    return FutureBuilder<String>(
      future: file.readAsString(),
      builder: (c, snap) {
        if (snap.hasError) {
          return WsEmpty(icon: Ic.info, title: '${snap.error}');
        }
        if (!snap.hasData) {
          return Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: context.p.subtitle));
        }
        return HtmlSvgView(
          kind: _isSvg ? PreviewKind.image : PreviewKind.html,
          source: snap.data!,
        );
      },
    );
  }
}

/// An image at its own size, zoomable, capped on decode.
///
/// The cap matters: a photo straight off a phone camera is 50 MP and decoding
/// one at full size to fit it on a phone screen is how an app gets OOM killed.
class _ImageBody extends StatefulWidget {
  const _ImageBody({required this.file});
  final File file;

  @override
  State<_ImageBody> createState() => _ImageBodyState();
}

class _ImageBodyState extends State<_ImageBody> {
  /// A photo off a phone camera is 50 MP. Decoding one at full size to fit it on
  /// a phone screen is how an app gets killed for memory, so the decode is
  /// capped and the bytes are re-decoded by Image.memory at the display size.
  static const int _maxBytes = 20 * 1024 * 1024;

  Uint8List? _bytes;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (await widget.file.length() > _maxBytes) {
        if (mounted) setState(() => _error = context.l.wsPreviewTooBig);
        return;
      }
      final bytes = await widget.file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      // read only to prove it decodes at all, so it goes back rather than being
      // held alongside the Image.memory below, which decodes its own
      frame.image.dispose();
      codec.dispose();
      if (!mounted) return;
      setState(() => _bytes = bytes);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return WsEmpty(icon: Ic.info, title: '$_error');
    final bytes = _bytes;
    if (bytes == null)
      return Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: context.p.subtitle));
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 8,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.memory(
            bytes,
            // scaleDown rather than contain, so a 40x40 png stays 40x40
            // instead of being blown up to fill the screen
            fit: BoxFit.scaleDown,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) =>
                WsEmpty(icon: Ic.image, title: context.l.wsPreviewBinary),
          ),
        ),
      ),
    );
  }
}

/// The size and the name and an offer to copy the path, for a file with nothing
/// to render.
class _BinaryBody extends StatelessWidget {
  const _BinaryBody({required this.file});
  final File file;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final l = context.l;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TgIcon(fileTypeIcon(file.path), color: context.p.icon, size: 48),
          const SizedBox(height: 16),
          Text(l.wsPreviewBinary,
              style: TextStyle(
                  color: p.title,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none)),
          const SizedBox(height: 6),
          Text(path.basename(file.path),
              style: TextStyle(
                  color: p.subtitle,
                  fontSize: 15,
                  decoration: TextDecoration.none)),
          const SizedBox(height: 4),
          FutureBuilder<int>(
            future: file.length(),
            builder: (c, snap) => Text(fileSize(snap.data ?? 0),
                style: TextStyle(
                    color: p.subtitle,
                    fontSize: 14,
                    decoration: TextDecoration.none)),
          ),
          const SizedBox(height: 18),
          TgButton(
              label: l.wsCopyPath,
              onTap: () => copyWithToast(context, file.path, l.wsCopiedPath)),
        ]),
      ),
    );
  }
}

/// markdown and csv render as highlighted text here.
///
/// A separate markdown renderer would be one more dependency for what a model
/// actually produces, which is mostly prose and tables. Html and svg no longer
/// come through here by default: they render through [HtmlSvgView] with a flip
/// back to this view for the raw source.
class _TextBody extends StatelessWidget {
  const _TextBody({required this.file, required this.language});
  final File file;
  final String language;

  @override
  Widget build(BuildContext context) =>
      _SourceView(file: file, language: language, wrap: true);
}

/// The code viewer.
///
/// One paragraph for the whole file with the numbers in a second one beside it.
/// That is what makes a selection cross lines and a copy keep its line breaks;
/// one widget per line cannot be selected across and copies back as one line.
class _CodeBody extends StatefulWidget {
  const _CodeBody({required this.file});
  final File file;

  @override
  State<_CodeBody> createState() => _CodeBodyState();
}

class _CodeBodyState extends State<_CodeBody> {
  bool _wrap = false;
  double _fontSize = 13;

  @override
  Widget build(BuildContext context) => _SourceView(
        file: widget.file,
        language: previewLanguage(widget.file.path),
        wrap: _wrap,
        fontSize: _fontSize,
        // the header is here rather than in the page so it sits directly above
        // the text it controls
        header: Row(children: [
          _sizeButton(Ic.wrap, _wrap, context.l.wsWrap,
              () => setState(() => _wrap = !_wrap)),
          _sizeButton(Ic.minus, false, context.l.wsZoomOut,
              () => setState(() => _fontSize = (_fontSize - 1).clamp(11, 20))),
          _sizeButton(Ic.plus, false, context.l.wsZoomIn,
              () => setState(() => _fontSize = (_fontSize + 1).clamp(11, 20))),
        ]),
      );

  Widget _sizeButton(Ic icon, bool active, String tip, VoidCallback onTap) =>
      TgIconButton(
          icon: icon, size: 20, tooltip: tip, active: active, onTap: onTap);
}

/// The one code layout, used by both text and code bodies.
class _SourceView extends StatefulWidget {
  const _SourceView(
      {required this.file,
      required this.language,
      required this.wrap,
      this.fontSize = 14.5,
      this.header});
  final File file;
  final String? language;
  final bool wrap;
  final double fontSize;
  final Widget? header;

  @override
  State<_SourceView> createState() => _SourceViewState();
}

class _SourceViewState extends State<_SourceView> {
  /// Past either limit the file stops being a document and starts being a
  /// problem: no highlighting, no line numbers, paged reads.
  static const int _richMaxBytes = 256 * 1024;
  static const int _richMaxLines = 4000;

  String? _source;
  String? _error;
  List<String> _lines = const [];
  bool _truncated = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.file.length();
      if (bytes > _richMaxBytes) {
        final text = await widget.file.readAsString();
        final all = text.split('\n');
        if (all.length > _richMaxLines) {
          if (!mounted) return;
          setState(() {
            _lines = all.take(_richMaxLines).toList();
            _truncated = true;
            _error = null;
          });
          return;
        }
      }
      final text = await widget.file.readAsString();
      if (!mounted) return;
      setState(() {
        _source = text;
        _lines = const LineSplitter().convert(text);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    if (_error != null)
      return WsEmpty(
          icon: Ic.info,
          title: '$_error',
          action: TgButton(label: context.l.actionRetry, onTap: _load));
    if (_source == null && _lines.isEmpty) {
      return Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: p.subtitle));
    }
    if (_source == null) {
      // the truncated path: no highlighting because most of it is not here
      return _plain();
    }
    return Column(children: [
      if (widget.header != null)
        Container(
            color: p.bg,
            height: 48,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [widget.header!])),
      Expanded(child: _highlighted()),
    ]);
  }

  Widget _plain() {
    final p = context.p;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _lines.length + (_truncated ? 1 : 0),
      itemBuilder: (c, i) {
        if (i == _lines.length) {
          return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Text(context.l.wsPreviewTruncatedLines(_lines.length),
                  style: TextStyle(
                      color: p.subtitle,
                      fontSize: 13,
                      decoration: TextDecoration.none)));
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
          child: SelectableText('${i + 1}| ${_lines[i]}',
              style: TextStyle(
                  color: p.msg,
                  fontSize: 13,
                  fontFamily: 'monospace',
                  height: 1.35,
                  decoration: TextDecoration.none)),
        );
      },
    );
  }

  Widget _highlighted() {
    final p = context.p;
    final base = TextStyle(
        color: p.msg,
        fontSize: widget.fontSize,
        fontFamily: 'monospace',
        height: 1.35,
        decoration: TextDecoration.none);
    final gutter = base.copyWith(color: p.subtitle, fontSize: widget.fontSize);
    final theme = p.dark ? atomOneDarkTheme : githubTheme;
    final gutterWidth =
        (widget.fontSize * 0.62 * _lines.length.toString().length + 16)
            .clamp(36.0, 72.0);
    // the strut pins every line to the same height, so a line mixing latin and
    // CJK cannot grow taller than the number beside it and drift the columns
    final strut = StrutStyle.fromTextStyle(base, forceStrutHeight: true);
    final source = _lines.join('\n');
    final spans = widget.language == null
        ? [TextSpan(text: source, style: base)]
        : previewSpans(source, widget.language, theme, base);
    final span = TextSpan(style: base, children: spans);

    return LayoutBuilder(
      builder: (context, constraints) {
        final available =
            (constraints.maxWidth - gutterWidth).clamp(0.0, double.infinity);
        final code = Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          child: _column(span, base, strut),
        );
        return SingleChildScrollView(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: gutterWidth,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 24),
                // the numbers take no gesture: a drag over them scrolls the file
                child: IgnorePointer(
                  child: _column(
                    TextSpan(
                      text: gutterLabels(
                          span: span,
                          lines: _lines,
                          strutStyle: strut,
                          textScaler: MediaQuery.textScalerOf(context),
                          wrapWidth: widget.wrap ? available - 24 : null),
                      style: gutter,
                    ),
                    gutter,
                    strut,
                    selectable: false,
                  ),
                ),
              ),
            ),
            if (widget.wrap)
              Expanded(child: code)
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: available),
                      child: code),
                ),
              ),
          ]),
        );
      },
    );
  }

  /// Both columns are SelectableText even though only the code is ever
  /// selected: RenderParagraph and RenderEditable round a forced strut
  /// differently, so a plain Text gutter beside selectable code drifts a pixel
  /// per line, which is a whole line every twenty.
  Widget _column(TextSpan span, TextStyle style, StrutStyle strut,
          {bool selectable = true}) =>
      SelectableText.rich(
        span,
        style: style,
        strutStyle: strut,
        cursorWidth: 2,
        enableInteractiveSelection: selectable,
        scrollPhysics: const NeverScrollableScrollPhysics(),
      );
}
