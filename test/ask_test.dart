import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paradise/core/theme.dart';
import 'package:paradise/data/models.dart';
import 'package:paradise/data/store.dart';
import 'package:paradise/l10n/x.dart';
import 'package:paradise/ui/media_bubbles.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The `ask` tool's card: the store side is a small state machine (stage,
// submit, skip, close) and the UI side is a poll card with a submit row.
// Both are pinned here so a later poll change cannot silently break asking.

Msg askCard({required bool multi, Map<String, dynamic>? extra}) {
  final m = Msg(id: 'ask1', out: false, time: 0, text: '', kind: MsgKind.poll);
  m.data.addAll({
    'q': 'Tea or coffee?',
    'opts': ['Tea', 'Coffee'],
    'votes': [0, 0],
    'mine': <int>[],
    'multi': multi,
    'quiz': false,
    'anon': true,
    'ask': true,
    'closed': false,
    ...?extra,
  });
  return m;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('ask state machine', () {
    test('a single choice closes on the first tap', () async {
      final st = await Store.load();
      final c = st.createChat('A', 'p');
      final m = askCard(multi: false);
      c.msgs.add(m);
      st.votePoll(c, m, 1);
      expect(m.data['mine'], [1]);
      expect(m.data['closed'], true);
    });

    test('a tap after close is a no-op', () async {
      final st = await Store.load();
      final c = st.createChat('A', 'p');
      final m = askCard(multi: false);
      c.msgs.add(m);
      st.votePoll(c, m, 0);
      st.votePoll(c, m, 1);
      expect(m.data['mine'], [0]);
      expect(m.data['closed'], true);
    });

    test('a multi choice stages taps until submit', () async {
      final st = await Store.load();
      final c = st.createChat('A', 'p');
      final m = askCard(multi: true);
      c.msgs.add(m);
      st.votePoll(c, m, 0);
      st.votePoll(c, m, 1);
      expect(m.data['closed'] != true, true);
      expect(Set<int>.from(m.data['mine'] as List), {0, 1});
      // tapping again unstages
      st.votePoll(c, m, 0);
      expect(m.data['mine'], [1]);
      expect(st.submitAskPoll(c, m), true);
      expect(m.data['closed'], true);
    });

    test('submit with nothing staged refuses', () async {
      final st = await Store.load();
      final c = st.createChat('A', 'p');
      final m = askCard(multi: true);
      c.msgs.add(m);
      expect(st.submitAskPoll(c, m), false);
      expect(m.data['closed'] != true, true);
    });

    test('custom text alone submits', () async {
      final st = await Store.load();
      final c = st.createChat('A', 'p');
      final m = askCard(multi: false);
      c.msgs.add(m);
      st.setAskCustom(c, m, '  juice  ');
      expect(m.data['custom'], 'juice');
      expect(st.submitAskPoll(c, m), true);
      expect(m.data['closed'], true);
    });

    test('custom text is capped at 500 and frozen once closed', () async {
      final st = await Store.load();
      final c = st.createChat('A', 'p');
      final m = askCard(multi: true);
      c.msgs.add(m);
      st.setAskCustom(c, m, 'x' * 600);
      expect((m.data['custom'] as String).length, 500);
      st.skipAskPoll(c, m);
      st.setAskCustom(c, m, 'late');
      expect((m.data['custom'] as String).length, 500);
    });

    test('skip marks the card and a second skip changes nothing', () async {
      final st = await Store.load();
      final c = st.createChat('A', 'p');
      final m = askCard(multi: true);
      c.msgs.add(m);
      st.skipAskPoll(c, m);
      expect(m.data['skipped'], true);
      expect(m.data['closed'], true);
      m.data['skipped'] = false;
      st.skipAskPoll(c, m);
      expect(m.data['skipped'], false);
    });

    test('an ordinary poll keeps toggling and never closes', () async {
      final st = await Store.load();
      final c = st.createChat('A', 'p');
      final m = Msg(id: 'p1', out: false, time: 0, text: '', kind: MsgKind.poll);
      m.data.addAll({'q': 'Lunch?', 'opts': ['A', 'B'], 'votes': [0, 0], 'mine': <int>[], 'multi': false});
      c.msgs.add(m);
      st.votePoll(c, m, 0);
      expect(m.data['mine'], [0]);
      expect(m.data['closed'] != true, true);
      st.votePoll(c, m, 0);
      expect(m.data['mine'], isEmpty);
      expect(m.data['closed'] != true, true);
    });

    test('cancelling with nothing pending leaves the card alone', () async {
      final st = await Store.load();
      final c = st.createChat('A', 'p');
      final m = askCard(multi: false);
      c.msgs.add(m);
      st.cancelAskForChat(c.id);
      expect(m.data['closed'] != true, true);
    });
  });

  group('ask card', () {
    Widget wrap(Msg m, {void Function(int)? onVote, VoidCallback? onSubmit, VoidCallback? onSkip, ValueChanged<String>? onCustom}) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ThemeScope(
            controller: themeCtl,
            child: MediaQuery(
              data: const MediaQueryData(size: Size(380, 800)),
              child: SizedBox(
                width: 380,
                child: Builder(
                  builder: (ctx) => mediaBody(ctx, m: m, p: ctx.p, width: 280, out: false, onAskVote: onVote, onAskSubmit: onSubmit, onAskSkip: onSkip, onAskCustom: onCustom),
                ),
              ),
            ),
          ),
        );

    testWidgets('a single card answers on tap and skips on skip', (t) async {
      final m = askCard(multi: false);
      var voted = -1;
      var skipped = false;
      await t.pumpWidget(wrap(m, onVote: (i) => voted = i, onSubmit: () {}, onSkip: () => skipped = true, onCustom: (_) {}));
      expect(find.text('Tea or coffee?'), findsOneWidget);
      expect(find.text('Tea'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
      await t.tap(find.text('Coffee'));
      expect(voted, 1);
      await t.tap(find.text('Skip'));
      expect(skipped, true);
      expect(t.takeException(), isNull);
    });

    testWidgets('typing enables submit and submit flushes the text first', (t) async {
      final m = askCard(multi: true);
      final calls = <String>[];
      await t.pumpWidget(wrap(m, onVote: (_) {}, onSubmit: () => calls.add('submit'), onSkip: () {}, onCustom: (s) => calls.add('custom:$s')));
      await t.tap(find.text('Submit'));
      await t.pump();
      // nothing staged, the tap lands on a disabled button
      expect(calls, isEmpty);
      await t.enterText(find.byType(EditableText), 'juice');
      await t.pump();
      await t.tap(find.text('Submit'));
      expect(calls, ['custom:juice', 'submit']);
      expect(t.takeException(), isNull);
    });

    testWidgets('a settled card shows its state and no buttons', (t) async {
      final done = askCard(multi: true, extra: {'mine': [0], 'closed': true});
      await t.pumpWidget(wrap(done));
      await t.pump();
      expect(find.text('Submit'), findsNothing);
      expect(find.text('Skip'), findsNothing);
      expect(find.byType(EditableText), findsNothing);
      // english strings come from the real arb through the delegates
      expect(find.text('Answered'), findsOneWidget);

      final skipped = askCard(multi: false, extra: {'skipped': true, 'closed': true});
      await t.pumpWidget(wrap(skipped));
      await t.pump();
      expect(find.text('Skipped'), findsOneWidget);
      expect(find.text('Submit'), findsNothing);
      expect(t.takeException(), isNull);
    });
  });
}
