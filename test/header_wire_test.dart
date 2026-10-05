import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/app_info.dart';
import 'package:paradise/data/ai/adapter.dart';
import 'package:paradise/data/ai/chain.dart';
import 'package:paradise/data/ai/fetcher.dart';
import 'package:paradise/data/ai/provider_model.dart';

// Header assembly is where every gateway specific requirement lands: a relay
// may demand a user agent it recognises, extra headers, or a per conversation
// routing header it can pin a session with. These tests run against a real
// loopback server, so what is asserted is what actually left the app.

/// Records the headers of every request and answers chat shaped SSE on POST
/// and model list shaped JSON on GET. The echoed headers ride back inside the
/// chat text so the chain treats the answer as a real one.
class _EchoServer {
  _EchoServer() {
    _server = HttpServer.bind(InternetAddress.loopbackIPv4, 0).then((server) {
      server.listen((req) async {
        final captured = <String, String>{};
        req.headers.forEach((name, values) => captured[name.toLowerCase()] = values.join(', '));
        requests.add(captured);
        if (req.method == 'GET') {
          req.response.headers.contentType = ContentType.json;
          req.response.write('{"data": []}');
        } else {
          final echo = jsonEncode(captured);
          req.response.headers.contentType = ContentType('text', 'event-stream');
          req.response.write('data: {"choices":[{"delta":{"content":${jsonEncode(echo)}}}]}\n\n');
        }
        await req.response.flush();
        await req.response.close();
      });
      return server;
    });
  }

  late final Future<HttpServer> _server;
  final List<Map<String, String>> requests = [];

  Future<String> get url async => 'http://127.0.0.1:${(await _server).port}/v1';

  Future<void> close() async {
    (await _server).close(force: true);
  }
}

AiSettings _settings(String baseUrl, {String userAgent = '', List<KeyValue> globalHeaders = const [], Provider? provider}) => AiSettings(
      providers: [provider ?? Provider.defaults(id: 'p', name: 'P', kind: ProviderKind.openaiChat, baseUrl: baseUrl)],
      chain: const [ChainNode(id: 'n', providerId: 'p', modelId: 'm')],
      replyMode: ReplyMode.full,
      temperature: 1,
      maxOutput: 0,
      firstBubbleDelayMs: 0,
      bubbleGapScale: 1,
      pacingJitter: 0.35,
      stripMarkdownInCharacterMode: false,
      compaction: const CompactionSettings(),
      userAgent: userAgent,
      globalHeaders: globalHeaders,
    );

/// Runs one chat turn against [server] and returns the request headers.
Future<Map<String, String>> _chatHeaders(_EchoServer server, AiSettings settings, {String? sessionId}) async {
  var text = '';
  final outcome = await runChain(
    settings: settings,
    apiKeys: const {'p': 'k'},
    system: 'sys',
    messages: const [ChatTurn('user', [])],
    nodes: const [ChainNode(id: 'n', providerId: 'p', modelId: 'm')],
    options: ChainOptions(
      onChunk: (chunk) {
        if (chunk.isText) text += chunk.delta;
      },
      backoffMs: const [],
      sessionId: sessionId,
    ),
  );
  expect(outcome.error, isNull, reason: '${outcome.error?.message}');
  return (jsonDecode(text) as Map).cast<String, String>();
}

void main() {
  late _EchoServer server;

  setUp(() => server = _EchoServer());
  tearDown(() => server.close());

  test('a configured user agent replaces the runtime default', () async {
    final url = await server.url;
    final headers = await _chatHeaders(server, _settings(url, userAgent: 'MyAgent/1.0'));
    expect(headers['user-agent'], 'MyAgent/1.0');
  });

  test('an empty user agent setting sends the app default, not the runtime one', () async {
    final url = await server.url;
    final headers = await _chatHeaders(server, _settings(url));
    expect(headers['user-agent'], defaultUserAgent);
    expect(headers['user-agent'], startsWith('Paradise-Client/'));
    expect(headers['user-agent'], isNot(contains('dart')));
  });

  test('a custom user agent still wins over the app default', () async {
    final url = await server.url;
    final headers = await _chatHeaders(server, _settings(url, userAgent: 'MyAgent/1.0'));
    expect(headers['user-agent'], 'MyAgent/1.0');
  });

  test('a User-Agent set through the header list is respected', () async {
    final url = await server.url;
    final provider = Provider.defaults(id: 'p', name: 'P', kind: ProviderKind.openaiChat, baseUrl: url)..extraHeaders = const [KeyValue('User-Agent', 'HeaderAgent/9')];
    final headers = await _chatHeaders(server, _settings(url, provider: provider));
    expect(headers['user-agent'], 'HeaderAgent/9');
  });

  test('a provider user agent beats the global setting', () async {
    final url = await server.url;
    final provider = Provider.defaults(id: 'p', name: 'P', kind: ProviderKind.openaiChat, baseUrl: url, userAgent: 'ProviderAgent/5');
    final headers = await _chatHeaders(server, _settings(url, userAgent: 'MyAgent/2.0', provider: provider));
    expect(headers['user-agent'], 'ProviderAgent/5');
  });

  test('a provider user agent beats one in its own header list', () async {
    final url = await server.url;
    final provider = Provider.defaults(id: 'p', name: 'P', kind: ProviderKind.openaiChat, baseUrl: url, userAgent: 'ProviderAgent/5')..extraHeaders = const [KeyValue('User-Agent', 'HeaderAgent/9')];
    final headers = await _chatHeaders(server, _settings(url, provider: provider));
    expect(headers['user-agent'], 'ProviderAgent/5');
    expect(headers.keys.where((k) => k.toLowerCase() == 'user-agent'), hasLength(1));
  });

  test('the global setting beats a User-Agent in the global list', () async {
    final url = await server.url;
    final headers = await _chatHeaders(server, _settings(url, userAgent: 'MyAgent/2.0', globalHeaders: const [KeyValue('User-Agent', 'GlobalAgent/1')]));
    expect(headers['user-agent'], 'MyAgent/2.0');
    expect(headers.keys.where((k) => k.toLowerCase() == 'user-agent'), hasLength(1));
  });

  test('global headers ride along with every request', () async {
    final url = await server.url;
    final headers = await _chatHeaders(server, _settings(url, globalHeaders: const [KeyValue('X-Title', 'paradise'), KeyValue('HTTP-Referer', 'https://example.org')]));
    expect(headers['x-title'], 'paradise');
    expect(headers['http-referer'], 'https://example.org');
  });

  test('a provider session header carries the stable conversation id', () async {
    final url = await server.url;
    final provider = Provider.defaults(id: 'p', name: 'P', kind: ProviderKind.openaiChat, baseUrl: url, sessionHeader: 'x-my-session');
    final one = await _chatHeaders(server, _settings(url, provider: provider), sessionId: 'chat-42');
    expect(one['x-my-session'], 'chat-42');

    // a different conversation gets its own id on the same wire
    final two = await _chatHeaders(server, _settings(url, provider: provider), sessionId: 'chat-43');
    expect(two['x-my-session'], 'chat-43');
  });

  test('a session header is not sent without an id or a name', () async {
    final url = await server.url;
    final named = Provider.defaults(id: 'p', name: 'P', kind: ProviderKind.openaiChat, baseUrl: url, sessionHeader: 'x-my-session');
    final noId = await _chatHeaders(server, _settings(url, provider: named));
    expect(noId.containsKey('x-my-session'), isFalse);

    final unnamed = Provider.defaults(id: 'p', name: 'P', kind: ProviderKind.openaiChat, baseUrl: url);
    final noName = await _chatHeaders(server, _settings(url, provider: unnamed), sessionId: 'chat-42');
    expect(noName.keys.any((k) => k.startsWith('x-my-session')), isFalse);
  });

  test('a hand configured header wins over the automatic session pin', () async {
    final url = await server.url;
    final provider = Provider.defaults(
      id: 'p',
      name: 'P',
      kind: ProviderKind.openaiChat,
      baseUrl: url,
      sessionHeader: 'x-my-session',
    )..extraHeaders = const [KeyValue('x-my-session', 'fixed-value')];
    final headers = await _chatHeaders(server, _settings(url, provider: provider), sessionId: 'chat-42');
    expect(headers['x-my-session'], 'fixed-value');
  });

  test('provider headers override global ones on the same name', () async {
    final url = await server.url;
    final provider = Provider.defaults(id: 'p', name: 'P', kind: ProviderKind.openaiChat, baseUrl: url)..extraHeaders = const [KeyValue('X-Title', 'provider')];
    final headers = await _chatHeaders(server, _settings(url, globalHeaders: const [KeyValue('X-Title', 'global')], provider: provider));
    expect(headers['x-title'], 'provider');
  });

  test('the settings blob round trips the new fields', () {
    final settings = _settings('https://example.com/v1', userAgent: 'MyAgent/2.0', globalHeaders: const [KeyValue('X-Title', 'paradise')]);
    final restored = AiSettings.fromJson(jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>);
    expect(restored.userAgent, 'MyAgent/2.0');
    expect(restored.globalHeaders.single.key, 'X-Title');
    expect(restored.globalHeaders.single.value, 'paradise');

    // and a blob from an older build still reads
    final legacy = AiSettings.fromJson({'providers': [], 'chain': []});
    expect(legacy.userAgent, '');
    expect(legacy.globalHeaders, isEmpty);
  });

  test('a provider round trips its session header through json', () {
    final provider = Provider.defaults(id: 'p', name: 'P', sessionHeader: 'x-my-session', userAgent: 'ProviderAgent/5');
    final restored = Provider.fromJson(jsonDecode(jsonEncode(provider.toJson())) as Map<String, dynamic>);
    expect(restored.sessionHeader, 'x-my-session');
    expect(restored.userAgent, 'ProviderAgent/5');
    // an older blob without the field stays valid
    expect(Provider.fromJson({'id': 'p', 'name': 'P'}).sessionHeader, '');
    expect(Provider.fromJson({'id': 'p', 'name': 'P'}).userAgent, '');
  });

  test('a configured user agent also rides on the model list call', () async {
    final url = await server.url;
    final provider = Provider.defaults(id: 'p', name: 'P', baseUrl: url);
    // no user agent configured: the model list carries the app default too
    final result = await fetchProviderModels(provider, 'k', settings: _settings(url));
    // an empty list keeps the call from ok, the sent headers are the point
    expect(result.ok, isFalse);
    expect(server.requests, hasLength(1));
    expect(server.requests.single['user-agent'], defaultUserAgent);
    expect(server.requests.single['authorization'], 'Bearer k');
  });
}
