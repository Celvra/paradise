import 'errors.dart';
import 'provider_model.dart';
import 'registry.dart';
import 'sse.dart';

const _listTimeout = Duration(seconds: 10);

class ModelListResult {
  const ModelListResult({required this.models, required this.source, required this.fetchedAt, this.warning});

  final List<ModelMeta> models;
  final ModelSource source;
  final int fetchedAt;
  final String? warning;

  bool get ok => source == ModelSource.api;
}

String joinUrl(String base, String path) {
  final cleanBase = base.trim().replaceAll(RegExp(r'/+$'), '');
  final cleanPath = path.trim();
  if (cleanPath.isEmpty) return cleanBase;
  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(cleanPath)) return cleanPath;
  return '$cleanBase/${cleanPath.replaceFirst(RegExp(r'^/+'), '')}';
}

Map<String, String> authHeaders(Provider provider, String apiKey) {
  final headers = <String, String>{};
  for (final h in provider.extraHeaders) {
    if (h.key.trim().isNotEmpty) headers[h.key.trim()] = h.value;
  }
  if (apiKey.isNotEmpty) {
    switch (provider.authStyle) {
      case AuthStyle.xApiKey:
        headers['x-api-key'] = apiKey;
      case AuthStyle.bearer:
        headers['Authorization'] = 'Bearer $apiKey';
      case AuthStyle.queryKey:
        break;
    }
  }
  return headers;
}

String _withKey(Provider provider, String url, String apiKey) {
  if (apiKey.isEmpty || provider.authStyle != AuthStyle.queryKey) return url;
  return '$url${url.contains('?') ? '&' : '?'}key=${Uri.encodeComponent(apiKey)}';
}

// a dotted key writes into a nested object so gateways that need
// generation_config.foo can still be configured from the ui
Map<String, dynamic> applyExtraBody(Provider provider, Map<String, dynamic> body) {
  for (final item in provider.extraBody) {
    final key = item.key.trim();
    if (key.isEmpty) continue;
    if (key.startsWith('.')) {
      final path = key.substring(1).split('.');
      Map<String, dynamic> cursor = body;
      for (var i = 0; i < path.length - 1; i++) {
        final next = cursor[path[i]];
        if (next is! Map) cursor[path[i]] = <String, dynamic>{};
        cursor = (cursor[path[i]] as Map).cast<String, dynamic>();
      }
      cursor[path.last] = item.value;
    } else {
      body[key] = item.value;
    }
  }
  return body;
}

// anthropic has no list endpoint so we always fall back to the catalog
Future<ModelListResult> fetchProviderModels(Provider provider, String apiKey) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  if (provider.kind == ProviderKind.anthropic || provider.modelsPath.trim().isEmpty) {
    return ModelListResult(models: provider.models, source: provider.modelsSource, fetchedAt: now, warning: 'This provider has no model list endpoint');
  }
  if (apiKey.trim().isEmpty) {
    return ModelListResult(models: provider.models, source: provider.modelsSource, fetchedAt: now, warning: 'Add an API key first');
  }
  final url = _withKey(provider, joinUrl(provider.baseUrl, provider.modelsPath), apiKey);
  try {
    // most vendor list endpoints return bare ids, so pull models.dev in
    // before parsing and let it fill the missing windows and capabilities
    final catalog = warmCatalog();
    final data = await getJson(url, headers: authHeaders(provider, apiKey), timeout: _listTimeout);
    final raw = _pickModelArray(data);
    if (raw.isEmpty) {
      return ModelListResult(models: provider.models, source: provider.modelsSource, fetchedAt: now, warning: 'The provider returned an empty model list');
    }
    await catalog;
    final models = [for (final e in raw) _toModelMeta(e, provider.id)];
    return ModelListResult(models: mergeModels(provider, models), source: ModelSource.api, fetchedAt: now);
  } on AiError catch (e) {
    return ModelListResult(models: provider.models, source: provider.modelsSource, fetchedAt: now, warning: e.message);
  } catch (e) {
    return ModelListResult(models: provider.models, source: provider.modelsSource, fetchedAt: now, warning: e.toString());
  }
}

List<Map<String, dynamic>> _pickModelArray(Object? data) {
  if (data is List) return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  if (data is Map) {
    for (final key in const ['data', 'models', 'result', 'items']) {
      final value = data[key];
      if (value is List) return value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
  }
  return const [];
}

ModelMeta _toModelMeta(Map<String, dynamic> entry, String providerId) {
  final id = entry['id'] as String? ?? entry['name'] as String? ?? '';
  final top = entry['top_provider'];
  // open router reports the usable window in top_provider
  final context = (top is Map ? (top['context_length'] as num?)?.toInt() : null) ?? (entry['context_length'] as num?)?.toInt() ?? 0;
  return enrich(
    ModelMeta(
      id: id,
      name: entry['display_name'] as String? ?? entry['name'] as String? ?? id,
      contextWindow: context,
      maxOutput: 0,
      vision: false,
      textToImage: false,
      reasoning: false,
      source: ModelSource.api,
    ),
    providerId,
  );
}