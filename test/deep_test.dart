import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paradise/core/ui_kit.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/data/ai_config.dart';
import 'package:paradise/l10n/gen/l10n_en.dart';
import 'package:paradise/main.dart';
import 'package:paradise/ui/emoji_panel.dart';
import 'package:paradise/ui/input_bar.dart';

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Finder icon(Ic ic) => find.byWidgetPredicate((w) => w is TgIcon && w.ic == ic);
Finder inPanel(Finder f) => find.descendant(of: find.byType(EmojiPanel), matching: f);

void main() {
  testWidgets('attach emoji search profile persona', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 2.75;
    final store = await Store.load();
    final ai = await AiConfig.load();
    store.attachAi(ai);
    await t.pumpWidget(TgApp(store: store, ai: ai));
    await settle(t);
    await t.tap(find.text('Assistant'));
    await settle(t, 800);

    // attach sheet, the gallery is the only tab left and uploads ride on top of it
    await t.tap(icon(Ic.attach).last);
    await settle(t, 900);
    expect(find.text('Gallery'), findsWidgets);
    expect(find.text('Upload files'), findsOneWidget);
    expect(find.text('Poll'), findsNothing);
    expect(find.text('Contact'), findsNothing);
    expect(find.text('Browse files'), findsNothing);
    // the sheet only closes by drag or scrim tap, there is no close glyph
    (t.state(find.byType(Navigator).first) as NavigatorState).pop();
    await settle(t, 600);

    // emoji panel then sticker: the panel has two tabs now, the GIF tab lives
    // inside the sticker tab as the "my stickers" section
    await t.tap(find.descendant(of: find.byType(InputBar), matching: icon(Ic.smile)));
    await settle(t, 700);
    expect(find.text('SMILEYS & PEOPLE'), findsWidgets);
    await t.tap(find.descendant(of: find.byType(EmojiPanel), matching: icon(Ic.sticker)));
    await settle(t, 600);
    expect(find.text('MY STICKERS'), findsWidgets);
    expect(find.text('ANIMALS'), findsWidgets);
    final chat = store.chats.firstWhere((c) => c.persona.name == 'Assistant');
    final before = chat.msgs.length;
    // the packs sit below the library section, search brings one into reach
    await t.tap(inPanel(icon(Ic.search)));
    await settle(t, 600);
    await t.enterText(inPanel(find.byType(EditableText)), 'puppy');
    await settle(t, 600);
    await t.tap(find.text('🐶').first);
    await settle(t, 700);
    // the sticker itself plus the no-api-key service bubble behind it
    expect(chat.msgs.length, before + 2);
    expect(chat.msgs[before].kind, MsgKind.sticker);
    expect(chat.msgs[before].data['emoji'], '🐶');
    await t.tap(icon(Ic.keyboard).first);
    await settle(t, 600);

    // in chat search
    store.send(chat, 'find me needle please');
    await settle(t, 600);
    await t.tap(icon(Ic.more).last);
    await settle(t, 500);
    await t.tap(find.text('Search').last);
    await settle(t, 600);
    await t.enterText(find.byType(EditableText).first, 'needle');
    await settle(t, 600);
    expect(find.text('1 of 1'), findsOneWidget);
    await t.tap(icon(Ic.back).last);
    await settle(t, 500);

    // profile from the header
    await t.tap(find.text('Assistant').last);
    await settle(t, 800);
    expect(find.text('Instructions'), findsOneWidget);
    await t.drag(find.text('Instructions'), const Offset(0, 300));
    await settle(t, 700);
    await t.drag(find.text('Instructions'), const Offset(0, -300));
    await settle(t, 600);
    await t.tap(find.text('Media').last);
    await settle(t, 500);
    expect(find.text('No media yet'), findsWidgets);
  });

  testWidgets('persona card', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 2.75;
    final store = await Store.load();
    final ai = await AiConfig.load();
    store.attachAi(ai);
    await t.pumpWidget(TgApp(store: store, ai: ai));
    await settle(t);
    await t.tap(icon(Ic.pencil).first);
    await settle(t, 800);
    expect(find.text(AppLocalizationsEn().personaCreate), findsOneWidget);
    // the chip is the emoji and the name separated by two spaces
    await t.tap(find.text('💻  Coder'));
    await settle(t, 600);
    await t.tap(find.text(AppLocalizationsEn().personaCreate));
    await settle(t, 900);
    expect(store.chats.any((c) => c.persona.name == 'Coder'), true);
  });
}
