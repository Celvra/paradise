import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/core/theme.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/l10n/gen/l10n_en.dart';
import 'package:paradise/l10n/x.dart';
import 'package:paradise/ui/bubble.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A cited workspace file arrives as markdown: `[label](paradise://zone/path)`.
// The bubble has to turn that into a tappable link and leave everything that
// only looks like one alone.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // an explicit empty list rather than {}: a first launch seeds starter
  // chats and arms the save debounce, a timer this fake async test would
  // otherwise end with still pending
  SharedPreferences.setMockInitialValues({'chats': '[]'});
  L10n.sync(AppLocalizationsEn());

  Widget wrap(Store st, Widget child) => MaterialApp(
        home: StoreScope(
          store: st,
          child: ThemeScope(
            controller: themeCtl,
            child: MediaQuery(data: const MediaQueryData(), child: child),
          ),
        ),
      );

  Msg withText(String text) => Msg(id: 'b1', out: false, text: text, time: 1, read: true);

  testWidgets('a cited file link renders as its label and taps through', (t) async {
    final st = await Store.load();
    var opened = '';
    const url = 'paradise://workspace/%E5%92%AA%E7%9A%84%E8%A7%82%E5%AF%9F%E6%97%A5%E8%AE%B0.txt';
    await t.pumpWidget(wrap(st, BubbleView(
      msg: withText('写好了：[咪的观察日记.txt]($url)'),
      tail: true,
      topNear: false,
      maxWidth: 300,
      onFileLink: (l) => opened = l,
    )));
    await t.pumpAndSettle();

    // the label shows, the encoded url does not
    expect(find.textContaining('咪的观察日记.txt', findRichText: true), findsOneWidget);
    expect(find.textContaining('%E5%92%AA', findRichText: true), findsNothing);

    await t.tap(find.textContaining('咪的观察日记.txt', findRichText: true));
    expect(opened, url);
  });

  testWidgets('a bare url link taps with itself as the label', (t) async {
    final st = await Store.load();
    var opened = '';
    const url = 'paradise://workspace/notes.md';
    await t.pumpWidget(wrap(st, BubbleView(
      msg: withText('在 $url 里'),
      tail: true,
      topNear: false,
      maxWidth: 300,
      onFileLink: (l) => opened = l,
    )));
    await t.pumpAndSettle();

    await t.tap(find.textContaining('notes.md'));
    expect(opened, url);
  });

  testWidgets('text that only looks like a link stays plain', (t) async {
    final st = await Store.load();
    var opened = '';
    await t.pumpWidget(wrap(st, BubbleView(
      // no handler is the same as an inert link; a bracket label without our
      // scheme must not be eaten either
      msg: withText('见 [note](https://example.com/x) 和普通括号 [草稿]'),
      tail: true,
      topNear: false,
      maxWidth: 300,
      onFileLink: (l) => opened = l,
    )));
    await t.pumpAndSettle();

    expect(find.textContaining('https://example.com'), findsOneWidget);
    expect(find.textContaining('[草稿]', findRichText: true), findsOneWidget);
    await t.tap(find.textContaining('https://example.com'));
    expect(opened, '');
  });

  testWidgets('no handler means inert tinted text', (t) async {
    final st = await Store.load();
    await t.pumpWidget(wrap(st, BubbleView(
      msg: withText('[a](paradise://workspace/a.md)'),
      tail: true,
      topNear: false,
      maxWidth: 300,
    )));
    await t.pumpAndSettle();
    expect(find.textContaining('a', findRichText: true), findsOneWidget);
  });
}
