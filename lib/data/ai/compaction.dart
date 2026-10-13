import 'dart:math';

import 'chain.dart';
import 'content.dart';
import 'errors.dart';
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
];

final _reducePrompt = [
  'Below are partial summaries of the same conversation. Merge them into one coherent summary.',
  'You must preserve character relationships, key events, user preferences and unresolved threads.',
  'Do not editorialize, do not add headings, output only the summary body.',
];

/// The budget is stated in characters because that is the unit the settings
/// row shows, and it is the one a reader can check against the summary itself.
String _budgetRule(int targetChars) => 'Write the summary in the language the conversation is in, and keep the whole thing within $targetChars characters. When something does not fit, drop what no longer matters rather than running long.';

/// The largest transcript one summary request may carry, and the smallest a
/// window this small is allowed to ask for.
const _maxChunkChars = 6000;
const _minChunkChars = 1500;

/// How many recent rows stay verbatim, they carry the live thread.
const _keepTurns = 6;

/// How much transcript one summary request may carry.
///
/// A chunk has to fit the window of the model writing the summary, which is
/// usually the cheap one the settings picked and rarely the same size as the
/// model that was about to overflow. Six thousand characters is the ceiling; a
/// window too small for that gets a proportionally smaller chunk instead of a
/// failed request.
int summaryChunkChars(int contextWindow) {
  if (contextWindow <= 0) return _maxChunkChars;
  final byWindow = (contextWindow * 0.6 * 3.6).floor();
  if (byWindow < _minChunkChars) return _minChunkChars;
  return byWindow > _maxChunkChars ? _maxChunkChars : byWindow;
}

/// Output budget for one summary, in tokens.
///
/// Set at the character count rather than below it: a CJK summary is about one
/// token a character, so it fits, and a latin one is allowed to overshoot the
/// character budget and cut back to it at a sentence boundary by
/// [fitSummaryToBudget]. What the cap is really for is the model that would
/// otherwise write three times the budget.
int summaryTokenBudget(int targetChars) => targetChars < 256 ? 256 : targetChars;

/// Cuts a summary back to its budget at a sentence boundary.
///
/// The prompt asks for the budget and the token cap keeps the answer bounded,
/// but a model that ignores both is not a failure worth losing the reply over:
/// a summary cut at the last full stop reads as a summary, one cut mid sentence
/// reads as a bug.
String fitSummaryToBudget(String text, int targetChars) {
  final clean = text.trim();
  if (targetChars <= 0 || clean.length <= targetChars) return clean;
  var cut = targetChars;
  // a surrogate pair is two code units and both have to stay on the same side
  final edge = clean.codeUnitAt(cut - 1);
  if (edge >= 0xd800 && edge <= 0xdbff) cut--;
  final head = clean.substring(0, cut);
  // the ends of a sentence, with how much of it belongs to the cut
  const stops = [('\n\n', 2), ('\n', 1), ('。', 1), ('！', 1), ('？', 1), ('! ', 2), ('? ', 2), ('. ', 2), ('; ', 2), (': ', 2)];
  var last = 0;
  for (final stop in stops) {
    final at = head.lastIndexOf(stop.$1);
    // the terminator itself belongs to the summary, the space after it does not
    if (at >= 0 && at + stop.$2 > last) last = at + stop.$2;
  }
  // never walk back more than half the budget: a summary that spent itself on
  // one very long sentence would otherwise be cut down to a single word
  if (last < cut ~/ 2) return head.trim();
  return head.substring(0, last).trim();
}

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

/// What one request costs the window, pictures included.
///
/// This walks the assembled turns rather than the text transcript on purpose.
/// The transcript describes a photo as five words, so counting it there prices
/// a window full of pictures at nothing; the turns are what actually goes over
/// the wire, and each [ImagePart] carries the resolution its own cost is
/// derived from. [system] is counted too, because a persona, a world book and
/// a skill listing are the part of the request the transcript never sees.
int estimateRequestTokens(List<ChatTurn> turns, {String system = '', int overheadPerTurn = 4}) {
  var total = system.isEmpty ? 0 : overheadPerTurn + estimateTokens(system);
  for (final turn in turns) {
    var own = 0;
    for (final part in turn.content) {
      own += estimatePartTokens(part);
    }
    total += overheadPerTurn + own;
  }
  return total;
}

bool needsCompaction(List<ChatTurn> turns, int contextWindow, double triggerRatio, {String system = ''}) {
  if (contextWindow <= 0) return false;
  return estimateRequestTokens(turns, system: system) > contextWindow * triggerRatio;
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
  AiCancel? cancel,
}) async {
  var collected = '';
  final outcome = await runChain(
    settings: settings,
    apiKeys: apiKeys,
    system: system,
    messages: [ChatTurn('user', [textPart(prompt)])],
    nodes: [node],
    // the same node keeps one session id so a gateway that routes on it
    // keeps every summary for this model on one warm backend
    options: ChainOptions(sessionId: 'compact:${node.providerId}:${node.modelId}', cancel: cancel, onChunk: (chunk) {
      if (chunk.isText) collected += chunk.delta;
    }, backoffMs: const [800, 1600]),
  );
  if (outcome.error != null) throw outcome.error!;
  return collected.trim();
}

/// Splits [text] in half without cutting a surrogate pair in half, or null
/// when there is nothing left to split.
({String left, String right})? splitHalves(String text) {
  if (text.length < 2) return null;
  var mid = text.length ~/ 2;
  final unit = text.codeUnitAt(mid);
  if (unit >= 0xd800 && unit <= 0xdbff) mid++;
  if (mid <= 0 || mid >= text.length) return null;
  return (left: text.substring(0, mid), right: text.substring(mid));
}

/// Summarises [text], halving it and trying again when the summary model's own
/// window cannot take it.
///
/// Ported from kelivo's `summarizeWithContextRetry`. The window that matters
/// here is the summariser's, which is usually the small cheap model the settings
/// picked for the job, so the exact chunk the chat model would have carried is
/// the one this fails on; without the split that failure is invisible, because
/// nothing was visible yet when compaction ran. Every other error rethrows: a
/// summary that did not fit is worth retrying, one that was refused is not.
///
/// [merge] writes the two halves back into one, which is the same call the
/// multi chunk path already makes.
Future<String> summarizeWithContextRetry(
  String text, {
  required Future<String> Function(String text) summarize,
  required Future<String> Function(String text) merge,
  int maxSplits = 5,
  int minSplitChars = 512,
  AiCancel? cancel,
}) =>
    _summarizeSplitting(text, summarize: summarize, merge: merge, splitsLeft: maxSplits, minSplitChars: minSplitChars, cancel: cancel);

Future<String> _summarizeSplitting(
  String text, {
  required Future<String> Function(String text) summarize,
  required Future<String> Function(String text) merge,
  required int splitsLeft,
  required int minSplitChars,
  AiCancel? cancel,
}) async {
  try {
    return await summarize(text);
  } catch (e) {
    if (toAiError(e).kind != AiErrorKind.contextOverflow || splitsLeft <= 0) rethrow;
    if (cancel?.cancelled ?? false) rethrow;
    final halves = splitHalves(text);
    if (halves == null || halves.left.length < minSplitChars || halves.right.length < minSplitChars) rethrow;
    final left = await _summarizeSplitting(halves.left, summarize: summarize, merge: merge, splitsLeft: splitsLeft - 1, minSplitChars: minSplitChars, cancel: cancel);
    final right = await _summarizeSplitting(halves.right, summarize: summarize, merge: merge, splitsLeft: splitsLeft - 1, minSplitChars: minSplitChars, cancel: cancel);
    // the join is shorter than what failed, but it goes back through the same
    // path because a model with a small window can still refuse the pair
    return _summarizeSplitting('$left\n\n$right', summarize: merge, merge: merge, splitsLeft: splitsLeft - 1, minSplitChars: minSplitChars, cancel: cancel);
  }
}

Future<Compaction> compactHistory({
  required AiSettings settings,
  required Map<String, String> apiKeys,
  required String system,
  required List<HistoryItem> history,
  required Compaction? previous,
  required ChainNode node,
  required int targetChars,
  AiCancel? cancel,
}) async {
  final cutIndex = previous == null ? -1 : history.indexWhere((m) => m.id == previous.upToMessageId);
  final start = cutIndex >= 0 ? cutIndex : 0;
  // keep the recent turns verbatim, they carry the live thread
  final end = max(start, history.length - _keepTurns);
  final target = history.sublist(start, end);
  if (target.isEmpty) throw StateError('There is no history worth compacting');

  final parts = _chunk(target, summaryChunkChars(contextWindowOf(settings, node)));

  // the summary model answers inside its own budget, whatever the chat model
  // was configured for
  final bounded = settings.copyWith(maxOutput: summaryTokenBudget(targetChars));
  Future<String> summarize(String text) => _summarizeOnce(settings: bounded, apiKeys: apiKeys, system: system, node: node, cancel: cancel, prompt: '${[..._mapPrompt, _budgetRule(targetChars)].join('\n')}\n\n${text}');
  Future<String> merge(String text) => _summarizeOnce(settings: bounded, apiKeys: apiKeys, system: system, node: node, cancel: cancel, prompt: '${[..._reducePrompt, _budgetRule(targetChars)].join('\n')}\n\n$text');

  String summary;
  if (parts.length == 1) {
    summary = await summarizeWithContextRetry(_transcript(parts.single), summarize: summarize, merge: merge, cancel: cancel);
  } else {
    // long histories are summarized in bounded chunks then merged
    final partials = <String>[];
    for (final part in parts) {
      partials.add(await summarizeWithContextRetry(_transcript(part), summarize: summarize, merge: merge, cancel: cancel));
    }
    final joined = partials.asMap().entries.map((e) => '[Part ${e.key + 1}]${e.value}').join('\n\n');
    summary = await summarizeWithContextRetry(joined, summarize: merge, merge: merge, cancel: cancel);
  }
  summary = fitSummaryToBudget(summary, targetChars);

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

/// What one compaction run cost and produced.
///
/// Nothing in the app shows this on its own: compaction happens where the user
/// sees nothing, which is why the summary length it was configured with had
/// nothing to show either. The test screen renders this one run, in the same
/// numbers a reply would have paid.
class CompactionReport {
  const CompactionReport({
    required this.chatId,
    required this.ok,
    required this.beforeTokens,
    required this.afterTokens,
    required this.beforeChars,
    required this.afterChars,
    required this.summaryChars,
    required this.summaryTokens,
    required this.targetChars,
    required this.folded,
    required this.kept,
    required this.model,
    required this.contextWindow,
    required this.wouldFire,
    required this.ms,
    this.summary = '',
    this.error,
  });

  final String chatId;
  final bool ok;
  final Object? error;

  /// What the request looked like before and after, tokens the app counts
  final int beforeTokens;
  final int afterTokens;
  final int beforeChars;
  final int afterChars;

  final int summaryChars;
  final int summaryTokens;
  final int targetChars;

  /// how many transcript rows the summary swallowed, and how many stayed
  final int folded;
  final int kept;

  final String model;
  final int contextWindow;

  /// whether this chat was already over the trigger before the run, which is
  /// the answer to "why did it not compact on its own"
  final bool wouldFire;
  final int ms;
  final String summary;
}

// guaranteed backstop when compaction is off or failed
// hysteresis keeps the cut point still instead of moving every turn
List<ChatTurn> truncateHistory(List<ChatTurn> turns, int contextWindow, {double keepRatio = 0.5}) {
  if (contextWindow <= 0) return turns;
  if (estimateRequestTokens(turns) <= contextWindow * 0.9) return turns;
  final targetCount = max(4, (turns.length * keepRatio).round());
  // do not orphan a reply from its question
  var cut = max(0, turns.length - targetCount);
  while (cut > 0 && turns[cut].role == 'assistant') {
    cut--;
  }
  return turns.sublist(cut);
}