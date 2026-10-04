import 'package:flutter/widgets.dart';

import '../core/anim.dart';
import '../core/overlays.dart';
import '../core/theme.dart';
import '../core/ui_kit.dart';
import '../data/models.dart';
import '../l10n/x.dart';

// jump to date picker days that hold messages are lit the rest are dimmed
Future<DateTime?> showCalendarSheet(BuildContext context, Chat chat) {
  return showTgSheet<DateTime>(context, (_) => _Calendar(chat: chat));
}

class _Calendar extends StatefulWidget {
  const _Calendar({required this.chat});
  final Chat chat;

  @override
  State<_Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<_Calendar> {
  late DateTime _month;
  int _dir = 1;
  late final Set<int> _days = {
    for (final m in widget.chat.msgs)
      if (!m.service) _key(DateTime.fromMillisecondsSinceEpoch(m.time)),
  };

  int _key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  @override
  void initState() {
    super.initState();
    final last = widget.chat.last;
    final d = last == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(last.time);
    _month = DateTime(d.year, d.month);
  }

  void _shift(int by) => setState(() {
        _dir = by;
        _month = DateTime(_month.year, _month.month + by);
      });

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final first = DateTime(_month.year, _month.month);
    final count = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final today = DateTime.now();
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= count; d++) _day(p, DateTime(_month.year, _month.month, d), today),
    ];
    return TgSheet(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Tap(scale: .88, onTap: () => _shift(-1), child: SizedBox(width: 48, height: 44, child: Center(child: Transform.rotate(angle: 3.14159, child: TgIcon(Ic.chevron, color: p.icon, size: 22))))),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                // the leaving month travels the way the strip travels: it exits
                // left when going forward instead of crossing the incoming one
                // (AnimatedSwitcher plays the outgoing child backwards, so its
                // begin is mirrored; its key is the previous month)
                transitionBuilder: (c, a) {
                  final leaving = c.key != ValueKey(_month);
                  return FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: Offset(.25 * _dir * (leaving ? -1 : 1), 0), end: Offset.zero).animate(a), child: c));
                },
                child: Text(monthYear(_month), key: ValueKey(_month), textAlign: TextAlign.center, style: TextStyle(color: p.title, fontSize: 18, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
              ),
            ),
            Tap(scale: .88, onTap: () => _shift(1), child: SizedBox(width: 48, height: 44, child: Center(child: TgIcon(Ic.chevron, color: p.icon, size: 22)))),
          ]),
          // the grid starts on monday, so the header row runs 2024-01-01
          // (a monday) through the sixth and intl names them per language
          Row(children: [
            for (var i = 0; i < 7; i++)
              Expanded(child: Center(child: Text(L10n.date('E').format(DateTime(2024, 1, i + 1)), style: TextStyle(color: p.subtitle, fontSize: 12, height: 2, decoration: TextDecoration.none, fontWeight: FontWeight.w500)))),
          ]),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: GridView.count(key: ValueKey(_month), shrinkWrap: true, crossAxisCount: 7, physics: const NeverScrollableScrollPhysics(), children: cells),
          ),
        ]),
      ),
    );
  }

  Widget _day(Pal p, DateTime d, DateTime today) {
    final has = _days.contains(_key(d));
    final now = _key(d) == _key(today);
    return Tap(
      scale: .9,
      onTap: has ? () => Navigator.of(context).pop(d) : null,
      child: Center(
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: has ? p.accent.withAlpha(34) : const Color(0x00000000), border: now ? Border.all(color: p.accent, width: 1.4) : null),
          child: Text('${d.day}', style: TextStyle(color: has ? p.accent : p.hint, fontSize: 16, fontWeight: has ? FontWeight.w600 : FontWeight.w400, decoration: TextDecoration.none)),
        ),
      ),
    );
  }
}
