import 'ai/provider_model.dart';
import 'models.dart';
import 'speech_config.dart';

/// Resolves the generative side channels for one chat.
///
/// Two different shapes live here on purpose. Image generation is a provider
/// and a model chosen from the AI list, so it follows the rule that list
/// already established: a value on the persona wins, an empty value follows the
/// global default. Speech is a module of its own (SpeechConfig), so a persona
/// only ever overrides the few things that are worth differing per character —
/// the voice, and optionally the endpoint and the model. Nothing here decides
/// *whether* a channel may be used; that is the persona's own two switches.
class GenPrefs {
  const GenPrefs({
    required this.imageOn,
    required this.imageProviderId,
    required this.imageModelId,
    required this.imageSize,
    required this.ttsOn,
    required this.ttsEngine,
    required this.ttsBaseUrl,
    required this.ttsModel,
    required this.ttsVoice,
    required this.ttsSpeed,
    required this.ttsInstructions,
    required this.ttsAuthStyle,
    required this.ttsApiKey,
    required this.ttsAutoSpeak,
  });

  final bool imageOn;
  final String imageProviderId;
  final String imageModelId;
  final String imageSize;

  final bool ttsOn;
  final TtsEngine ttsEngine;
  final String ttsBaseUrl;
  final String ttsModel;
  final String ttsVoice;
  final double ttsSpeed;
  final String ttsInstructions;
  final AuthStyle ttsAuthStyle;
  final String ttsApiKey;

  /// Read finished replies out loud without being asked.
  final bool ttsAutoSpeak;

  /// True when there is an image endpoint and a model to ask it for.
  bool get imageReady => imageOn && imageProviderId.isNotEmpty && imageModelId.isNotEmpty;

  /// True when the module can speak. The device engine needs nothing but the
  /// switch, so it is ready as soon as it is on; the endpoint engine needs a
  /// base url, which is the one thing a user has to type.
  bool get ttsReady => ttsOn && (ttsEngine == TtsEngine.system || ttsBaseUrl.isNotEmpty);

  Provider? imageProvider(AiSettings settings) => imageProviderId.isEmpty ? null : findProvider(settings, imageProviderId);

  /// The voice module as a provider shaped view, so the speech client and the
  /// shared header builder can be reused unchanged.
  Provider get ttsProvider => Provider.defaults(
        id: 'speech',
        name: 'Speech',
        kind: ProviderKind.openaiCompatible,
        baseUrl: ttsBaseUrl,
        apiKeyRef: 'speech',
        authStyle: ttsAuthStyle,
        speechPath: '/audio/speech',
        builtIn: true,
      );
}

/// Builds the resolved view for [c].
///
/// The two switches live on the persona and default to off; everything else
/// falls back to the module or to the AI settings. That split is deliberate:
/// "which voice" is a preference a user sets once, "may this character talk" is
/// a property of the character.
GenPrefs genPrefsFor(Chat c, AiSettings settings, SpeechConfig speech) {
  final p = c.persona;

  final imgProvider = p.imageProvider.trim().isNotEmpty ? p.imageProvider.trim() : settings.imageProviderId;
  final imgModel = p.imageModel.trim().isNotEmpty ? p.imageModel.trim() : settings.imageModelId;
  final imgSize = p.imageSize.trim().isNotEmpty ? p.imageSize.trim() : settings.imageSize;

  // a role may point the voice at its own endpoint; empty means the module's
  final baseUrl = p.ttsBaseUrl.trim().isNotEmpty ? p.ttsBaseUrl.trim() : speech.baseUrl;
  final model = p.ttsModel.trim().isNotEmpty ? p.ttsModel.trim() : speech.model;
  final voice = p.ttsVoice.trim().isNotEmpty ? p.ttsVoice.trim() : speech.voice;

  return GenPrefs(
    imageOn: p.imageEnabled,
    imageProviderId: imgProvider,
    imageModelId: imgModel,
    imageSize: imgSize.trim().isEmpty ? '1024x1024' : imgSize.trim(),
    ttsOn: p.ttsEnabled,
    ttsEngine: p.ttsEngine ?? speech.engine,
    ttsBaseUrl: baseUrl,
    ttsModel: model,
    ttsVoice: voice,
    ttsSpeed: speech.speed,
    ttsInstructions: speech.instructions,
    ttsAuthStyle: speech.authStyle,
    // a role pointing at its own endpoint cannot borrow the module's key, so
    // the module's key is only handed over when the endpoint is the module's
    ttsApiKey: p.ttsBaseUrl.trim().isEmpty ? speech.apiKey : '',
    ttsAutoSpeak: p.ttsAutoSpeak,
  );
}

/// The line the model reads so it knows whether it can draw and speak.
///
/// Built from the resolved preferences rather than from the persona, so a role
/// that inherits a working endpoint is told it can use it, and one whose
/// endpoint is missing is told nothing rather than being invited to try and
/// fail.
String genCapabilityBlock(GenPrefs prefs) {
  final lines = <String>[];
  if (prefs.imageReady) {
    lines.add('You can draw: call generate_image with a detailed english prompt.');
  }
  if (prefs.ttsReady) {
    lines.add(prefs.ttsEngine == TtsEngine.api
        ? 'You can speak: call speak to have a line read aloud in your own voice.'
        : 'You can speak: call speak to have a line read aloud by the device voice.');
  }
  if (lines.isEmpty) return '';
  return lines.join('\n');
}
