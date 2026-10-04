import 'dart:async';

import '../../l10n/errors.dart';
import 'adapters.dart';
import 'adapter.dart';
import 'errors.dart';
import 'provider_model.dart';
import 'content.dart';
import 'tool_wire.dart';

class AttemptReport {
  const AttemptReport({required this.node, required this.ok, required this.attempts, this.error});
  final ChainNode node;
  final bool ok;
  final int attempts;
  final AiError? error;
}

enum ChainEventKind { node, degraded, failed }

class ChainEvent {
  const ChainEvent(this.kind, {this.node, this.message});
  final ChainEventKind kind;
  final ChainNode? node;
  final String? message;
}

class ChainOutcome {
  const ChainOutcome({required this.text, required this.reasoningBlocks, required this.servedBy, required this.reports, this.error, this.toolCalls = const []});

  /// Tools the model asked for during this single pass, empty for a plain answer
  final List<ToolCallPart> toolCalls;

  final String text;
  final List<({String text, int ms})> reasoningBlocks;
  final ChainNode? servedBy;
  final List<AttemptReport> reports;
  final AiError? error;
}

class ChainOptions {
  const ChainOptions({required this.onChunk, this.onEvent, this.onCompact, this.cancel, this.backoffMs});

  final void Function(StreamChunk chunk) onChunk;
  final void Function(ChainEvent event)? onEvent;

  // asked right before a node is retried after a context overflow
  final Future<void> Function()? onCompact;
  final AiCancel? cancel;
  final List<int>? backoffMs;
}

const _defaultBackoff = [1000, 2000, 4000];

Future<void> _delay(int ms, AiCancel? cancel) async {
  if (cancel?.cancelled ?? false) throw AiError(AiErrorKind.aborted, 'Stopped', 0);
  final c = Completer<void>();
  final timer = Timer(Duration(milliseconds: ms), c.complete);
  void onAbort() {
    timer.cancel();
    if (!c.isCompleted) c.completeError(AiError(AiErrorKind.aborted, 'Stopped', 0));
  }

  cancel?.addListener(onAbort);
  try {
    await c.future;
  } finally {
    cancel?.removeListener(onAbort);
  }
}

class _RunState {
  _RunState() : blocks = [];
  final List<({String text, int ms})> blocks;
  ChainNode? servedBy;
  String text = '';
  final List<ToolCallPart> calls = [];
}

// walks the chain until one node produces text
// a node is abandoned the moment it emits the first visible character
// switching providers mid sentence would leave two half answers in one row
Future<ChainOutcome> runChain({
  required AiSettings settings,
  required Map<String, String> apiKeys,
  required String system,
  required List<ChatTurn> messages,
  required List<ChainNode> nodes,
  required ChainOptions options,
  List<ToolSpec> tools = const [],
}) async {
  final reports = <AttemptReport>[];
  final run = _RunState();

  ChainOutcome bail(AiError error) => ChainOutcome(toolCalls: run.calls, text: run.text, reasoningBlocks: run.blocks, servedBy: run.servedBy, reports: reports, error: error);

  if (nodes.isEmpty) return bail(AiError(AiErrorKind.auth, 'The chain has no usable node yet', 0));

  for (final node in nodes) {
    final total = (node.retries < 0 ? 0 : node.retries) + 1;
    options.onEvent?.call(ChainEvent(ChainEventKind.node, node: node));
    String? degradedFrom;

    for (var attempt = 0; attempt < total; attempt++) {
      if (options.cancel?.cancelled ?? false) return bail(AiError(AiErrorKind.aborted, 'Stopped', 0));
      var visible = false;
      var pending = (text: '', startedAt: DateTime.now().millisecondsSinceEpoch);
      var compacted = false;
      try {
        await for (final chunk in _streamNode(
          settings: settings,
          apiKeys: apiKeys,
          node: node,
          system: system,
          messages: messages,
          tools: tools,
          cancel: options.cancel,
        )) {
          if (chunk.isReasoning) {
            if (visible) {
              // reasoning resumed after text so it becomes its own timeline step
              if (run.blocks.isNotEmpty && run.blocks.last.ms < 0) {
                final last = run.blocks.last;
                run.blocks[run.blocks.length - 1] = (text: last.text, ms: DateTime.now().millisecondsSinceEpoch - last.ms);
              }
            }
            pending = (text: pending.text + chunk.delta, startedAt: pending.startedAt);
            options.onChunk(chunk);
            continue;
          }
          if (!visible) {
            visible = true;
            run.blocks.add((text: pending.text, ms: DateTime.now().millisecondsSinceEpoch - pending.startedAt));
            pending = (text: '', startedAt: DateTime.now().millisecondsSinceEpoch);
            run.servedBy = node;
          }
          run.text += chunk.delta;
          if (chunk.call != null) run.calls.add(chunk.call!);
          options.onChunk(chunk);
        }
        if (options.cancel?.cancelled ?? false) return bail(AiError(AiErrorKind.aborted, 'Stopped', 0));
        if (!visible) throw AiError(AiErrorKind.empty, 'The model returned nothing', 0);
        if (run.blocks.isNotEmpty && run.blocks.last.text.isEmpty && run.blocks.last.ms >= 0) {
          run.blocks.removeLast();
        }
        reports.add(AttemptReport(node: node, ok: true, attempts: attempt + 1));
        if (degradedFrom != null) options.onEvent?.call(ChainEvent(ChainEventKind.degraded, node: node, message: degradedFrom));
        return ChainOutcome(toolCalls: run.calls, text: run.text, reasoningBlocks: run.blocks.where((b) => b.text.isNotEmpty).toList(), servedBy: run.servedBy, reports: reports);
      } catch (cause) {
        final error = toAiError(cause);
        // a stop tears the socket down mid stream, so the raw cause can be a
        // connection error; whatever it looks like, once the token is cancelled
        // the run is over and is reported as the stop it was, never retried
        final stopped = error.kind == AiErrorKind.aborted || (options.cancel?.cancelled ?? false);
        if (stopped) {
          final abort = error.kind == AiErrorKind.aborted ? error : AiError(AiErrorKind.aborted, 'Stopped', 0);
          reports.add(AttemptReport(node: node, ok: false, attempts: attempt + 1, error: abort));
          return bail(abort);
        }
        if (visible) {
          // already on screen so keep the partial and do not switch provider
          reports.add(AttemptReport(node: node, ok: false, attempts: attempt + 1, error: error));
          options.onEvent?.call(ChainEvent(ChainEventKind.failed, node: node, message: describeErrorL10n(error)));
          return ChainOutcome(text: run.text, reasoningBlocks: run.blocks.where((b) => b.text.isNotEmpty).toList(), servedBy: run.servedBy, reports: reports, error: error);
        }
        if (error.kind == AiErrorKind.contextOverflow && !compacted && options.onCompact != null) {
          compacted = true;
          try {
            await options.onCompact!();
            continue;
          } catch (_) {
            // fall through to the normal retry rules
          }
        }
        reports.add(AttemptReport(node: node, ok: false, attempts: attempt + 1, error: error));
        degradedFrom = describeErrorL10n(error);
        if (!error.retryable) break;
        if (attempt < total - 1) {
          final table = options.backoffMs ?? _defaultBackoff;
          final idx = attempt < table.length ? attempt : table.length - 1;
          try {
            await _delay(table[idx], options.cancel);
          } catch (e) {
            final err = toAiError(e);
            reports.add(AttemptReport(node: node, ok: false, attempts: attempt + 1, error: err));
            return bail(err);
          }
          continue;
        }
        break;
      }
    }
    options.onEvent?.call(ChainEvent(ChainEventKind.degraded, node: node, message: degradedFrom));
  }

  final lastError = reports.reversed.firstWhere((r) => r.error != null, orElse: () => AttemptReport(node: nodes.first, ok: false, attempts: 0)).error;
  return ChainOutcome(
    text: run.text,
    reasoningBlocks: run.blocks,
    servedBy: null,
    reports: reports,
    error: lastError ?? AiError(AiErrorKind.unknown, 'Every node on the chain failed', 0),
  );
}

// single node single attempt no retries
Stream<StreamChunk> _streamNode({
  required AiSettings settings,
  required Map<String, String> apiKeys,
  required ChainNode node,
  required String system,
  required List<ChatTurn> messages,
  List<ToolSpec> tools = const [],
  AiCancel? cancel,
}) async* {
  final provider = findProvider(settings, node.providerId);
  if (provider == null) throw AiError(AiErrorKind.auth, 'Provider ${node.providerId} no longer exists', 0);
  final apiKey = (apiKeys[provider.id] ?? '').trim();
  if (apiKey.isEmpty) throw AiError(AiErrorKind.auth, 'Add an API key for ${provider.name} first', 0);
  final adapter = adapterFor(provider.kind);
  var produced = false;
  final stream = adapter.stream(StreamRequest(
    provider: provider,
    apiKey: apiKey,
    model: node.modelId,
    system: system,
    messages: messages,
    temperature: settings.temperature,
    maxOutput: settings.maxOutput,
    tools: tools,
    cancel: cancel,
  ));
  await for (final chunk in stream) {
    if (chunk.delta.isNotEmpty || chunk.call != null) produced = true;
    yield chunk;
  }
  if (!produced) throw AiError(AiErrorKind.empty, 'The model returned nothing', 0);
}