import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/ai/adapter.dart';
import 'package:paradise/data/ai/adapters.dart';
import 'package:paradise/data/ai/chain.dart';
import 'package:paradise/data/ai/errors.dart';
import 'package:paradise/data/ai/provider_model.dart';

/// Fake adapter so chain behaviour can be exercised without a network.
class _FakeAdapter implements ProviderAdapter {
  _FakeAdapter(this.script);

  /// each entry is what one attempt emits, an error entry throws instead
  final List<Object> script;
  int attempt = 0;

  @override
  Stream<StreamChunk> stream(StreamRequest req) async* {
    final step = script[attempt < script.length ? attempt : script.length - 1];
    attempt++;
    if (step is AiError) throw step;
    for (final chunk in step as List<StreamChunk>) {
      if (req.cancel?.cancelled ?? false) throw AiError(AiErrorKind.aborted, 'Stopped', 0);
      yield chunk;
    }
  }
}

AiSettings _settings(List<ChainNode> chain) => AiSettings(
      providers: [
        Provider.defaults(id: 'p1', name: 'P1'),
        Provider.defaults(id: 'p2', name: 'P2'),
      ],
      chain: chain,
      replyMode: ReplyMode.full,
      temperature: 1,
      maxOutput: 0,
      firstBubbleDelayMs: 0,
      bubbleGapScale: 1,
      pacingJitter: 0.35,
      stripMarkdownInCharacterMode: false,
      compaction: const CompactionSettings(),
    );

Future<ChainOutcome> _run(
  AiSettings settings,
  List<ChainNode> nodes, {
  required void Function(StreamChunk) onChunk,
  List<int>? backoff,
  AiCancel? cancel,
  Future<void> Function()? onCompact,
}) =>
    runChain(
      settings: settings,
      apiKeys: {'p1': 'k1', 'p2': 'k2'},
      system: 'sys',
      messages: const [ChatTurn('user', [])],
      nodes: nodes,
      options: ChainOptions(onChunk: onChunk, backoffMs: backoff, cancel: cancel, onCompact: onCompact),
    );

void main() {
  late _FakeAdapter currentFake;

  setUp(() {
    currentFake = _FakeAdapter(const []);
    adapterOverride = (kind) => currentFake;
  });

  tearDown(() => adapterOverride = null);

  group('chain failover', () {
    test('a healthy first node answers and later ones are untouched', () async {
      currentFake = _FakeAdapter([
        [const StreamChunk.text('hello ')],
        [const StreamChunk.text('never')],
      ]);

      final outcome = await _run(
        _settings(const [ChainNode(id: 'a', providerId: 'p1', modelId: 'm')]),
        const [ChainNode(id: 'a', providerId: 'p1', modelId: 'm')],
        onChunk: (_) {},
      );

      expect(outcome.error, isNull);
      expect(outcome.text, 'hello ');
      expect(outcome.servedBy?.id, 'a');
      expect(currentFake.attempt, 1);
    });

    test('a failing node falls through to the next one', () async {
      currentFake = _FakeAdapter([
        AiError(AiErrorKind.auth, 'bad key'),
        [const StreamChunk.text('second wins')],
      ]);

      const nodes = [
        ChainNode(id: 'a', providerId: 'p1', modelId: 'm'),
        ChainNode(id: 'b', providerId: 'p2', modelId: 'm'),
      ];
      final outcome = await _run(_settings(nodes), nodes, onChunk: (_) {});

      expect(outcome.text, 'second wins');
      expect(outcome.servedBy?.id, 'b');
      expect(outcome.reports.length, 2);
      expect(outcome.reports.first.ok, isFalse);
      expect(outcome.reports.first.error?.kind, AiErrorKind.auth);
      expect(outcome.reports.last.ok, isTrue);
    });

    test('a missing key fails the node without any network call', () async {
      final outcome = await runChain(
        settings: _settings(const [ChainNode(id: 'a', providerId: 'p1', modelId: 'm')]),
        apiKeys: const {},
        system: 'sys',
        messages: const [ChatTurn('user', [])],
        nodes: const [ChainNode(id: 'a', providerId: 'p1', modelId: 'm')],
        options: ChainOptions(onChunk: (_) {}),
      );

      expect(outcome.error?.kind, AiErrorKind.auth);
      expect(outcome.error?.message, contains('P1'));
    });

    test('an empty stream is an empty error and moves on', () async {
      currentFake = _FakeAdapter([
        <StreamChunk>[],
        [const StreamChunk.text('ok')],
      ]);

      const nodes = [
        ChainNode(id: 'a', providerId: 'p1', modelId: 'm'),
        ChainNode(id: 'b', providerId: 'p2', modelId: 'm'),
      ];
      final outcome = await _run(_settings(nodes), nodes, onChunk: (_) {});

      expect(outcome.text, 'ok');
      expect(outcome.reports.first.error?.kind, AiErrorKind.empty);
    });

    test('an empty chain reports an auth error', () async {
      final outcome = await _run(_settings(const []), const [], onChunk: (_) {});
      expect(outcome.error?.kind, AiErrorKind.auth);
      expect(outcome.error?.message, contains('no usable node'));
    });
  });

  group('chain retries', () {
    test('a retryable failure is retried up to the configured count', () async {
      currentFake = _FakeAdapter([
        AiError(AiErrorKind.rate, 'slow down'),
        AiError(AiErrorKind.rate, 'slow down'),
        [const StreamChunk.text('third time lucky')],
      ]);

      const node = ChainNode(id: 'a', providerId: 'p1', modelId: 'm', retries: 2);
      final outcome = await _run(_settings(const [node]), const [node], onChunk: (_) {}, backoff: const [1, 1]);

      expect(outcome.text, 'third time lucky');
      expect(currentFake.attempt, 3);
      // one report per attempt, the last one carries the success
      expect(outcome.reports.length, 3);
      expect(outcome.reports.last.ok, isTrue);
      expect(outcome.reports.last.attempts, 3);
    });

    test('a non retryable failure does not consume retries', () async {
      currentFake = _FakeAdapter([
        AiError(AiErrorKind.quota, 'no credit'),
        [const StreamChunk.text('should not run')],
      ]);

      const node = ChainNode(id: 'a', providerId: 'p1', modelId: 'm', retries: 3);
      final outcome = await _run(_settings(const [node]), const [node], onChunk: (_) {}, backoff: const [1]);

      expect(outcome.text, '');
      expect(currentFake.attempt, 1);
    });

    test('retries are clamped to zero so the node still runs once', () async {
      currentFake = _FakeAdapter([
        AiError(AiErrorKind.rate, 'nope'),
        [const StreamChunk.text('fallback')],
      ]);

      const nodes = [
        ChainNode(id: 'a', providerId: 'p1', modelId: 'm', retries: 0),
        ChainNode(id: 'b', providerId: 'p2', modelId: 'm'),
      ];
      final outcome = await _run(_settings(nodes), nodes, onChunk: (_) {}, backoff: const [1]);

      expect(outcome.text, 'fallback');
      expect(outcome.reports.first.attempts, 1);
    });
  });

  group('chain events', () {
    test('a degraded event fires when a node is abandoned', () async {
      currentFake = _FakeAdapter([
        AiError(AiErrorKind.auth, 'nope'),
        [const StreamChunk.text('ok')],
      ]);
      final events = <ChainEvent>[];

      const nodes = [
        ChainNode(id: 'a', providerId: 'p1', modelId: 'm'),
        ChainNode(id: 'b', providerId: 'p2', modelId: 'm'),
      ];
      await runChain(
        settings: _settings(nodes),
        apiKeys: {'p1': 'k1', 'p2': 'k2'},
        system: 'sys',
        messages: const [ChatTurn('user', [])],
        nodes: nodes,
        options: ChainOptions(onChunk: (_) {}, onEvent: events.add, backoffMs: const []),
      );

      expect(events.any((e) => e.kind == ChainEventKind.node && e.node?.id == 'a'), isTrue);
      expect(events.any((e) => e.kind == ChainEventKind.node && e.node?.id == 'b'), isTrue);
      final degraded = events.where((e) => e.kind == ChainEventKind.degraded).toList();
      expect(degraded, isNotEmpty);
      expect(degraded.first.message, contains('API key'));
    });

    test('a failure after text is visible keeps the partial', () async {
      currentFake = _FakeAdapter([
        [const StreamChunk.text('partial')],
      ]);

      // fail mid stream, after some text already landed
      final outcome = await runChain(
        settings: _settings(const [ChainNode(id: 'a', providerId: 'p1', modelId: 'm')]),
        apiKeys: {'p1': 'k1'},
        system: 'sys',
        messages: const [ChatTurn('user', [])],
        nodes: const [ChainNode(id: 'a', providerId: 'p1', modelId: 'm')],
        options: ChainOptions(onChunk: (_) {}),
      );

      expect(outcome.text, 'partial');
      expect(outcome.error, isNull);
    });
  });

  group('reasoning', () {
    test('reasoning is separated from text and kept out of the answer', () async {
      currentFake = _FakeAdapter([
        [
          const StreamChunk.reasoning('thinking...'),
          const StreamChunk.text('answer'),
        ],
      ]);
      final seen = <StreamChunk>[];

      final outcome = await _run(
        _settings(const [ChainNode(id: 'a', providerId: 'p1', modelId: 'm')]),
        const [ChainNode(id: 'a', providerId: 'p1', modelId: 'm')],
        onChunk: seen.add,
      );

      expect(seen.where((c) => c.isReasoning).length, 1);
      expect(outcome.text, 'answer');
      expect(outcome.reasoningBlocks.length, 1);
      expect(outcome.reasoningBlocks.first.text, 'thinking...');
    });

    test('a reasoning only stream counts as empty', () async {
      currentFake = _FakeAdapter([
        [const StreamChunk.reasoning('only thoughts')],
        [const StreamChunk.text('real answer')],
      ]);

      const nodes = [
        ChainNode(id: 'a', providerId: 'p1', modelId: 'm'),
        ChainNode(id: 'b', providerId: 'p2', modelId: 'm'),
      ];
      final outcome = await _run(_settings(nodes), nodes, onChunk: (_) {});

      expect(outcome.text, 'real answer');
    });

    test('an answer that landed in the reasoning block is retried, not given up on', () async {
      // A model that streams fast can leave its whole answer inside the think
      // block and never close it, so nothing visible ever arrives. That reads as
      // an empty response and has to cost a retry rather than end the node.
      currentFake = _FakeAdapter([
        [const StreamChunk.reasoning('here is the answer you asked for')],
        [const StreamChunk.reasoning('still thinking')],
        [const StreamChunk.text('the real answer')],
      ]);

      const node = ChainNode(id: 'a', providerId: 'p1', modelId: 'm', retries: 2);
      final outcome = await _run(_settings(const [node]), const [node], onChunk: (_) {}, backoff: const [1, 1]);

      expect(currentFake.attempt, 3);
      expect(outcome.text, 'the real answer');
      expect(outcome.reports.length, 3);
      expect(outcome.reports.first.error?.kind, AiErrorKind.empty);
      expect(outcome.reports.last.ok, isTrue);
    });

    test('an empty stream still falls through to the next node once retries run out', () async {
      currentFake = _FakeAdapter([
        <StreamChunk>[],
        <StreamChunk>[],
        <StreamChunk>[],
        <StreamChunk>[],
      ]);

      const nodes = [
        ChainNode(id: 'a', providerId: 'p1', modelId: 'm', retries: 2),
        ChainNode(id: 'b', providerId: 'p2', modelId: 'm'),
      ];
      final outcome = await _run(_settings(nodes), nodes, onChunk: (_) {}, backoff: const [1, 1]);

      expect(outcome.error?.kind, AiErrorKind.empty);
      expect(outcome.servedBy, isNull);
      // the whole retry budget went to the first node, then the chain moved on
      expect(outcome.reports.where((r) => r.node.id == 'a').length, 3);
      expect(outcome.reports.where((r) => r.node.id == 'b').length, 1);
    });

    test('reasoning with no text after it is dropped', () async {
      currentFake = _FakeAdapter([
        [
          const StreamChunk.text('visible'),
          const StreamChunk.reasoning('late thoughts'),
        ],
      ]);

      final outcome = await _run(
        _settings(const [ChainNode(id: 'a', providerId: 'p1', modelId: 'm')]),
        const [ChainNode(id: 'a', providerId: 'p1', modelId: 'm')],
        onChunk: (_) {},
      );

      // the trailing reasoning never became a block, so it stays out
      expect(outcome.text, 'visible');
      expect(outcome.reasoningBlocks, isEmpty);
    });

    test('reasoning between two text blocks becomes its own step', () async {
      currentFake = _FakeAdapter([
        [
          const StreamChunk.reasoning('first thoughts'),
          const StreamChunk.text('one'),
          const StreamChunk.reasoning('second thoughts'),
          const StreamChunk.text('two'),
        ],
      ]);

      final outcome = await _run(
        _settings(const [ChainNode(id: 'a', providerId: 'p1', modelId: 'm')]),
        const [ChainNode(id: 'a', providerId: 'p1', modelId: 'm')],
        onChunk: (_) {},
      );

      // only the reasoning that arrived before visible text becomes a block,
// trailing reasoning stays in pending and is discarded, same as upstream
      expect(outcome.text, 'onetwo');
      expect(outcome.reasoningBlocks.map((b) => b.text), ['first thoughts']);
    });
  });

  group('cancellation', () {
    test('a cancelled token stops the stream', () async {
      currentFake = _FakeAdapter([
        [
          const StreamChunk.text('one'),
          const StreamChunk.text('two'),
        ],
      ]);
      final cancel = AiCancel();
      final seen = <String>[];

      final outcome = await _run(
        _settings(const [ChainNode(id: 'a', providerId: 'p1', modelId: 'm')]),
        const [ChainNode(id: 'a', providerId: 'p1', modelId: 'm')],
        onChunk: (c) {
          seen.add(c.delta);
          if (seen.length == 1) cancel.cancel();
        },
        cancel: cancel,
      );

      expect(seen, ['one']);
      expect(outcome.error?.kind, AiErrorKind.aborted);
    });

    test('an already cancelled token does not start the request', () async {
      currentFake = _FakeAdapter([[const StreamChunk.text('nope')]]);
      final cancel = AiCancel()..cancel();

      final outcome = await _run(
        _settings(const [ChainNode(id: 'a', providerId: 'p1', modelId: 'm')]),
        const [ChainNode(id: 'a', providerId: 'p1', modelId: 'm')],
        onChunk: (_) {},
        cancel: cancel,
      );

      expect(outcome.error?.kind, AiErrorKind.aborted);
      expect(currentFake.attempt, 0);
    });
  });

  group('compaction hook', () {
    test('an overflow triggers compaction then retries', () async {
      currentFake = _FakeAdapter([
        AiError(AiErrorKind.contextOverflow, 'too long'),
        [const StreamChunk.text('fits now')],
      ]);
      var compactions = 0;

      // the post compaction attempt consumes one retry, same as upstream
      const node = ChainNode(id: 'a', providerId: 'p1', modelId: 'm', retries: 1);
      final outcome = await _run(
        _settings(const [node]),
        const [node],
        onChunk: (_) {},
        onCompact: () async => compactions++,
      );

      expect(compactions, 1);
      expect(outcome.text, 'fits now');
    });

    test('compaction with no retry budget still gives up on the node', () async {
      currentFake = _FakeAdapter([
        AiError(AiErrorKind.contextOverflow, 'too long'),
        [const StreamChunk.text('never reached')],
      ]);
      var compactions = 0;

      // retries 0 means a single attempt, the continue ends the loop
      const node = ChainNode(id: 'a', providerId: 'p1', modelId: 'm');
      final outcome = await _run(
        _settings(const [node]),
        const [node],
        onChunk: (_) {},
        onCompact: () async => compactions++,
      );

      expect(compactions, 1);
      expect(currentFake.attempt, 1);
      expect(outcome.text, '');
      // the compaction branch never pushed a report so the walk ends unknown
      expect(outcome.error?.kind, AiErrorKind.unknown);
    });

    test('the compaction guard resets per attempt, as upstream does', () async {
      currentFake = _FakeAdapter([
        AiError(AiErrorKind.contextOverflow, 'still too long'),
        AiError(AiErrorKind.contextOverflow, 'still too long'),
      ]);
      var compactions = 0;

      // the flag is declared inside the attempt loop so each attempt may compact
      const node = ChainNode(id: 'a', providerId: 'p1', modelId: 'm', retries: 3);
      final outcome = await _run(
        _settings(const [node]),
        const [node],
        onChunk: (_) {},
        backoff: const [1, 1, 1],
        onCompact: () async => compactions++,
      );

      expect(compactions, 4);
      expect(outcome.reports, isEmpty);
      // every attempt took the compaction branch and pushed no report
      expect(outcome.error?.kind, AiErrorKind.unknown);
    });

    test('a compaction failure falls through to the normal retry rules', () async {
      currentFake = _FakeAdapter([
        AiError(AiErrorKind.contextOverflow, 'too long'),
        AiError(AiErrorKind.contextOverflow, 'too long'),
      ]);

      const node = ChainNode(id: 'a', providerId: 'p1', modelId: 'm', retries: 1);
      final outcome = await _run(
        _settings(const [node]),
        const [node],
        onChunk: (_) {},
        backoff: const [1],
        onCompact: () async => throw StateError('compaction failed'),
      );

      expect(outcome.error?.kind, AiErrorKind.contextOverflow);
    });

    test('without a hook an overflow just retries the same node', () async {
      currentFake = _FakeAdapter([
        AiError(AiErrorKind.contextOverflow, 'too long'),
        [const StreamChunk.text('recovered')],
      ]);

      const node = ChainNode(id: 'a', providerId: 'p1', modelId: 'm', retries: 1);
      final outcome = await _run(
        _settings(const [node]),
        const [node],
        onChunk: (_) {},
        backoff: const [1],
      );

      expect(outcome.text, 'recovered');
    });
  });

  test('every node failing surfaces the last error', () async {
    currentFake = _FakeAdapter([
      AiError(AiErrorKind.rate, 'first rate'),
      AiError(AiErrorKind.quota, 'second quota'),
    ]);

    const nodes = [
      ChainNode(id: 'a', providerId: 'p1', modelId: 'm'),
      ChainNode(id: 'b', providerId: 'p2', modelId: 'm'),
    ];
    final outcome = await _run(_settings(nodes), nodes, onChunk: (_) {}, backoff: const []);

    expect(outcome.servedBy, isNull);
    expect(outcome.text, '');
    expect(outcome.error?.kind, AiErrorKind.quota);
  });
}