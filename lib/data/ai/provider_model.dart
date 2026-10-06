// provider kind decides both the auth style and the request shape
enum ProviderKind { openaiChat, openaiResponses, gemini, anthropic, openaiCompatible }

ProviderKind providerKindOf(String raw) => switch (raw) {
      'openai-chat' => ProviderKind.openaiChat,
      'openai-responses' => ProviderKind.openaiResponses,
      'gemini' => ProviderKind.gemini,
      'anthropic' => ProviderKind.anthropic,
      _ => ProviderKind.openaiCompatible,
    };

String kindWire(ProviderKind k) => switch (k) {
      ProviderKind.openaiChat => 'openai-chat',
      ProviderKind.openaiResponses => 'openai-responses',
      ProviderKind.gemini => 'gemini',
      ProviderKind.anthropic => 'anthropic',
      ProviderKind.openaiCompatible => 'openai-compatible',
    };

String providerKindLabel(ProviderKind k) => switch (k) {
      ProviderKind.openaiCompatible => 'OpenAI compatible',
      ProviderKind.openaiChat => 'OpenAI Chat Completions',
      ProviderKind.openaiResponses => 'OpenAI Responses',
      ProviderKind.gemini => 'Google Gemini',
      ProviderKind.anthropic => 'Anthropic',
    };

enum AuthStyle { bearer, xApiKey, queryKey }

AuthStyle authStyleOf(String raw) => switch (raw) {
      'x-api-key' => AuthStyle.xApiKey,
      'query-key' => AuthStyle.queryKey,
      _ => AuthStyle.bearer,
    };

String authWire(AuthStyle a) => switch (a) {
      AuthStyle.bearer => 'bearer',
      AuthStyle.xApiKey => 'x-api-key',
      AuthStyle.queryKey => 'query-key',
    };

enum ModelSource { api, catalog, manual, none }

ModelSource modelSourceOf(String raw) => switch (raw) {
      'api' => ModelSource.api,
      'catalog' => ModelSource.catalog,
      'manual' => ModelSource.manual,
      _ => ModelSource.none,
    };

String sourceWire(ModelSource s) => switch (s) {
      ModelSource.api => 'api',
      ModelSource.catalog => 'catalog',
      ModelSource.manual => 'manual',
      ModelSource.none => 'none',
    };

class KeyValue {
  const KeyValue(this.key, this.value);
  final String key;
  final String value;

  KeyValue copyWith({String? key, String? value}) => KeyValue(key ?? this.key, value ?? this.value);

  Map<String, dynamic> toJson() => {'key': key, 'value': value};

  static KeyValue fromJson(Map<String, dynamic> j) => KeyValue(j['key'] as String? ?? '', j['value'] as String? ?? '');
}

class ModelMeta {
  const ModelMeta({
    required this.id,
    required this.name,
    required this.contextWindow,
    required this.maxOutput,
    required this.vision,
    required this.textToImage,
    required this.reasoning,
    required this.source,
    this.video = false,
  });

  final String id;
  final String name;
  final int contextWindow;
  final int maxOutput;
  final bool vision;
  final bool textToImage;
  final bool reasoning;

  /// video input is tracked separately from [vision]: several vision models
  /// accept images only, and guessing video support from image support would
  /// hand the adapter a part the endpoint rejects
  final bool video;
  final ModelSource source;

  ModelMeta copyWith({String? name, int? contextWindow, int? maxOutput, bool? vision, bool? textToImage, bool? reasoning, ModelSource? source, bool? video}) => ModelMeta(
        id: id,
        name: name ?? this.name,
        contextWindow: contextWindow ?? this.contextWindow,
        maxOutput: maxOutput ?? this.maxOutput,
        vision: vision ?? this.vision,
        textToImage: textToImage ?? this.textToImage,
        reasoning: reasoning ?? this.reasoning,
        source: source ?? this.source,
        video: video ?? this.video,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'c': contextWindow,
        'max': maxOutput,
        'vision': vision,
        't2i': textToImage,
        'r': reasoning,
        'source': sourceWire(source),
        if (video) 'video': true,
      };

  static ModelMeta fromJson(Map<String, dynamic> j) => ModelMeta(
        id: j['id'] as String,
        name: j['name'] as String? ?? j['id'] as String,
        contextWindow: (j['c'] as num?)?.toInt() ?? 0,
        maxOutput: (j['max'] as num?)?.toInt() ?? 0,
        vision: j['vision'] as bool? ?? false,
        textToImage: j['t2i'] as bool? ?? false,
        reasoning: j['r'] as bool? ?? false,
        source: modelSourceOf(j['source'] as String? ?? 'manual'),
        video: j['video'] as bool? ?? false,
      );
}

ModelMeta emptyModel(String id, [String? name]) => ModelMeta(
      id: id,
      name: name ?? id,
      contextWindow: 0,
      maxOutput: 0,
      vision: false,
      textToImage: false,
      reasoning: false,
      source: ModelSource.manual,
    );

/// Input modalities the model in front of a chain accepts. A chain can mix
/// models with different abilities, so the picker asks for the union across
/// its enabled nodes rather than trusting one entry.
class ModelCaps {
  const ModelCaps({this.vision = false, this.video = false});
  final bool vision;
  final bool video;

  bool get any => vision || video;

  ModelCaps operator |(ModelCaps other) => ModelCaps(
        vision: vision || other.vision,
        video: video || other.video,
      );
}

ModelCaps capsOf(AiSettings settings, ChainNode node) {
  final m = findModel(settings, node.providerId, node.modelId);
  return ModelCaps(vision: m?.vision ?? false, video: m?.video ?? false);
}

/// The union over the enabled nodes. The primary node serves most turns but
/// the whole point of the fallback chain is that any node can answer, so
/// attachment gating has to allow everything at least one fallback can take.
ModelCaps chainCaps(AiSettings settings, List<ChainNode> chain) {
  var caps = const ModelCaps();
  for (final n in chain) {
    if (n.enabled) caps = caps | capsOf(settings, n);
  }
  return caps;
}

class Provider {
  Provider({
    required this.id,
    required this.name,
    required this.kind,
    required this.baseUrl,
    required this.apiKeyRef,
    required this.modelsPath,
    required this.chatPath,
    required this.authStyle,
    required this.extraHeaders,
    required this.extraBody,
    required this.models,
    required this.modelsFetchedAt,
    required this.modelsSource,
    required this.builtIn,
    this.sessionHeader = '',
    this.userAgent = '',
    this.relay = false,
  });

  factory Provider.defaults({
    required String id,
    required String name,
    ProviderKind kind = ProviderKind.openaiCompatible,
    String baseUrl = '',
    String? apiKeyRef,
    String? modelsPath,
    String? chatPath,
    AuthStyle authStyle = AuthStyle.bearer,
    String sessionHeader = '',
    String userAgent = '',
    bool builtIn = false,
    bool relay = false,
    List<ModelMeta> models = const [],
  }) =>
      Provider(
        id: id,
        name: name,
        kind: kind,
        baseUrl: baseUrl,
        apiKeyRef: apiKeyRef ?? id,
        modelsPath: modelsPath ?? '/models',
        chatPath: chatPath ?? '/chat/completions',
        authStyle: authStyle,
        sessionHeader: sessionHeader,
        userAgent: userAgent,
        extraHeaders: const [],
        extraBody: const [],
        models: models,
        modelsFetchedAt: 0,
        modelsSource: ModelSource.none,
        builtIn: builtIn,
        relay: relay,
      );

  final String id;
  String name;
  ProviderKind kind;
  String baseUrl;
  // the secret never lives on the provider, this only names where to look
  final String apiKeyRef;
  String modelsPath;
  String chatPath;
  AuthStyle authStyle;

  /// Header some gateways use to pin a conversation to one backend. The app
  /// fills the value with a stable per chat id, this only names the header.
  String sessionHeader;

  /// User-Agent for this provider alone. Empty falls back to the global
  /// setting, then to a User-Agent in either header list, then to the default.
  String userAgent;
  /// True when this provider fronts a blind-test relay whose model ids are its
  /// own (`auto` among them). Those ids are never matched against the
  /// cross-provider catalog fallback, so `auto` cannot inherit OpenRouter's
  /// 2M context window by token accident, and the display layer can rename
  /// them (auto shows as a localized "Auto model").
  bool relay;
  List<KeyValue> extraHeaders;
  List<KeyValue> extraBody;
  List<ModelMeta> models;
  int modelsFetchedAt;
  ModelSource modelsSource;
  bool builtIn;

  Provider copy() => Provider(
        id: id,
        name: name,
        kind: kind,
        baseUrl: baseUrl,
        apiKeyRef: apiKeyRef,
        modelsPath: modelsPath,
        chatPath: chatPath,
        authStyle: authStyle,
        sessionHeader: sessionHeader,
        userAgent: userAgent,
        extraHeaders: [...extraHeaders],
        extraBody: [...extraBody],
        models: [...models],
        modelsFetchedAt: modelsFetchedAt,
        modelsSource: modelsSource,
        builtIn: builtIn,
        relay: relay,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kindWire(kind),
        'baseUrl': baseUrl,
        'apiKeyRef': apiKeyRef,
        'modelsPath': modelsPath,
        'chatPath': chatPath,
        'authStyle': authWire(authStyle),
        'sessionHeader': sessionHeader,
        'userAgent': userAgent,
        'extraHeaders': extraHeaders.map((e) => e.toJson()).toList(),
        'extraBody': extraBody.map((e) => e.toJson()).toList(),
        'models': models.map((e) => e.toJson()).toList(),
        'modelsFetchedAt': modelsFetchedAt,
        'modelsSource': sourceWire(modelsSource),
        'builtIn': builtIn,
        'relay': relay,
      };

  static Provider fromJson(Map<String, dynamic> j) => Provider(
        id: j['id'] as String,
        name: j['name'] as String? ?? j['id'] as String,
        kind: providerKindOf(j['kind'] as String? ?? 'openai-compatible'),
        baseUrl: j['baseUrl'] as String? ?? '',
        apiKeyRef: j['apiKeyRef'] as String? ?? j['id'] as String,
        modelsPath: j['modelsPath'] as String? ?? '/models',
        chatPath: j['chatPath'] as String? ?? '/chat/completions',
        authStyle: authStyleOf(j['authStyle'] as String? ?? 'bearer'),
        sessionHeader: j['sessionHeader'] as String? ?? '',
        userAgent: j['userAgent'] as String? ?? '',
        relay: j['relay'] as bool? ?? false,
        extraHeaders: _kvList(j['extraHeaders']),
        extraBody: _kvList(j['extraBody']),
        models: ((j['models'] as List?) ?? const []).map((e) => ModelMeta.fromJson(e as Map<String, dynamic>)).toList(),
        modelsFetchedAt: (j['modelsFetchedAt'] as num?)?.toInt() ?? 0,
        modelsSource: modelSourceOf(j['modelsSource'] as String? ?? 'none'),
        builtIn: j['builtIn'] as bool? ?? false,
      );

  static List<KeyValue> _kvList(Object? raw) =>
      ((raw as List?) ?? const []).map((e) => KeyValue.fromJson(e as Map<String, dynamic>)).toList();
}

class ChainNode {
  const ChainNode({required this.id, required this.providerId, required this.modelId, this.retries = 0, this.enabled = true});

  final String id;
  final String providerId;
  final String modelId;
  final int retries;
  final bool enabled;

  ChainNode copyWith({int? retries, bool? enabled}) => ChainNode(id: id, providerId: providerId, modelId: modelId, retries: retries ?? this.retries, enabled: enabled ?? this.enabled);

  Map<String, dynamic> toJson() => {'id': id, 'providerId': providerId, 'modelId': modelId, 'retries': retries, 'enabled': enabled};

  static ChainNode fromJson(Map<String, dynamic> j) => ChainNode(
        id: j['id'] as String,
        providerId: j['providerId'] as String,
        modelId: j['modelId'] as String,
        retries: (j['retries'] as num?)?.toInt() ?? 0,
        enabled: j['enabled'] as bool? ?? true,
      );
}

enum ReplyMode { full, character }

ReplyMode replyModeOf(String raw) => raw == 'character' ? ReplyMode.character : ReplyMode.full;

String replyWire(ReplyMode m) => m == ReplyMode.character ? 'character' : 'full';

class CompactionSettings {
  const CompactionSettings({this.enabled = true, this.providerId = '', this.modelId = '', this.targetChars = 1200, this.triggerRatio = 0.75});

  final bool enabled;
  final String providerId;
  final String modelId;
  final int targetChars;
  final double triggerRatio;

  CompactionSettings copyWith({bool? enabled, String? providerId, String? modelId, int? targetChars, double? triggerRatio}) =>
      CompactionSettings(enabled: enabled ?? this.enabled, providerId: providerId ?? this.providerId, modelId: modelId ?? this.modelId, targetChars: targetChars ?? this.targetChars, triggerRatio: triggerRatio ?? this.triggerRatio);

  Map<String, dynamic> toJson() =>
      {'enabled': enabled, 'providerId': providerId, 'modelId': modelId, 'targetChars': targetChars, 'triggerRatio': triggerRatio};

  static CompactionSettings fromJson(Map<String, dynamic> j) => CompactionSettings(
        enabled: j['enabled'] as bool? ?? true,
        providerId: j['providerId'] as String? ?? '',
        modelId: j['modelId'] as String? ?? '',
        targetChars: (j['targetChars'] as num?)?.toInt() ?? 1200,
        triggerRatio: (j['triggerRatio'] as num?)?.toDouble() ?? 0.75,
      );
}

class AiSettings {
  const AiSettings({
    required this.providers,
    required this.chain,
    required this.replyMode,
    required this.temperature,
    required this.maxOutput,
    required this.firstBubbleDelayMs,
    required this.bubbleGapScale,
    required this.pacingJitter,
    required this.stripMarkdownInCharacterMode,
    required this.compaction,
    this.userAgent = '',
    this.globalHeaders = const [],
  });

  final List<Provider> providers;
  final List<ChainNode> chain;
  final ReplyMode replyMode;
  final double temperature;
  final int maxOutput;

  /// read time before the first bubble of a character mode turn
  final int firstBubbleDelayMs;

  /// multiplier on the pause between two character mode bubbles
  final double bubbleGapScale;

  /// 0 to 0.6, half span of the dice around every pacing value, 0 is a metronome
  final double pacingJitter;
  final bool stripMarkdownInCharacterMode;
  final CompactionSettings compaction;

  /// Sent as User-Agent on every ai request. Empty keeps [defaultUserAgent],
  /// which names the app and its version rather than bare runtime.
  final String userAgent;

  /// Headers sent with every ai request to every provider, under the
  /// per provider ones so a provider can override a key.
  final List<KeyValue> globalHeaders;

  AiSettings copyWith({
    List<Provider>? providers,
    List<ChainNode>? chain,
    ReplyMode? replyMode,
    double? temperature,
    int? maxOutput,
    int? firstBubbleDelayMs,
    double? bubbleGapScale,
    double? pacingJitter,
    bool? stripMarkdownInCharacterMode,
    CompactionSettings? compaction,
    String? userAgent,
    List<KeyValue>? globalHeaders,
  }) =>
      AiSettings(
        providers: providers ?? this.providers,
        chain: chain ?? this.chain,
        replyMode: replyMode ?? this.replyMode,
        temperature: temperature ?? this.temperature,
        maxOutput: maxOutput ?? this.maxOutput,
        firstBubbleDelayMs: firstBubbleDelayMs ?? this.firstBubbleDelayMs,
        bubbleGapScale: bubbleGapScale ?? this.bubbleGapScale,
        pacingJitter: pacingJitter ?? this.pacingJitter,
        stripMarkdownInCharacterMode: stripMarkdownInCharacterMode ?? this.stripMarkdownInCharacterMode,
        compaction: compaction ?? this.compaction,
        userAgent: userAgent ?? this.userAgent,
        globalHeaders: globalHeaders ?? this.globalHeaders,
      );

  Map<String, dynamic> toJson() => {
        'providers': providers.map((e) => e.toJson()).toList(),
        'chain': chain.map((e) => e.toJson()).toList(),
        'replyMode': replyWire(replyMode),
        'temperature': temperature,
        'maxOutput': maxOutput,
        'firstBubbleDelayMs': firstBubbleDelayMs,
        'bubbleGapScale': bubbleGapScale,
        'pacingJitter': pacingJitter,
        'stripMarkdownInCharacterMode': stripMarkdownInCharacterMode,
        'compaction': compaction.toJson(),
        'userAgent': userAgent,
        'globalHeaders': globalHeaders.map((e) => e.toJson()).toList(),
      };

  static AiSettings fromJson(Map<String, dynamic> j) => AiSettings(
        providers: ((j['providers'] as List?) ?? const []).map((e) => Provider.fromJson(e as Map<String, dynamic>)).toList(),
        chain: ((j['chain'] as List?) ?? const []).map((e) => ChainNode.fromJson(e as Map<String, dynamic>)).toList(),
        replyMode: replyModeOf(j['replyMode'] as String? ?? 'full'),
        temperature: (j['temperature'] as num?)?.toDouble() ?? 1,
        maxOutput: (j['maxOutput'] as num?)?.toInt() ?? 0,
        firstBubbleDelayMs: (j['firstBubbleDelayMs'] as num?)?.toInt() ?? 1000,
        bubbleGapScale: (j['bubbleGapScale'] as num?)?.toDouble() ?? 1,
        pacingJitter: (j['pacingJitter'] as num?)?.toDouble() ?? 0.35,
        stripMarkdownInCharacterMode: j['stripMarkdownInCharacterMode'] as bool? ?? true,
        compaction: j['compaction'] is Map ? CompactionSettings.fromJson(j['compaction'] as Map<String, dynamic>) : const CompactionSettings(),
        userAgent: j['userAgent'] as String? ?? '',
        globalHeaders: ((j['globalHeaders'] as List?) ?? const []).map((e) => KeyValue.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

const unknownContext = 0;

Provider? findProvider(AiSettings settings, String providerId) {
  for (final p in settings.providers) {
    if (p.id == providerId) return p;
  }
  return null;
}

ModelMeta? findModel(AiSettings settings, String providerId, String modelId) {
  final p = findProvider(settings, providerId);
  if (p == null) return null;
  for (final m in p.models) {
    if (m.id == modelId) return m;
  }
  return null;
}

/// What a chain node or model row shows as its title. The relay's `auto` is a
/// lane, not a model name, so it renders as a localized "Auto model" wherever
/// a raw id would otherwise read like gibberish to a beginner. [autoLabel]
/// supplies that word; everything else keeps its id.
String modelDisplayLabel(AiSettings settings, String providerId, String modelId, String Function() autoLabel) {
  if (modelId == 'auto') {
    final p = findProvider(settings, providerId);
    if (p?.relay ?? false) return autoLabel();
  }
  return modelId;
}

List<ChainNode> activeChain(AiSettings settings) => settings.chain.where((n) => n.enabled).toList();

bool chainReady(AiSettings settings) => activeChain(settings).isNotEmpty;

int contextWindowOf(AiSettings settings, ChainNode node) => findModel(settings, node.providerId, node.modelId)?.contextWindow ?? unknownContext;