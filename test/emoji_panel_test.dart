import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paradise/core/ui_kit.dart';
import 'package:paradise/data/ai_config.dart';
import 'package:paradise/data/human/sticker_lib.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/main.dart';
import 'package:paradise/ui/emoji_panel.dart';
import 'package:paradise/ui/human_data_pages.dart';
import 'package:paradise/ui/input_bar.dart';

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Finder icon(Ic ic) => find.byWidgetPredicate((w) => w is TgIcon && w.ic == ic);
Finder inBar(Finder f) => find.descendant(of: find.byType(InputBar), matching: f);
Finder inPanel(Finder f) => find.descendant(of: find.byType(EmojiPanel), matching: f);

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

/// Opens the panel on the given tab, 0 emoji and 1 stickers.
Future<void> openPanel(WidgetTester t, int tab) async {
  await t.tap(find.text('Assistant'));
  await settle(t, 800);
  await t.tap(inBar(icon(Ic.smile)));
  await settle(t, 700);
  if (tab == 1) {
    await t.tap(inPanel(icon(Ic.sticker)));
    await settle(t, 600);
  }
}

void main() {
  testWidgets('the panel has two tabs, the GIF tab is gone', (t) async {
    await boot(t);
    await openPanel(t, 0);
    expect(find.byType(EmojiPanel), findsOneWidget);
    expect(inPanel(icon(Ic.smile)), findsOneWidget);
    expect(inPanel(icon(Ic.sticker)), findsOneWidget);
    expect(inPanel(icon(Ic.video)), findsNothing);
    expect(find.text('SMILEYS & PEOPLE'), findsWidgets);
  });

  testWidgets('the sticker tab leads with the user library', (t) async {
    final (store, _) = await boot(t);
    final lib = store.human!.stickers;
    final shark = lib.add(kind: StickerKind.emoji, value: '🦈', name: 'shark', emotion: '笑死', tags: ['shark', 'lol'], category: 'Mood');
    lib.add(kind: StickerKind.gif, value: 'https://example.invalid/doge.gif', name: 'doge', emotion: '笑死', tags: ['doge'], category: 'Mood');
    await t.pumpAndSettle();
    await openPanel(t, 1);

    // the library sits on top with its filters, the placeholder emoji pack is gone
    expect(find.text('MY STICKERS'), findsWidgets);
    expect(find.text('All'), findsWidgets);
    expect(find.text('+ Add'), findsWidgets);
    expect(find.text('ANIMALS'), findsWidgets);
    expect(find.text('FACES'), findsNothing);

    // the emoji of the library is not in a pack any more, it is the user's own
    expect(find.text('🦈'), findsOneWidget);

    final chat = store.chats.first;
    final before = chat.msgs.length;
    await t.tap(find.text('🦈'));
    await settle(t, 700);
    expect(chat.msgs.length, before + 2);
    expect(chat.msgs[before].kind, MsgKind.sticker);
    expect(chat.msgs[before].data['sid'], shark.id);
    expect(chat.msgs[before].data['emoji'], '🦈');
    // it counts as used, so the library can sort and filter on it
    expect(lib.byId(shark.id)!.uses, 1);
  });

  testWidgets('favourites filter the library section', (t) async {
    final (store, _) = await boot(t);
    final lib = store.human!.stickers;
    lib.add(kind: StickerKind.emoji, value: '🦈', name: 'shark');
    final doge = lib.add(kind: StickerKind.emoji, value: '🐕', name: 'doge');
    doge.favorite = true;
    await t.pumpAndSettle();
    await openPanel(t, 1);
    expect(find.text('🦈'), findsOneWidget);
    await t.tap(find.text('★ Favorites'));
    await settle(t, 500);
    expect(find.text('🐕'), findsOneWidget);
    expect(find.text('🦈'), findsNothing);
  });

  testWidgets('search reaches the packs and the library together', (t) async {
    final (store, _) = await boot(t);
    store.human!.stickers.add(kind: StickerKind.emoji, value: '🦈', name: 'shark', tags: ['shark']);
    await t.pumpAndSettle();
    await openPanel(t, 1);
    await t.tap(inPanel(icon(Ic.search)));
    await settle(t, 600);
    await t.enterText(find.descendant(of: find.byType(EmojiPanel), matching: find.byType(EditableText)).first, 'shark');
    await settle(t, 600);
    expect(find.text('🦈'), findsWidgets);
    await t.enterText(find.descendant(of: find.byType(EmojiPanel), matching: find.byType(EditableText)).first, 'pizza');
    await settle(t, 600);
    expect(find.text('🍕'), findsWidgets);
  });

  group('the sticker library in settings', () {
    Future<Store> openStickers(WidgetTester t) async {
      final (store, _) = await boot(t);
      await t.tap(find.text('Settings').last);
      await settle(t, 700);
      await t.tap(find.text('Humanize'));
      await settle(t, 700);
      await t.tap(find.text('Stickers'));
      await settle(t, 700);
      expect(find.byType(StickerSettingsPage), findsOneWidget);
      return store;
    }

    testWidgets('no placeholder emoji is seeded', (t) async {
      final (store, _) = await boot(t);
      expect(store.human!.stickers.items, isEmpty);
      // and nothing is seeded when the page is opened either
      await openStickers(t);
      expect(find.textContaining('Nothing here yet'), findsOneWidget);
    });

    testWidgets('hold a sticker to act on several at once', (t) async {
      final store = await openStickers(t);
      final lib = store.human!.stickers;
      final a = lib.add(kind: StickerKind.emoji, value: '🦈', name: 'a', category: 'Mood');
      final b = lib.add(kind: StickerKind.emoji, value: '🐕', name: 'b', category: 'Mood');
      final c = lib.add(kind: StickerKind.emoji, value: '🦊', name: 'c', category: 'Jokes');
      store.human!.changed();
      await settle(t, 600);
      expect(find.text('🦈'), findsOneWidget);

      // a hold opens the batch bar on that sticker
      await t.longPress(find.text('🦈'));
      await settle(t, 600);
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Actions'), findsOneWidget);

      // tapping more adds them, tapping the picked one takes it back
      await t.tap(find.text('🐕'));
      await settle(t, 400);
      expect(find.text('2 selected'), findsOneWidget);
      await t.tap(find.text('🐕'));
      await settle(t, 400);
      expect(find.text('1 selected'), findsOneWidget);
      await t.tap(find.text('🐕'));
      await settle(t, 400);

      // favorite both in one go
      await t.tap(find.text('Actions'));
      await settle(t, 600);
      await t.tap(find.text('Favorite').last);
      await settle(t, 700);
      expect(lib.byId(a.id)!.favorite, isTrue);
      expect(lib.byId(b.id)!.favorite, isTrue);
      expect(lib.byId(c.id)!.favorite, isFalse);

      // then move them to another category
      await t.longPress(find.text('🦈'));
      await settle(t, 500);
      await t.tap(find.text('🐕'));
      await settle(t, 400);
      await t.tap(find.text('Actions'));
      await settle(t, 600);
      await t.tap(find.text('Move to category'));
      await settle(t, 600);
      await t.enterText(find.byType(EditableText).last, 'Memes');
      await settle(t, 300);
      await t.tap(find.text('OK'));
      await settle(t, 700);
      expect(lib.byId(a.id)!.category, 'Memes');
      expect(lib.byId(b.id)!.category, 'Memes');
      expect(lib.categories, contains('Memes'));
    });

    testWidgets('delete asks once and clears the picks', (t) async {
      final store = await openStickers(t);
      final lib = store.human!.stickers;
      final a = lib.add(kind: StickerKind.emoji, value: '🦈', name: 'a');
      final b = lib.add(kind: StickerKind.emoji, value: '🐕', name: 'b');
      store.human!.changed();
      await settle(t, 600);

      await t.longPress(find.text('🦈'));
      await settle(t, 500);
      await t.tap(find.text('🐕'));
      await settle(t, 400);
      await t.tap(find.text('Actions'));
      await settle(t, 600);
      await t.tap(find.text('Delete').last);
      await settle(t, 600);
      expect(find.textContaining('Delete 2 stickers?'), findsOneWidget);
      await t.tap(find.text('Delete').last);
      await settle(t, 700);

      expect(lib.byId(a.id), isNull);
      expect(lib.byId(b.id), isNull);
      expect(lib.items, isEmpty);
      // the batch bar is gone and the page fell back to the empty copy
      expect(find.text('Actions'), findsNothing);
      expect(find.textContaining('Nothing here yet'), findsOneWidget);
    });

    testWidgets('select all takes the whole filter', (t) async {
      final store = await openStickers(t);
      final lib = store.human!.stickers;
      lib.add(kind: StickerKind.emoji, value: '🦈', name: 'a');
      lib.add(kind: StickerKind.emoji, value: '🐕', name: 'b');
      lib.add(kind: StickerKind.emoji, value: '🦊', name: 'c');
      store.human!.changed();
      await settle(t, 600);

      await t.tap(find.text('Select all'));
      await settle(t, 600);
      expect(find.text('3 selected'), findsOneWidget);

      // leaving the batch bar does not lose the list
      await t.tap(find.text('Cancel'));
      await settle(t, 400);
      expect(find.text('Actions'), findsNothing);
      expect(lib.items.length, 3);
    });
  });
}