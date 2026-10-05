import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/ui/bubble.dart';

/// The update sheet passes onWebLink so release notes link out; bubbles pass
/// nothing and must keep the plain behaviour bubble_link_test locks in.
void main() {
  Widget wrap(List<Widget> Function(BuildContext c) build) => MaterialApp(
        home: Builder(builder: (c) => Column(children: build(c))),
      );

  TextStyle style() => const TextStyle(fontSize: 14, decoration: TextDecoration.none);

  testWidgets('markdown and bare web links tap through with onWebLink', (t) async {
    final opened = <String>[];
    List<Widget> blocks(BuildContext c, String text) => mdBlocks(
          c,
          text,
          style(),
          const Color(0xFFEEEEEE),
          const Color(0xFF1488E1),
          0,
          onWebLink: opened.add,
        );
    await t.pumpWidget(wrap((c) => [
          ...blocks(c, '[note](https://example.com/x)'),
          ...blocks(c, 'https://example.com/y'),
        ]));
    await t.pumpAndSettle();

    // the label shows, the raw markdown target does not
    expect(find.textContaining('note', findRichText: true), findsOneWidget);
    expect(find.textContaining('](https://example.com/x)', findRichText: true), findsNothing);

    await t.tap(find.textContaining('note', findRichText: true));
    await t.tap(find.textContaining('https://example.com/y', findRichText: true));
    expect(opened, ['https://example.com/x', 'https://example.com/y']);
  });

  testWidgets('trailing punctuation stays outside the link', (t) async {
    final opened = <String>[];
    await t.pumpWidget(wrap((c) => mdBlocks(
          c,
          'https://example.com/z。',
          style(),
          const Color(0xFFEEEEEE),
          const Color(0xFF1488E1),
          0,
          onWebLink: opened.add,
        )));
    await t.pumpAndSettle();

    expect(find.textContaining('。', findRichText: true), findsOneWidget);
    await t.tap(find.textContaining('https://example.com/z', findRichText: true));
    expect(opened, ['https://example.com/z']);
  });

  testWidgets('no onWebLink keeps web links plain', (t) async {
    final opened = <String>[];
    await t.pumpWidget(wrap((c) => mdBlocks(
          c,
          '见 [note](https://example.com/x)',
          style(),
          const Color(0xFFEEEEEE),
          const Color(0xFF1488E1),
          0,
        )));
    await t.pumpAndSettle();

    // untouched markdown, exactly what bubbles show today
    expect(find.textContaining('](https://example.com/x)', findRichText: true), findsOneWidget);
    await t.tap(find.textContaining('note', findRichText: true));
    expect(opened, isEmpty);
  });
}
