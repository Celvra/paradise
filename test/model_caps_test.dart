import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/ai/model_id.dart';
import 'package:paradise/data/ai/provider_model.dart';
import 'package:paradise/data/ai/registry.dart';

ModelMeta _m(String id, {bool vision = false, bool video = false}) => ModelMeta(
      id: id,
      name: id,
      contextWindow: 100000,
      maxOutput: 8000,
      vision: vision,
      textToImage: false,
      reasoning: false,
      source: ModelSource.manual,
      video: video,
    );

AiSettings _settings(List<ModelMeta> models, List<ChainNode> chain) => AiSettings(
      providers: [Provider.defaults(id: 'p1', name: 'P1', models: models)],
      chain: chain,
      replyMode: ReplyMode.full,
      temperature: 1,
      maxOutput: 0,
      firstBubbleDelayMs: 0,
      bubbleGapScale: 1,
      pacingJitter: 0.35,
      stripMarkdownInCharacterMode: false,
      compaction: const CompactionSettings(),
    );

void main() {
  test('video flag survives the settings json round trip', () {
    final m = _m('gemini-x', vision: true, video: true);
    final back = ModelMeta.fromJson(jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);
    expect(back.video, isTrue);
    expect(back.vision, isTrue);
    // absent flag defaults to false so older settings blobs keep loading
    final legacy = ModelMeta.fromJson({'id': 'old', 'name': 'old', 'c': 100, 'max': 10, 'vision': true, 't2i': false, 'r': false, 'source': 'manual'});
    expect(legacy.video, isFalse);
  });

  test('chainCaps unions the enabled nodes and skips disabled ones', () {
    final s = _settings([
      _m('text-only'),
      _m('vision-model', vision: true),
      _m('av-model', vision: true, video: true),
    ], [
      ChainNode(id: 'n1', providerId: 'p1', modelId: 'text-only'),
      ChainNode(id: 'n2', providerId: 'p1', modelId: 'vision-model', enabled: false),
      ChainNode(id: 'n3', providerId: 'p1', modelId: 'av-model'),
    ]);
    final caps = chainCaps(s, s.chain);
    expect(caps.vision, isTrue);
    expect(caps.video, isTrue);
    // the disabled vision node alone must not widen the union
    final caps2 = chainCaps(s, [s.chain[0], s.chain[1]]);
    expect(caps2.any, isFalse);
  });

  test('chainCaps is empty when the chain is empty or unknown', () {
    final s = _settings([_m('m')], const []);
    expect(chainCaps(s, const []).any, isFalse);
    final s2 = _settings([], [const ChainNode(id: 'n', providerId: 'p1', modelId: 'missing')]);
    expect(chainCaps(s2, s2.chain).any, isFalse);
  });

  test('gemini ids guess video, image generation variants do not', () {
    expect(guessFromModelId('gemini-2.5-flash').video, isTrue);
    expect(guessFromModelId('gemini-3-pro').video, isTrue);
    expect(guessFromModelId('gemini-3.1-flash-image-preview').video, isFalse);
    expect(guessFromModelId('gpt-4o').video ?? false, isFalse);
    expect(guessFromModelId('deepseek-chat').vision ?? false, isFalse);
  });

  test('deepseek v4.1 and qwen vl/omni ids guess video', () {
    expect(guessFromModelId('deepseek-v4.1-flash').video, isTrue);
    expect(guessFromModelId('deepseek-v4p1-flash').video, isTrue);
    expect(guessFromModelId('deepseek-v4.1-flash').vision, isTrue);
    // v4 flash is image-vision only, no video understanding
    expect(guessFromModelId('deepseek-v4-flash').video ?? false, isFalse);
    expect(guessFromModelId('qwen2.5-vl-72b-instruct').video, isTrue);
    expect(guessFromModelId('qwen3-vl-plus').video, isTrue);
    expect(guessFromModelId('qwen3-omni-flash').video, isTrue);
    expect(guessFromModelId('qwen-plus').video ?? false, isFalse);
  });

  test('bundled catalog marks deepseek v4.1 flash video', () {
    // no warmed remote: the lookup must fall through to the bundled subset
    resetCatalog();
    final flash = enrich(_m('deepseek-flash'), 'deepseek');
    expect(flash.vision, isTrue);
    expect(flash.video, isTrue);
    final v4 = enrich(_m('deepseek-v4-flash'), 'deepseek');
    expect(v4.vision, isTrue);
    expect(v4.video, isFalse);
  });

  test('enrich fills video from the models.dev feed', () async {
    final feed = jsonEncode({
      'v': 2,
      'at': DateTime.now().millisecondsSinceEpoch,
      'data': {
        'google': {
          'name': 'Google',
          'models': {
            'gemini-test-v1': {
              'name': 'Gemini Test',
              'modalities': {'input': ['text', 'image', 'video'], 'output': ['text']},
              'limit': {'context': 1000000, 'output': 64000},
            },
          },
        },
      },
    });
    AiRegistryCache.reader = () => feed;
    AiRegistryCache.writer = (_) {};
    addTearDown(() {
      AiRegistryCache.reader = null;
      AiRegistryCache.writer = null;
      resetCatalog();
    });
    await warmCatalog();
    final meta = enrich(emptyModel('gemini-test-v1'), 'google');
    expect(meta.vision, isTrue);
    expect(meta.video, isTrue);
    expect(meta.contextWindow, 1000000);
  });

  test('the feed cannot strip video from deepseek v4.1 flash', () async {
    // models.dev lists deepseek-flash as text+image only, but the official
    // API takes native video: the registry must not let the feed block a
    // capability the provider ships
    final feed = jsonEncode({
      'v': 2,
      'at': DateTime.now().millisecondsSinceEpoch,
      'data': {
        'deepseek': {
          'name': 'DeepSeek',
          'models': {
            'deepseek-flash': {
              'name': 'DeepSeek V4.1 Flash',
              'modalities': {'input': ['text', 'image'], 'output': ['text']},
              'limit': {'context': 1000000, 'output': 393216},
            },
          },
        },
      },
    });
    AiRegistryCache.reader = () => feed;
    AiRegistryCache.writer = (_) {};
    addTearDown(() {
      AiRegistryCache.reader = null;
      AiRegistryCache.writer = null;
      resetCatalog();
    });
    await warmCatalog();
    final flash = enrich(emptyModel('deepseek-flash'), 'deepseek');
    expect(flash.vision, isTrue);
    expect(flash.video, isTrue, reason: 'deepseek v4.1 flash takes native video input');
    final viaRouter = enrich(emptyModel('deepseek/deepseek-v4.1-flash'), 'openrouter');
    expect(viaRouter.video, isTrue);
  });
}
