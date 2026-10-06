import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'model_catalog.dart';
import 'model_id.dart';
import 'provider_model.dart';

const _catalogUrl = 'https://models.dev/api.json';
const _snapshotAsset = 'assets/catalog/models.dev.snapshot.json';
const _cacheTtl = Duration(days: 14);
// models.dev answers in seconds on a fast link but crawls at a few KB/s from
// networks that need a long handshake, so give the pull real headroom
const _fetchTimeout = Duration(seconds: 30);

// the remote feed and the bundled subset are both flattened into this shape so
// every lookup below works against one type
typedef Catalog = Map<String, CatalogProvider>;

Catalog? _remote;
Future<Catalog>? _pending;

Future<Catalog> _loadRemote() {
  if (_remote != null) return Future.value(_remote);
  return _pending ??= _fetchRemote().whenComplete(() => _pending = null);
}

Future<Catalog> _fetchRemote() async {
  final cached = _readCache();
  if (cached != null && DateTime.now().millisecondsSinceEpoch - cached.at < _cacheTtl.inMilliseconds && cached.data.isNotEmpty) {
    _remote = cached.data;
    return cached.data;
  }
  try {
    final res = await http.get(Uri.parse(_catalogUrl)).timeout(_fetchTimeout);
    if (res.statusCode != 200) throw AiRegistryException('catalog ${res.statusCode}');
    final parsed = jsonDecode(utf8.decode(res.bodyBytes));
    if (parsed is Map<String, dynamic>) {
      final data = _normalize(parsed);
      _remote = data;
      // the reader parses the models.dev shape, so cache the payload as it
      // arrived rather than re-encoding it into short keys it cannot read
      _writeCache(parsed);
      return data;
    }
  } catch (_) {
    // offline is fine, the bundled snapshot covers the whole catalog
  }
  _remote = cached != null && cached.data.isNotEmpty ? cached.data : await _loadSnapshot();
  return _remote ?? const {};
}

/// Minified models.dev payload shipped inside the apk, so a device that cannot
/// reach the feed at all still sees every provider. Loaded lazily and memoised
/// because parsing 1.5MB of json has a real cost on first launch.
Future<Catalog>? _snapshotPending;
Future<Catalog> _loadSnapshot() {
  return _snapshotPending ??= _readSnapshot().whenComplete(() => _snapshotPending = null);
}

Future<Catalog> _readSnapshot() async {
  try {
    // widget tests never answer the asset channel, which leaves loadString
    // pending forever rather than throwing; the timeout keeps that failure
    // mode inside the catch below. a bundled asset read is milliseconds on a
    // real device, so a short leash costs nothing there and keeps the
    // fallback snappy everywhere
    final raw = await rootBundle.loadString(_snapshotAsset).timeout(const Duration(milliseconds: 300));
    final parsed = jsonDecode(raw);
    if (parsed is Map<String, dynamic>) return _normalize(parsed);
  } catch (_) {
    // tests run without assets; a missing snapshot just means no catalog
  }
  return const {};
}

class AiRegistryException implements Exception {
  AiRegistryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Bumped whenever the stored shape changes. Caches written by an older shape
/// are unreadable, so they are discarded instead of being parsed into zeroes.
const _cacheVersion = 2;

({int at, Catalog data})? _readCache() {
  // cache is injected by the store so this module stays free of shared prefs
  final raw = AiRegistryCache.read();
  if (raw == null) return null;
  try {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['v'] != _cacheVersion) return null;
    return (at: (j['at'] as num).toInt(), data: _normalize(j['data']));
  } catch (_) {
    return null;
  }
}

void _writeCache(Map<String, dynamic> feed) => AiRegistryCache.write(jsonEncode({'v': _cacheVersion, 'at': DateTime.now().millisecondsSinceEpoch, 'data': feed}));

// models.dev lags the providers on video input: the deepseek v4.1 flash
// family takes native video (verified against the official API) while the
// feed lists text+image only. Trust the provider, not the feed.
bool _feedOmitsVideo(String id) =>
    id == 'deepseek-flash' || id.endsWith('/deepseek-flash') || id.endsWith('deepseek-v4.1-flash') || id.endsWith('deepseek-v4p1-flash');

Catalog _normalize(Map raw) {
  final out = <String, CatalogProvider>{};
  raw.forEach((key, value) {
    if (value is! Map) return;
    final models = <String, CatalogModel>{};
    final rawModels = value['models'];
    if (rawModels is Map) {
      rawModels.forEach((id, m) {
        if (m is! Map) return;
        final modalities = m['modalities'];
        final input = modalities is Map && modalities['input'] is List ? (modalities['input'] as List).cast<String>() : const <String>[];
        final output = modalities is Map && modalities['output'] is List ? (modalities['output'] as List).cast<String>() : const <String>[];
        final limit = m['limit'];
        models[id as String] = CatalogModel(
          m['name'] as String? ?? id,
          (limit is Map ? (limit['context'] as num?)?.toInt() : null) ?? 0,
          (limit is Map ? (limit['output'] as num?)?.toInt() : null) ?? 0,
          m['attachment'] == true || input.contains('image'),
          output.contains('image'),
          m['reasoning'] == true,
          input.contains('video') || _feedOmitsVideo(id),
        );
      });
    }
    out[key as String] = CatalogProvider(value['name'] as String? ?? key, models, value['api'] as String?);
  });
  return out;
}

String normalizeId(String id) => id.trim().toLowerCase().replaceAll(RegExp(r'[-_.]+'), '-');

// open router style ids carry a provider prefix the catalog does not
List<String> _candidateKeys(String providerId) {
  final base = normalizeId(providerId);
  const alias = {
    'google': 'google',
    'gemini': 'google',
    'googledeepmind': 'google',
    'xai': 'xai',
    'grok': 'xai',
    'x-ai': 'xai',
    'qwen': 'alibaba',
    'dashscope': 'alibaba',
    'tongyi': 'alibaba',
    'glm': 'zhipuai',
    'zhipu': 'zhipuai',
    'zhipuai': 'zhipuai',
    'moonshot': 'moonshotai',
    'kimi': 'moonshotai',
    'moonshotai': 'moonshotai',
    'openrouter': 'openrouter',
    'siliconflow': 'siliconflow',
    'deepseek': 'deepseek',
    'openai': 'openai',
    'anthropic': 'anthropic',
  };
  return [base, alias[base] ?? base, base.replaceFirst(RegExp(r'^ai-'), '')];
}

CatalogModel? _lookupIn(Catalog source, String providerId, String modelId, [String? modelName]) {
  final wanted = normalizeId(modelId);
  // vendors list a friendlier display name than the catalog key, so the name
  // is real evidence too
  final wantedName = modelName == null || modelName.trim().isEmpty ? '' : normalizeId(modelName);
  for (final key in _candidateKeys(providerId)) {
    final models = source[key]?.models;
    if (models == null) continue;
    final direct = models[modelId];
    if (direct != null) return direct;
    for (final entry in models.entries) {
      if (normalizeId(entry.key) == wanted) return entry.value;
      if (wantedName.isNotEmpty && normalizeId(entry.value.n) == wantedName) return entry.value;
    }
  }
  return null;
}

/// A relay is not a key models.dev knows about, so its provider lookup always
/// misses even though the model ids it hands out are the vendors own. Search
/// every provider by model id instead.
///
/// Only the same id in a different spelling counts: a relay may prefix a vendor
/// slug or use different separators, so `deepseek/deepseek-flash` and
/// `DeepSeek_Flash` are the same model. A merely similar id is never accepted,
/// so `deepseek-chat` cannot borrow `deepseek-v4-flash`.
CatalogModel? _matchModelId(Catalog source, String modelId) {
  final wanted = _tokens(modelId);
  if (wanted.isEmpty) return null;
  final vendor = wanted.first;
  CatalogModel? any;
  // the same id sits under many providers and each one reports the window it
  // is willing to serve, so the vendors own entry is the one that describes the
  // model rather than a relay that merely caps it
  CatalogModel? authoritative;
  for (final provider in source.entries) {
    for (final entry in provider.value.models.entries) {
      if (!_sameTokens(_tokens(entry.key), wanted)) continue;
      any ??= entry.value;
      if (_keysMatch(provider.key, vendor) || _apiIsVendor(provider.value, vendor)) {
        authoritative ??= entry.value;
      }
    }
  }
  return authoritative ?? any;
}

/// A provider whose key is the vendor named by the model id, e.g. deepseek.
bool _keysMatch(String providerId, String vendor) => normalizeId(providerId) == vendor;

/// The catalog entry carries the vendor api host, so `api.deepseek.com` counts
/// as the vendor even when the provider key is spelled differently.
bool _apiIsVendor(CatalogProvider provider, String vendor) {
  final api = provider.api;
  if (api == null || api.isEmpty) return false;
  return api.contains('.$vendor.') || api == 'https://api.$vendor.com';
}

bool _sameTokens(List<String> a, List<String> b) {
  if (a.isEmpty || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Lowercased dash separated tokens, with any vendor prefix dropped.
///
/// A trailing `latest` names the same model as the plain id, so it is dropped
/// rather than treated as a different one.
List<String> _tokens(String id) {
  final tail = id.contains('/') ? id.split('/').last : id;
  final parts = normalizeId(tail).split('-').where((t) => t.isNotEmpty).toList();
  if (parts.length > 1 && _latestAliases.contains(parts.last)) parts.removeLast();
  return parts;
}

/// Markers a relay appends to point at a moving target rather than a new model.
const _latestAliases = {'latest', 'preview'};

/// Searches the fetched models.dev feed first, then the bundled subset, so an
/// upstream model list that carries no metadata of its own still gets filled.
///
/// [crossProvider] turns off the last two fallbacks, the by-id search across
/// every provider. A relay hands out ids under its own name, so `auto` there
/// must not inherit the window of OpenRouter's `openrouter/auto` (2M context)
/// merely because the tokens match.
CatalogModel? _lookupAnywhere(String providerId, String modelId, [String? modelName, bool crossProvider = true]) {
  final hit = _lookupIn(_remote ?? const {}, providerId, modelId, modelName) ?? _lookupIn(modelCatalog, providerId, modelId, modelName);
  if (hit != null) return hit;
  if (!crossProvider) return null;
  return _matchModelId(_remote ?? const {}, modelId) ?? _matchModelId(modelCatalog, modelId);
}

/// Pulls the remote feed into memory once. Later synchronous lookups see it.
Future<void> warmCatalog() => _loadRemote().then((_) {});

/// Drops the memoised feed so the next lookup refetches. Tests swap the cache
/// seam out from under the module global and need a clean slate each time.
void resetCatalog() {
  _remote = null;
  _pending = null;
}

ModelMeta _toMeta(CatalogModel m, String id, String? name, ModelSource source) => ModelMeta(
      id: id,
      name: name ?? m.n,
      contextWindow: m.c,
      maxOutput: m.max,
      vision: m.vision,
      textToImage: m.t2i,
      reasoning: m.r,
      source: source,
      video: m.video,
    );

// fill missing capability fields from the catalog without overwriting api data
ModelMeta enrich(ModelMeta model, String providerId, {bool crossProvider = true}) {
  // a bare upstream entry carries no limits at all, so match it against the
  // fetched models.dev feed by id and by name, then the bundled subset
  final hit = _lookupAnywhere(providerId, model.id, model.name, crossProvider);
  if (hit == null) {
    // an id the catalog missed still carries capability hints
    final g = guessFromModelId(model.id);
    return model.copyWith(
      vision: model.vision || (g.vision ?? false),
      reasoning: model.reasoning || (g.reasoning ?? false),
      textToImage: model.textToImage || (g.textToImage ?? false),
      video: model.video || (g.video ?? false),
    );
  }
  final fromCatalog = _toMeta(hit, model.id, model.name, model.source == ModelSource.manual ? ModelSource.catalog : model.source);
  return model.copyWith(
    name: model.name.isNotEmpty ? model.name : fromCatalog.name,
    contextWindow: model.contextWindow == 0 ? fromCatalog.contextWindow : model.contextWindow,
    maxOutput: model.maxOutput == 0 ? fromCatalog.maxOutput : model.maxOutput,
    vision: model.vision || fromCatalog.vision,
    textToImage: model.textToImage || fromCatalog.textToImage,
    reasoning: model.reasoning || fromCatalog.reasoning,
    video: model.video || fromCatalog.video,
  );
}

Future<ModelMeta?> lookupModel(String providerId, String modelId, [String? modelName]) async {
  final remote = await _loadRemote();
  final hit = _lookupIn(remote, providerId, modelId, modelName) ?? _lookupIn(modelCatalog, providerId, modelId, modelName);
  final ModelMeta meta;
  if (hit != null) {
    meta = _toMeta(hit, modelId, null, ModelSource.catalog);
  } else {
    final base = emptyModel(modelId);
    final g = guessFromModelId(modelId);
    meta = base.copyWith(
      vision: g.vision ?? false,
      reasoning: g.reasoning ?? false,
      textToImage: g.textToImage ?? false,
      video: g.video ?? false,
    );
  }
  // never let a guessed entry rename the model
  return meta.copyWith(name: modelId);
}

// used when the provider exposes no model list endpoint
Future<List<ModelMeta>> catalogModels(String providerId) async {
  final remote = await _loadRemote();
  for (final key in _candidateKeys(providerId)) {
    final models = remote[key]?.models;
    if (models != null) return models.entries.map((e) => _toMeta(e.value, e.key, null, ModelSource.catalog)).toList();
  }
  for (final key in _candidateKeys(providerId)) {
    final models = modelCatalog[key]?.models;
    if (models != null) return models.entries.map((e) => _toMeta(e.value, e.key, null, ModelSource.catalog)).toList();
  }
  return const [];
}

/// Every successful pull replaces the previous upstream list: an id the server
/// no longer returns disappears instead of lingering as a zombie. Hand-added
/// entries are user data rather than upstream state, so they survive the pull
/// unless the new list already carries the same id (the fresh api row wins).
List<ModelMeta> mergeModels(Provider provider, List<ModelMeta> fetched) {
  final cross = !provider.relay;
  final byId = <String, ModelMeta>{};
  for (final model in fetched) {
    if (model.id.trim().isEmpty) continue;
    // Enrich the fresh row itself; the stored copy is deliberately ignored so
    // stale windows and capabilities cannot survive a re-pull.
    // Relay providers skip the cross-provider match: their ids are their own,
    // and a plain `auto` must never grow OpenRouter's 2M window.
    byId[model.id] = enrich(model, provider.id, crossProvider: cross);
  }
  for (final m in provider.models) {
    if (m.source == ModelSource.manual && !byId.containsKey(m.id)) {
      byId[m.id] = m;
    }
  }
  return byId.values.toList();
}

// the store owns persistence, this is the seam the registry reads through
abstract class AiRegistryCache {
  static String? Function()? reader;
  static void Function(String)? writer;

  static String? read() => reader?.call();
  static void write(String value) => writer?.call(value);
}