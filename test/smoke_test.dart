import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paradise/core/ui_kit.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/data/ai_config.dart';
import 'package:paradise/l10n/gen/l10n_en.dart';
import 'package:paradise/main.dart';

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('list chat search profile settings', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 2.75;
    final store = await Store.load();
    final ai = await AiConfig.load();
    store.attachAi(ai);
    await t.pumpWidget(TgApp(store: store, ai: ai));
    await settle(t);
    expect(find.text('Chats'), findsWidgets);
    expect(find.text('Assistant'), findsOneWidget);

    // open the chat
    await t.tap(find.text('Assistant'));
    await settle(t, 800);
    expect(find.text('Message'), findsWidgets);

    // send a message and watch the delivery state settle
    await t.enterText(find.byType(EditableText).last, 'hello world');
    await settle(t, 200);
    final chat = store.chats.firstWhere((c) => c.persona.name == 'Assistant');
    store.send(chat, 'hello world');
    await settle(t, 100);
    // no api key in the mock store, so the outgoing message settles as failed
    // and a service bubble lands on top of it
    final mine = chat.msgs.where((m) => m.out).toList();
    expect(mine.last.state, St.failed);
    await settle(t, 600);

    // sticker, poll, contact and file messages render
    store.addOut(chat, kind: MsgKind.sticker, data: {'emoji': '😀'});
    store.addOut(chat, kind: MsgKind.poll, data: {'q': 'Tea or coffee', 'opts': ['Tea', 'Coffee'], 'votes': [0, 0], 'mine': <int>[]});
    store.addOut(chat, kind: MsgKind.contact, data: {'name': 'Ann', 'phone': '+1 555'});
    store.addOut(chat, kind: MsgKind.file, data: {'name': 'notes.txt', 'size': 1200, 'path': '/nope'});
    await settle(t, 900);
    expect(find.text('Tea or coffee'), findsOneWidget);
    await t.tap(find.text('Coffee'));
    await settle(t, 600);
    expect(find.text(AppLocalizationsEn().pluralVotes(1)), findsOneWidget);

    // in chat search
    await t.tapAt(const Offset(1000, 2000));
    await settle(t, 100);
  });

  testWidgets('tabs search and persona card', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 2.75;
    final store = await Store.load();
    final ai = await AiConfig.load();
    store.attachAi(ai);
    await t.pumpWidget(TgApp(store: store, ai: ai));
    await settle(t);
    await t.tap(find.text('Search'));
    await settle(t, 600);
    expect(find.text('People'), findsOneWidget);
    await t.enterText(find.byType(EditableText).first, 'assist');
    await settle(t, 500);
    expect(find.text('Chats'), findsWidgets);
    (t.state(find.byType(Navigator).first) as NavigatorState).pop();
    await settle(t, 600);
    await t.tap(find.text('Settings').last);
    await settle(t, 700);
    // the row now opens the multi provider AI screen instead of the flat endpoint editor
    expect(find.text('AI'), findsWidgets);
    // name and bio now live on their own account page and save from the action bar
    await t.tap(find.text('My Account'));
    await settle(t, 700);
    expect(find.text('My Account'), findsWidgets);
    await t.enterText(find.byType(EditableText).first, 'Ada');
    await settle(t, 300);
    await t.tap(find.byWidgetPredicate((w) => w is TgIcon && w.ic == Ic.check));
    await settle(t, 700);
    expect(store.userName, 'Ada');
    // a photo path that is gone must fall back to the initial everywhere
    store.setAvatar('/does/not/exist.png');
    await settle(t, 300);
    expect(find.text('My Account'), findsWidgets);
    store.setAvatar('');
    await settle(t, 300);
    await t.tap(find.text('Chat Appearance'));
    await settle(t, 800);
    expect(find.text('Night Mode'), findsOneWidget);
    (t.state(find.byType(Navigator).first) as NavigatorState).pop();
    await settle(t, 600);
    await t.tap(find.text('Profile').last);
    await settle(t, 700);
    expect(find.text('Edit'), findsWidgets);
  });
}
