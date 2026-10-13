import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/ai/adapter.dart';
import 'package:paradise/data/ai/adapters.dart';
import 'package:paradise/data/ai/compaction.dart';
import 'package:paradise/data/ai/content.dart';
import 'package:paradise/data/ai/errors.dart';
import 'package:paradise/data/ai/provider_model.dart';

/// The summary length setting used to be read by nothing: the prompts never
/// mentioned a budget and nothing capped the answer, so a "1200 char" summary
/// was whatever the model felt like writing. These pin the three things that
/// make it mean something, plus the retry that stops a small summariser from
/// failing a compaction silently.

/// Answers with whatever the test hands it, which is where a summariser that
/// refuses an oversized chunk is scripted.
class _Summarizer implements ProviderAdapter {
  _Summarizer(this.reply);

  final String Function(String prompt) reply;

  final prompts = <String>[];
  final seenMaxOutput = <int>[];

  @override
  Stream<StreamChunk> stream(StreamRequest req) async* {
    final prompt = (req.messages.first.content.first as TextPart).text;
    prompts.add(prompt);
    seenMaxOutput.add(req.maxOutput);
    yield StreamChunk.text(reply(prompt));
  }
}

AiSettings _settings({ChainNode? node, int maxOutput = 0, int contextWindow = 32000, CompactionSettings compaction = const CompactionSettings()}) => AiSettings(
      providers: [
        Provider.defaults(id: 'p1', name: 'P1', models: [ModelMeta(id: 'm1', name: 'm1', contextWindow: contextWindow, maxOutput: 4096, vision: false, textToImage: false, reasoning: false, source: ModelSource.manual, video: false)]),
      ],
      chain: [node ?? const ChainNode(id: 'n1', providerId: 'p1', modelId: 'm1', retries: 0, enabled: true)],
      replyMode: ReplyMode.full,
      temperature: 1,
      maxOutput: maxOutput,
      firstBubbleDelayMs: 0,
      bubbleGapScale: 1,
      pacingJitter: 0.35,
      stripMarkdownInCharacterMode: false,
      compaction: compaction,
    );

const _node = ChainNode(id: 'n1', providerId: 'p1', modelId: 'm1', retries: 0, enabled: true);

List<HistoryItem> _history(int n, {String body = 'a line of conversation that happened once'}) =>
    List.generate(n, (i) => HistoryItem(id: 'm$i', role: i.isEven ? 'user' : 'assistant', content: '$body $i'));

Future<Compaction> _compact(_Summarizer fake, {List<HistoryItem>? history, int targetChars = 1200, CompactionSettings compaction = const CompactionSettings(), AiSettings? settings}) async {
  adapterOverride = (kind) => fake;
  return compactHistory(
    settings: settings ?? _settings(compaction: compaction),
    apiKeys: {'p1': 'k1'},
    system: 'sys',
    history: history ?? _history(20),
    previous: null,
    node: _node,
    targetChars: targetChars,
  );
}

void main() {
  tearDown(() => adapterOverride = null);

  group('summary budget', () {
    test('a summary inside the budget is left alone', () {
      expect(fitSummaryToBudget('short enough', 1200), 'short enough');
      expect(fitSummaryToBudget('  padded  ', 1200), 'padded');
    });

    test('an over budget summary is cut at a sentence, not mid sentence', () {
      final text = 'They met on a train. Then they argued about the window seat. Then they made up near the coast.';
      final cut = fitSummaryToBudget(text, 60);
      expect(cut.length, lessThanOrEqualTo(60));
      expect(cut.endsWith('.'), isTrue, reason: 'the cut has to land on a full stop');
      // whatever was dropped was a whole sentence, not the middle of one
      expect(text.substring(cut.length, cut.length + 1), ' ', reason: 'the cut consumed exactly one terminator');
      expect(cut, contains('window seat'), reason: 'the first full sentences are the ones that fit');
    });

    test('cjk stops are cut on too', () {
      final text = '他们在火车上相遇。然后因为靠窗的位置吵了一架。然后在海岸附近和好了。';
      final cut = fitSummaryToBudget(text, 30);
      expect(cut.length, lessThanOrEqualTo(30));
      expect(cut.endsWith('。'), isTrue);
      expect(cut, '他们在火车上相遇。然后因为靠窗的位置吵了一架。');
    });

    test('a run of short lines still yields a summary rather than nothing', () {
      final cut = fitSummaryToBudget(List.generate(60, (i) => 'line $i').join('\n'), 40);
      expect(cut.length, greaterThan(20), reason: 'never walk back more than half the budget');
    });

    test('the cut never lands between the halves of an emoji', () {
      final text = '${'字' * 100}${List.filled(20, '🎈').join()}';
      for (final budget in [12, 13, 40, 101, 119]) {
        final cut = fitSummaryToBudget(text, budget);
        expect(cut.runes.every((r) => r != 0xFFFD), isTrue, reason: 'a lone surrogate becomes a replacement char at budget $budget');
      }
    });

    test('the output cap follows the budget but never drops under a floor', () {
      expect(summaryTokenBudget(1200), 1200);
      expect(summaryTokenBudget(10), 256, reason: 'a floor a model cannot answer under');
    });

    test('a chunk follows the window of the model writing the summary', () {
      expect(summaryChunkChars(0), 6000, reason: 'an unknown window gets the ceiling');
      expect(summaryChunkChars(200000), 6000);
      expect(summaryChunkChars(2000), lessThan(6000), reason: 'a small window gets a smaller chunk');
      expect(summaryChunkChars(200), 1500, reason: 'and never smaller than a workable chunk');
    });
  });

  group('summarize with context retry', () {
    test('an oversized transcript is halved until it fits', () async {
      final sizes = <int>[];
      final out = await summarizeWithContextRetry(
        'x' * 4000,
        summarize: (t) async {
          sizes.add(t.length);
          if (t.length > 2000) throw AiError(AiErrorKind.contextOverflow, 'maximum context length', 400);
          return 'summary of ${t.length}';
        },
        merge: (t) async => 'merged ${t.length}',
      );
      expect(sizes.first, 4000);
      expect(out, contains('merged'), reason: 'the halves come back through the merge step');
    });

    test('a refusal that is not an overflow is not retried', () async {
      var calls = 0;
      await expectLater(
        summarizeWithContextRetry('x' * 4000, summarize: (t) async {
          calls++;
          throw AiError(AiErrorKind.auth, 'no key', 401);
        }, merge: (t) async => 'never'),
        throwsA(isA<AiError>()),
      );
      expect(calls, 1);
    });

    test('the splitting gives up rather than cutting forever', () async {
      var calls = 0;
      await expectLater(
        summarizeWithContextRetry('x' * 4000, maxSplits: 2, minSplitChars: 10, summarize: (t) async {
          calls++;
          throw AiError(AiErrorKind.contextOverflow, 'too long', 400);
        }, merge: (t) async => 'never'),
        throwsA(isA<AiError>()),
      );
      expect(calls, 3, reason: 'the first attempt plus one per split');
    });

    test('a cancelled run does not split its way through the transcript', () async {
      final cancel = AiCancel();
      cancel.cancel();
      var calls = 0;
      await expectLater(
        summarizeWithContextRetry(
          'x' * 4000,
          cancel: cancel,
          summarize: (t) async {
            calls++;
            throw AiError(AiErrorKind.contextOverflow, 'maximum context length', 400);
          },
          merge: (t) async => 'never',
        ),
        throwsA(isA<AiError>()),
      );
      expect(calls, 1, reason: 'halving the text after the user pressed stop would keep the run alive');
    });
  });

  group('compactHistory', () {
    test('the prompt states the budget and the answer is capped to it', () async {
      final long = List.generate(80, (i) => 'Sentence number $i about the trip.').join(' ');
      final fake = _Summarizer((_) => long);
      final result = await _compact(fake, targetChars: 300);
      expect(fake.prompts.first, contains('within 300 characters'), reason: 'the budget has to reach the model');
      expect(result.summary.length, lessThanOrEqualTo(300));
      expect(fake.seenMaxOutput.first, 300, reason: 'and the output is capped so it cannot run away');
    });

    test('a model that ignores the budget still leaves a whole sentence', () async {
      final long = List.generate(200, (i) => 'Another point about the trip, number $i. ').join('');
      final result = await _compact(_Summarizer((_) => long), targetChars: 200);
      expect(result.summary.length, lessThanOrEqualTo(200));
      expect(result.summary.endsWith('.'), isTrue);
    });

    test('the checkpoint names the last row it swallowed and keeps the tail', () async {
      final result = await _compact(_Summarizer((_) => 'a summary'));
      expect(result.summary, 'a summary');
      expect(result.upToMessageId, 'm13', reason: 'the six newest rows stay verbatim');
    });

    test('a long transcript is chunked and merged back into one summary', () async {
      final fake = _Summarizer((prompt) => prompt.contains('partial summaries') ? 'the merged one' : 'one part');
      final history = _history(60, body: 'x' * 900);
      final result = await _compact(fake, history: history, targetChars: 400);
      expect(fake.prompts.length, greaterThan(2), reason: 'more than one chunk went out');
      expect(fake.prompts.where((p) => p.contains('partial summaries')), isNotEmpty, reason: 'and they came back through the merge prompt');
      expect(result.summary, 'the merged one');
    });

    test('a summariser with a small window splits the chunk rather than failing', () async {
      final fake = _Summarizer((prompt) {
        if (prompt.length > 3000) throw AiError(AiErrorKind.contextOverflow, 'maximum context length', 400);
        return 'summary';
      });
      final history = _history(40, body: 'y' * 400);
      final result = await _compact(fake, history: history, targetChars: 400);
      expect(result.summary, 'summary');
      expect(fake.prompts.length, greaterThan(4), reason: 'the chunks that did not fit came back in pieces instead of failing the whole compaction');
    });

    test('a failure reaches the caller instead of an empty checkpoint', () async {
      final fake = _Summarizer((_) => throw AiError(AiErrorKind.auth, 'no key', 401));
      await expectLater(_compact(fake), throwsA(isA<AiError>()));
    });

    test('there is nothing to compact in a short chat', () async {
      await expectLater(_compact(_Summarizer((_) => 'x'), history: _history(3)), throwsA(isA<StateError>()));
    });
  });
}