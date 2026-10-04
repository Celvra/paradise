import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../core/anim.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../data/workspace/workspace_metadata.dart';

/// The body of a trace row for a workspace tool.
///
/// Split from [TraceView] because the two have nothing in common beyond the
/// card they sit in: an MCP row is JSON in and JSON out, a file row is a path,
/// a diff and a chip. Keeping them apart stops the generic panel growing a
/// branch for every tool the workspace ever grows.
///
/// Reads only what is on the row. Nothing here talks to the store, which is
/// what lets the row be laid out in a test with a hand-built message.
class WsTraceBody extends StatelessWidget {
  const WsTraceBody({super.key, required this.meta, required this.result, required this.running, this.onOpenFile});

  final WorkspaceToolMeta meta;

  /// What the model was told. Kept, and shown collapsed, because a refusal is
  /// only half the story without it.
  final String result;

  final bool running;

  /// Opens the preview for a model path. Null when there is nothing to open,
  /// which is the case for a row about a file the app cannot reach.
  final void Function(String modelPath)? onOpenFile;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final mono = TextStyle(color: p.msg, fontSize: 12, height: 1.45, fontFamily: 'monospace', decoration: TextDecoration.none);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (meta.path.isNotEmpty) _pathLine(p, mono),
      if (meta.diff.isNotEmpty) ...[
        const SizedBox(height: 9),
        _counts(p),
        const SizedBox(height: 5),
        _diff(p, mono),
      ] else if (meta.files.length > 1) ...[
        const SizedBox(height: 9),
        _chips(context, p),
      ] else if (meta.bytes > 0 || meta.count > 0 || meta.lines > 0) ...[
        const SizedBox(height: 9),
        _chips(context, p),
      ],
      if (result.isNotEmpty || running) ...[
        const SizedBox(height: 9),
        _tag(p, result.isEmpty ? '…' : result, mono.copyWith(color: meta.status == 'denied' || meta.status == 'error' ? p.danger : p.subtitle)),
      ],
    ]);
  }

  Widget _pathLine(Pal p, TextStyle mono) => Row(children: [
        TgIcon(meta.created ? Ic.plus : Ic.file, color: p.subtitle, size: 13),
        const SizedBox(width: 6),
        Expanded(child: Text(meta.path, maxLines: 2, style: mono.copyWith(color: p.subtitle, fontSize: 11.5))),
      ]);

  Widget _counts(Pal p) => Row(children: [
        if (meta.added != 0) Text('+${meta.added}', style: TextStyle(color: const Color(0xFF3FB950), fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace', decoration: TextDecoration.none)),
        if (meta.added != 0 && meta.removed != 0) const SizedBox(width: 10),
        if (meta.removed != 0) Text('−${meta.removed}', style: TextStyle(color: const Color(0xFFE5534B), fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace', decoration: TextDecoration.none)),
        if (meta.strategy.isNotEmpty && meta.strategy != 'exact') ...[
          const SizedBox(width: 10),
          Text(meta.strategy, style: TextStyle(color: p.subtitle, fontSize: 11.5, decoration: TextDecoration.none)),
        ],
      ]);

  Widget _diff(Pal p, TextStyle mono) {
    final lines = [
      for (final l in const LineSplitter().convert(meta.diff))
        if (!l.startsWith('--- ') && !l.startsWith('+++ ') && !l.startsWith('@@')) l,
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          for (final line in lines)
            Container(
              color: line.startsWith('+')
                  ? const Color(0x263FB950)
                  : (line.startsWith('-') ? const Color(0x26E5534B) : const Color(0x00000000)),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(line, style: mono.copyWith(color: line.startsWith('+') || line.startsWith('-') ? p.title : p.subtitle, fontSize: 11.5)),
            ),
        ]),
      ),
    );
  }

  /// Tappable chips for what the tool touched. Only shown when there is more
  /// than one, or when there is a count to report; a single file is already
  /// named by the path line above and a chip would repeat it.
  Widget _chips(BuildContext context, Pal p) {
    final files = meta.files.take(12).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final f in files)
            Tap(
              onTap: onOpenFile == null ? null : () => onOpenFile!(f.modelPath),
              scale: .94,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 210),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: p.selector.withAlpha(p.dark ? 90 : 60), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  f.modelPath.split('/').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.title, fontSize: 11.5, fontFamily: 'monospace', decoration: TextDecoration.none),
                ),
              ),
            ),
          if (meta.files.length > files.length) _plain('+${meta.files.length - files.length}', p),
          if (meta.truncated) _plain('+', p),
        ],
      ),
      const SizedBox(height: 6),
      _summary(p),
    ]);
  }

  Widget _summary(Pal p) {
    final bits = <String>[
      if (meta.lines > 0) '${meta.lines} lines',
      if (meta.count > 0) '${meta.count} files',
      if (meta.bytes > 0) _bytes(meta.bytes),
    ];
    if (bits.isEmpty) return const SizedBox.shrink();
    return Text(bits.join(' · '), style: TextStyle(color: p.subtitle, fontSize: 11.5, decoration: TextDecoration.none));
  }

  Widget _plain(String text, Pal p) => Text(text, style: TextStyle(color: p.subtitle, fontSize: 11.5, decoration: TextDecoration.none));

  Widget _tag(Pal p, String text, TextStyle style) => Text(text, maxLines: 6, overflow: TextOverflow.ellipsis, style: style);

  static String _bytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  /// The row title for a workspace tool. A raw tool name reads as a log line;
  /// "Write · notes/report.md" reads as what happened.
  static String titleFor(WorkspaceToolMeta meta, String fallback) {
    if (meta.status == 'denied') return 'refused';
    final name = switch (meta.tool) {
      'read_file' => 'Read',
      'write_file' => 'Write',
      'edit_file' => 'Edit',
      'list_dir' => 'List',
      'glob' => 'Find',
      'grep' => 'Search',
      _ => fallback,
    };
    if (meta.path.isEmpty) return name;
    return '$name · ${meta.path.split('/').last}';
  }
}