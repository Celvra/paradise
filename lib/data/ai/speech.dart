import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'errors.dart';
import 'fetcher.dart';
import 'provider_model.dart';
import 'sse.dart';

/// Where a speech request goes for this provider.
///
/// OpenAI's default is `/audio/speech`. A gateway that re-homes the path
/// overrides it per provider, the same way the chat path is overridable.
String speechPathFor(Provider provider) {
  final p = provider.speechPath.trim();
  return p.isEmpty ? '/audio/speech' : p;
}

/// The voices the OpenAI speech endpoint documents, plus the neutral default.
///
/// The list is a starting point for the picker, not a validation: a gateway
/// with cloned voices accepts ids that are not here, so a value the user typed
/// is passed through untouched and this list only decides what is suggested.
const kOpenAiVoices = <String>[
  'alloy',
  'ash',
  'ballad',
  'coral',
  'echo',
  'fable',
  'nova',
  'onyx',
  'sage',
  'shimmer',
  'verse',
];

/// The audio formats the endpoint can return. mp3 is the default because it is
/// the one every player handles and the smallest of the set.
const kSpeechFormats = <String>['mp3', 'opus', 'aac', 'flac', 'wav', 'pcm'];

/// The speech models that are known to exist. An empty model lets the gateway
/// pick its own default, which is what a relay usually wants.
const kSpeechModels = <String>['tts-1', 'tts-1-hd', 'gpt-4o-mini-tts'];

/// Asks an OpenAI compatible endpoint to speak [text].
///
/// Returns the raw audio bytes plus the format they are in, so the player knows
/// whether it can hand them straight to the platform decoder or has to wrap
/// them. Nothing is written to disk here: the caller decides whether the audio
/// is a throwaway or a message that has to survive a restart.
Future<SpeechAudio> synthesize({
  required Provider provider,
  required String apiKey,
  required String model,
  required String voice,
  required String text,
  String format = 'mp3',
  double speed = 1.0,
  String instructions = '',
  AiSettings? settings,
  AiCancel? cancel,
}) async {
  final payload = <String, dynamic>{
    'model': model.trim().isEmpty ? 'tts-1' : model.trim(),
    'input': text,
    'voice': voice.trim().isEmpty ? 'alloy' : voice.trim(),
    'response_format': format,
    // the endpoint rejects a speed outside this window rather than clamping
    if (speed != 1.0) 'speed': speed.clamp(0.25, 4.0),
    // only the gpt-4o-mini-tts family understands this, the older ones ignore it
    if (instructions.trim().isNotEmpty) 'instructions': instructions.trim(),
  };

  final live = await postJson(
    joinUrl(provider.baseUrl, speechPathFor(provider)),
    headers: authHeaders(provider, apiKey, settings: settings),
    body: payload,
    timeout: const Duration(seconds: 120),
    cancel: cancel,
  );
  try {
    final bytes = await _readBytes(live);
    if (bytes.isEmpty) {
      throw AiError(AiErrorKind.empty, 'The speech endpoint returned no audio.', 0);
    }
    // a json body under a 200 means the gateway explained a failure instead of
    // synthesising, and playing that json would be silence with no clue why
    if (_looksLikeJson(bytes)) {
      throw AiError(AiErrorKind.badRequest, _jsonMessage(bytes), 0);
    }
    return SpeechAudio(bytes: bytes, format: format);
  } finally {
    live.close();
  }
}

/// Audio bytes and the container they are in.
class SpeechAudio {
  const SpeechAudio({required this.bytes, required this.format});

  final List<int> bytes;
  final String format;

  /// The extension to give a file holding these bytes.
  String get extension => format == 'pcm' ? 'pcm' : format;

  String get mimeType => switch (format) {
        'mp3' => 'audio/mpeg',
        'opus' => 'audio/ogg',
        'aac' => 'audio/aac',
        'flac' => 'audio/flac',
        'wav' => 'audio/wav',
        'pcm' => 'audio/L16',
        _ => 'audio/mpeg',
      };
}

Future<List<int>> _readBytes(Live live) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in live.response.stream) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

bool _looksLikeJson(List<int> bytes) {
  for (final b in bytes) {
    // skip leading whitespace before deciding
    if (b == 0x20 || b == 0x09 || b == 0x0a || b == 0x0d) continue;
    return b == 0x7b || b == 0x5b; // '{' or '['
  }
  return false;
}

String _jsonMessage(List<int> bytes) {
  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is Map) {
      final err = decoded['error'];
      if (err is Map && err['message'] is String) return '${err['message']}';
      if (decoded['message'] is String) return '${decoded['message']}';
    }
  } catch (_) {}
  return 'The speech endpoint answered with json instead of audio.';
}
