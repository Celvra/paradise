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
    throw toAiError(e);
  } finally {
    live.close();
  }
}

Future<Live> postJson(String url, {required Map<String, String> headers, required Object body, Duration timeout = const Duration(seconds: 45), AiCancel? cancel}) async {
  final client = http.Client();
  final request = http.Request('POST', Uri.parse(url))
    ..headers.addAll({'Content-Type': 'application/json', ...headers})
    ..body = jsonEncode(body);
  try {
    final res = await client.send(request).timeout(timeout);
    if (res.statusCode >= 200 && res.statusCode < 300) return Live(client, res);
    final text = await _safeText(res);
    client.close();
    throw classify(res.statusCode, text);
  } on AiError {
    rethrow;
  } catch (e) {
    client.close();
    throw toAiError(e);
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