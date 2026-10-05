import 'dart:io';

import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/anim.dart';
import '../../core/overlays.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../l10n/x.dart';
import 'preview_kind.dart';
import 'workspace_prompts.dart' show WsEmpty;
import 'file_preview_page.dart';

/// Renders one html or svg document: a webview for html, flutter_svg for svg.
///
/// Used by the workspace file preview page and by the in-chat code block
/// preview, so the two places stay one rendering path rather than drifting.
class HtmlSvgView extends StatefulWidget {
  const HtmlSvgView({super.key, required this.kind, required this.source, this.dark, this.backgroundColor});

  /// [PreviewKind.html] goes to the webview, [PreviewKind.image] with svg
  /// content goes to flutter_svg.
  final PreviewKind kind;
  final String source;
  final bool? dark;
  final Color? backgroundColor;

  @override
  State<HtmlSvgView> createState() => _HtmlSvgViewState();
}

class _HtmlSvgViewState extends State<HtmlSvgView> {
  WebViewController? _controller;
  String? _error;

  /// What the live webview was loaded with, so a dependency change that
  /// touches nothing (a palette shade that keeps the same dark flag) does not
  /// reload the page.
  String? _loaded;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // the palette is an inherited dependency and may only be read once the
    // state is mounted into the tree; initState is too early, which is what
    // the framework assertion used to catch here
    _load();
  }

  @override
  void didUpdateWidget(covariant HtmlSvgView old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source || old.kind != widget.kind) _load();
  }

  Future<void> _load() async {
    if (widget.kind == PreviewKind.html) {
      try {
        final dark = widget.dark ?? context.p.dark;
        final key = '$dark|${widget.source.length}|${widget.source.hashCode}';
        if (_controller != null && key == _loaded) return;
        final controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(dark ? const Color(0xFF101418) : const Color(0xFFFFFFFF))
          ..loadHtmlString(wrapDocument(widget.source, dark: dark));
        if (!mounted) return;
        setState(() {
          _controller = controller;
          _loaded = key;
        });
        return;
      } catch (e) {
        if (mounted) setState(() => _error = '$e');
        return;
      }
    }
    // svg: nothing async, the widget below paints it; dropping a stale webview
    // from an earlier source keeps the two kinds from mixing
    _controller = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _failed(context, _error!);
    if (widget.kind == PreviewKind.html) {
      final c = _controller;
      if (c == null) {
        return Center(child: TypingDots(color: context.p.subtitle));
      }
      return WebViewWidget(controller: c);
    }
    return InteractiveViewer(
      maxScale: 8,
      child: Center(
        child: SvgPicture.string(
          widget.source,
          fit: BoxFit.scaleDown,
          placeholderBuilder: (_) => TypingDots(color: context.p.subtitle),
        ),
      ),
    );
  }

  Widget _failed(BuildContext context, String message) => WsEmpty(icon: Ic.info, title: message);
}

/// Wraps a bare fragment in a document with the viewport meta and the palette,
/// so a model's snippet fills the phone screen instead of sitting in the top
/// left corner at desktop width.
String wrapDocument(String body, {required bool dark}) {
  final head = '''
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  html,body{margin:0;padding:0;min-height:100%;}
  body{
    background:${dark ? '#101418' : '#ffffff'};
    color:${dark ? '#e8eaed' : '#1b1b1b'};
    font-family:-apple-system,Roboto,'Segoe UI','PingFang SC','Noto Sans CJK SC',sans-serif;
    padding:14px;
    box-sizing:border-box;
    word-break:break-word;
  }
</style>''';
  final t = body.trimLeft().toLowerCase();
  final full = t.startsWith('<!doctype html') || t.startsWith('<html');
  return full ? body : '<!DOCTYPE html><html><head>$head</head><body>$body</body></html>';
}

/// The preview page for a snippet the chat cites, opened from a code block.
/// The source lives in the message itself, there is no file behind it.
Future<void> showSnippetPreview(BuildContext context, String source, {required PreviewKind kind, String? title}) {
  return Navigator.of(context).push(TgRoute(
    builder: (_) => _SnippetPreviewPage(source: source, kind: kind, title: title),
  ));
}

/// Same page for a file on disk: an svg card the model sent taps through here.
/// The kind is read off the extension, like the workspace preview does.
Future<void> showSnippetPreviewFromFile(BuildContext context, File file) async {
  final kind = previewKindFor(file.path);
  if (kind != PreviewKind.html && kind != PreviewKind.image) {
    await showFilePreview(context, file);
    return;
  }
  final source = await file.readAsString();
  if (!context.mounted) return;
  await showSnippetPreview(context, source, kind: kind == PreviewKind.image ? PreviewKind.image : PreviewKind.html, title: file.path.split('/').last);
}

class _SnippetPreviewPage extends StatefulWidget {
  const _SnippetPreviewPage({required this.source, required this.kind, this.title});
  final String source;
  final PreviewKind kind;
  final String? title;

  @override
  State<_SnippetPreviewPage> createState() => _SnippetPreviewPageState();
}

class _SnippetPreviewPageState extends State<_SnippetPreviewPage> {
  /// Rendered first; the reader can flip to the raw source and back.
  bool _source = false;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final mq = MediaQuery.of(context);
    final l = context.l;
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
                        child: Center(child: TgIcon(Ic.back, color: p.icon, size: 24)))),
                Expanded(
                    child: Text(widget.title ?? l.codePreview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: p.title,
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none))),
                Tap(
                    scale: .88,
                    onTap: () => setState(() => _source = !_source),
                    child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Center(
                            child: TgIcon(_source ? Ic.eye : Ic.fileCode,
                                color: p.icon, size: 20)))),
              ]),
            ),
          ),
          Container(height: .5, color: p.divider),
          Expanded(
            child: _source
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: SelectableText(
                      widget.source,
                      style: TextStyle(
                          color: p.msg,
                          fontSize: 13,
                          fontFamily: 'monospace',
                          height: 1.4,
                          decoration: TextDecoration.none),
                    ),
                  )
                : HtmlSvgView(kind: widget.kind, source: widget.source),
          ),
        ]),
      ),
    );
  }
}
