import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

// MCP over the Streamable HTTP transport (JSON-RPC 2.0 over POST). A server
// answers either with a plain JSON body or with a short text/event-stream that
// carries the response as an SSE "message" event, both are read here. Stdio
// servers cannot run inside an Android app, so only URL servers are listed.

class McpServerConfig {
  McpServerConfig({required this.id, required this.name, required this.url, Map<String, String>? headers, this.enabled = true}) : headers = headers ?? {};
  final String id;
  String name;
  String url;
  final Map<String, String> headers;
  bool enabled;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'url': url, 'headers': headers, 'enabled': enabled};
  factory McpServerConfig.fromJson(Map<String, dynamic> j) => McpServerConfig(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        url: j['url'] as String? ?? '',
        headers: {for (final e in ((j['headers'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'},
        enabled: j['enabled'] as bool? ?? true,
      );
}

class McpTool {
  McpTool({required this.serverId, required this.serverName, required this.name, required this.description, required this.schema});
  final String serverId;
  final String serverName;
  final String name;
  final String description;
  final Map<String, dynamic> schema;

  /// the name the model sees, unique across servers
  String get key => 'mcp_${serverId}_$name'.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
}

class McpException implements Exception {
  McpException(this.message);
  final String message;
  @override
  String toString() => message;
}

class McpClient {
  McpClient(this.config);
  final McpServerConfig config;
  String? _session;
  var _id = 0;
  var _ready = false;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/event-stream',
        if (_session != null) 'Mcp-Session-Id': _session!,
        ...config.headers,
      };

  Future<Map<String, dynamic>?> _post(Map<String, dynamic> body, {bool expectReply = true}) async {
    final res = await http.post(Uri.parse(config.url), headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 30));
    final sid = res.headers['mcp-session-id'];
    if (sid != null) _session = sid;
    if (res.statusCode == 202 || (!expectReply && res.statusCode < 300)) return null;
    if (res.statusCode >= 300) throw McpException('HTTP ${res.statusCode}: ${res.body.length > 200 ? res.body.substring(0, 200) : res.body}');
    final type = res.headers['content-type'] ?? '';
    final text = utf8.decode(res.bodyBytes);
    Map<String, dynamic>? found;
    if (type.contains('text/event-stream')) {
      for (final line in const LineSplitter().convert(text)) {
        if (!line.startsWith('data:')) continue;
        try {
          final j = jsonDecode(line.substring(5).trim());
          if (j is Map && j['id'] == body['id']) found = Map<String, dynamic>.from(j);
        } catch (_) {}
      }
    } else if (text.trim().isNotEmpty) {
      final j = jsonDecode(text);
      if (j is Map) found = Map<String, dynamic>.from(j);
    }
    if (found == null) throw McpException('empty response to ${body['method']}');
    if (found['error'] != null) throw McpException('${(found['error'] as Map)['message'] ?? found['error']}');
    return found;
  }

  Future<Map<String, dynamic>> _rpc(String method, [Map<String, dynamic>? params]) async {
    final res = await _post({'jsonrpc': '2.0', 'id': ++_id, 'method': method, if (params != null) 'params': params});
    return Map<String, dynamic>.from((res?['result'] as Map?) ?? const {});
  }

  Future<void> connect() async {
    if (_ready) return;
    await _rpc('initialize', {
      'protocolVersion': '2025-03-26',
      'capabilities': <String, dynamic>{},
      'clientInfo': {'name': 'lib3', 'version': '1.0.0'},
    });
    await _post({'jsonrpc': '2.0', 'method': 'notifications/initialized'}, expectReply: false);
    _ready = true;
  }

  Future<List<McpTool>> listTools() async {
    await connect();
    final out = <McpTool>[];
    String? cursor;
    do {
      final r = await _rpc('tools/list', cursor == null ? null : {'cursor': cursor});
      for (final t in (r['tools'] as List? ?? const [])) {
        final m = Map<String, dynamic>.from(t as Map);
        out.add(McpTool(
          serverId: config.id,
          serverName: config.name,
          name: m['name'] as String,
          description: m['description'] as String? ?? '',
          schema: m['inputSchema'] is Map ? Map<String, dynamic>.from(m['inputSchema'] as Map) : {'type': 'object', 'properties': <String, dynamic>{}},
        ));
      }
      cursor = r['nextCursor'] as String?;
    } while (cursor != null);
    return out;
  }

  Future<String> callTool(String name, Map<String, dynamic> args) async {
    await connect();
    final r = await _rpc('tools/call', {'name': name, 'arguments': args});
    final parts = <String>[];
    for (final c in (r['content'] as List? ?? const [])) {
      final m = c as Map;
      if (m['type'] == 'text') {
        parts.add('${m['text']}');
      } else if (m['type'] == 'resource' && m['resource'] is Map) {
        parts.add('${(m['resource'] as Map)['text'] ?? (m['resource'] as Map)['uri']}');
      } else {
        parts.add('[${m['type']} content]');
      }
    }
    final text = parts.join('\n');
    if (r['isError'] == true) throw McpException(text.isEmpty ? 'tool reported an error' : text);
    return text.isEmpty ? 'ok' : text;
  }
}

/// All configured servers and the tools they offered at the last refresh.
class McpHub {
  final Map<String, McpClient> _clients = {};
  final List<McpTool> tools = [];
  final Map<String, String> errors = {};

  Future<void> refresh(List<McpServerConfig> servers) async {
    tools.clear();
    errors.clear();
    _clients.removeWhere((id, _) => !servers.any((s) => s.id == id));
    for (final s in servers.where((s) => s.enabled && s.url.trim().isNotEmpty)) {
      final client = _clients[s.id] = McpClient(s);
      try {
        tools.addAll(await client.listTools());
      } catch (e) {
        errors[s.id] = '$e';
        _clients.remove(s.id);
      }
    }
  }

  McpTool? byKey(String key) => tools.where((t) => t.key == key).firstOrNull;

  Future<String> call(McpTool t, Map<String, dynamic> args) {
    final c = _clients[t.serverId];
    if (c == null) throw McpException('server ${t.serverName} is not connected');
    return c.callTool(t.name, args);
  }
}
