import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../data/ai/provider_model.dart';
import '../data/ai/speech.dart';

/// The one place the app speaks.
///
/// Two engines sit behind one call because the choice is a per character
/// preference, not a per app one: the offline engine costs nothing and works in
/// a tunnel, the endpoint carries a cloned voice and costs a request. A caller
/// asks for a line to be spoken and does not care which one answered, so the
/// branch lives here rather than in the chat page.
///
/// Playback is deliberately serialised. Two characters answering at once, or a
/// reply that arrives while the previous line is still being read, would
/// otherwise talk over each other, and there is no sensible way to mix them.
class SpeechService {
  SpeechService._();

  static final SpeechService instance = SpeechService._();

  FlutterTts? _tts;
  AudioPlayer? _player;

  bool _speaking = false;

  /// True while a line is being spoken or an mp3 is playing.
  bool get isSpeaking => _speaking;

  /// Notifies on every start and stop so a bubble can show a speaking mark
  /// without polling.
  final ValueNotifier<bool> speaking = ValueNotifier<bool>(false);

  FlutterTts _engine() {
    final existing = _tts;
    if (existing != null) return existing;
    final t = FlutterTts();
    _tts = t;
    return t;
  }

  AudioPlayer _audio() {
    final existing = _player;
    if (existing != null) return existing;
    final p = AudioPlayer();
    _player = p;
    return p;
  }

  void _setSpeaking(bool value) {
    _speaking = value;
    speaking.value = value;
  }

  /// Stops whatever is speaking and releases the audio focus.
  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
    try {
      await _player?.stop();
    } catch (_) {}
    _setSpeaking(false);
  }

  /// Speaks [text] through the phone's own engine.
  ///
  /// [voice] is the platform voice name; empty lets the device pick, which is
  /// the right answer for a phone whose installed voices the user never chose.
  Future<void> speakSystem(
    String text, {
    String voice = '',
    double speed = 1.0,
    double pitch = 1.0,
    String language = '',
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    await stop();
    final t = _engine();
    try {
      if (language.trim().isNotEmpty) await t.setLanguage(language.trim());
      if (voice.trim().isNotEmpty) await t.setVoice({'name': voice.trim()});
      // the platform range is 0.0 to 1.0 on Android and 0.0 to 2.0 on iOS; the
      // clamp keeps a stored 1.5 from being rejected outright by Android
      await t.setSpeechRate((speed.clamp(0.0, 1.0)).toDouble());
      await t.setPitch(pitch.clamp(0.5, 2.0).toDouble());
      _setSpeaking(true);
      await t.awaitSpeakCompletion(true);
      await t.speak(clean);
    } catch (_) {
      // a device with no TTS engine installed must not take the chat down
    } finally {
      _setSpeaking(false);
    }
  }

  /// Plays audio that an OpenAI compatible speech endpoint returned.
  ///
  /// The bytes are written to a cache file first because both the Android and
  /// the iOS decoders want a path or a url rather than a buffer, and the file
  /// is named from the content so replaying the same line reuses it.
  Future<void> speakBytes(SpeechAudio audio, {String cacheKey = ''}) async {
    if (audio.bytes.isEmpty) return;
    await stop();
    try {
      final dir = await getTemporaryDirectory();
      final folder = Directory('${dir.path}/speech');
      if (!await folder.exists()) await folder.create(recursive: true);
      final name = cacheKey.isNotEmpty ? cacheKey : _digest(audio.bytes);
      final file = File('${folder.path}/$name.${audio.extension}');
      if (!await file.exists()) await file.writeAsBytes(audio.bytes, flush: false);
      final p = _audio();
      _setSpeaking(true);
      await p.setFilePath(file.path);
      await p.play();
      // play() returns as soon as playback starts, so the completion has to be
      // awaited separately or the speaking flag would clear on the first frame
      await p.processingStateStream.firstWhere(
        (s) => s == ProcessingState.completed,
      );
    } catch (_) {
      // a codec the device does not have must not take the chat down
    } finally {
      _setSpeaking(false);
    }
  }

  /// Speaks [text] through whichever engine [engine] names.
  ///
  /// This is the entry point a reply uses: it resolves the persona's engine
  /// choice, asks the right endpoint for audio when that is what was asked for,
  /// and falls back to the offline engine when the endpoint cannot answer, so a
  /// character with a broken voice provider still says something instead of
  /// staying mute with no explanation.
  Future<void> speak(
    String text, {
    required TtsEngine engine,
    TtsEndpoint? endpoint,
    String voice = '',
    String model = '',
    double speed = 1.0,
    String instructions = '',
    String cacheKey = '',
    String language = '',
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    if (engine == TtsEngine.api && endpoint != null) {
      try {
        final audio = await synthesize(
          provider: endpoint.provider,
          apiKey: endpoint.apiKey,
          model: model,
          voice: voice,
          text: clean,
          speed: speed,
          instructions: instructions,
          settings: endpoint.settings,
        );
        await speakBytes(audio, cacheKey: cacheKey);
        return;
      } catch (_) {
        // fall through to the offline engine rather than going silent
      }
    }
    await speakSystem(clean, voice: engine == TtsEngine.system ? voice : '', speed: speed, language: language);
  }

  /// Short stable name for a blob, so the same line reuses its cache file.
  String _digest(List<int> bytes) {
    var h = 0x811c9dc5;
    // sampling rather than hashing the whole buffer: the name only has to be
    // stable and collision unlikely, and a 2 MB mp3 hashed byte by byte on the
    // ui isolate is a dropped frame for no benefit
    for (var i = 0; i < bytes.length; i += 7) {
      h ^= bytes[i];
      h = (h * 0x01000193) & 0xffffffff;
    }
    return 'tts_${bytes.length}_${h.toRadixString(16)}';
  }

  Future<void> dispose() async {
    await stop();
    await _tts?.stop();
    await _player?.dispose();
    _player = null;
    _tts = null;
    speaking.dispose();
  }
}

/// Everything needed to reach a speech endpoint, resolved from the persona and
/// the global settings before the call, so the service never reads config.
class TtsEndpoint {
  const TtsEndpoint({
    required this.provider,
    required this.apiKey,
    this.settings,
  });

  final Provider provider;
  final String apiKey;
  final AiSettings? settings;
}
