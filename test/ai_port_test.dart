import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/data/ai/adapter.dart';
import 'package:paradise/data/ai/compaction.dart';
import 'package:paradise/data/ai/content.dart';
import 'package:paradise/data/ai/errors.dart';
import 'package:paradise/data/ai/model_id.dart';
import 'package:paradise/data/ai/model_catalog.dart';
import 'package:paradise/data/ai/provider_model.dart';
import 'package:paradise/data/ai/registry.dart';
import 'package:paradise/data/ai/segmenter.dart';
import 'package:paradise/data/ai/tokenizer.dart';

/// Serves a models.dev shaped feed through the cache seam so the remote
/// lookup path can be exercised without the network.
///
/// The version marker must match what the registry writes, otherwise the cache
/// is treated as unreadable and refetched.
void seedRemoteCatalog(Map<String, dynamic> feed) {
  resetCatalog();
  AiRegistryCache.reader = () => jsonEncode({'v': 2, 'at': DateTime.now().millisecondsSinceEpoch, 'data': feed});
  AiRegistryCache.writer = (_) {};
}

/// registry memoises the feed in a module global, so it has to be re-primed
/// for the next test rather than leaking across them.
void resetCatalogCache() {
  resetCatalog();
  AiRegistryCache.reader = null;
  AiRegistryCache.writer = null;
}

void main() {
  group('relay providers', () {
    setUp(resetCatalog);
    tearDown(resetCatalogCache);

    // a relay is a provider models.dev has never heard of, so the lookup has to
    // find the model by id across every provider instead
    test('a relay provider still resolves the vendor model ids', () {
      for (final relay in ['My Relay', '中转站', 'relay1', 'sk-xxx']) {
        expect(enrich(emptyModel('deepseek-flash'), relay).contextWindow, 1000000, reason: relay);
        expect(enrich(emptyModel('deepseek-v4-pro'), relay).contextWindow, 1000000, reason: relay);
      }
    });

    test('relay spellings of the same id still resolve', () {
      for (final id in ['deepseek/deepseek-flash', 'DeepSeek_Flash', 'deepseek_flash', 'deepseek-flash-latest']) {
        expect(enrich(emptyModel(id), 'relay').contextWindow, 1000000, reason: id);
      }
    });

    test('the vendor entry wins over a relay that caps the window', () {
      // models.dev lists deepseek-flash under both deepseek and 302ai with
      // different output limits, and the vendor number describes the model
      final out = enrich(emptyModel('deepseek-flash'), 'relay');
      expect(out.maxOutput, 393216);
      expect(out.reasoning, isTrue);
    });

    test('a model no provider lists stays unknown', () {
      expect(enrich(emptyModel('deepseek-chatty'), 'relay').contextWindow, 0);
    });
  });

  group('tokenizer', () {
    test('cjk counts about one token per glyph', () {
      expect(estimateTokens('你好世界'), 4);
    });

    test('latin runs about four chars per token', () {
      expect(estimateTokens('abcdefgh'), 3);
    });

    test('empty text is zero', () {
      expect(estimateTokens(''), 0);
    });

    test('formatTokens uses k and m suffixes', () {
      expect(formatTokens(0), 'unknown');
      expect(formatTokens(999), '999');
      expect(formatTokens(128000), '128K');
      expect(formatTokens(1050000), '1.1M');
    });
  });

  group('errors', () {
    test('401 and 403 are auth failures', () {
      expect(classify(401, '').kind, AiErrorKind.auth);
      expect(classify(403, '').kind, AiErrorKind.auth);
    });

    test('402 is quota and 429 is rate', () {
      expect(classify(402, '').kind, AiErrorKind.quota);
      expect(classify(429, '').kind, AiErrorKind.rate);
    });

    test('5xx is a retryable server error', () {
      final e = classify(503, '');
      expect(e.kind, AiErrorKind.server);
      expect(e.retryable, isTrue);
    });

    test('auth failures are not retryable', () {
      expect(classify(401, '').retryable, isFalse);
      expect(classify(402, '').retryable, isFalse);
    });

    test('an empty response is retryable', () {
      // A model that put its whole answer in the reasoning block leaves nothing
      // visible. It has to cost a retry instead of ending the node.
      expect(AiError(AiErrorKind.empty, 'The model returned nothing').retryable, isTrue);
    });

    test('a 400 that mentions context becomes an overflow', () {
      expect(classify(400, '{"error":{"message":"maximum context length is 8192 tokens"}}').kind, AiErrorKind.contextOverflow);
    });

    test('a 400 that mentions billing becomes quota', () {
      expect(classify(400, '{"error":{"message":"insufficient credits"}}').kind, AiErrorKind.quota);
    });

    test('extractMessage digs out the nested error text', () {
      expect(extractMessage('{"error":{"message":"boom"}}'), 'boom');
      expect(extractMessage('{"message":"flat"}'), 'flat');
      expect(extractMessage('not json'), 'not json');
    });

    test('describeError covers the user facing cases', () {
      expect(describeError(AiError(AiErrorKind.auth, 'x')), contains('API key'));
      expect(describeError(AiError(AiErrorKind.quota, 'x')), contains('credit'));
      expect(describeError(AiError(AiErrorKind.aborted, 'x')), contains('stopped'));
    });
  });

  group('model id guessing', () {
    test('normalizes separators', () {
      expect(normalizeModelId('GPT_4.1'), 'gpt-4-1');
    });

    test('claude from 3.7 onwards is a reasoning model', () {
      expect(guessFromModelId('claude-3-7-sonnet').reasoning, isTrue);
      expect(guessFromModelId('claude-3-5-sonnet').reasoning, isFalse);
    });

    test('gemini from 2.5 onwards reasons', () {
      expect(guessFromModelId('gemini-2-5-pro').reasoning, isTrue);
      expect(guessFromModelId('gemini-2-0-flash').reasoning, isFalse);
    });

    test('vision families are detected', () {
      expect(guessFromModelId('gpt-4o').vision, isTrue);
      expect(guessFromModelId('gpt-3.5-turbo').vision, isFalse);
    });

    test('image models are detected', () {
      expect(guessFromModelId('dall-e-3').textToImage, isTrue);
    });
  });

  group('catalog', () {
    test('the bundled catalog is populated', () {
      expect(modelCatalog.length, greaterThan(10));
      expect(modelCatalog['openai']!.models.length, greaterThan(10));
    });

    test('openai gpt-4o carries the right capabilities', () {
      final m = modelCatalog['openai']!.models['gpt-4o']!;
      expect(m.c, 128000);
      expect(m.vision, isTrue);
      expect(m.r, isFalse);
    });
  });

  group('enrich', () {
    test('fills a bare api entry from the catalog', () {
      final bare = emptyModel('gpt-4o', 'gpt-4o');
      final out = enrich(bare, 'openai');
      expect(out.contextWindow, 128000);
      expect(out.vision, isTrue);
    });

    test('never renames the model', () {
      final renamed = enrich(emptyModel('gpt-4o', 'my alias'), 'openai');
      expect(renamed.name, 'my alias');
    });

    test('falls back to id hints for an unknown model', () {
      final out = enrich(emptyModel('some-new-vl-model'), 'custom');
      expect(out.id, 'some-new-vl-model');
    });

    test('an upstream entry with a friendly name is matched by that name', () {
      // vendors list the display name while the catalog keys on the id, so a
      // bare /models response must still resolve its window and capabilities
      final bare = ModelMeta(
        id: 'vendor-prefix/whatever-2025-01-01',
        name: 'GPT-4o',
        contextWindow: 0,
        maxOutput: 0,
        vision: false,
        textToImage: false,
        reasoning: false,
        source: ModelSource.api,
      );
      final out = enrich(bare, 'openai');
      expect(out.contextWindow, 128000);
      expect(out.vision, isTrue);
    });

    test('a name match never overwrites what the api already reported', () {
      final known = ModelMeta(
        id: 'vendor-prefix/whatever-2025-01-01',
        name: 'GPT-4o',
        contextWindow: 4096,
        maxOutput: 1024,
        vision: true,
        textToImage: false,
        reasoning: false,
        source: ModelSource.api,
      );
      final out = enrich(known, 'openai');
      expect(out.contextWindow, 4096);
      expect(out.maxOutput, 1024);
      expect(out.name, 'GPT-4o');
    });

    test('the fetched models.dev feed is consulted, not just the bundled subset', () async {
      // a provider the bundled table has never heard of
      seedRemoteCatalog({
        'acme': {
          'name': 'Acme',
          'models': {
            'acme-large': {
              'name': 'Acme Large',
              'limit': {'context': 900000, 'output': 32000},
              'modalities': {'input': ['text', 'image'], 'output': ['text']},
              'reasoning': true,
            },
          },
        },
      });
      addTearDown(resetCatalogCache);

      await warmCatalog();

      final out = enrich(emptyModel('acme-large'), 'acme');
      expect(out.contextWindow, 900000);
      expect(out.maxOutput, 32000);
      expect(out.vision, isTrue);
      expect(out.reasoning, isTrue);
    });

    test('a relay id is matched against the feed by model id, not by display name', () async {
      seedRemoteCatalog({
        'acme': {
          'name': 'Acme',
          'models': {
            'acme-large': {'name': 'Acme Large', 'limit': {'context': 512000, 'output': 16000}},
          },
        },
      });
      addTearDown(resetCatalogCache);

      await warmCatalog();

      // the relay hands out the vendor id, so it resolves by id
      expect(enrich(emptyModel('acme-large'), 'my-relay').contextWindow, 512000);
    });

    test('a display name still resolves within its own provider', () async {
      seedRemoteCatalog({
        'acme': {
          'name': 'Acme',
          'models': {
            'acme-large': {'name': 'Acme Large', 'limit': {'context': 512000, 'output': 16000}},
          },
        },
      });
      addTearDown(resetCatalogCache);

      await warmCatalog();

      // same vendor, same display name, so it is the same model even though the
      // relay spells the id differently
      expect(enrich(emptyModel('vendor-prefix/whatever-9', 'Acme Large'), 'acme').contextWindow, 512000);
    });

    test('an id no provider lists gets no invented window', () {
      expect(enrich(emptyModel('totally-made-up-xyz'), 'deepseek').contextWindow, 0);
    });

    test('a relay also resells other vendors, so the search is not provider bound', () {
      // gpt-4o is not an anthropic key, but a relay serving both still lists it
      expect(enrich(emptyModel('gpt-4o'), 'anthropic').contextWindow, 128000);
      // deepseek-chat is only keyed under openrouter
      expect(enrich(emptyModel('deepseek-chat'), 'deepseek').contextWindow, 163840);
    });

    test('ids the feed does carry resolve exactly', () {
      expect(enrich(emptyModel('gpt-4o'), 'openai').contextWindow, 128000);
      expect(enrich(emptyModel('deepseek-flash'), 'deepseek').contextWindow, 1000000);
      expect(enrich(emptyModel('deepseek-v4-pro'), 'deepseek').contextWindow, 1000000);
    });

    test('a dot or underscore in the id still matches', () {
      expect(enrich(emptyModel('deepseek-v4.flash'), 'deepseek').contextWindow, 1000000);
      expect(enrich(emptyModel('deepseek_v4_pro'), 'deepseek').contextWindow, 1000000);
    });
  });

  group('mergeModels', () {
    setUp(resetCatalog);

    ModelMeta bare(String id) => ModelMeta(
          id: id,
          name: id,
          contextWindow: 0,
          maxOutput: 0,
          vision: false,
          textToImage: false,
          reasoning: false,
          source: ModelSource.api,
        );

    test('a bare upstream list is filled from the catalog', () {
      final provider = Provider.defaults(id: 'deepseek', name: 'DeepSeek');
      final merged = mergeModels(provider, [bare('deepseek-flash'), bare('deepseek-v4-pro')]);
      for (final m in merged) {
        expect(m.contextWindow, 1000000, reason: '${m.id} gained no window');
        expect(m.maxOutput, 393216, reason: '${m.id} gained no output limit');
      }
    });

    test('zeros stored by an earlier fetch are repaired, not preserved', () {
      // this is the state that survives a restart: a previous fetch ran while
      // the catalog was unreachable and persisted contextWindow 0
      final provider = Provider.defaults(id: 'deepseek', name: 'DeepSeek', models: [bare('deepseek-flash')]);
      final merged = mergeModels(provider, [bare('deepseek-flash')]);
      expect(merged.single.contextWindow, 1000000);
    });
  });

  group('segmenter', () {
    test('splits on newline', () {
      final s = Segmenter(strip: false);
      expect(s.push('你好呀\n今天'), ['你好呀']);
      expect(s.push('怎么样？'), isEmpty);
      expect(s.flush(), ['今天怎么样？']);
    });

    test('splits on br tags', () {
      final s = Segmenter(strip: false);
      expect(s.push('第一句<br/>第二句'), ['第一句']);
      expect(s.push('<br>第三句'), ['第二句']);
      expect(s.flush(), ['第三句']);
    });

    test('length cap fires with no newline', () {
      final s = Segmenter(strip: false);
      final out = s.push('啊' * 200);
      expect(out, isNotEmpty);
      expect(out.first.length, lessThanOrEqualTo(120));
    });

    test('tiny fragments merge instead of vanishing', () {
      final s = Segmenter(strip: false);
      expect(s.push('嗯\n'), isEmpty);
      expect(s.push('好\n'), isEmpty);
      expect(s.flush(), ['嗯好']);
    });

    test('markdown is stripped in character mode', () {
      final s = Segmenter(strip: true);
      expect(s.push('**粗体**\n'), ['粗体']);
      expect(stripMarkdown('# 标题\n\n- 项目一'), contains('标题'));
      expect(stripMarkdown('```js\ncode\n```'), isNot(contains('```')));
    });

    test('human delays stay in range', () {
      for (final len in [1, 10, 40, 120]) {
        for (var i = 0; i < 30; i++) {
          final d = humanDelay('字' * len);
          expect(d, greaterThanOrEqualTo(180));
          expect(d, lessThanOrEqualTo(1700));
        }
      }
    });
  });

  group('compaction', () {
    List<HistoryItem> historyOf(int n) => List.generate(n, (i) => HistoryItem(id: 'm$i', role: i.isEven ? 'user' : 'assistant', content: 'line $i'));

    test('token estimate grows with history', () {
      expect(estimateHistoryTokens(historyOf(10)), greaterThan(estimateHistoryTokens(historyOf(2))));
    });

    test('a known window does not need compaction', () {
      expect(needsCompaction(historyOf(4), 128000, 0.75), isFalse);
    });

    test('a tiny window needs compaction', () {
      expect(needsCompaction(historyOf(400), 1000, 0.75), isTrue);
    });

    test('an unknown window never triggers compaction', () {
      expect(needsCompaction(historyOf(400), 0, 0.75), isFalse);
    });

    test('a checkpoint puts the summary ahead of the tail', () {
      final h = historyOf(10);
      final turns = assembleTurns(h, Compaction(summary: 'earlier stuff', upToMessageId: 'm4', reasoningDigest: '', createdAt: 0));
      expect(turns.first.content.first, isA<TextPart>());
      expect((turns.first.content.first as TextPart).text, contains('earlier stuff'));
      expect(turns.length, 7);
    });

    test('no checkpoint means the whole history is sent', () {
      expect(assembleTurns(historyOf(5), null).length, 5);
    });

    test('truncation never orphans a reply from its question', () {
      final turns = [
        const ChatTurn('user', []),
        const ChatTurn('assistant', []),
        const ChatTurn('user', []),
        const ChatTurn('assistant', []),
        const ChatTurn('user', []),
        const ChatTurn('assistant', []),
      ];
      final cut = truncateHistory(turns, 1);
      expect(cut.first.role, 'user');
    });

    test('truncation leaves a comfortable history alone', () {
      final turns = [const ChatTurn('user', []), const ChatTurn('assistant', [])];
      expect(truncateHistory(turns, 128000).length, 2);
    });
  });

  group('settings helpers', () {
    AiSettings sample() => AiSettings(
          providers: [
            Provider.defaults(id: 'openai', name: 'OpenAI', kind: ProviderKind.openaiResponses, baseUrl: 'https://api.openai.com/v1', builtIn: true),
            Provider.defaults(id: 'mine', name: 'Mine'),
          ],
          chain: const [
            ChainNode(id: 'n1', providerId: 'openai', modelId: 'gpt-4o'),
            ChainNode(id: 'n2', providerId: 'mine', modelId: 'local', enabled: false),
          ],
          replyMode: ReplyMode.full,
          temperature: 1,
          maxOutput: 0,
          typewriterMs: 50,
          stripMarkdownInCharacterMode: true,
          compaction: const CompactionSettings(),
        );

    test('only enabled nodes take part', () {
      expect(activeChain(sample()).length, 1);
      expect(chainReady(sample()), isTrue);
    });

    test('an empty chain is not ready', () {
      expect(chainReady(sample().copyWith(chain: const [])), isFalse);
    });

    test('providers round trip through json', () {
      final s = sample();
      final back = AiSettings.fromJson(s.toJson());
      expect(back.providers.length, 2);
      expect(back.providers[0].kind, ProviderKind.openaiResponses);
      expect(back.chain.length, 2);
      expect(back.compaction.targetChars, 1200);
    });

    test('provider kind labels survive the wire format', () {
      for (final k in ProviderKind.values) {
        expect(providerKindOf(kindWire(k)), k);
      }
    });

    test('auth style survives the wire format', () {
      for (final a in AuthStyle.values) {
        expect(authStyleOf(authWire(a)), a);
      }
    });

    test('a provider defaults to the openai compatible shape', () {
      final p = Provider.defaults(id: 'x', name: 'X');
      expect(p.kind, ProviderKind.openaiCompatible);
      expect(p.chatPath, '/chat/completions');
      expect(p.authStyle, AuthStyle.bearer);
    });

    test('built in providers can still be edited', () {
      final p = Provider.defaults(id: 'openai', name: 'OpenAI', builtIn: true);
      expect(p.builtIn, isTrue);
    });
  });

  group('cancellation', () {
    test('cancel flips the flag and wakes listeners', () {
      final c = AiCancel();
      var woke = false;
      c.addListener(() => woke = true);
      expect(c.cancelled, isFalse);
      c.cancel();
      expect(c.cancelled, isTrue);
      expect(woke, isTrue);
    });

    test('a listener added after cancel fires immediately', () {
      final c = AiCancel()..cancel();
      var woke = false;
      c.addListener(() => woke = true);
      expect(woke, isTrue);
    });

    test('cancelling twice is harmless', () {
      final c = AiCancel();
      c.cancel();
      c.cancel();
      expect(c.cancelled, isTrue);
    });
  });
}