import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/core/theme.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/l10n/gen/l10n_en.dart';
import 'package:paradise/l10n/x.dart';
import 'package:paradise/ui/bubble.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The bubble is the reader's window on what the model wrote. These pin the two
// renderings this build added: a latex span becomes math, a fenced block gets
// a header with a wrap toggle and a copy row, and nothing of either throws.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'chats': '[]'});
  L10n.sync(AppLocalizationsEn());

  Future<Store> store() async => Store.load();

  Widget wrap(Store st, Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StoreScope(
          store: st,
          child: ThemeScope(
            controller: themeCtl,
            child: MediaQuery(data: const MediaQueryData(), child: child),
          ),
        ),
      );

  Msg withText(String text) => Msg(id: 'b1', out: false, text: text, time: 1, read: true);

  testWidgets('a latex span renders without the raw dollars', (t) async {
    final st = await store();
    await t.pumpWidget(wrap(st, BubbleView(
      msg: withText(r'质能方程 $E = mc^2$ 很有名。'),
      tail: true,
      topNear: false,
      maxWidth: 300,
    )));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    // the delimiters are consumed by the renderer, the formula itself is a
    // Math widget rather than plain text
    expect(find.textContaining(r'$E', findRichText: true), findsNothing);
  });

  testWidgets('a display formula renders centered and never throws', (t) async {
    final st = await store();
    await t.pumpWidget(wrap(st, BubbleView(
      msg: withText(r'$$\int_0^\infty e^{-x}\,dx = 1$$'),
      tail: true,
      topNear: false,
      maxWidth: 300,
    )));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('money dollars stay plain text', (t) async {
    final st = await store();
    await t.pumpWidget(wrap(st, BubbleView(
      msg: withText('这杯奶茶 \$15，找零 \$5。'),
      tail: true,
      topNear: false,
      maxWidth: 300,
    )));
    await t.pumpAndSettle();
    // an open pair with no closing dollar never becomes math
    expect(find.textContaining(r'$15', findRichText: true), findsOneWidget);
  });

  testWidgets('a fenced block renders its header and body', (t) async {
    final st = await store();
    await t.pumpWidget(wrap(st, BubbleView(
      msg: withText('```dart\nvoid main() {}\n```'),
      tail: true,
      topNear: false,
      maxWidth: 300,
    )));
    await t.pumpAndSettle();
    expect(find.text('dart'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.textContaining('void main()', findRichText: true), findsOneWidget);
  });

  testWidgets('an html block offers a preview page', (t) async {
    final st = await store();
    await t.pumpWidget(wrap(st, BubbleView(
      msg: withText('```html\n<p>hi</p>\n```'),
      tail: true,
      topNear: false,
      maxWidth: 300,
    )));
    await t.pumpAndSettle();
    // the eye glyph sits in the header row between the language and Copy; the
    // page it opens is covered by the workspace preview tests, here it is
    // enough that the block builds and the header is present
    expect(find.text('html'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });
}
