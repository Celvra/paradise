import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/core/theme.dart';
import 'package:paradise/l10n/gen/l10n.dart';
import 'package:paradise/ui/whats_new.dart';

// The update dialog's body text once came without a color, which reads black.
// On the night-mode dialog that is black on near-black. These pin the body to
// the theme's own title color in both modes.
void main() {
  Future<void> openDialog(WidgetTester t, {required bool dark}) async {
    themeCtl.setDark(dark, animate: false);
    addTearDown(() => themeCtl.setDark(false, animate: false));
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        home: ThemeScope(
          controller: themeCtl,
          child: Builder(builder: (c) {
            WidgetsBinding.instance.addPostFrameCallback((_) => showWhatsNewDialog(c));
            return const SizedBox();
          }),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  Color bodyColor(WidgetTester t) {
    final texts = t.widgetList<Text>(find.byType(Text)).where((w) => (w.data ?? '').isNotEmpty).toList();
    // the dialog carries the title and the action label too; the body is the
    // long one. Last of the longest: each phase opens its own dialog on top of
    // the previous one, and the topmost route is the one under test.
    texts.sort((a, b) => (b.data?.length ?? 0).compareTo(a.data?.length ?? 0));
    final longest = texts.first.data?.length ?? 0;
    final w = texts.lastWhere((x) => (x.data?.length ?? 0) == longest);
    // Text.style is the unresolved one. A style the dialog resolves against
    // the ambient DefaultTextStyle reads differently from what this file set,
    // so the two are folded the way the render object does.
    final ambient = DefaultTextStyle.of(t.element(find.byWidget(w)));
    final mine = w.style ?? const TextStyle();
    return mine.color ?? ambient.style.color ?? const Color(0xFF000000);
  }

  testWidgets('the body follows the theme, not black', (t) async {
    await openDialog(t, dark: false);
    final light = bodyColor(t);
    expect(light, isNot(const Color(0xFF000000)));

    await openDialog(t, dark: true);
    final darkColor = bodyColor(t);
    expect(darkColor, isNot(const Color(0xFF000000)));
    // both are the running palette's title color, so this is not a fixed tint
    // that happens to read in daylight. Same instance, because Text takes the
    // palette's color object by reference rather than copying its channels.
    expect(identical(darkColor, themeCtl.effective.title), isTrue);
  });
}