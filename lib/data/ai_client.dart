import 'ai/adapter.dart';
import 'ai/chain.dart';
import 'ai/content.dart';
import 'ai/errors.dart';
import 'ai/provider_model.dart';

export 'ai/errors.dart' show AiError, AiErrorKind, describeError;

/// One off calls used by the ai editor and the settings test button.
///
/// Everything routes through the same adapters as the chat, so a model that
/// works in one place works in the other.
class AiClient {
  /// Runs [messages] against a single throwaway provider and returns the text.
  ///
  /// [baseUrl] and [key] are passed explicitly so the caller can probe an
  /// endpoint that is not saved yet.
  Future<String> complete({
    required String baseUrl,
    required String key,
    required String model,
    required List<Map<String, String>> messages,
    AiCancel? cancel,
  }) async {
    const probeId = 'probe';
    final system = messages.firstWhere((m) => m['role'] == 'system', orElse: () => const {'role': 'system', 'content': ''})['content'] ?? '';

    final provider = Provider.defaults(
      id: probeId,
      name: 'probe',
      baseUrl: baseUrl,
      models: [emptyModel(model, model)],
    );

    final settings = AiSettings(
      providers: [provider],
      chain: const [],
      replyMode: ReplyMode.full,
      temperature: 1,
      maxOutput: 0,
      typewriterMs: 0,
      stripMarkdownInCharacterMode: false,
      compaction: const CompactionSettings(),
    );

    var collected = '';
    final outcome = await runChain(
      settings: settings,
      apiKeys: {probeId: key},
      system: system,
      messages: [
        for (final m in messages.where((m) => m['role'] != 'system'))
          ChatTurn(m['role'] == 'assistant' ? 'assistant' : 'user', [textPart(m['content'] ?? '')]),
      ],
      nodes: [ChainNode(id: probeId, providerId: probeId, modelId: model, retries: 0, enabled: true)],
      options: ChainOptions(
        cancel: cancel,
        onChunk: (chunk) {
          if (chunk.isText) collected += chunk.delta;
        },
        backoffMs: const [],
      ),
    );

    if (outcome.error != null) throw outcome.error!;
    return collected.trim();
  }
}