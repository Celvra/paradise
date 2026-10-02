import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/x.dart';
import 'ai/compaction.dart';
import 'ai/provider_model.dart';
import 'ai/registry.dart';

const _settingsKey = 'ai.settings';

// the six providers the app ships with
List<Provider> _seedProviders() => [
      Provider.defaults(
        id: 'openai',
        name: 'OpenAI',
        kind: ProviderKind.openaiResponses,
        baseUrl: 'https://api.openai.com/v1',
        chatPath: '/responses',
        builtIn: true,
      ),
      Provider.defaults(
        id: 'anthropic',
        name: 'Anthropic',
        kind: ProviderKind.anthropic,
        baseUrl: 'https://api.anthropic.com/v1',
        chatPath: '/messages',
        authStyle: AuthStyle.xApiKey,
        builtIn: true,
      ),
      Provider.defaults(
        id: 'gemini',
        name: 'Google Gemini',
        kind: ProviderKind.gemini,
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
        chatPath: '/models',
        authStyle: AuthStyle.queryKey,
        builtIn: true,
      ),
      Provider.defaults(
        id: 'deepseek',
        name: 'DeepSeek',
        kind: ProviderKind.openaiChat,
        baseUrl: 'https://api.deepseek.com/v1',
        builtIn: true,
      ),
      Provider.defaults(
        id: 'openrouter',
        name: 'OpenRouter',
        kind: ProviderKind.openaiChat,
        baseUrl: 'https://openrouter.ai/api/v1',
        builtIn: true,
      ),
      Provider.defaults(
        id: 'siliconflow',
        name: 'SiliconFlow',
        kind: ProviderKind.openaiChat,
        baseUrl: 'https://api.siliconflow.cn/v1',
        builtIn: true,
      ),
    ];

AiSettings defaultAiSettings() => AiSettings(
      providers: _seedProviders(),
      chain: const [],
      replyMode: ReplyMode.full,
      temperature: 1,
      maxOutput: 0,
      typewriterMs: 50,
      stripMarkdownInCharacterMode: true,
      compaction: const CompactionSettings(),
    );

// anything malformed is dropped rather than crashing the settings screen
AiSettings sanitizeAiSettings(Object? value) {
  final base = defaultAiSettings();
  if (value is! Map) return base;
  final raw = value.cast<String, dynamic>();

  List<Provider> providers;
  if (raw['providers'] is List) {
    providers = [
      for (final e in raw['providers'] as List)
        if (e is Map && (e['id'] as String? ?? '').isNotEmpty) Provider.fromJson(e.cast<String, dynamic>()),
    ];
    if (providers.isEmpty) providers = base.providers;
  } else {
    providers = base.providers;
  }

  final knownIds = providers.map((p) => p.id).toSet();
  final chain = [
    if (raw['chain'] is List)
      for (final e in raw['chain'] as List)
        if (e is Map && knownIds.contains(e['providerId']) && (e['modelId'] as String? ?? '').isNotEmpty) ChainNode.fromJson(e.cast<String, dynamic>()),
  ];

  return AiSettings(
    providers: providers,
    chain: chain,
    replyMode: replyModeOf(raw['replyMode'] as String? ?? 'full'),
    temperature: (raw['temperature'] as num?)?.toDouble() ?? base.temperature,
    maxOutput: (raw['maxOutput'] as num?)?.toInt() ?? base.maxOutput,
    typewriterMs: (raw['typewriterMs'] as num?)?.toInt() ?? base.typewriterMs,
    stripMarkdownInCharacterMode: raw['stripMarkdownInCharacterMode'] as bool? ?? true,
    compaction: raw['compaction'] is Map ? CompactionSettings.fromJson((raw['compaction'] as Map).cast<String, dynamic>()) : base.compaction,
  );
}

/// Owns the provider list, the fallback chain and every per provider API key.
///
/// Keys live under their own pref so removing a provider cannot leak its
/// secret, and the settings blob never carries key material.
class AiConfig extends ChangeNotifier {
  AiConfig._(this._sp);

  final SharedPreferences _sp;

  AiSettings _settings = defaultAiSettings();
  final Map<String, String> _keys = {};
  final Map<String, Compaction> _compactions = {};
  int _seq = 0;

  AiSettings get settings => _settings;
  Map<String, String> get apiKeys => Map.unmodifiable(_keys);
  Map<String, Compaction> get compactions => Map.unmodifiable(_compactions);

  String keyOf(String providerId) => _keys[providerId] ?? '';

  bool get ready => chainReady(_settings);

  bool hasAnyKey() => _settings.providers.any((p) => (_keys[p.id] ?? '').trim().isNotEmpty);

  /// True when every enabled chain node points at a provider that holds a key.
  /// A key on an unrelated provider does not make the chain runnable.
  bool get chainHasKeys {
    final nodes = activeChain(_settings);
    return nodes.isNotEmpty && nodes.every((n) => keyOf(n.providerId).trim().isNotEmpty);
  }

  /// The first enabled chain node that can actually be called.
  ChainNode? get runnableNode {
    for (final node in activeChain(_settings)) {
      if (keyOf(node.providerId).trim().isNotEmpty) return node;
    }
    return null;
  }

  String get chainSummary {
    final nodes = activeChain(_settings);
    if (nodes.isEmpty) return hasAnyKey() ? L10n.current.aiSummaryNoNodes : L10n.current.aiSummaryNoKey;
    return nodes.map((node) {
      final provider = findProvider(_settings, node.providerId);
      final tries = node.retries > 0 ? ' x${node.retries + 1}' : '';
      return '${provider?.name ?? node.providerId} - ${node.modelId}$tries';
    }).join('  |  ');
  }

  static Future<AiConfig> load() async {
    final sp = await SharedPreferences.getInstance();
    final c = AiConfig._(sp);

    AiRegistryCache.reader = () => sp.getString('ai.catalog');
    AiRegistryCache.writer = (v) => sp.setString('ai.catalog', v);

    final raw = sp.getString(_settingsKey);
    if (raw == null) {
      c._settings = defaultAiSettings();
      c._migrateLegacy();
    } else {
      try {
        c._settings = sanitizeAiSettings(jsonDecode(raw));
      } catch (_) {
        c._settings = defaultAiSettings();
      }
    }

    for (final p in c._settings.providers) {
      final k = sp.getString('paradise.key.${p.id}');
      if (k != null && k.isNotEmpty) c._keys[p.id] = k;
    }
    c._loadCompactions();
    return c;
  }

  /// The pre chain build stored one flat base/key/model triple.
  /// Fold it into a single provider and a one node chain so nothing is lost.
  void _migrateLegacy() {
    final base = _sp.getString('base');
    final key = _sp.getString('key') ?? '';
    final model = _sp.getString('model') ?? '';
    if (base == null && key.isEmpty) return;
    final provider = Provider.defaults(
      id: 'legacy',
      name: 'My Provider',
      baseUrl: base?.trim().isNotEmpty == true ? base!.trim() : 'https://api.openai.com/v1',
    );
    _settings = _settings.copyWith(
      providers: [..._settings.providers, provider],
      chain: [
        if (model.trim().isNotEmpty)
          ChainNode(id: 'node_legacy', providerId: 'legacy', modelId: model.trim(), retries: 1, enabled: true),
      ],
    );
    if (key.trim().isNotEmpty) _keys[provider.id] = key.trim();
    _save();
  }

  void _loadCompactions() {
    for (final key in _sp.getKeys()) {
      if (!key.startsWith('ai.compaction.')) continue;
      try {
        final j = jsonDecode(_sp.getString(key)!) as Map<String, dynamic>;
        _compactions[key.substring('ai.compaction.'.length)] = Compaction.fromJson(j);
      } catch (_) {}
    }
  }

  void _save() {
    _sp.setString(_settingsKey, jsonEncode(_settings.toJson()));
  }

  void _commit(AiSettings next) {
    _settings = next;
    _save();
    notifyListeners();
  }

  void _drop() {
    // a provider gone from the list must not keep its secret around
    final live = _settings.providers.map((p) => p.id).toSet();
    for (final id in _keys.keys.toList()) {
      if (!live.contains(id)) {
        _keys.remove(id);
        _sp.remove('paradise.key.$id');
      }
    }
  }

  void update(AiSettings Function(AiSettings) patch) {
    _commit(patch(_settings));
    _drop();
  }

  void saveApiKey(String providerId, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _keys.remove(providerId);
      _sp.remove('paradise.key.$providerId');
    } else {
      _keys[providerId] = trimmed;
      _sp.setString('paradise.key.$providerId', trimmed);
    }
    notifyListeners();
  }

  void patchProvider(String providerId, void Function(Provider p) patch) => update((s) => s.copyWith(
        providers: [for (final p in s.providers) if (p.id == providerId) _patched(p, patch) else p],
      ));

  Provider _patched(Provider p, void Function(Provider) patch) {
    final copy = p.copy();
    patch(copy);
    return copy;
  }

  void addProvider(Provider provider) => update((s) => s.copyWith(providers: [...s.providers, provider]));

  void removeProvider(String providerId) => update((s) => s.copyWith(
        providers: s.providers.where((p) => p.id != providerId).toList(),
        chain: s.chain.where((n) => n.providerId != providerId).toList(),
      ));

  void addChainNode(String providerId, String modelId) {
    if (_settings.chain.any((n) => n.providerId == providerId && n.modelId == modelId)) return;
    final node = ChainNode(id: _newId('node'), providerId: providerId, modelId: modelId, retries: 1, enabled: true);
    update((s) => s.copyWith(chain: [...s.chain, node]));
  }

  void removeChainNode(String nodeId) => update((s) => s.copyWith(chain: s.chain.where((n) => n.id != nodeId).toList()));

  void moveChainNode(String nodeId, int delta) => update((s) {
        final list = [...s.chain];
        final index = list.indexWhere((n) => n.id == nodeId);
        final target = index + delta;
        if (index < 0 || target < 0 || target >= list.length) return s;
        final moved = list.removeAt(index);
        list.insert(target, moved);
        return s.copyWith(chain: list);
      });

  void patchNode(String nodeId, {int? retries, bool? enabled}) => update((s) => s.copyWith(
        chain: [for (final n in s.chain) if (n.id == nodeId) n.copyWith(retries: retries, enabled: enabled) else n],
      ));

  void setChainRetries(String nodeId, int retries) => patchNode(nodeId, retries: retries < 0 ? 0 : (retries > 4 ? 4 : retries));

  void toggleChainNode(String nodeId) {
    final node = _settings.chain.where((n) => n.id == nodeId).firstOrNull;
    if (node != null) patchNode(nodeId, enabled: !node.enabled);
  }

  void patchCompaction(CompactionSettings Function(CompactionSettings) patch) => update((s) => s.copyWith(compaction: patch(s.compaction)));

  String _newId(String prefix) => '$prefix${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  Compaction? compactionOf(String chatId) => _compactions[chatId];

  void setCompaction(String chatId, Compaction? value) {
    if (value == null) {
      _compactions.remove(chatId);
      _sp.remove('ai.compaction.$chatId');
    } else {
      _compactions[chatId] = value;
      _sp.setString('ai.compaction.$chatId', jsonEncode(value.toJson()));
    }
  }

  /// Everything one reply needs, assembled in a single place.
  ChatPlan planFor({
    required String system,
    required List<HistoryItem> history,
    bool allowCompaction = true,
  }) {
    final nodes = activeChain(_settings);
    final first = nodes.isEmpty ? null : nodes.first;
    final window = first == null ? unknownContext : contextWindowOf(_settings, first);
    final cp = _settings.compaction;
    final shouldCompact = allowCompaction && cp.enabled && window > 0 && needsCompaction(history, window, cp.triggerRatio);
    return ChatPlan(
      nodes: nodes,
      contextWindow: window,
      needsCompaction: shouldCompact,
      compaction: cp,
      system: system,
    );
  }
}

class ChatPlan {
  const ChatPlan({required this.nodes, required this.contextWindow, required this.needsCompaction, required this.compaction, required this.system});

  final List<ChainNode> nodes;
  final int contextWindow;
  final bool needsCompaction;
  final CompactionSettings compaction;
  final String system;
}