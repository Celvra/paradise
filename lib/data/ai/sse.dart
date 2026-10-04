import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'errors.dart';

class SseEvent {
  const SseEvent(this.data, this.event);
  final String data;
  final String event;
}

// a live request the caller owns, closing it releases the socket
class Live {
  Live(this.client, this.response);
  final http.Client client;
  final http.StreamedResponse response;

  void close() => client.close();
}

final _splitRe = RegExp(r'\r?\n\r?\n');

SseEvent parseEvent(String raw) {
  final data = <String>[];
  var event = '';
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    if (line.startsWith('event:')) {
      event = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      data.add(line.substring(5).trim());
    }
  }
  return SseEvent(data.join(''), event);
}

// streams server sent events off a live response
// events are separated by a blank line so the tail is buffered until it closes
Stream<SseEvent> readSse(Live live, {AiCancel? cancel}) async* {
  if (cancel?.cancelled ?? false) throw AiError(AiErrorKind.aborted, 'Stopped', 0);
  // the loop can only check the token between chunks, and a server that has
  // gone quiet (a long think, a relay buffering the whole answer) sends none,
  // so a stop also closes the socket: the await for below wakes on the dead
  // connection instead of sitting there until the model deigns to speak
  cancel?.addListener(live.close);
  try {
    var buffer = '';
    await for (final chunk in live.response.stream.transform(utf8.decoder)) {
      if (cancel?.cancelled ?? false) throw AiError(AiErrorKind.aborted, 'Stopped', 0);
      buffer += chunk;
      while (true) {
        final m = _splitRe.firstMatch(buffer);
        if (m == null) break;
        final raw = buffer.substring(0, m.start);
        buffer = buffer.substring(m.end);
        final event = parseEvent(raw);
        if (event.data.isNotEmpty && event.data != '[DONE]') yield event;
      }
    }
    final tail = parseEvent(buffer);
    if (tail.data.isNotEmpty && tail.data != '[DONE]') yield tail;
  } on AiError {
    rethrow;
  } catch (e) {
    // the close above lands here as a socket error; a stop is not a network
    // failure, the chain must not retry it and the row must not blame the wire
    if (cancel?.cancelled ?? false) throw AiError(AiErrorKind.aborted, 'Stopped', 0);
    throw toAiError(e);
  } finally {
    cancel?.removeListener(live.close);
    live.close();
  }
}

Future<Live> postJson(String url, {required Map<String, String> headers, required Object body, Duration timeout = const Duration(seconds: 45), AiCancel? cancel, http.Client? client}) async {
  // the client is injectable so a test can drive the abort without a socket
  final conn = client ?? http.Client();
  final request = http.Request('POST', Uri.parse(url))
    ..headers.addAll({'Content-Type': 'application/json', ...headers})
    ..body = jsonEncode(body);
  // while the send waits for response headers nothing else is checking the
  // token, so the abort races the send and wins at once: a stop during the
  // dead wait before the first byte never sits out the header timeout
  final sent = conn.send(request).timeout(timeout);
  final aborted = Completer<Live>();
  void onAbort() {
    if (!aborted.isCompleted) aborted.completeError(AiError(AiErrorKind.aborted, 'Stopped', 0));
    conn.close();
  }

  cancel?.addListener(onAbort);
  try {
    final winner = await Future.any<Object>([sent, aborted.future]);
    // the abort future only ever errors, so the winner is the response
    final res = winner as http.StreamedResponse;
    if (res.statusCode >= 200 && res.statusCode < 300) return Live(conn, res);
    final text = await _safeText(res);
    throw classify(res.statusCode, text);
  } on AiError {
    conn.close();
    rethrow;
  } catch (e) {
    // the abort close lands here as a socket error; a stop is not a network
    // failure, the chain must not retry it and the row must not blame the wire
    if (cancel?.cancelled ?? false) throw AiError(AiErrorKind.aborted, 'Stopped', 0);
    throw toAiError(e);
  } finally {
    cancel?.removeListener(onAbort);
  }
}

Future<Object?> getJson(String url, {required Map<String, String> headers, Duration timeout = const Duration(seconds: 10)}) async {
  final client = http.Client();
  try {
    final res = await client.get(Uri.parse(url), headers: headers).timeout(timeout);
    final text = _decode(res.bodyBytes);
    if (res.statusCode < 200 || res.statusCode >= 300) throw classify(res.statusCode, text);
    try {
      return jsonDecode(text);
    } catch (_) {
      throw AiError(AiErrorKind.server, 'The model list response was not valid JSON', res.statusCode);
    }
  } on AiError {
    rethrow;
  } catch (e) {
    throw toAiError(e);
  } finally {
    client.close();
  }
}

Future<String> _safeText(http.StreamedResponse res) async {
  try {
    return (await res.stream.bytesToString()).trim();
  } catch (_) {
    return '';
  }
}

String _decode(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } catch (_) {
    return '';
  }
}

Map<String, dynamic>? safeParse(String text) {
  try {
    final value = jsonDecode(text);
    return value is Map<String, dynamic> ? value : null;
  } catch (_) {
    return null;
  }
}