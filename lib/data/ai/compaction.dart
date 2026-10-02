import 'dart:math';

import 'chain.dart';
import 'content.dart';
import 'provider_model.dart';
import 'tokenizer.dart';
import 'adapter.dart';

class HistoryItem {
  const HistoryItem({required this.id, required this.role, required this.content});
  final String id;

  // 'user' | 'assistant' | 'system'
  final String role;
  final String content;
}

class Compaction {
  const Compaction({required this.summary, required this.upToMessageId, required this.reasoningDigest, required this.createdAt});

  final String summary;
  final String upToMessageId;
  final String reasoningDigest;
  final int createdAt;

  Map<String, dynamic> toJson() => {'summary': summary, 'upToMessageId': upToMessageId, 'reasoningDigest': reasoningDigest, 'createdAt': createdAt};

  static Compaction fromJson(Map<String, dynamic> j) => Compaction(
        summary: j['summary'] as String? ?? '',
        upToMessageId: j['upToMessageId'] as String? ?? '',
        reasoningDigest: j['reasoningDigest'] as String? ?? '',
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
      );
}

const _summaryHeader = 'Below is a compressed summary of your earlier conversation with the user. Use it to stay consistent in character and keep the story continuous:';

final _mapPrompt = [
  'Compress the following chat transcript into one coherent summary.',
  'You must preserve: character relationships, key events that already happened, preferences and forms of address the user explicitly stated, and any unresolved threads.',
  'Do not editorialize, do not add headings, output only the summary body.',
].join('\n');

final _reducePrompt = [
  'Below are partial summaries of the same conversation. Merge them into one coherent summary.',
  'You must preserve character relationships, key events, user preferences and unresolved threads.',
  'Do not editorialize, do not add headings, output only the summary body.',
].join('\n');

const _chunkChars = 6000;
const _keepTurns = 6;

// the visible transcript stays whole
// the provider only ever sees the checkpoint plus the tail after it
List<ChatTurn> assembleTurns(List<HistoryItem> history, Compaction? checkpoint) {
  final cutIndex = checkpoint == null ? -1 : history.indexWhere((m) => m.id == checkpoint.upToMessageId);
  final tail = cutIndex >= 0 ? history.sublist(cutIndex) : history;
  final turns = <ChatTurn>[];
  final summary = checkpoint?.summary.trim() ?? '';
  if (summary.isNotEmpty) {
    turns.add(ChatTurn('user', [textPart('$_summaryHeader\n$summary')]));
  }
  for (final item in tail) {
    if (item.role == 'system') continue;
    turns.add(ChatTurn(item.role == 'user' ? 'user' : 'assistant', [textPart(item.content)], sourceId: item.id));
  }
  return turns;
}

int estimateHistoryTokens(List<HistoryItem> history) {
  var total = 0;
  for (final item in history) {
    total += 4 + estimateTokens(item.content);
  }
  return total;
}

bool needsCompaction(List<HistoryItem> history, int contextWindow, double triggerRatio) {
  if (contextWindow <= 0) return false;
  return estimateHistoryTokens(history) > contextWindow * triggerRatio;
}

List<List<HistoryItem>> _chunk(List<HistoryItem> items, int size) {
  final chunks = <List<HistoryItem>>[];
  var current = <HistoryItem>[];
  var chars = 0;
  for (final item in items) {
    final length = item.content.length;
    if (current.isNotEmpty && chars + length > size) {
      chunks.add(current);
      current = <HistoryItem>[];
      chars = 0;
    }
    current.add(item);
    chars += length;
  }
  if (current.isNotEmpty) chunks.add(current);
  return chunks;
}

String _transcript(List<HistoryItem> items) => items
    .map((item) => '${item.role == 'user' ? 'User' : 'Assistant'}: ${item.content}')
    .join('\n');

Future<String> _summarizeOnce({
  required AiSettings settings,
  required Map<String, String> apiKeys,
  required String system,
  required ChainNode node,
  required String prompt,
}) async {
  var collected = '';
  final outcome = await runChain(
    settings: settings,
    apiKeys: apiKeys,
    system: system,
    messages: [ChatTurn('user', [textPart(prompt)])],
    nodes: [node],
    options: ChainOptions(onChunk: (chunk) {
      if (chunk.isText) collected += chunk.delta;
    }, backoffMs: const [800, 1600]),
  );
  if (outcome.error != null) throw outcome.error!;
  return collected.trim();
}

Future<Compaction> compactHistory({
  required AiSettings settings,
  required Map<String, String> apiKeys,
  required String system,
  required List<HistoryItem> history,
  required Compaction? previous,
  required ChainNode node,
}) async {
  final cutIndex = previous == null ? -1 : history.indexWhere((m) => m.id == previous.upToMessageId);
  final start = cutIndex >= 0 ? cutIndex : 0;
  // keep the recent turns verbatim, they carry the live thread
  final end = max(start, history.length - _keepTurns);
  final target = history.sublist(start, end);
  if (target.isEmpty) throw StateError('There is no history worth compacting');

  final parts = _chunk(target, _chunkChars);

  String summary;
  if (parts.length == 1) {
    summary = await _summarizeOnce(settings: settings, apiKeys: apiKeys, system: system, node: node, prompt: '$_mapPrompt\n\n${_transcript(parts[0])}');
  } else {
    // long histories are summarized in bounded chunks then merged
    final partials = <String>[];
    for (final part in parts) {
      partials.add(await _summarizeOnce(settings: settings, apiKeys: apiKeys, system: system, node: node, prompt: '$_mapPrompt\n\n${_transcript(part)}'));
    }
    final merged = partials.asMap().entries.map((e) => '[Part ${e.key + 1}]${e.value}').join('\n\n');
    summary = await _summarizeOnce(settings: settings, apiKeys: apiKeys, system: system, node: node, prompt: '$_reducePrompt\n\n$merged');
  }

  final digest = target
      .where((item) => item.role == 'assistant' && item.content.isNotEmpty)
      .toList()
      .reversed
      .take(4)
      .map((item) => item.content.length > 160 ? item.content.substring(0, 160) : item.content)
      .toList()
      .reversed
      .join('\n');

  return Compaction(
    summary: summary.isEmpty ? '(earlier conversation compacted)' : summary,
    upToMessageId: target.last.id,
    reasoningDigest: digest,
    createdAt: DateTime.now().millisecondsSinceEpoch,
  );
}

// guaranteed backstop when compaction is off or failed
// hysteresis keeps the cut point still instead of moving every turn
List<ChatTurn> truncateHistory(List<ChatTurn> turns, int contextWindow, {double keepRatio = 0.5}) {
  if (contextWindow <= 0) return turns;
  var total = 0;
  for (final turn in turns) {
    total += 4 + estimateTokens(partsToText(turn.content));
  }
  if (total <= contextWindow * 0.9) return turns;
  final targetCount = max(4, (turns.length * keepRatio).round());
  // do not orphan a reply from its question
  var cut = max(0, turns.length - targetCount);
  while (cut > 0 && turns[cut].role == 'assistant') {
    cut--;
  }
  return turns.sublist(cut);
}