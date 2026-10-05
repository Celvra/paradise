import 'errors.dart';
import 'provider_model.dart';
import 'registry.dart';
import 'sse.dart';

import '../../app_info.dart' show defaultUserAgent;

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

// header assembly, one place so every request shape stays consistent:
// global headers, then the provider's own, then auth, then the session pin,
// then the user agent. Later and more specific entries win on a repeated
// name, compared case insensitively as http header names are.
Map<String, String> authHeaders(Provider provider, String apiKey, {AiSettings? settings, String? sessionId}) {
  final headers = <String, String>{};
  void put(String key, String value) {
    headers.removeWhere((k, _) => k.toLowerCase() == key.toLowerCase());
    headers[key] = value;
  }

  for (final h in settings?.globalHeaders ?? const <KeyValue>[]) {
    if (h.key.trim().isNotEmpty) put(h.key.trim(), h.value);
  }
  var providerUa = false;
  for (final h in provider.extraHeaders) {
    final key = h.key.trim();
    if (key.isEmpty) continue;
    if (key.toLowerCase() == 'user-agent') providerUa = true;
    put(key, h.value);
  }
  if (apiKey.isNotEmpty) {
    switch (provider.authStyle) {
      case AuthStyle.xApiKey:
        put('x-api-key', apiKey);
      case AuthStyle.bearer:
        put('Authorization', 'Bearer $apiKey');
      case AuthStyle.queryKey:
        break;
    }
  }
  final pin = provider.sessionHeader.trim();
  final id = sessionId?.trim() ?? '';
  // an explicitly configured header wins over the automatic pin
  if (pin.isNotEmpty && id.isNotEmpty && !headers.keys.any((k) => k.toLowerCase() == pin.toLowerCase())) {
    put(pin, id);
  }
  // the user agent follows the same rule as every other header: the more
  // specific wins. The provider's own setting beats a User-Agent in the
  // provider's list, which beats the global setting, which beats one in the
  // global list, which beats the app default.
  final ownUa = provider.userAgent.trim();
  final globalUa = settings?.userAgent.trim() ?? '';
  if (ownUa.isNotEmpty) {
    put('User-Agent', ownUa);
  } else if (providerUa) {
    // already carried by the provider's own header list
  } else if (globalUa.isNotEmpty) {
    put('User-Agent', globalUa);
  } else if (!headers.keys.any((k) => k.toLowerCase() == 'user-agent')) {
    put('User-Agent', defaultUserAgent);
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
Future<ModelListResult> fetchProviderModels(Provider provider, String apiKey, {AiSettings? settings}) async {
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
    final data = await getJson(url, headers: authHeaders(provider, apiKey, settings: settings), timeout: _listTimeout);
    final raw = _pickModelArray(data);
    if (raw.isEmpty) {
      return ModelListResult(models: provider.models, source: provider.modelsSource, fetchedAt: now, warning: 'The provider returned an empty model list');
    }
    await catalog;
    final models = [for (final e in raw) _toModelMeta(e, provider.id, crossProvider: !provider.relay)];
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

ModelMeta _toModelMeta(Map<String, dynamic> entry, String providerId, {bool crossProvider = true}) {
  final id = entry['id'] as String? ?? entry['name'] as String? ?? '';
  final top = entry['top_provider'];
  // open router reports the usable window in top_provider
  final context = (top is Map ? (top['context_length'] as num?)?.toInt() : null) ?? (entry['context_length'] as num?)?.toInt() ?? 0;
  // a blind-test relay declares `auto` with no window at all; a fixed modest
  // default beats both a zero the picker cannot render and the 2M an
  // OpenRouter id collision would hand over
  final safeContext = context == 0 && id == 'auto' ? 128000 : context;
  final caps = entry['capabilities'];
  return enrich(
    ModelMeta(
      id: id,
      name: entry['display_name'] as String? ?? entry['name'] as String? ?? id,
      contextWindow: safeContext,
      maxOutput: (entry['max_output_tokens'] as num?)?.toInt() ?? 0,
      vision: caps is Map && caps['attachment'] == true,
      textToImage: false,
      reasoning: caps is Map && caps['reasoning'] == true,
      source: ModelSource.api,
    ),
    providerId,
    crossProvider: crossProvider,
  );
}