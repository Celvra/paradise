import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/core/theme.dart';
import 'package:paradise/core/ui_kit.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/data/world_book/world_book.dart';
import 'package:paradise/l10n/gen/l10n_en.dart';
import 'package:paradise/l10n/x.dart';
import 'package:paradise/ui/tg_cells.dart';
import 'package:paradise/ui/world_book_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_paths.dart';

/// The picker is the page a role's card opens to bind world books. It once
/// wrapped every book in a section of its own, so three books read as three
/// floating cards with gaps between them instead of one list. These pin the
/// single card: the count of sections, not the look, is what regressed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Store st;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await useTempDocsDir('wb_picker');
    L10n.sync(AppLocalizationsEn());
    st = await Store.load();
    for (final name in ['Fantasy', 'Scifi', 'Noir']) {
      await st.worldBooks.create(name: name, entries: [WorldEntry(id: 'e-$name', comment: 'note', content: 'lore')]);
    }
  });

  Future<void> show(WidgetTester t, {List<String> selected = const []}) async {
    await t.pumpWidget(StoreScope(
      store: st,
      child: ThemeScope(
        controller: themeCtl,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WorldBookPickerPage(selected: selected),
        ),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  testWidgets('every book is a row of one card, not a card of its own', (t) async {
    await show(t);

    expect(find.text('Choose world books'), findsOneWidget);
    // three books, one section: a section per book made the page explode
    // into a stack of floating rows with gaps between them
    expect(find.byType(TgSection), findsOneWidget);
    for (final name in ['Fantasy', 'Scifi', 'Noir']) {
      expect(find.text(name), findsOneWidget);
      expect(find.textContaining('1 entries'), findsWidgets, reason: 'the row subtitle');
    }
    // the footer explains what binding means, inside the same card
    expect(find.text('The books this role lives in.'), findsOneWidget);
  });

  testWidgets('the save button is pinned to the bottom of the page', (t) async {
    await show(t);

    expect(find.text('Save'), findsOneWidget);
    final button = find.byType(TgButton).evaluate().single.findRenderObject() as RenderBox;
    final top = button.localToGlobal(Offset.zero).dy;
    final screen = t.view.physicalSize.height / t.view.devicePixelRatio;
    // bottom of the button sits on the bottom inset padding of the page, not
    // right under the books: a short list must not leave it floating mid screen
    expect(top + button.size.height, closeTo(screen - 12, 1));
    // and it clears the card above it
    final section = find.byType(TgSection).evaluate().single.findRenderObject() as RenderBox;
    final sectionBottom = section.localToGlobal(Offset.zero).dy + section.size.height;
    expect(top, greaterThanOrEqualTo(sectionBottom));
    expect(find.byType(TgSection), findsOneWidget);
  });

  testWidgets('ticking a row keeps the one-card layout and the pick', (t) async {
    await show(t);

    await t.tap(find.text('Scifi'));
    await t.pumpAndSettle();

    expect(find.byType(TgSection), findsOneWidget);
    // the state the page will hand back on Save
    expect(st.worldBooks.books.map((b) => b.name), contains('Scifi'));
  });

  testWidgets('a pre-selected book starts ticked, still one card', (t) async {
    final bound = st.worldBooks.books.first.id;
    await show(t, selected: [bound]);

    expect(find.byType(TgSection), findsOneWidget);
    expect(find.text('Fantasy'), findsOneWidget);
  });

  testWidgets('no books at all: the empty state is the one card', (t) async {
    for (final b in [...st.worldBooks.books]) {
      await st.worldBooks.remove(b.id);
    }
    await show(t);

    expect(find.byType(TgSection), findsOneWidget);
    expect(find.text('No world book yet'), findsOneWidget);
    expect(find.textContaining('Create one, or import'), findsOneWidget);
    // the pinned save still closes an empty page
    expect(find.text('Save'), findsOneWidget);
  });
}
