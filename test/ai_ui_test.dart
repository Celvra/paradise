import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paradise/data/ai/provider_model.dart';
import 'package:paradise/data/ai_config.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/main.dart';
import 'package:paradise/ui/ai_model_picker.dart';
import 'package:paradise/ui/ai_settings_page.dart';
import 'package:paradise/ui/provider_detail_page.dart';

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// The bulletin auto dismisses after ~2s; drain it so no timer outlives the test.
Future<void> drainBulletin(WidgetTester t) => settle(t, 2600);

Future<(Store, AiConfig)> boot(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(1080, 2200);
  t.view.devicePixelRatio = 2.75;
  final store = await Store.load();
  final ai = await AiConfig.load();
  store.attachAi(ai);
  await t.pumpWidget(TgApp(store: store, ai: ai));
  await settle(t);
  return (store, ai);
}

/// stateful stand-in pane: counts taps so a remount shows up as a reset
class _CounterPane extends StatefulWidget {
  const _CounterPane(this.label);
  final String label;
  @override
  State<_CounterPane> createState() => _CounterPaneState();
}

class _CounterPaneState extends State<_CounterPane> {
  int _taps = 0;
  @override
  Widget build(BuildContext context) => Center(
        child: GestureDetector(onTap: () => setState(() => _taps++), child: Text('${widget.label}:$_taps taps')),
      );
}

void main() {
  testWidgets('ai screen lists the six built in providers', (t) async {
    final (_, ai) = await boot(t);
    expect(ai.settings.providers.length, 6);

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);

    expect(find.byType(AiSettingsPage), findsOneWidget);
    // the header and the group both read "Providers", so both are on screen
    expect(find.text('Providers'), findsNWidgets(2));
    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('Anthropic'), findsOneWidget);
    expect(find.text('Google Gemini'), findsOneWidget);
    expect(find.text('DeepSeek'), findsOneWidget);
    expect(find.text('Add Provider'), findsOneWidget);
  });

  testWidgets('no chain shows the empty banner copy', (t) async {
    final (_, ai) = await boot(t);
    expect(ai.ready, isFalse);

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);

    expect(find.textContaining('No API key'), findsWidgets);
  });

  testWidgets('chain tab starts empty then reports the hint', (t) async {
    final (_, ai) = await boot(t);
    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);

    await t.tap(find.text('Chain'));
    await settle(t, 500);

    expect(ai.settings.chain, isEmpty);
    expect(find.textContaining('chain is empty'), findsOneWidget);
    expect(find.text('Compact long conversations'), findsOneWidget);
  });

  testWidgets('advanced tab lists reply and sampling knobs', (t) async {
    final (_, ai) = await boot(t);
    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);

    await t.tap(find.text('Advanced'));
    await settle(t, 500);

    expect(find.text('Reply style'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);
    expect(find.text(ai.settings.temperature.toStringAsFixed(2)), findsOneWidget);
    expect(find.text('Max output'), findsOneWidget);
    expect(find.text('Extra system prompt'), findsNothing);
    // the markdown switch moved to the AI replies page
    expect(find.text('Strip markdown in character mode'), findsNothing);
  });

  testWidgets('the markdown switch lives on the AI replies page', (t) async {
    final (_, ai) = await boot(t);
    expect(ai.settings.stripMarkdownInCharacterMode, isTrue); // default: stripped

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI replies').last);
    await settle(t, 700);

    // stored stripped, shown as Markdown off
    expect(find.text('Markdown'), findsOneWidget);
    await t.tap(find.text('Markdown'));
    await settle(t, 700);
    expect(ai.settings.stripMarkdownInCharacterMode, isFalse);

    // and back off again
    await t.tap(find.text('Markdown'));
    await settle(t, 700);
    expect(ai.settings.stripMarkdownInCharacterMode, isTrue);
  });

  testWidgets('picking character mode writes through to settings', (t) async {
    final (_, ai) = await boot(t);
    expect(ai.settings.replyMode, ReplyMode.full);

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);
    await t.tap(find.text('Advanced'));
    await settle(t, 500);

    await t.tap(find.text('Reply style'));
    await settle(t, 700);
    await t.tap(find.text('Character').last);
    await settle(t, 700);

    expect(ai.settings.replyMode, ReplyMode.character);
  });

  testWidgets('picking a temperature writes through', (t) async {
    final (_, ai) = await boot(t);
    expect(ai.settings.temperature, 1.0);

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);
    await t.tap(find.text('Advanced'));
    await settle(t, 500);

    await t.tap(find.text('Temperature'));
    await settle(t, 700);
    await t.tap(find.text('0.40'));
    await settle(t, 700);

    expect(ai.settings.temperature, 0.4);
  });

  testWidgets('provider detail opens with connection rows', (t) async {
    final (_, ai) = await boot(t);
    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);

    await t.tap(find.text('OpenAI'));
    await settle(t, 800);

    expect(find.byType(ProviderDetailPage), findsOneWidget);
    expect(find.text('Connection'), findsOneWidget);
    expect(find.text('API key'), findsOneWidget);
    expect(find.text('Base URL'), findsOneWidget);
    // openai responses fixes its own path so the row is not editable
    expect(find.text('Decided by the protocol'), findsOneWidget);
    expect(find.text('Fetch models'), findsOneWidget);
    expect(find.text('Test connection'), findsOneWidget);
    expect(ai.settings.providers.firstWhere((p) => p.id == 'openai').baseUrl, 'https://api.openai.com/v1');
  });

  testWidgets('changing the protocol rewrites the chat path', (t) async {
    final (_, ai) = await boot(t);
    final openai = ai.settings.providers.firstWhere((p) => p.id == 'openai');

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);
    await t.tap(find.text('OpenAI'));
    await settle(t, 800);

    await t.tap(find.text('Protocol'));
    await settle(t, 700);
    await t.tap(find.text('OpenAI Chat Completions'));
    await settle(t, 700);

    final after = ai.settings.providers.firstWhere((p) => p.id == 'openai');
    expect(after.kind, ProviderKind.openaiChat);
    expect(after.chatPath, '/chat/completions');
    expect(openai.chatPath, '/responses');
  });

  testWidgets('an editable protocol exposes the chat path row', (t) async {
    final (_, ai) = await boot(t);
    final deepseek = ai.settings.providers.firstWhere((p) => p.id == 'deepseek');

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);
    await t.tap(find.text('DeepSeek'));
    await settle(t, 800);

    expect(deepseek.kind, ProviderKind.openaiChat);
    expect(find.text('/chat/completions'), findsOneWidget);
  });

  testWidgets('testing without a key reports it instead of calling out', (t) async {
    final (_, ai) = await boot(t);
    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);
    await t.tap(find.text('OpenAI'));
    await settle(t, 800);

    await t.tap(find.text('Test connection'));
    await drainBulletin(t);

    expect(find.textContaining('Add an API key first'), findsOneWidget);
    expect(ai.settings.chain, isEmpty);
  });

  testWidgets('a key round trips through secure storage per provider', (t) async {
    final (_, ai) = await boot(t);

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);
    await t.tap(find.text('OpenAI'));
    await settle(t, 800);

    await t.tap(find.text('API key'));
    await settle(t, 700);
    await t.enterText(find.byType(EditableText).last, 'sk-test-123456');
    await settle(t, 300);
    await t.tap(find.text('OK'));
    await drainBulletin(t);

    expect(ai.keyOf('openai'), 'sk-test-123456');
    // the row masks it but reflects that a key is now set
    expect(find.text('sk-tes****'), findsOneWidget);
    expect(find.text('Not set'), findsNothing);
  });

  testWidgets('adding a custom provider lands on its detail page', (t) async {
    final (_, ai) = await boot(t);
    final before = ai.settings.providers.length;

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);

    await t.tap(find.text('Add Provider'));
    await settle(t, 700);
    await t.enterText(find.byType(EditableText).last, 'My Relay');
    await settle(t, 300);
    await t.tap(find.text('OK'));
    await drainBulletin(t);

    expect(ai.settings.providers.length, before + 1);
    expect(ai.settings.providers.any((p) => p.name == 'My Relay'), isTrue);
    expect(find.byType(ProviderDetailPage), findsOneWidget);
  });

  testWidgets('the model picker says so when nothing is loaded', (t) async {
    await boot(t);
    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);
    await t.tap(find.text('Chain'));
    await settle(t, 500);

    await t.tap(find.text('Summary model'));
    await settle(t, 800);

    expect(find.textContaining('No models loaded yet'), findsOneWidget);
    expect(find.text('Follow the first node on the chain'), findsOneWidget);
  });

  testWidgets('the picker lists models and searches them', (t) async {
    final (_, ai) = await boot(t);
    ai.patchProvider('openai', (p) => p.models = [emptyModel('gpt-4o', 'gpt-4o'), emptyModel('gpt-3.5-turbo', 'gpt-3.5-turbo')]);
    await settle(t, 300); // the chain tab reads cfg on rebuild

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);
    await t.tap(find.text('Chain'));
    await settle(t, 500);
    // the compaction section sits under the chain list, scroll it into reach
    await t.scrollUntilVisible(find.text('Summary model'), 300, scrollable: find.byType(Scrollable).first);
    await settle(t, 400);
    await t.tap(find.text('Summary model'));
    await settle(t, 1000);

    // the underlying chain tab also shows the chosen model once it is picked
    expect(find.text('gpt-4o'), findsWidgets);
    expect(find.text('gpt-3.5-turbo'), findsWidgets);

    await t.enterText(find.widgetWithText(AiSearchBox, 'Search models'), '3.5');
    await settle(t, 500);
    // only gpt-3.5 matches, gpt-4o drops out of the filtered list
    expect(find.text('gpt-4o'), findsNothing);
    expect(find.text('gpt-3.5-turbo'), findsOneWidget);
  });

  testWidgets('picking a model sets the compaction provider', (t) async {
    final (_, ai) = await boot(t);
    ai.patchProvider('openai', (p) => p.models = [emptyModel('gpt-4o', 'gpt-4o')]);

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);
    await t.tap(find.text('Chain'));
    await settle(t, 500);
    await t.tap(find.text('Summary model'));
    await settle(t, 800);
    // the picker row is the one inside the search box list
    await t.tap(find.text('gpt-4o').last);
    await settle(t, 800);

    expect(ai.settings.compaction.providerId, 'openai');
    expect(ai.settings.compaction.modelId, 'gpt-4o');
  });

  testWidgets('toggling compaction flips the setting', (t) async {
    final (_, ai) = await boot(t);
    expect(ai.settings.compaction.enabled, isTrue);

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);
    await t.tap(find.text('Chain'));
    await settle(t, 500);

    await t.tap(find.text('Compact long conversations'));
    await settle(t, 600);

    expect(ai.settings.compaction.enabled, isFalse);
  });

  testWidgets('the chain banner updates once a node exists', (t) async {
    final (_, ai) = await boot(t);
    ai.addChainNode('deepseek', 'deepseek-chat');

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);

    expect(find.textContaining('DeepSeek'), findsWidgets);
    expect(ai.chainSummary, contains('deepseek-chat'));
  });

  testWidgets('removing a provider drops its chain nodes and key', (t) async {
    final (_, ai) = await boot(t);
    // built in providers cannot be deleted, so make a custom one first
    ai.addProvider(Provider.defaults(id: 'relay', name: 'My Relay'));
    ai.saveApiKey('relay', 'sk-relay');
    ai.addChainNode('relay', 'some-model');
    expect(ai.keyOf('relay'), 'sk-relay');
    expect(ai.settings.chain.length, 1);

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);
    await t.tap(find.text('My Relay'));
    await settle(t, 800);

    // the delete action sits at the bottom of a long scrollable page
    for (var i = 0; i < 4 && find.text('Delete this provider').evaluate().isEmpty; i++) {
      await t.drag(find.byType(ListView).last, const Offset(0, -600));
      await settle(t, 300);
    }
    expect(find.text('Delete this provider'), findsOneWidget);

    await t.tap(find.text('Delete this provider'));
    await settle(t, 700);
    await t.tap(find.text('Delete'));
    await drainBulletin(t);

    expect(ai.settings.providers.any((p) => p.id == 'relay'), isFalse);
    expect(ai.settings.chain.where((n) => n.providerId == 'relay'), isEmpty);
    expect(ai.keyOf('relay'), '');
  });

  testWidgets('switching tabs animates the page and settles on the new one', (t) async {
    await boot(t);
    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);

    // mid transition the incoming page is already mounted, just sliding in
    await t.tap(find.text('Chain'));
    await t.pump(const Duration(milliseconds: 120));
    expect(find.text('Compact long conversations'), findsOneWidget);

    // once settled the destination is still the one on screen
    await settle(t, 600);
    expect(find.text('Compact long conversations'), findsOneWidget);
    // the page that left is offstage, so its content is out of the tree
    expect(find.text('PROVIDERS'), findsNothing);
  });

  testWidgets('the pane that leaves goes the way the strip travels', (t) async {
    Widget pane(String s) => Center(child: Text(s));
    Widget page(int i) => Directionality(
          textDirection: TextDirection.ltr,
          child: Switcher(index: i, children: [pane('a'), pane('b'), pane('c')]),
        );

    await t.pumpWidget(page(0));
    await t.pumpWidget(page(1)); // providers -> chain, the strip moves right
    for (var frame = 0; frame < 8; frame++) {
      await t.pump(const Duration(milliseconds: 30)); // step a frame first so t > 0
      final dx = t
          .widgetList<FractionalTranslation>(find.byType(FractionalTranslation))
          .map((w) => w.translation.dx)
          .toList();
      expect(dx, hasLength(2));
      // the leaving pane exits left, the entering one lands from the right:
      // the two must never sit on the same side, let alone overlap
      expect(dx.where((d) => d <= 0), hasLength(1), reason: 'frame $frame: $dx');
      expect(dx.where((d) => d >= 0), hasLength(1), reason: 'frame $frame: $dx');
    }
    await t.pump(const Duration(milliseconds: 400));
  });

  testWidgets('reversing mid-flight keeps both panes where they were', (t) async {
    Widget pane(String s) => Center(child: Text(s));
    Widget page(int i) => Directionality(
          textDirection: TextDirection.ltr,
          child: Switcher(index: i, children: [pane('a'), pane('b'), pane('c')]),
        );
    double dxOf(String label) => t
        .widget<FractionalTranslation>(find.ancestor(of: find.text(label), matching: find.byType(FractionalTranslation)))
        .translation
        .dx;

    await t.pumpWidget(page(0));
    await t.pumpWidget(page(1));
    await t.pump(const Duration(milliseconds: 60)); // mid-flight
    final aBefore = dxOf('a');
    final bBefore = dxOf('b');

    await t.pumpWidget(page(0)); // straight back, same instant
    // neither pane may snap: the flight just turns around where it stands
    expect(dxOf('a'), closeTo(aBefore, 0.001), reason: 'a jumped: $aBefore -> ${dxOf('a')}');
    expect(dxOf('b'), closeTo(bBefore, 0.001), reason: 'b jumped: $bBefore -> ${dxOf('b')}');

    // still heading the way it should: a drifts home, b keeps fading right
    await t.pump(const Duration(milliseconds: 90));
    expect(dxOf('a'), greaterThan(aBefore));
    expect(dxOf('b'), greaterThan(bBefore));

    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsNothing);
  });

  testWidgets('jumping to a third tab mid-flight keeps the old panes continuous', (t) async {
    Widget pane(String s) => Center(child: Text(s));
    Widget page(int i) => Directionality(
          textDirection: TextDirection.ltr,
          child: Switcher(index: i, children: [pane('a'), pane('b'), pane('c')]),
        );
    double dxOf(String label) => t
        .widget<FractionalTranslation>(find.ancestor(of: find.text(label), matching: find.byType(FractionalTranslation)))
        .translation
        .dx;

    await t.pumpWidget(page(0));
    await t.pumpWidget(page(1));
    await t.pump(const Duration(milliseconds: 60));
    final aBefore = dxOf('a');
    final bBefore = dxOf('b');

    await t.pumpWidget(page(2)); // off to a third tab while a is still leaving
    expect(dxOf('a'), closeTo(aBefore, 0.001), reason: 'a jumped: $aBefore -> ${dxOf('a')}');
    expect(dxOf('b'), closeTo(bBefore, 0.001), reason: 'b jumped: $bBefore -> ${dxOf('b')}');

    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('c'), findsOneWidget);
    expect(find.text('a'), findsNothing);
    expect(find.text('b'), findsNothing);
  });

  testWidgets('panes keep their state when you switch back to them', (t) async {
    Widget page(int i) => Directionality(
          textDirection: TextDirection.ltr,
          child: Switcher(index: i, children: [const _CounterPane('a'), const _CounterPane('b'), const _CounterPane('c')]),
        );

    await t.pumpWidget(page(0));
    expect(find.text('a:0 taps'), findsOneWidget);
    await t.tap(find.text('a:0 taps'));
    await t.pump();
    expect(find.text('a:1 taps'), findsOneWidget);

    await t.pumpWidget(page(1));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('b:0 taps'), findsOneWidget);

    await t.pumpWidget(page(0)); // back to a
    await t.pump(const Duration(milliseconds: 400));
    // the tap must have survived the round trip, not been remounted to zero
    expect(find.text('a:1 taps'), findsOneWidget);
  });

  testWidgets('a key on a later provider is not reported as missing', (t) async {
    final (store, ai) = await boot(t);
    // openai is first in the list but carries no key, anthropic does
    ai.saveApiKey('anthropic', 'sk-ant-test');
    ai.addChainNode('anthropic', 'claude-sonnet-4-5');

    expect(ai.hasAnyKey(), isTrue);
    expect(ai.chainHasKeys, isTrue);
    expect(ai.runnableNode?.providerId, 'anthropic');
    // the flat view must follow the chain instead of reading providers.first
    expect(store.apiKey, 'sk-ant-test');
    expect(store.baseUrl, 'https://api.anthropic.com/v1');
    expect(store.model, 'claude-sonnet-4-5');
  });

  testWidgets('a key on an unrelated provider does not make the chain ready', (t) async {
    final (_, ai) = await boot(t);
    ai.saveApiKey('openai', 'sk-openai-test');
    ai.addChainNode('anthropic', 'claude-sonnet-4-5');

    // there is a key somewhere, but not on the node that would be called
    expect(ai.hasAnyKey(), isTrue);
    expect(ai.chainHasKeys, isFalse);
    expect(ai.runnableNode, isNull);
  });

  testWidgets('built in providers cannot be deleted', (t) async {
    await boot(t);
    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);
    await t.tap(find.text('OpenAI'));
    await settle(t, 800);

    expect(find.text('Delete this provider'), findsNothing);
  });

  testWidgets('adding a model by hand enriches it from the catalog', (t) async {
    final (_, ai) = await boot(t);

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);
    await t.tap(find.text('DeepSeek'));
    await settle(t, 800);

    await t.tap(find.text('Add a model by hand'));
    await settle(t, 700);
    // deepseek-flash is in the bundled catalog so it gains a window
    await t.enterText(find.byType(EditableText).last, 'deepseek-flash');
    await settle(t, 300);
    await t.tap(find.text('OK'));
    await drainBulletin(t);

    final provider = ai.settings.providers.firstWhere((p) => p.id == 'deepseek');
    expect(provider.models.any((m) => m.id == 'deepseek-flash'), isTrue);
    final added = provider.models.firstWhere((m) => m.id == 'deepseek-flash');
    // enrich fills capabilities but keeps the entry hand added, same as upstream
    expect(added.contextWindow, greaterThan(0));
    expect(added.source, ModelSource.manual);
  });

  testWidgets('a model the catalog misses still gets id hints', (t) async {
    final (_, ai) = await boot(t);

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);
    await t.tap(find.text('DeepSeek'));
    await settle(t, 800);

    await t.tap(find.text('Add a model by hand'));
    await settle(t, 700);
    await t.enterText(find.byType(EditableText).last, 'some-unknown-relay-model');
    await settle(t, 300);
    await t.tap(find.text('OK'));
    await drainBulletin(t);

    final provider = ai.settings.providers.firstWhere((p) => p.id == 'deepseek');
    final added = provider.models.firstWhere((m) => m.id == 'some-unknown-relay-model');
    expect(added.contextWindow, 0);
    expect(added.source, ModelSource.manual);
    expect(added.name, 'some-unknown-relay-model');
  });

  testWidgets('tapping a model toggles it on the chain', (t) async {
    final (_, ai) = await boot(t);
    ai.patchProvider('deepseek', (p) => p.models = [emptyModel('deepseek-chat', 'deepseek-chat')]);

    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    await t.tap(find.text('AI'));
    await settle(t, 700);
    await t.tap(find.text('DeepSeek'));
    await settle(t, 800);

    expect(ai.settings.chain, isEmpty);
    await t.tap(find.text('deepseek-chat'));
    await settle(t, 700);
    expect(ai.settings.chain.length, 1);
    expect(ai.settings.chain.first.modelId, 'deepseek-chat');
    expect(ai.ready, isTrue);
  });
}