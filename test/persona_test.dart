import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/data/ai_config.dart';
import 'package:paradise/data/ai/adapter.dart';
import 'package:paradise/data/ai/content.dart';
import 'package:paradise/data/ai/prompt.dart';
import 'package:paradise/data/ai/provider_model.dart';
import 'package:paradise/main.dart';
import 'package:paradise/core/provider_icons.dart';
import 'package:paradise/l10n/gen/l10n_en.dart';
import 'package:paradise/ui/persona_card.dart';
import 'package:paradise/ui/user_persona.dart';

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

PromptInput input({String desc = 'a tester', PersonaPosition pos = PersonaPosition.inPrompt, String bio = ''}) => PromptInput(
      personaName: 'Assistant',
      personaPrompt: 'You are helpful.',
      personaBio: '',
      userName: 'Ada',
      userBio: bio,
      userDescription: desc,
      userPosition: pos,
      replyMode: ReplyMode.full,
    );

void main() {
  group('persona cards in the store', () {
    test('a fresh install has no card and falls back to You', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      expect(st.personas, isEmpty);
      expect(st.userName, 'You');
      expect(st.userAvatar, '');
    });

    test('legacy name bio and photo migrate into the first card', () async {
      SharedPreferences.setMockInitialValues({'userName': 'Ada', 'userBio': '28, coder', 'userAvatar': '/tmp/a.png'});
      final st = await Store.load();
      expect(st.personas.length, 1);
      expect(st.activePersona.name, 'Ada');
      expect(st.activePersona.description, '28, coder');
      expect(st.activePersona.avatarPath, '/tmp/a.png');
      expect(st.isDefault(st.activePersona.id), true);
      expect(st.userName, 'Ada');
    });

    test('name and avatar follow the card in hand', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final a = st.createPersonaCard(name: 'Ada');
      st.updatePersonaCard(a.id, (p) => p.avatarPath = '/tmp/a.png');
      expect(st.userName, 'Ada');
      expect(st.userAvatar, '/tmp/a.png');

      st.createPersonaCard(name: 'Blaze');
      expect(st.userName, 'Blaze');
      expect(st.userAvatar, '');
      st.selectPersona(a.id);
      expect(st.userName, 'Ada');
      expect(st.userAvatar, '/tmp/a.png');
    });

    test('cards survive a reload', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final a = st.createPersonaCard(name: 'Ada');
      st.updatePersonaCard(a.id, (p) => p.description = 'long text');
      final b = st.createPersonaCard(name: 'Blaze');
      st.toggleDefaultPersona(a.id);
      st.selectPersona(a.id);

      final st2 = await Store.load();
      expect(st2.personas.length, 2);
      expect(st2.personas.firstWhere((p) => p.id == a.id).description, 'long text');
      expect(st2.activePersona.id, a.id);
      expect(st2.isDefault(a.id), true);
      expect(st2.personas.any((p) => p.id == b.id), true);
    });

    test('duplicate copies the body and picks the copy', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final a = st.createPersonaCard(name: 'Ada', description: 'a tester');
      st.updatePersonaCard(a.id, (p) => p.position = PersonaPosition.bottomNote);
      final copy = st.duplicatePersonaCard(a.id);
      expect(copy.name, 'Ada copy');
      expect(copy.description, 'a tester');
      expect(copy.position, PersonaPosition.bottomNote);
      expect(st.activePersona.id, copy.id);
    });

    test('deleting drops every lock pointing at the card', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final chat = st.createChat('Assistant', 'be helpful');
      final a = st.createPersonaCard(name: 'Ada');
      final b = st.createPersonaCard(name: 'Blaze');
      st.toggleDefaultPersona(a.id);
      st.toggleChatLock(chat, a.id);
      st.toggleCharLock('Assistant', b.id);

      st.deletePersonaCard(a.id);
      expect(st.personas.length, 1);
      expect(st.isDefault(a.id), false);
      expect(chat.personaId, isNull);
      st.deletePersonaCard(b.id);
      expect(st.charLocks.containsKey('Assistant'), false);
    });
  });

  group('persona resolution order', () {
    test('chat lock beats character lock beats the card in hand', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final chat = st.createChat('Assistant', 'be helpful');
      final a = st.createPersonaCard(name: 'Ada');
      st.createPersonaCard(name: 'Blaze');
      final c = st.createPersonaCard(name: 'Cass');
      final b = st.personas[1];

      st.selectPersona(a.id);
      expect(st.personaFor(chat).name, 'Ada');

      st.toggleCharLock('Assistant', b.id);
      expect(st.personaFor(chat).name, 'Blaze');

      st.toggleChatLock(chat, c.id);
      expect(st.personaFor(chat).name, 'Cass');

      st.toggleChatLock(chat, c.id);
      expect(st.personaFor(chat).name, 'Blaze');
    });

    test('a lock on a deleted chat never applies', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final chat = st.createChat('Assistant', 'be helpful');
      final a = st.createPersonaCard(name: 'Ada');
      st.createPersonaCard(name: 'Blaze');
      st.toggleChatLock(chat, a.id);
      st.deletePersonaCard(a.id);
      expect(st.personaFor(chat).name, 'Blaze');
    });

    test('default is used when nothing is locked', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final chat = st.createChat('Assistant', 'be helpful');
      final a = st.createPersonaCard(name: 'Ada');
      final b = st.createPersonaCard(name: 'Blaze');
      st.toggleDefaultPersona(a.id);
      st.deletePersonaCard(a.id);
      st.selectPersona(b.id);
      st.deletePersonaCard(b.id);
      // both gone, the store must still answer with something
      expect(st.personaFor(chat).name, 'You');
    });
  });

  group('per persona model override', () {
    /// a store with one provider holding a key and a two node chain
    Future<Store> withChain() async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final ai = await AiConfig.load();
      ai.update((s) => s.copyWith(
            providers: [
              Provider.defaults(id: 'p1', name: 'P1', models: [emptyModel('m1')]),
              Provider.defaults(id: 'p2', name: 'P2', models: [emptyModel('m2')]),
            ],
            chain: const [
              ChainNode(id: 'n1', providerId: 'p1', modelId: 'm1', enabled: true),
              ChainNode(id: 'n2', providerId: 'p2', modelId: 'm2', enabled: true),
            ],
          ));
      ai.saveApiKey('p1', 'k1');
      ai.saveApiKey('p2', 'k2');
      st.attachAi(ai);
      return st;
    }

    test('no override means the chain runs untouched', () async {
      final st = await withChain();
      final chat = st.createChat('Assistant', 'be helpful');
      expect(chat.persona.hasModelOverride, false);
      expect(chat.persona.modelLabel, 'Global');
      expect(st.chainFor(chat).map((n) => n.id), ['n1', 'n2']);
    });

    test('an override leads the chain, the rest stays as fallback', () async {
      final st = await withChain();
      final chat = st.createChat('Assistant', 'be helpful', modelProvider: 'p2', modelId: 'm2');
      expect(chat.persona.modelLabel, 'm2');
      final nodes = st.chainFor(chat);
      expect(nodes.first.modelId, 'm2');
      // m2 is on the chain already, so it must not be tried twice
      expect(nodes.map((n) => n.modelId), ['m2', 'm1']);
    });

    test('the switch off leaves the override standing alone', () async {
      final st = await withChain();
      final chat = st.createChat('Assistant', 'be helpful', modelProvider: 'p2', modelId: 'm2', modelFallback: false);
      expect(st.chainFor(chat).map((n) => n.modelId), ['m2']);
    });

    test('an override on a different model keeps the whole chain behind it', () async {
      final st = await withChain();
      st.aiConfig.patchProvider('p2', (p) => p.models = [emptyModel('m2'), emptyModel('m2-turbo')]);
      final chat = st.createChat('Assistant', 'be helpful', modelProvider: 'p2', modelId: 'm2-turbo');
      expect(st.chainFor(chat).map((n) => n.modelId), ['m2-turbo', 'm1', 'm2']);
    });

    test('an override works with an empty chain', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Store.load();
      final ai = await AiConfig.load();
      ai.update((s) => s.copyWith(providers: [Provider.defaults(id: 'p1', name: 'P1', models: [emptyModel('m1')])]));
      ai.saveApiKey('p1', 'k1');
      st.attachAi(ai);

      final chat = st.createChat('Assistant', 'be helpful', modelProvider: 'p1', modelId: 'm1');
      expect(ai.ready, false);
      expect(st.chainFor(chat).map((n) => n.modelId), ['m1']);
    });

    test('a half finished pick counts as no override at all', () async {
      final st = await withChain();
      final chat = st.createChat('Assistant', 'be helpful', modelProvider: 'p2');
      expect(chat.persona.hasModelOverride, false);
      expect(chat.persona.modelLabel, 'Global');
      expect(st.chainFor(chat).map((n) => n.id), ['n1', 'n2']);
    });

    test('one persona overriding leaves the others on the chain', () async {
      final st = await withChain();
      final a = st.createChat('Assistant', 'be helpful', modelProvider: 'p2', modelId: 'm2');
      final b = st.createChat('Coder', 'write code');
      expect(st.chainFor(b).map((n) => n.id), ['n1', 'n2']);
      expect(st.chainFor(a).first.modelId, 'm2');
    });

    test('the override survives a reload and an edit round trip', () async {
      final st = await withChain();
      st.createChat('Coder', 'write code', modelProvider: 'p2', modelId: 'm2', modelFallback: false);
      // chats are written through a 400ms debounce
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final st2 = await Store.load();
      final chat = st2.chats.firstWhere((c) => c.persona.name == 'Coder');
      expect(chat.persona.hasModelOverride, true);
      expect(chat.persona.modelId, 'm2');
      expect(chat.persona.modelFallback, false);

      st2.editPersona(chat, 'Assistant', 'still helpful', modelProvider: 'p1', modelId: 'm1');
      expect(chat.persona.modelId, 'm1');
      // the fallback switch is left alone when an edit does not mention it
      expect(chat.persona.modelFallback, false);
    });

    test('a chat saved before the feature reads as following the chain', () async {
      final p = Persona.fromJson({'name': 'Assistant', 'prompt': 'x', 'color': 1});
      expect(p.hasModelOverride, false);
      expect(p.modelLabel, 'Global');
      // forgiving by default so an old persona keeps answering on the first error
      expect(p.modelFallback, true);
    });
  });

  group('provider logos', () {
    test('the six shipped providers all have a logo', () {
      // the seeded list is what a fresh install shows, none may fall back
      for (final id in ['OpenAI', 'Anthropic', 'Google Gemini', 'DeepSeek', 'OpenRouter', 'SiliconFlow']) {
        expect(provFor(id), isNotNull, reason: id);
      }
      expect(provFor('OpenAI'), Prov.openai);
      expect(provFor('Anthropic'), Prov.anthropic);
      expect(provFor('Google Gemini'), Prov.gemini);
      expect(provFor('DeepSeek'), Prov.deepseek);
      expect(provFor('OpenRouter'), Prov.openrouter);
      expect(provFor('SiliconFlow'), Prov.siliconflow);
    });

    test('the name is matched case insensitively', () {
      expect(provFor('openai'), Prov.openai);
      expect(provFor('ANTHROPIC'), Prov.anthropic);
      expect(provFor('sIlIcOnFlOw'), Prov.siliconflow);
    });

    test('a model name alone is enough', () {
      expect(provFor('claude-sonnet-4'), Prov.anthropic);
      expect(provFor('gpt-4o'), Prov.openai);
      expect(provFor('gemini-2.5-pro'), Prov.gemini);
    });

    test('a broad rule never steals a specific one', () {
      // o1 and o3 look like OpenAI but "o1" must not be read as xAI
      expect(provFor('o3-mini'), Prov.openai);
      expect(provFor('Grok 4'), Prov.xai);
      // a Claude endpoint behind an OpenAI compatible relay still reads Claude
      expect(provFor('My Claude Relay'), Prov.anthropic);
    });

    test('a custom provider falls back to its endpoint', () {
      // the name says nothing at all, the base url still does
      expect(provFor('Relay', 'https://api.groq.com/openai/v1'), Prov.groq);
      expect(provFor('', 'https://openrouter.ai/api/v1'), Prov.openrouter);
      expect(provFor('Mine', 'http://192.168.1.5:8080/v1'), isNull);
    });

    test('an unrecognisable provider gets the initial instead', () {
      expect(provFor('My Relay', 'http://192.168.1.5:8080/v1'), isNull);
      expect(provFor(''), isNull);
      expect(provFor(null), isNull);
    });

    test('every brand has its svg actually on disk', () {
      // a name in the table with no file would render as an empty tile at
      // runtime, which no unit test on the matching would ever catch
      for (final prov in Prov.values) {
        final f = File(provAsset(prov));
        expect(f.existsSync(), isTrue, reason: '${provAsset(prov)} is declared but not bundled');
        expect(f.readAsStringSync(), contains('<svg'), reason: provAsset(prov));
      }
    });
  });

  testWidgets('a provider with no logo falls back to its initial', (t) async {
    SharedPreferences.setMockInitialValues({});
    final store = await Store.load();
    final ai = await AiConfig.load();
    store.attachAi(ai);
    // the tests drive in-app screens, not the wizard
    store.onboarded = true;
    await t.pumpWidget(TgApp(store: store, ai: ai));
    await settle(t);

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);

    // the six shipped providers are all logos, so no stray initial appears
    expect(find.byType(ProviderAvatar), findsWidgets);
    // a custom relay named "Zebra" draws the Z because nothing matches it
    ai.addProvider(Provider.defaults(id: 'zebra', name: 'Zebra', baseUrl: 'http://10.0.0.2:8080/v1'));
    await settle(t, 500);
    expect(find.text('Z'), findsOneWidget);
  });

  group('position in the system prompt', () {
    test('none keeps the card out of the request', () {
      final s = buildSystemPrompt(input(desc: 'a tester', pos: PersonaPosition.none));
      expect(s.contains('a tester'), false);
    });

    test('in prompt folds into the blurb slot', () {
      final s = buildSystemPrompt(input(desc: 'a tester', pos: PersonaPosition.inPrompt, bio: 'short'));
      expect(s.contains('About them:\nshort\n\na tester'), true);
    });

    test('top note goes ahead of everything', () {
      final s = buildSystemPrompt(input(desc: 'a tester', pos: PersonaPosition.topNote));
      expect(s.startsWith('About the person you are talking to:\na tester'), true);
    });

    test('bottom note goes last', () {
      final s = buildSystemPrompt(input(desc: 'a tester', pos: PersonaPosition.bottomNote));
      expect(s.trimRight().endsWith('About the person you are talking to:\na tester'), true);
    });

    test('at depth is left out of the system prompt', () {
      final s = buildSystemPrompt(input(desc: 'a tester', pos: PersonaPosition.atDepth));
      expect(s.contains('a tester'), false);
    });

    test('an empty card adds nothing in any position', () {
      for (final pos in PersonaPosition.values) {
        expect(buildSystemPrompt(input(desc: '   ', pos: pos)).contains('About the person'), false);
      }
    });
  });

  group('in chat depth injection', () {
  List<ChatTurn> chat(int n) => [
        for (var i = 0; i < n; i++) ChatTurn(i.isEven ? 'user' : 'assistant', [TextPart('m$i')]),
      ];

  String textOf(ChatTurn t) => (t.content.first as TextPart).text;

  /// index of the injected turn, found by its body rather than by arithmetic
  int where(List<ChatTurn> turns) => turns.indexWhere((t) => textOf(t) == 'CARD');

  test('the turn count grows by exactly one', () {
    for (final d in [1, 2, 3, 5]) {
      expect(injectPersonaDepth(chat(6), 'CARD', depth: d, role: PersonaRole.system).length, 7, reason: 'depth $d');
    }
  });

  test('depth 1 lands near the end of the chat', () {
    final t = injectPersonaDepth(chat(4), 'CARD', depth: 1, role: PersonaRole.system);
    expect(where(t), greaterThanOrEqualTo(3));
    expect(t.map(textOf).toList(), ['m0', 'm1', 'm2', 'CARD', 'm3']);
  });

  test('a deeper depth lands further back', () {
    final near = where(injectPersonaDepth(chat(10), 'CARD', depth: 1, role: PersonaRole.system));
    final mid = where(injectPersonaDepth(chat(10), 'CARD', depth: 5, role: PersonaRole.system));
    expect(mid, lessThan(near));
  });

  test('the card never opens right after an assistant turn', () {
    // whatever the depth, the turn preceding the card must not be a reply,
    // otherwise the model reads the card as part of its own last answer
    for (var d = 1; d <= 5; d++) {
      final t = injectPersonaDepth(chat(10), 'CARD', depth: d, role: PersonaRole.system);
      final i = where(t);
      if (i > 0) expect(t[i - 1].role, 'user', reason: 'depth $d landed right after an assistant turn');
    }
  });

  test('the relative order of the real messages survives', () {
    final t = injectPersonaDepth(chat(6), 'CARD', depth: 3, role: PersonaRole.system);
    expect(t.map(textOf).where((x) => x != 'CARD').toList(), ['m0', 'm1', 'm2', 'm3', 'm4', 'm5']);
  });

  test('a depth past the start clamps without ever trailing a reply', () {
    for (final n in [1, 2, 3, 4, 5, 10]) {
      final t = injectPersonaDepth(chat(n), 'CARD', depth: 999, role: PersonaRole.system);
      expect(t.length, n + 1, reason: 'n=$n');
      final i = where(t);
      if (i > 0) expect(t[i - 1].role, 'user', reason: 'n=$n');
    }
    // clamped to the start, the card lands before the very first answer
    expect(where(injectPersonaDepth(chat(4), 'CARD', depth: 999, role: PersonaRole.system)), 1);
  });

  test('depth below one still injects', () {
    expect(injectPersonaDepth(chat(3), 'CARD', depth: 0, role: PersonaRole.system).length, 4);
  });

  test('an empty history and an empty body are both no ops', () {
    expect(injectPersonaDepth([], 'CARD', depth: 2, role: PersonaRole.system), isEmpty);
    expect(injectPersonaDepth(chat(3), '   ', depth: 2, role: PersonaRole.system).length, 3);
  });

  test('the role travels through as chosen', () {
    for (final r in PersonaRole.values) {
      final t = injectPersonaDepth(chat(4), 'CARD', depth: 2, role: r);
      expect(t[where(t)].role, r.name, reason: r.name);
    }
  });

  test('the injected turn carries no source id so attachments skip it', () {
    final t = injectPersonaDepth(chat(4), 'CARD', depth: 2, role: PersonaRole.system);
    expect(t[where(t)].sourceId, isNull);
  });

  test('every original turn keeps its source id', () {
    final turns = [
      ChatTurn('user', [TextPart('m0')], sourceId: 'm0'),
      ChatTurn('assistant', [TextPart('m1')], sourceId: 'm1'),
      ChatTurn('user', [TextPart('m2')], sourceId: 'm2'),
      ChatTurn('assistant', [TextPart('m3')], sourceId: 'm3'),
    ];
    final t = injectPersonaDepth(turns, 'CARD', depth: 2, role: PersonaRole.system);
    expect([for (final e in t) e.sourceId].where((e) => e != null).toList(), ['m0', 'm1', 'm2', 'm3']);
  });
});

group('macros in the card', () {
  test('user and char expand before the prompt', () {
    expect(expandMacros('{{user}} talks to {{char}}', 'Ava', 'Ada'), 'Ada talks to Ava');
  });

  test('every spelling resolves', () {
    expect(expandMacros('{{me}} / {{user}}', 'A', 'Ada'), 'Ada / Ada');
    expect(expandMacros('{{persona}} / {{ai}} / {{char}}', 'Ava', 'Ada'), 'Ava / Ava / Ava');
  });

  test('matching ignores case', () {
    expect(expandMacros('{{USER}} {{Char}}', 'Ava', 'Ada'), 'Ada Ava');
  });

  test('text with no macro is untouched', () {
    expect(expandMacros('plain body', 'Ava', 'Ada'), 'plain body');
  });
});

group('card persistence shape', () {    test('an unknown position or role falls back instead of throwing', () {
      final p = UserPersona.fromJson({'id': 'x', 'name': 'Ada', 'position': 'fromTheFuture', 'role': 'nope'});
      expect(p.position, PersonaPosition.inPrompt);
      expect(p.role, PersonaRole.system);
      expect(p.depth, 2);
    });

    test('a round trip keeps every field', () {
      final p = UserPersona(id: 'a', name: 'Ada', title: 'dev', description: 'body', avatarPath: '/x.png', color: 3, position: PersonaPosition.atDepth, depth: 5, role: PersonaRole.user);
      final back = UserPersona.fromJson(p.toJson());
      expect(back.id, 'a');
      expect(back.title, 'dev');
      expect(back.position, PersonaPosition.atDepth);
      expect(back.depth, 5);
      expect(back.role, PersonaRole.user);
    });
  });

  testWidgets('the account page hosts the persona cards', (t) async {
    SharedPreferences.setMockInitialValues({});
    // tall enough that the whole section builds at once, no scrolling needed
    t.view.physicalSize = const Size(1080, 4400);
    t.view.devicePixelRatio = 2.75;
    final store = await Store.load();
    final ai = await AiConfig.load();
    store.attachAi(ai);
    // the tests drive in-app screens, not the wizard
    store.onboarded = true;
    await t.pumpWidget(TgApp(store: store, ai: ai));
    await settle(t);

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('My Account'));
    await settle(t, 800);

    // nothing saved yet, so the empty state with the create button. The wording
    // is read off the english table so a rename in the arb cannot rot this test.
    final l = AppLocalizationsEn();
    expect(find.text(l.cardEmptyTitle), findsOneWidget);
    await t.tap(find.text(l.cardCreate));
    await settle(t, 800);
    expect(store.personas.length, 1);
    expect(find.text(l.cardEmptyTitle), findsNothing);

    // the editor, its description box and the connections row are all there
    expect(find.text(l.cardEditing), findsOneWidget);
    expect(find.text(l.cardFieldDescription), findsOneWidget);
    expect(find.text(l.cardPositionLabel), findsOneWidget);
    expect(find.text(l.cardDefaultLabel), findsOneWidget);
    expect(find.text(l.cardSave), findsOneWidget);

    // the position picker opens the shared single choice sheet
    await t.tap(find.text(l.cardPositionLabel));
    await settle(t, 700);
    for (final at in PersonaPosition.values) {
      expect(find.text(positionOption(l, at).label), findsWidgets, reason: '$at');
    }
    await t.tap(find.text(positionOption(l, PersonaPosition.atDepth).label).last);
    await settle(t, 700);
    expect(store.activePersona.position, PersonaPosition.atDepth);

    // picking a depth position reveals the depth and role controls
    expect(find.text(l.cardDepthLabel), findsOneWidget);
    expect(find.text(l.cardRoleLabel), findsOneWidget);
  });

  testWidgets('switching cards repoints the editors', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 4400);
    t.view.devicePixelRatio = 2.75;
    final store = await Store.load();
    final ai = await AiConfig.load();
    store.attachAi(ai);
    // the tests drive in-app screens, not the wizard
    store.onboarded = true;
    await t.pumpWidget(TgApp(store: store, ai: ai));
    await settle(t);

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('My Account'));
    await settle(t, 800);
    await t.tap(find.text(AppLocalizationsEn().cardCreate));
    await settle(t, 800);

    // two cards saved, only the one in hand is named on the page
    store.updatePersonaCard(store.activePersona.id, (p) => p.name = 'Ada');
    store.createPersonaCard(name: 'Blaze');
    await settle(t, 400);
    expect(find.text('Ada'), findsNothing);
    expect(find.text('Blaze'), findsWidgets);

    // the current card row opens the sheet, which lists both, and picking from
    // it switches the card in hand and the whole identity with it
    final l = AppLocalizationsEn();
    expect(store.userName, 'Blaze');
    await t.tap(find.text(l.cardCurrentLabel));
    await settle(t, 800);
    expect(find.text(l.cardPickTitle), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Blaze'), findsWidgets, reason: 'the sheet lists it, the row behind names it too');
    await t.tap(find.text('Ada').last);
    await settle(t, 800);
    expect(store.activePersona.name, 'Ada');
    expect(store.userName, 'Ada');
    expect(find.text(l.cardEditing), findsOneWidget);
    // the row now names the card in hand, and the editors hold its text
    expect(find.text('Ada'), findsWidgets);

    // and back again
    await t.tap(find.text(l.cardCurrentLabel));
    await settle(t, 800);
    await t.tap(find.text('Blaze').last);
    await settle(t, 800);
    expect(store.userName, 'Blaze');
  });

  testWidgets('the persona editor offers Global and a model of its own', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2600);
    t.view.devicePixelRatio = 2.75;
    final store = await Store.load();
    final ai = await AiConfig.load();
    ai.patchProvider('openai', (p) => p.models = [emptyModel('gpt-4o')]);
    store.attachAi(ai);
    // the tests drive in-app screens, not the wizard
    store.onboarded = true;
    await t.pumpWidget(TgApp(store: store, ai: ai));
    await settle(t);

    final chat = store.createChat('Coder', 'be helpful');
    await settle(t, 400);
    // open the chat, then its profile from the header
    await t.tap(find.text('Coder').first);
    await settle(t, 900);
    // the chat header avatar opens the persona profile
    await t.tap(find.text('Coder').last);
    await settle(t, 900);
    await t.tap(find.text('Edit').last);
    await settle(t, 900);

    // the profile underneath keeps its own Global cell, so scope to the editor.
    // the Model section sits below the fold, the list has to reach it first.
    // scroll to the Global chain row itself, not the section label: another
    // section (clinginess) now sits between and the row can stay just below
    // the viewport when only the label is scrolled into view
    Finder inEditor(String text) => find.descendant(of: find.byType(PersonaCardPage), matching: find.text(text));
    final editorScroll = find.descendant(of: find.byType(PersonaCardPage), matching: find.byType(Scrollable)).first;
    // scrollUntilVisible doubles as the wait: the Global chain row only builds
    // once the model catalog is ready, and the dragging pumps long enough
    // for that async load to land
    await t.scrollUntilVisible(inEditor(AppLocalizationsEn().personaModelGlobalChain), 300, scrollable: editorScroll);
    // a row merely intersecting the viewport (all scrollUntilVisible
    // guarantees) can sit under the floating header bar or the save bar,
    // where its center does not hit-test. center it instead
    Scrollable.ensureVisible(inEditor(AppLocalizationsEn().personaModelGlobalChain).evaluate().single, alignment: .5);
    await settle(t, 600);

    // the section starts on Global and the fallback switch stays hidden
    final l = AppLocalizationsEn();
    expect(inEditor(l.personaModelGlobalChain), findsOneWidget);
    expect(find.text(l.personaModelFallback), findsNothing);

    await t.tap(inEditor(l.personaModelGlobalChain));
    await settle(t, 900);
    expect(find.text('gpt-4o'), findsWidgets);
    await t.tap(find.text('gpt-4o').last);
    await settle(t, 900);

    // picking one reveals the switch and saves it on the persona
    expect(find.text(l.personaModelFallback), findsOneWidget);
    // the editor is a plain Column inside the profile page, so the page's own
    // scrollable is the only thing that can move the save button into view
    final pageScroll = find.descendant(of: find.byType(PersonaCardPage), matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.text(l.personaSave), 300, scrollable: pageScroll);
    await settle(t, 400);
    await t.tap(find.text(l.personaSave).last);
    await settle(t, 900);
    expect(chat.persona.modelId, 'gpt-4o');
    expect(chat.persona.modelProvider, 'openai');
    expect(chat.persona.modelLabel, 'gpt-4o');
  });

  testWidgets('the persona profile shows Global until one is picked', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    final store = await Store.load();
    final ai = await AiConfig.load();
    store.attachAi(ai);
    // the tests drive in-app screens, not the wizard
    store.onboarded = true;
    await t.pumpWidget(TgApp(store: store, ai: ai));
    await settle(t);

    final chat = store.createChat('Coder', 'be helpful');
    await settle(t, 400);
    await t.tap(find.text('Coder').first);
    await settle(t, 900);
    // the chat header avatar opens the persona profile
    await t.tap(find.text('Coder').last);
    await settle(t, 900);
    expect(find.text('Global'), findsOneWidget);

    // once overridden the profile names the model instead of the word Global
    store.editPersona(chat, 'Coder', 'be helpful', modelProvider: 'openai', modelId: 'gpt-4o');
    await settle(t, 400);
    expect(find.text('gpt-4o'), findsOneWidget);
    expect(find.text('Global'), findsNothing);
  });

  testWidgets('my own profile no longer lists a provider or a model', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    final store = await Store.load();
    final ai = await AiConfig.load();
    store.attachAi(ai);
    // the tests drive in-app screens, not the wizard
    store.onboarded = true;
    await t.pumpWidget(TgApp(store: store, ai: ai));
    await settle(t);

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('My Account'));
    await settle(t, 800);
    expect(find.text('Provider'), findsNothing);
    expect(find.text('Model'), findsNothing);
  });
}