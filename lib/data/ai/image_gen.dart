import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'errors.dart';
import 'fetcher.dart';
import 'provider_model.dart';
import 'sse.dart';

/// One picture back from an OpenAI compatible image endpoint.
///
/// The documented shape is a `data` array whose entries carry either
/// `b64_json` (what gpt-image-1 returns by default) or a short lived `url`
/// (dall-e-3 and most gateways). Both are understood because a gateway that
/// speaks the protocol may pick either, and a client that only read one would
/// look like a broken endpoint.
class GeneratedImage {
  const GeneratedImage({this.bytes, this.url, this.revisedPrompt});

  /// Decoded picture bytes, when the endpoint inlined them.
  final List<int>? bytes;

  /// Temporary download url, when the endpoint handed one out instead.
  final String? url;

  /// What the model says it actually drew. dall-e-3 rewrites the prompt, and
  /// the rewrite is usually a better caption than the one that was sent.
  final String? revisedPrompt;

  bool get isEmpty => (bytes == null || bytes!.isEmpty) && (url == null || url!.isEmpty);
}

/// Where an image request goes for this provider.
///
/// OpenAI's default is `/images/generations`. A gateway that re-homes the path
/// overrides it per provider, the same way the chat path is overridable.
String imagePathFor(Provider provider) {
  final p = provider.imagesPath.trim();
  return p.isEmpty ? '/images/generations' : p;
}

/// Asks an OpenAI compatible endpoint for one picture.
///
/// [size] is passed through verbatim: the accepted set differs per model and
/// per gateway, and guessing for the caller is how a request that would have
/// worked gets rewritten into one that does not.
Future<GeneratedImage> generateImage({
  required Provider provider,
  required String apiKey,
  required String model,
  required String prompt,
  String size = '1024x1024',
  String quality = '',
  String background = '',
  String outputFormat = '',
  AiSettings? settings,
  AiCancel? cancel,
}) async {
  final payload = <String, dynamic>{
    'model': model,
    'prompt': prompt,
    'n': 1,
    if (size.trim().isNotEmpty) 'size': size.trim(),
    if (quality.trim().isNotEmpty) 'quality': quality.trim(),
    if (background.trim().isNotEmpty) 'background': background.trim(),
    if (outputFormat.trim().isNotEmpty) 'output_format': outputFormat.trim(),
  };

  // the same transport the chat path uses, so auth styles, the global headers
  // and the abort token all behave identically here
  final live = await postJson(
    joinUrl(provider.baseUrl, imagePathFor(provider)),
    headers: authHeaders(provider, apiKey, settings: settings),
    body: payload,
    timeout: const Duration(seconds: 180),
    cancel: cancel,
  );
  final text = await _drain(live);
  return _parse(text);
}

/// Reads a whole non streaming json body off a live response.
Future<String> _drain(Live live) async {
  try {
    return (await live.response.stream.bytesToString()).trim();
  } finally {
    live.close();
  }
}

GeneratedImage _parse(String text) {
  Object? decoded;
  try {
    decoded = jsonDecode(text);
  } catch (_) {
    throw AiError(AiErrorKind.server, 'The image endpoint did not answer with json.', 0);
  }
  if (decoded is! Map) {
    throw AiError(AiErrorKind.server, 'The image endpoint did not answer with a json object.', 0);
  }
  final data = decoded['data'];
  if (data is! List || data.isEmpty) {
    // an error object delivered under a 200 is a real thing gateways do
    final err = decoded['error'];
    if (err is Map && err['message'] is String) {
      throw AiError(AiErrorKind.badRequest, '${err['message']}', 0);
    }
    throw AiError(AiErrorKind.empty, 'The image endpoint returned no image.', 0);
  }
  final first = data.first;
  if (first is! Map) {
    throw AiError(AiErrorKind.server, 'The image endpoint returned a malformed entry.', 0);
  }
  final b64 = first['b64_json'];
  if (b64 is String && b64.isNotEmpty) {
    return GeneratedImage(
      bytes: base64Decode(b64),
      revisedPrompt: first['revised_prompt'] as String?,
    );
  }
  final url = first['url'];
  if (url is String && url.isNotEmpty) {
    return GeneratedImage(url: url, revisedPrompt: first['revised_prompt'] as String?);
  }
  throw AiError(AiErrorKind.empty, 'The image endpoint returned neither b64_json nor url.', 0);
}

/// Downloads the bytes of a picture the endpoint handed out as a url.
Future<List<int>> downloadImage(String url, {AiCancel? cancel}) async {
  final client = http.Client();
  cancel?.addListener(client.close);
  try {
    final res = await client.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
      throw AiError(AiErrorKind.network, 'Could not download the picture (${res.statusCode}).', res.statusCode);
    }
    return res.bodyBytes;
  } on AiError {
    rethrow;
  } catch (e) {
    if (cancel?.cancelled ?? false) throw AiError(AiErrorKind.aborted, 'Stopped', 0);
    throw toAiError(e);
  } finally {
    cancel?.removeListener(client.close);
    client.close();
  }
}
