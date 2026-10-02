import 'content.dart';
import 'errors.dart';
import 'provider_model.dart';
import 'tool_wire.dart';

// a stream produces either visible text or a reasoning trace, they are kept apart
// so a thinking model never leaks its scratchpad into the message bubble
class StreamChunk {
  const StreamChunk.text(this.delta)
      : reasoning = false,
        call = null;
  const StreamChunk.reasoning(this.delta)
      : reasoning = true,
        call = null;
  const StreamChunk.tool(ToolCallPart this.call)
      : delta = '',
        reasoning = false;

  final String delta;
  final bool reasoning;

  /// Set when the model asked for a tool, delta is empty in that case
  final ToolCallPart? call;

  bool get isText => !reasoning && call == null;
  bool get isReasoning => reasoning;

  @override
  String toString() => call != null ? 'tool:${call!.name}' : (reasoning ? 'r:$delta' : 't:$delta');
}

class ChatTurn implements ChatTurnLike {
  const ChatTurn(this.role, this.content, {this.sourceId});
  final String role;
  final List<ContentPart> content;

  // the message this turn came from so attachments can be matched back
  final String? sourceId;
}

class StreamRequest {
  const StreamRequest({
    required this.provider,
    required this.apiKey,
    required this.model,
    required this.system,
    required this.messages,
    required this.temperature,
    required this.maxOutput,
    this.cancel,
    this.tools = const [],
  });

  final List<ToolSpec> tools;
  final Provider provider;
  final String apiKey;
  final String model;
  final String system;
  final List<ChatTurn> messages;
  final double temperature;
  final int maxOutput;
  final AiCancel? cancel;
}

abstract class ProviderAdapter {
  Stream<StreamChunk> stream(StreamRequest req);
}

final _openThink = RegExp(r'<\s*(think|thought)\s*>', caseSensitive: false);
final _closeThink = RegExp(r'<\s*/\s*(think|thought)\s*>', caseSensitive: false);
const _tagStems = ['<think', '</think', '<thought', '</thought'];

// length of the tail that could still grow into a tag
// an exact prefix test so short text is never held back by mistake
int _partialTagLength(String buffer) {
  final max = buffer.length < 12 ? buffer.length : 12;
  for (var len = max; len > 0; len--) {
    final tail = buffer.substring(buffer.length - len).toLowerCase();
    for (final stem in _tagStems) {
      if (stem.startsWith(tail)) return len;
    }
  }
  return 0;
}

// many openai compatible gateways inline the chain of thought in the text body
// this splits it out so the reasoning never leaks into the visible message
class ThinkSplitter {
  bool _thinking = false;
  String _hold = '';

  bool get inThinking => _thinking;

  ({String reasoning, String text}) push(String delta) {
    var buffer = _hold + delta;
    _hold = '';
    final reasoning = StringBuffer();
    final text = StringBuffer();
    for (;;) {
      if (_thinking) {
        final m = _closeThink.firstMatch(buffer);
        if (m == null) {
          final keep = _partialTagLength(buffer);
          final cut = buffer.length - keep;
          reasoning.write(buffer.substring(0, cut));
          _hold = buffer.substring(cut);
          break;
        }
        reasoning.write(buffer.substring(0, m.start));
        buffer = buffer.substring(m.start + m.group(0)!.length);
        _thinking = false;
        continue;
      }
      final m = _openThink.firstMatch(buffer);
      if (m == null) {
        final keep = _partialTagLength(buffer);
        final cut = buffer.length - keep;
        text.write(buffer.substring(0, cut));
        _hold = buffer.substring(cut);
        break;
      }
      text.write(buffer.substring(0, m.start));
      buffer = buffer.substring(m.start + m.group(0)!.length);
      _thinking = true;
    }
    return (reasoning: reasoning.toString(), text: text.toString());
  }

  // an unclosed think block is normal mid stream so the tail is released on flush
  ({String reasoning, String text}) flush() {
    final rest = _hold;
    _hold = '';
    return (reasoning: '', text: _thinking ? '' : rest);
  }
}

// a turn with nothing at all carries no signal
List<ChatTurn> makeTurns(List<ChatTurn> messages) => messages
    .where((m) => m.content.any((part) => switch (part) {
          TextPart(:final text) => text.trim().isNotEmpty,
          ImagePart(:final data) => data.isNotEmpty,
          ToolCallPart() => true,
          ToolResultPart() => true,
        }))
    .toList();

// every protocol but the openai compatible family has exactly one path so it is
// derived from the kind and the field is hidden instead of asked for
String chatPathFor(Provider provider) {
  if (provider.kind == ProviderKind.openaiChat || provider.kind == ProviderKind.openaiCompatible) {
    final p = provider.chatPath.trim();
    return p.isEmpty ? '/chat/completions' : p;
  }
  return switch (provider.kind) {
    ProviderKind.openaiResponses => '/responses',
    ProviderKind.anthropic => '/messages',
    ProviderKind.gemini => '/models',
    _ => '/chat/completions',
  };
}

// only the openai compatible family has a path worth overriding by hand
bool pathIsEditable(ProviderKind kind) => kind == ProviderKind.openaiChat || kind == ProviderKind.openaiCompatible;

String withKeyInUrl(String url, String apiKey) {
  if (apiKey.isEmpty) return url;
  return '$url${url.contains('?') ? '&' : '?'}key=${Uri.encodeComponent(apiKey)}';
}