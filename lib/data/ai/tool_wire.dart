import 'dart:convert';

import 'content.dart';

// Native tool calling for the four wire protocols the app speaks. The shape of
// a call differs per vendor, so every protocol gets a request side (history to
// wire messages, tool list to wire tools) and a stream side (events to calls).
// The stream side is stateful because OpenAI and Anthropic dribble the JSON
// arguments across many events, the same approach Kelivo takes in its
// tool_loop_runner.

/// What the model is told about one callable tool. `parameters` is a JSON
/// schema object, kept to type / properties / required / enum / description so
/// Gemini accepts it as well.
class ToolSpec {
  const ToolSpec({required this.name, required this.description, required this.parameters});
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
}

/// Tool names must survive every provider, so anything outside the safe set is
/// replaced and the length capped.
String safeToolName(String raw) {
  final s = raw.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  return s.length > 64 ? s.substring(0, 64) : s;
}

Map<String, dynamic> _args(String raw) {
  if (raw.trim().isEmpty) return {};
  try {
    final v = jsonDecode(raw);
    if (v is Map) return Map<String, dynamic>.from(v);
  } catch (_) {}
  return {};
}

// ---------------------------------------------------------------- requests

List<Map<String, dynamic>> openAiTools(List<ToolSpec> tools) => [
      for (final t in tools) {'type': 'function', 'function': {'name': t.name, 'description': t.description, 'parameters': t.parameters}},
    ];

List<Map<String, dynamic>> responsesTools(List<ToolSpec> tools) => [
      for (final t in tools) {'type': 'function', 'name': t.name, 'description': t.description, 'parameters': t.parameters},
    ];

List<Map<String, dynamic>> anthropicTools(List<ToolSpec> tools) => [
      for (final t in tools) {'name': t.name, 'description': t.description, 'input_schema': t.parameters},
    ];

List<Map<String, dynamic>> geminiTools(List<ToolSpec> tools) => [
      {
        'functionDeclarations': [
          for (final t in tools) {'name': t.name, 'description': t.description, 'parameters': t.parameters},
        ],
      },
    ];

List<Map<String, dynamic>> _openAiParts(List<ContentPart> parts, String imageType) => [
      for (final part in parts)
        if (part is TextPart)
          {'type': imageType == 'input_image' ? 'input_text' : 'text', 'text': part.text}
        else if (part is ImagePart)
          {
            'type': imageType,
            'image_url': {'url': 'data:${part.mime};base64,${part.data}'},
          },
    ];

String _text(List<ContentPart> parts) => parts.whereType<TextPart>().map((p) => p.text).join('\n');

/// Chat completions messages. Tool results become their own `tool` role rows
/// and an assistant turn that called tools carries `tool_calls`.
List<Map<String, dynamic>> openAiMessages(String system, List<ChatTurnLike> turns, String imageType) {
  final out = <Map<String, dynamic>>[
    {'role': 'system', 'content': system},
  ];
  for (final t in turns) {
    final results = t.content.whereType<ToolResultPart>().toList();
    final calls = t.content.whereType<ToolCallPart>().toList();
    if (results.isNotEmpty) {
      for (final r in results) {
        out.add({'role': 'tool', 'tool_call_id': r.callId, 'content': r.result});
      }
      continue;
    }
    if (calls.isNotEmpty) {
      final text = _text(t.content);
      out.add({
        'role': 'assistant',
        'content': text.isEmpty ? null : text,
        'tool_calls': [
          for (final c in calls) {'id': c.id, 'type': 'function', 'function': {'name': c.name, 'arguments': jsonEncode(c.args)}},
        ],
      });
      continue;
    }
    out.add({'role': t.role, 'content': _openAiParts(t.content, imageType)});
  }
  return out;
}

/// Responses API input items.
List<Map<String, dynamic>> responsesInput(List<ChatTurnLike> turns) {
  final out = <Map<String, dynamic>>[];
  for (final t in turns) {
    for (final p in t.content) {
      if (p is ToolResultPart) {
        out.add({'type': 'function_call_output', 'call_id': p.callId, 'output': p.result});
      } else if (p is ToolCallPart) {
        out.add({'type': 'function_call', 'call_id': p.id, 'name': p.name, 'arguments': jsonEncode(p.args)});
      }
    }
    final rest = t.content.where((p) => p is TextPart || p is ImagePart).toList();
    if (rest.isNotEmpty) out.add({'role': t.role, 'content': _openAiParts(rest, 'input_image')});
  }
  return out;
}

List<Map<String, dynamic>> anthropicMessages(List<ChatTurnLike> turns) {
  final out = <Map<String, dynamic>>[];
  for (final t in turns) {
    final blocks = <Map<String, dynamic>>[];
    for (final p in t.content) {
      if (p is TextPart) {
        if (p.text.isNotEmpty) blocks.add({'type': 'text', 'text': p.text});
      } else if (p is ImagePart) {
        blocks.add({
          'type': 'image',
          'source': {'type': 'base64', 'media_type': p.mime, 'data': p.data},
        });
      } else if (p is ToolCallPart) {
        blocks.add({'type': 'tool_use', 'id': p.id, 'name': p.name, 'input': p.args});
      } else if (p is ToolResultPart) {
        blocks.add({'type': 'tool_result', 'tool_use_id': p.callId, 'content': p.result, if (p.isError) 'is_error': true});
      }
    }
    if (blocks.isEmpty) continue;
    // a tool result rides on a user turn on this protocol
    out.add({'role': t.role == 'assistant' ? 'assistant' : 'user', 'content': blocks});
  }
  return out;
}

List<Map<String, dynamic>> geminiContents(List<ChatTurnLike> turns) {
  final out = <Map<String, dynamic>>[];
  for (final t in turns) {
    final parts = <Map<String, dynamic>>[];
    for (final p in t.content) {
      if (p is TextPart) {
        if (p.text.isNotEmpty) parts.add({'text': p.text});
      } else if (p is ImagePart) {
        parts.add({
          'inlineData': {'mimeType': p.mime, 'data': p.data}
        });
      } else if (p is VideoPart) {
        // only gemini takes inline video today; the request is gated by the
        // model's video flag long before it reaches this converter
        parts.add({
          'inlineData': {'mimeType': p.mime, 'data': p.data}
        });
      } else if (p is ToolCallPart) {
        parts.add({
          'functionCall': {'name': p.name, 'args': p.args},
          if (p.signature != null) 'thoughtSignature': p.signature,
        });
      } else if (p is ToolResultPart) {
        parts.add({
          'functionResponse': {
            'name': p.name,
            'response': {p.isError ? 'error' : 'result': p.result},
          },
        });
      }
    }
    if (parts.isEmpty) continue;
    out.add({'role': t.role == 'assistant' ? 'model' : 'user', 'parts': parts});
  }
  return out;
}

/// The two fields a wire converter needs from a turn. ChatTurn satisfies it
/// through the extension below, which keeps this file free of an import cycle.
abstract class ChatTurnLike {
  String get role;
  List<ContentPart> get content;
}

// ------------------------------------------------------------------ stream

class _Partial {
  String id = '';
  String name = '';
  final StringBuffer args = StringBuffer();
}

/// Collects tool calls out of the raw event objects of any protocol. Feed every
/// parsed event, drain once the stream is over.
class ToolAccumulator {
  final Map<int, _Partial> _open = {};
  final List<ToolCallPart> _done = [];
  var _seq = 0;

  String _fallbackId() => 'call_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  void feedOpenAi(Map<String, dynamic> event) {
    final choices = event['choices'];
    if (choices is! List || choices.isEmpty) return;
    final delta = (choices.first as Map)['delta'];
    if (delta is! Map) return;
    final calls = delta['tool_calls'];
    if (calls is! List) return;
    for (final raw in calls) {
      if (raw is! Map) continue;
      final idx = (raw['index'] as num?)?.toInt() ?? 0;
      final p = _open.putIfAbsent(idx, _Partial.new);
      if (raw['id'] is String && (raw['id'] as String).isNotEmpty) p.id = raw['id'] as String;
      final fn = raw['function'];
      if (fn is Map) {
        if (fn['name'] is String) p.name += fn['name'] as String;
        if (fn['arguments'] is String) p.args.write(fn['arguments'] as String);
      }
    }
  }

  void feedResponses(Map<String, dynamic> event) {
    if (event['type'] != 'response.output_item.done') return;
    final item = event['item'];
    if (item is! Map || item['type'] != 'function_call') return;
    _done.add(ToolCallPart(
      id: (item['call_id'] as String?) ?? _fallbackId(),
      name: (item['name'] as String?) ?? '',
      args: _args((item['arguments'] as String?) ?? ''),
    ));
  }

  void feedAnthropic(Map<String, dynamic> event) {
    final type = event['type'];
    final idx = (event['index'] as num?)?.toInt() ?? 0;
    if (type == 'content_block_start') {
      final block = event['content_block'];
      if (block is Map && block['type'] == 'tool_use') {
        final p = _open.putIfAbsent(idx, _Partial.new);
        p.id = (block['id'] as String?) ?? '';
        p.name = (block['name'] as String?) ?? '';
      }
    } else if (type == 'content_block_delta') {
      final delta = event['delta'];
      final p = _open[idx];
      if (p != null && delta is Map && delta['type'] == 'input_json_delta') {
        p.args.write((delta['partial_json'] as String?) ?? '');
      }
    } else if (type == 'content_block_stop') {
      final p = _open.remove(idx);
      if (p != null) _done.add(ToolCallPart(id: p.id.isEmpty ? _fallbackId() : p.id, name: p.name, args: _args(p.args.toString())));
    }
  }

  void feedGemini(Map<String, dynamic> event) {
    final candidates = event['candidates'];
    if (candidates is! List || candidates.isEmpty) return;
    final content = (candidates.first as Map)['content'];
    if (content is! Map || content['parts'] is! List) return;
    for (final p in content['parts'] as List) {
      if (p is! Map || p['functionCall'] is! Map) continue;
      final fc = p['functionCall'] as Map;
      _done.add(ToolCallPart(
        id: _fallbackId(),
        name: (fc['name'] as String?) ?? '',
        args: fc['args'] is Map ? Map<String, dynamic>.from(fc['args'] as Map) : {},
        signature: p['thoughtSignature'] as String?,
      ));
    }
  }

  /// Everything that finished, in the order the model asked for it.
  List<ToolCallPart> drain() {
    final keys = _open.keys.toList()..sort();
    for (final k in keys) {
      final p = _open[k]!;
      if (p.name.isEmpty) continue;
      _done.add(ToolCallPart(id: p.id.isEmpty ? _fallbackId() : p.id, name: p.name, args: _args(p.args.toString())));
    }
    _open.clear();
    final out = [..._done];
    _done.clear();
    return out;
  }
}
