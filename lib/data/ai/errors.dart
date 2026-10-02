import 'dart:async';
import 'dart:convert';

// failures are classified so the chain knows what is worth retrying and what
// has to fall through to the next node right away
enum AiErrorKind { auth, badRequest, quota, rate, server, network, contextOverflow, aborted, empty, unknown }

const _retryable = {
  AiErrorKind.rate,
  AiErrorKind.server,
  AiErrorKind.network,
  AiErrorKind.contextOverflow,
  AiErrorKind.unknown,
};

class AiError implements Exception {
  AiError(this.kind, this.message, [this.status = 0]);

  final AiErrorKind kind;
  final String message;
  final int status;

  bool get retryable => _retryable.contains(kind);

  @override
  String toString() => message;
}

// set by Store.stop so an in flight request can bail between chunks
// listeners exist so a pending backoff sleep wakes up instead of running its clock
class AiCancel implements Exception {
  final List<void Function()> _listeners = [];
  bool _cancelled = false;

  bool get cancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final l in [..._listeners]) {
      l();
    }
    _listeners.clear();
  }

  void addListener(void Function() l) {
    if (_cancelled) {
      l();
      return;
    }
    _listeners.add(l);
  }

  void removeListener(void Function() l) => _listeners.remove(l);
}

const _overflowHints = [
  'context length',
  'context_length',
  'maximum context',
  'too many tokens',
  'request too large',
  'prompt is too long',
  'reduce the length',
  'input is too long',
  'token count',
  'exceeds the maximum',
  'input length and `max_tokens` exceed',
];

const _quotaHints = [
  'insufficient',
  'quota',
  'billing',
  'payment required',
  'credit balance',
  'arrears',
  'exceeded your current quota',
  '余额',
  '欠费',
];

AiErrorKind classifyMessage(String message) {
  final lower = message.toLowerCase();
  if (_overflowHints.any(lower.contains)) return AiErrorKind.contextOverflow;
  if (_quotaHints.any(lower.contains)) return AiErrorKind.quota;
  return AiErrorKind.unknown;
}

AiError classify(int status, String body) {
  final message = extractMessage(body);
  if (status == 401 || status == 403) return AiError(AiErrorKind.auth, _or(message, 'Authentication failed ($status)'), status);
  if (status == 402) return AiError(AiErrorKind.quota, _or(message, 'Out of credit'), status);
  if (status == 429) return AiError(AiErrorKind.rate, _or(message, 'Rate limited'), status);
  if (status == 400) {
    // a 400 can still be an overflow or a billing problem behind a gateway
    final kind = classifyMessage(message);
    return AiError(kind == AiErrorKind.unknown ? AiErrorKind.badRequest : kind, _or(message, 'Request rejected ($status)'), status);
  }
  if (status >= 500) return AiError(AiErrorKind.server, _or(message, 'Provider error ($status)'), status);
  return AiError(classifyMessage(message), _or(message, 'Request failed ($status)'), status);
}

String _or(String value, String fallback) => value.trim().isEmpty ? fallback : value;

String extractMessage(String body) {
  try {
    final parsed = jsonDecode(body);
    if (parsed is Map) {
      final error = parsed['error'];
      final parts = <String?>[
        if (error is Map && error['message'] is String) error['message'] as String,
        if (parsed['message'] is String) parsed['message'] as String,
      ];
      final found = parts.firstWhere((p) => p != null && p.trim().isNotEmpty, orElse: () => null);
      if (found != null) return found.trim();
      if (error is Map && error['type'] is String && (error['type'] as String).isNotEmpty) {
        return error['type'] as String;
      }
    }
  } catch (_) {
    // not json, fall through to the raw body
  }
  final trimmed = body.trim();
  return trimmed.length > 400 ? trimmed.substring(0, 400) : trimmed;
}

AiError toAiError(Object cause) {
  if (cause is AiError) return cause;
  if (cause is AiCancel) return AiError(AiErrorKind.aborted, 'Stopped', 0);
  if (cause is TimeoutException) return AiError(AiErrorKind.network, 'Request timed out', 0);
  final text = cause is Exception ? _describe(cause) : cause.toString();
  final lower = text.toLowerCase();
  if (lower.contains('network') || lower.contains('socket') || lower.contains('fetch') || lower.contains('timeout') || lower.contains('connection')) {
    return AiError(AiErrorKind.network, text, 0);
  }
  return AiError(classifyMessage(text), text, 0);
}

// socketexception prefixes its type name onto the message, the chain shows it verbatim
String _describe(Exception e) {
  final t = e.toString();
  final prefix = '${e.runtimeType}: ';
  return t.startsWith(prefix) ? t.substring(prefix.length) : t;
}

String describeError(AiError error) => switch (error.kind) {
      AiErrorKind.auth => 'API key is invalid or has no access',
      AiErrorKind.quota => 'Provider is out of credit',
      AiErrorKind.rate => 'Rate limited by the provider',
      AiErrorKind.contextOverflow => 'Context is longer than the model window',
      AiErrorKind.server => 'Provider returned an error',
      AiErrorKind.network => 'Network connection failed',
      AiErrorKind.aborted => 'Generation stopped',
      AiErrorKind.empty => 'The model returned nothing',
      _ => error.message.isEmpty ? 'Request failed' : error.message,
    };