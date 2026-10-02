import 'adapter.dart';
import 'errors.dart';
import 'fetcher.dart';
import 'provider_model.dart';
import 'sse.dart';
import 'tool_wire.dart';

Map<String, dynamic> _buildBody(StreamRequest req, List<ChatTurn> turns, String system) {
  final body = <String, dynamic>{'model': req.model, 'stream': true};
  if (req.provider.kind == ProviderKind.openaiResponses) {
    body['instructions'] = system;
    body['input'] = responsesInput(turns);
    if (req.tools.isNotEmpty) body['tools'] = responsesTools(req.tools);
  } else {
    body['messages'] = openAiMessages(system, turns, 'image_url');
    if (req.tools.isNotEmpty) body['tools'] = openAiTools(req.tools);
  }
  if (req.temperature > 0) body['temperature'] = req.temperature;
  if (req.maxOutput > 0) body['max_tokens'] = req.maxOutput;
  return applyExtraBody(req.provider, body);
}

StreamChunk? _parseOpenAiChat(Map<String, dynamic> event) {
  final choices = event['choices'];
  if (choices is! List || choices.isEmpty) return null;
  final delta = (choices.first as Map)['delta'];
  if (delta is! Map) return null;
  // deepseek and friends use reasoning_content, openrouter uses reasoning
  final reasoning = delta['reasoning_content'] ?? delta['reasoning'];
  if (reasoning is String && reasoning.isNotEmpty) return StreamChunk.reasoning(reasoning);
  final content = delta['content'];
  if (content is String && content.isNotEmpty) return StreamChunk.text(content);
  return null;
}

StreamChunk? _parseOpenAiResponses(Map<String, dynamic> event) {
  final type = event['type'] is String ? event['type'] as String : '';
  final delta = event['delta'] is String ? event['delta'] as String : '';
  if (type.contains('reasoning') && delta.isNotEmpty) return StreamChunk.reasoning(delta);
  if (type == 'response.output_text.delta' && delta.isNotEmpty) return StreamChunk.text(delta);
  if (type == 'error' || type == 'response.failed') {
    throw AiError(AiErrorKind.server, 'The provider returned an error event', 0);
  }
  if (type == 'response.refusal.delta' && delta.isNotEmpty) return StreamChunk.text(delta);
  return null;
}

StreamChunk? _parseGemini(Map<String, dynamic> event) {
  final candidates = event['candidates'];
  if (candidates is! List || candidates.isEmpty) return null;
  final content = (candidates.first as Map)['content'];
  if (content is! Map) return null;
  final parts = content['parts'];
  if (parts is! List) return null;
  final text = StringBuffer();
  final reasoning = StringBuffer();
  for (final p in parts) {
    if (p is! Map) continue;
    final value = p['text'];
    if (value is! String || value.isEmpty) continue;
    if (p['thought'] == true) {
      reasoning.write(value);
    } else {
      text.write(value);
    }
  }
  if (reasoning.isNotEmpty) return StreamChunk.reasoning(reasoning.toString());
  if (text.isNotEmpty) return StreamChunk.text(text.toString());
  return null;
}

StreamChunk? _parseAnthropic(Map<String, dynamic> event) {
  final type = event['type'] is String ? event['type'] as String : '';
  if (type == 'error') {
    final error = event['error'];
    final message = error is Map && error['message'] is String ? error['message'] as String : 'The provider returned an error event';
    throw AiError(AiErrorKind.server, message, 0);
  }
  final delta = event['delta'];
  if (delta is! Map) return null;
  if (delta['type'] == 'thinking_delta' && delta['thinking'] is String && (delta['thinking'] as String).isNotEmpty) {
    return StreamChunk.reasoning(delta['thinking'] as String);
  }
  if (delta['type'] == 'text_delta' && delta['text'] is String && (delta['text'] as String).isNotEmpty) {
    return StreamChunk.text(delta['text'] as String);
  }
  return null;
}

ModelMeta? _metaOf(StreamRequest req) {
  for (final m in req.provider.models) {
    if (m.id == req.model) return m;
  }
  return null;
}

class _OpenAiChatAdapter implements ProviderAdapter {
  const _OpenAiChatAdapter();

  @override
  Stream<StreamChunk> stream(StreamRequest req) async* {
    final turns = makeTurns(req.messages);
    final live = await postJson(joinUrl(req.provider.baseUrl, chatPathFor(req.provider)), headers: authHeaders(req.provider, req.apiKey), body: _buildBody(req, turns, req.system), cancel: req.cancel);
    final splitter = ThinkSplitter();
    final tools = ToolAccumulator();
    await for (final event in readSse(live, cancel: req.cancel)) {
      final parsed = safeParse(event.data);
      if (parsed == null) continue;
      tools.feedOpenAi(parsed);
      final chunk = _parseOpenAiChat(parsed);
      if (chunk == null) continue;
      if (chunk.isReasoning) {
        yield chunk;
        continue;
      }
      final split = splitter.push(chunk.delta);
      if (split.reasoning.isNotEmpty) yield StreamChunk.reasoning(split.reasoning);
      if (split.text.isNotEmpty) yield StreamChunk.text(split.text);
    }
    for (final call in tools.drain()) {
      yield StreamChunk.tool(call);
    }
  }
}

class _OpenAiResponsesAdapter implements ProviderAdapter {
  const _OpenAiResponsesAdapter();

  @override
  Stream<StreamChunk> stream(StreamRequest req) async* {
    final turns = makeTurns(req.messages);
    final body = _buildBody(req, turns, req.system);
    // only first party openai accepts the effort field, gateways often reject it
    final meta = _metaOf(req);
    if (req.provider.id == 'openai' && (meta?.reasoning ?? false)) {
      body['reasoning'] = {'effort': 'medium'};
    }
    final live = await postJson(joinUrl(req.provider.baseUrl, chatPathFor(req.provider)), headers: authHeaders(req.provider, req.apiKey), body: body, cancel: req.cancel);
    final tools = ToolAccumulator();
    await for (final event in readSse(live, cancel: req.cancel)) {
      final parsed = safeParse(event.data);
      if (parsed == null) continue;
      tools.feedResponses(parsed);
      final chunk = _parseOpenAiResponses(parsed);
      if (chunk != null) yield chunk;
    }
    for (final call in tools.drain()) {
      yield StreamChunk.tool(call);
    }
  }
}

class _GeminiAdapter implements ProviderAdapter {
  const _GeminiAdapter();

  @override
  Stream<StreamChunk> stream(StreamRequest req) async* {
    final turns = makeTurns(req.messages);
    final base = chatPathFor(req.provider).replaceFirst(RegExp(r'/$'), '');
    final path = '$base/${Uri.encodeComponent(req.model)}:streamGenerateContent';
    // gemini carries the key in the query string when auth style is query key
    final url = withKeyInUrl('${joinUrl(req.provider.baseUrl, path)}?alt=sse', req.apiKey);
    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': req.system}
        ]
      },
      'contents': geminiContents(turns),
    };
    final generationConfig = <String, dynamic>{};
    if (req.temperature > 0) generationConfig['temperature'] = req.temperature;
    if (req.maxOutput > 0) generationConfig['maxOutputTokens'] = req.maxOutput;
    if (_metaOf(req)?.reasoning ?? false) {
      generationConfig['thinkingConfig'] = {'thinkingLevel': 'high', 'includeThoughts': true};
    }
    if (generationConfig.isNotEmpty) body['generationConfig'] = generationConfig;
    if (req.tools.isNotEmpty) body['tools'] = geminiTools(req.tools);
    final live = await postJson(
      url,
      headers: authHeaders(req.provider, req.provider.authStyle == AuthStyle.queryKey ? '' : req.apiKey),
      body: applyExtraBody(req.provider, body),
      cancel: req.cancel,
    );
    final tools = ToolAccumulator();
    await for (final event in readSse(live, cancel: req.cancel)) {
      final parsed = safeParse(event.data);
      if (parsed == null) continue;
      tools.feedGemini(parsed);
      final chunk = _parseGemini(parsed);
      if (chunk != null) yield chunk;
    }
    for (final call in tools.drain()) {
      yield StreamChunk.tool(call);
    }
  }
}

class _AnthropicAdapter implements ProviderAdapter {
  const _AnthropicAdapter();

  @override
  Stream<StreamChunk> stream(StreamRequest req) async* {
    final turns = makeTurns(req.messages);
    final meta = _metaOf(req);
    final catalogMax = meta?.maxOutput ?? 0;
    final maxTokens = req.maxOutput > 0 ? req.maxOutput : (catalogMax == 0 ? 4096 : (catalogMax < 1024 ? 1024 : catalogMax));
    // thinking blocks would have to be replayed with every tool turn, so a
    // request that carries tools runs without extended thinking
    final wantsThinking = (meta?.reasoning ?? false) && req.tools.isEmpty;
    // budget must stay below max_tokens
    final budget = wantsThinking ? (maxTokens ~/ 2 < 1024 ? 1024 : (maxTokens ~/ 2 > 8192 ? 8192 : maxTokens ~/ 2)) : 0;
    final body = <String, dynamic>{
      'model': req.model,
      'max_tokens': wantsThinking ? (maxTokens < budget + 1024 ? budget + 1024 : maxTokens) : maxTokens,
      'system': req.system,
      'messages': anthropicMessages(turns),
      'stream': true,
    };
    if (req.temperature > 0 && !wantsThinking) body['temperature'] = req.temperature;
    if (budget > 0) body['thinking'] = {'type': 'enabled', 'budget_tokens': budget};
    if (req.tools.isNotEmpty) body['tools'] = anthropicTools(req.tools);
    final live = await postJson(
      joinUrl(req.provider.baseUrl, chatPathFor(req.provider)),
      headers: {
        ...authHeaders(req.provider, req.apiKey),
        'anthropic-version': '2023-06-01',
      },
      body: applyExtraBody(req.provider, body),
      cancel: req.cancel,
    );
    final tools = ToolAccumulator();
    await for (final event in readSse(live, cancel: req.cancel)) {
      final parsed = safeParse(event.data);
      if (parsed == null) continue;
      tools.feedAnthropic(parsed);
      final chunk = _parseAnthropic(parsed);
      if (chunk != null) yield chunk;
    }
    for (final call in tools.drain()) {
      yield StreamChunk.tool(call);
    }
  }
}

ProviderAdapter adapterFor(ProviderKind kind) {
  // tests swap in a fake so chain behaviour can run without a network
  final override = adapterOverride;
  if (override != null) return override(kind);
  return switch (kind) {
    ProviderKind.gemini => const _GeminiAdapter(),
    ProviderKind.anthropic => const _AnthropicAdapter(),
    ProviderKind.openaiResponses => const _OpenAiResponsesAdapter(),
    ProviderKind.openaiChat || ProviderKind.openaiCompatible => const _OpenAiChatAdapter(),
  };
}

/// Seam used by the chain tests, production leaves this null.
ProviderAdapter Function(ProviderKind kind)? adapterOverride;