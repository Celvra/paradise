import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/ai/adapter.dart';
import 'package:paradise/data/ai/chain.dart';
import 'package:paradise/data/ai/errors.dart';
import 'package:paradise/data/ai/provider_model.dart';
import 'package:paradise/data/ai/sse.dart';

// A stop used to be a flag nobody looked at while the provider was silent: the
// stream only checks the token between chunks and the send only fails on its
// header timeout, so a tap during a long think did nothing for a minute. These
// tests run against a real loopback server that goes silent on purpose, the
// shape a thinking model or a buffering relay actually presents.

AiSettings _settings(String baseUrl) => AiSettings(
      providers: [Provider.defaults(id: 'p', name: 'P', kind: ProviderKind.openaiChat, baseUrl: baseUrl)],
      chain: const [ChainNode(id: 'n', providerId: 'p', modelId: 'm')],
      replyMode: ReplyMode.full,
      temperature: 1,
      maxOutput: 0,
      firstBubbleDelayMs: 0,
      bubbleGapScale: 1,
      pacingJitter: 0.35,
      stripMarkdownInCharacterMode: false,
      compaction: const CompactionSettings(),
    );

/// One openai shaped delta, then nothing: the server holds the connection open
/// and never writes another byte, so only a torn down socket ends the read.
/// bufferOutput off because a fifteen byte event would otherwise sit in the
/// server write buffer forever and the test would exercise nothing.
Future<HttpServer> _silentServer({String first = ''}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    req.response.bufferOutput = false;
    if (first.isNotEmpty) {
      req.response.headers.contentType = ContentType('text', 'event-stream');
      req.response.write(first);
      await req.response.flush();
    }
    // silence: the socket stays open until the test tears it down
  });
  return server;
}

void main() {
  test('a stop closes an idle stream instead of waiting for the next chunk', () async {
    final server = await _silentServer(first: 'data: {"a":1}\n\n');
    addTearDown(() => server.close(force: true));

    final cancel = AiCancel();
    final live = await postJson('http://127.0.0.1:${server.port}/v1/chat/completions', headers: const {}, body: {}, cancel: cancel);
    final queue = StreamQueue(readSse(live, cancel: cancel));
    expect((await queue.next).data, '{"a":1}');

    // the server has gone quiet: the stop must still land
    cancel.cancel();
    final result = await queue.next.then<String>((_) => 'kept streaming', onError: (Object e) => e is AiError && e.kind == AiErrorKind.aborted ? 'aborted' : 'other: $e').timeout(const Duration(seconds: 5), onTimeout: () => 'hung');
    // either the abort error or a clean end of stream is fine, hanging is not:
    // the chain folds a clean end into the same aborted outcome
    expect(result, isNot('hung'));
    expect(result, isNot('kept streaming'));
  });

  test('a stop during the header wait fails the request at once', () async {
    final server = await _silentServer(); // receives the request, answers nothing
    addTearDown(() => server.close(force: true));

    final cancel = AiCancel();
    final done = postJson('http://127.0.0.1:${server.port}/v1/chat/completions', headers: const {}, body: {}, cancel: cancel).then<String>((_) => 'opened', onError: (Object e) => e is AiError && e.kind == AiErrorKind.aborted ? 'aborted' : 'other: $e');

    // wait until the request has actually arrived, then stop mid wait
    while (server.connectionsInfo().active == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    cancel.cancel();

    final result = await done.timeout(const Duration(seconds: 5), onTimeout: () => 'hung');
    expect(result, 'aborted');
  });

  test('a stop mid answer leaves the partial and reports aborted', () async {
    // one openai chat delta lands, the server then goes quiet: exactly the
    // "stop button did nothing" a buffering relay looks like. The text is long
    // enough that the think splitter cannot mistake its tail for a partial
    // <think> tag and hold it back from the chunk callback.
    final server = await _silentServer(first: 'data: {"choices":[{"delta":{"content":"hello there"}}]}\n\n');
    addTearDown(() => server.close(force: true));

    final cancel = AiCancel();
    var texts = 0;
    final outcome = await runChain(
      settings: _settings('http://127.0.0.1:${server.port}/v1'),
      apiKeys: {'p': 'k'},
      system: 'sys',
      messages: const [ChatTurn('user', [])],
      nodes: const [ChainNode(id: 'n', providerId: 'p', modelId: 'm')],
      options: ChainOptions(
        cancel: cancel,
        onChunk: (chunk) {
          if (chunk.isText && ++texts == 1) cancel.cancel();
        },
      ),
    ).timeout(const Duration(seconds: 5), onTimeout: () => throw TimeoutException('the stop never landed'));

    expect(texts, 1);
    expect(outcome.text, 'hello there'); // what the reader already saw stays
    expect(outcome.error?.kind, AiErrorKind.aborted);
  });
}
