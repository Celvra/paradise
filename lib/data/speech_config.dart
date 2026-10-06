import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai/provider_model.dart';

/// The voice module's own settings.
///
/// Speech synthesis is deliberately not a provider in the AI list. A chat
/// provider is a fallback chain that answers messages, and everything in that
/// list is offered to the model as somewhere a reply may come from. A speech
/// endpoint answers a different question entirely: it takes a line of text and
/// returns audio, it is never part of the chain, and asking a user to add a
/// fake provider just to hear their character talk was the wrong shape. This
/// holds the one endpoint the voice module talks to, on its own keys, so the
/// two can be configured and cleared independently.
class SpeechConfig extends ChangeNotifier {
  SpeechConfig._(this._sp) {
    _load();
  }

  static const _kEngine = 'speech.engine';
  static const _kBaseUrl = 'speech.baseUrl';
  static const _kApiKey = 'speech.apiKey';
  static const _kModel = 'speech.model';
  static const _kVoice = 'speech.voice';
  static const _kSpeed = 'speech.speed';
  static const _kInstructions = 'speech.instructions';
  static const _kAuthStyle = 'speech.authStyle';

  final SharedPreferences _sp;

  TtsEngine _engine = TtsEngine.system;
  String _baseUrl = '';
  String _apiKey = '';
  String _model = 'tts-1';
  String _voice = 'alloy';
  double _speed = 1.0;
  String _instructions = '';
  AuthStyle _authStyle = AuthStyle.bearer;

  TtsEngine get engine => _engine;
  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;
  String get model => _model;
  String get voice => _voice;
  double get speed => _speed;

  /// Free text handed to the endpoint as `instructions`. Only the
  /// gpt-4o-mini-tts family reads it, the older models ignore it, so it is
  /// optional and never required for a working setup.
  String get instructions => _instructions;
  AuthStyle get authStyle => _authStyle;

  /// True when the endpoint engine has everything it needs to be called.
  /// The device engine needs nothing at all, which is why it is the default.
  bool get apiReady => _baseUrl.trim().isNotEmpty;

  /// True when the module can speak at all with the current settings.
  bool get ready => _engine == TtsEngine.system || apiReady;

  static Future<SpeechConfig> load() async {
    final sp = await SharedPreferences.getInstance();
    return SpeechConfig._(sp);
  }

  void _load() {
    _engine = ttsEngineOf(_sp.getString(_kEngine) ?? 'system');
    _baseUrl = _sp.getString(_kBaseUrl) ?? '';
    _apiKey = _sp.getString(_kApiKey) ?? '';
    _model = _sp.getString(_kModel) ?? 'tts-1';
    _voice = _sp.getString(_kVoice) ?? 'alloy';
    _speed = _sp.getDouble(_kSpeed) ?? 1.0;
    _instructions = _sp.getString(_kInstructions) ?? '';
    _authStyle = authStyleOf(_sp.getString(_kAuthStyle) ?? 'bearer');
  }

  void setEngine(TtsEngine v) {
    if (_engine == v) return;
    _engine = v;
    unawaited(_sp.setString(_kEngine, ttsEngineWire(v)));
    notifyListeners();
  }

  void setBaseUrl(String v) {
    final t = v.trim();
    if (_baseUrl == t) return;
    _baseUrl = t;
    unawaited(t.isEmpty ? _sp.remove(_kBaseUrl) : _sp.setString(_kBaseUrl, t));
    notifyListeners();
  }

  void setApiKey(String v) {
    final t = v.trim();
    if (_apiKey == t) return;
    _apiKey = t;
    unawaited(t.isEmpty ? _sp.remove(_kApiKey) : _sp.setString(_kApiKey, t));
    notifyListeners();
  }

  void setModel(String v) {
    final t = v.trim();
    if (_model == t) return;
    _model = t;
    unawaited(t.isEmpty ? _sp.remove(_kModel) : _sp.setString(_kModel, t));
    notifyListeners();
  }

  void setVoice(String v) {
    final t = v.trim();
    if (_voice == t) return;
    _voice = t;
    unawaited(t.isEmpty ? _sp.remove(_kVoice) : _sp.setString(_kVoice, t));
    notifyListeners();
  }

  void setSpeed(double v) {
    final t = v.clamp(0.25, 4.0);
    if (_speed == t) return;
    _speed = t;
    unawaited(_sp.setDouble(_kSpeed, t));
    notifyListeners();
  }

  void setInstructions(String v) {
    final t = v.trim();
    if (_instructions == t) return;
    _instructions = t;
    unawaited(t.isEmpty ? _sp.remove(_kInstructions) : _sp.setString(_kInstructions, t));
    notifyListeners();
  }

  void setAuthStyle(AuthStyle v) {
    if (_authStyle == v) return;
    _authStyle = v;
    unawaited(_sp.setString(_kAuthStyle, authWire(v)));
    notifyListeners();
  }

  /// A provider shaped view of this module, so the speech client and the shared
  /// auth header builder can be reused unchanged. The id is a constant because
  /// nothing persists a reference to it: the module is a singleton, not an
  /// entry in a list.
  Provider get asProvider => Provider.defaults(
        id: 'speech',
        name: 'Speech',
        kind: ProviderKind.openaiCompatible,
        baseUrl: _baseUrl,
        apiKeyRef: 'speech',
        authStyle: _authStyle,
        speechPath: '/audio/speech',
        builtIn: true,
      );

  /// Everything the voice module stores, for the backup and for a reset.
  Map<String, dynamic> toJson() => {
        'engine': ttsEngineWire(_engine),
        'baseUrl': _baseUrl,
        'model': _model,
        'voice': _voice,
        'speed': _speed,
        'instructions': _instructions,
        'authStyle': authWire(_authStyle),
      };

  /// Wipes the endpoint and the key. The device engine is left selected so the
  /// module still speaks after a reset rather than going silent.
  void clear() {
    _baseUrl = '';
    _apiKey = '';
    _instructions = '';
    _sp.remove(_kBaseUrl);
    _sp.remove(_kApiKey);
    _sp.remove(_kInstructions);
    notifyListeners();
  }
}

/// Carried down the widget tree the same way AiConfig is, so a page can read
/// the voice settings without threading them through every constructor.
class SpeechScope extends InheritedNotifier<SpeechConfig> {
  const SpeechScope({super.key, required SpeechConfig config, required super.child}) : super(notifier: config);

  static SpeechConfig of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SpeechScope>();
    assert(scope != null, 'SpeechScope is missing above this widget');
    return scope!.notifier!;
  }

  /// Reads without subscribing, for a callback that only needs the value once.
  static SpeechConfig read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SpeechScope>();
    assert(scope != null, 'SpeechScope is missing above this widget');
    return scope!.notifier!;
  }
}

/// Encodes the module into the one json string a backup carries.
String encodeSpeechConfig(SpeechConfig c) => jsonEncode(c.toJson());
