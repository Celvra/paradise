import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

// palette pulled from telegram android ThemeColors and darkblue.attheme
class Pal {
  const Pal(this.c, this.dark);
  final List<Color> c;
  final bool dark;

  Color get bg => c[0];
  Color get gray => c[1];
  Color get bar => c[2];
  Color get title => c[3];
  Color get subtitle => c[4];
  Color get icon => c[5];
  Color get divider => c[6];
  Color get selector => c[7];
  Color get accent => c[8];
  Color get send => c[9];
  Color get unread => c[10];
  Color get unreadMuted => c[11];
  Color get name => c[12];
  Color get msg => c[13];
  Color get date => c[14];
  Color get pinnedBg => c[15];
  Color get pinIcon => c[16];
  Color get muteIcon => c[17];
  Color get sentCheck => c[18];
  Color get draft => c[19];
  Color get danger => c[20];
  Color get inBubble => c[21];
  List<Color> get outGrad => [c[22], c[23], c[24], c[25]];
  Color get textIn => c[26];
  Color get textOut => c[27];
  Color get timeIn => c[28];
  Color get timeOut => c[29];
  Color get checkOut => c[30];
  Color get lineIn => c[31];
  Color get lineOut => c[32];
  Color get nameIn => c[33];
  Color get nameOut => c[34];
  Color get service => c[35];
  Color get hint => c[36];
  Color get glassFill => c[37];
  Color get glassStroke => c[38];
  Color get glassIcon => c[39];
  Color get tabSel => c[40];
  Color get tabUnsel => c[41];
  List<Color> get wall => [c[42], c[43], c[44], c[45]];
  Color get codeIn => c[46];
  Color get codeOut => c[47];
  Color get sheet => c[48];
  Color get dateBold => c[49];

  static Pal lerp(Pal a, Pal b, double t) => Pal([for (var i = 0; i < a.c.length; i++) Color.lerp(a.c[i], b.c[i], t)!], t > .5 ? b.dark : a.dark);

  static const day = Pal([
    Color(0xFFFFFFFF), // bg
    Color(0xFFF1F1F3), // gray
    Color(0xFFFFFFFF), // bar
    Color(0xFF1A1D21), // title
    Color(0xFF79817E), // subtitle
    Color(0xFF1A1D21), // icon
    Color(0xFFD9D9D9), // divider
    Color(0x0F000000), // selector
    Color(0xFF229AF0), // accent
    Color(0xFF229AF0), // send
    Color(0xFF229AF0), // unread
    Color(0xFFBEC3C7), // unread muted
    Color(0xFF1A1D21), // name
    Color(0xFF75787A), // msg
    Color(0xFF848688), // date
    Color(0x08000000), // pinned bg
    Color(0xFF919294), // pin icon
    Color(0xFFBDC1C4), // mute icon
    Color(0xFF46AA36), // sent check
    Color(0xFFDD4B39), // draft
    Color(0xFFDB4A48), // danger
    Color(0xFFFFFFFF), // in bubble
    Color(0xFFEFFFDE), // out 0
    Color(0xFFEFFFDE), // out 1
    Color(0xFFEFFFDE), // out 2
    Color(0xFFEFFFDE), // out 3
    Color(0xFF000000), // text in
    Color(0xFF000000), // text out
    Color(0xFFA1AAB3), // time in
    Color(0xFF70B15C), // time out
    Color(0xFF5DB050), // check out
    Color(0xFF599FD8), // line in
    Color(0xFF6EB969), // line out
    Color(0xFF298ACF), // name in
    Color(0xFF55AB4F), // name out
    Color(0x804A6E45), // service
    Color(0xFF858A84), // hint
    Color(0xB8FFFFFF), // glass fill
    Color(0x1A000000), // glass stroke
    Color(0x991B2227), // glass icon
    Color(0xFF1A91E6), // tab selected
    Color(0xFF1A1D21), // tab unselected
    Color(0xFFDBDDBB), // wall 0
    Color(0xFF6BA587), // wall 1
    Color(0xFFD5D88D), // wall 2
    Color(0xFF88B884), // wall 3
    Color(0x0D000000), // code in
    Color(0x0D000000), // code out
    Color(0xFFFFFFFF), // sheet
    Color(0xFF919395), // date bold
  ], false);

  static const night = Pal([
    Color(0xFF1D2733), // bg
    Color(0xFF151E27), // gray
    Color(0xFF242D39), // bar
    Color(0xFFFFFFFF), // title
    Color(0x7DDBF2FF), // subtitle
    Color(0xFFFFFFFF), // icon
    Color(0xFF111820), // divider
    Color(0x1AFFFFFF), // selector
    Color(0xFF64B5EF), // accent
    Color(0xFF229AF0), // send
    Color(0xFF64B5EF), // unread
    Color(0xFF3E5263), // unread muted
    Color(0xFFE9EEF4), // name
    Color(0xFF7D8B99), // msg
    Color(0xFF737F8B), // date
    Color(0x08FFFFFF), // pinned bg
    Color(0xFF586D80), // pin icon
    Color(0xFF4E5F6A), // mute icon
    Color(0xFF64B5EF), // sent check
    Color(0xFFE0524F), // draft
    Color(0xFFED5D54), // danger
    Color(0xFF232E3B), // in bubble
    Color(0xFF258DE5), // out 0
    Color(0xFF4272DF), // out 1
    Color(0xFF8146D7), // out 2
    Color(0xFF9F3EAA), // out 3
    Color(0xFFFAFAFA), // text in
    Color(0xFFFFFFFF), // text out
    Color(0xD98091A0), // time in
    Color(0xB3FFFFFF), // time out
    Color(0xFFFFFFFF), // check out
    Color(0xFF79C4FC), // line in
    Color(0xFFFFFFFF), // line out
    Color(0xFF79C4FC), // name in
    Color(0xFFFFFFFF), // name out
    Color(0x82354251), // service
    Color(0x6EDBEFFF), // hint
    Color(0xB3212D3B), // glass fill
    Color(0x22FFFFFF), // glass stroke
    Color(0xB0DBEFFF), // glass icon
    Color(0xFF64B5EF), // tab selected
    Color(0xFFE9EEF4), // tab unselected
    Color(0xFF1B2A3D), // wall 0
    Color(0xFF0D1620), // wall 1
    Color(0xFF24354B), // wall 2
    Color(0xFF121C29), // wall 3
    Color(0x26000000), // code in
    Color(0x33000000), // code out
    Color(0xFF212D3B), // sheet
    Color(0xFF787878), // date bold
  ], true);
}

// night switch fades palette over 220ms like the android theme animation
class ThemeController extends ChangeNotifier {
  Pal pal = Pal.day;
  bool dark = false;
  Pal _from = Pal.day;
  Pal _to = Pal.day;
  Duration? _start;
  int _gen = 0;

  void setDark(bool v, {bool animate = true}) {
    if (v == dark) return;
    dark = v;
    _from = pal;
    _to = v ? Pal.night : Pal.day;
    if (!animate) {
      pal = _to;
      notifyListeners();
      return;
    }
    _start = null;
    _tick(++_gen);
  }

  void _tick(int gen) {
    SchedulerBinding.instance.scheduleFrameCallback((d) {
      if (gen != _gen) return;
      _start ??= d;
      final t = ((d - _start!).inMilliseconds / 220).clamp(0.0, 1.0);
      pal = Pal.lerp(_from, _to, Curves.easeInOut.transform(t));
      notifyListeners();
      if (t < 1) _tick(gen);
    });
  }
}

final ThemeController themeCtl = ThemeController();

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({super.key, required ThemeController controller, required super.child}) : super(notifier: controller);
  static Pal of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<ThemeScope>()!.notifier!.pal;
}

extension PalX on BuildContext {
  Pal get p => ThemeScope.of(this);
}

// telegram avatar gradient pairs top to bottom
const avatarColors = <List<Color>>[
  [Color(0xFFFF845E), Color(0xFFD45246)],
  [Color(0xFFFEBB5B), Color(0xFFF68136)],
  [Color(0xFFB694F9), Color(0xFF6C61DF)],
  [Color(0xFF9AD164), Color(0xFF46BA43)],
  [Color(0xFF5BCBE3), Color(0xFF359AD4)],
  [Color(0xFF5CAFFA), Color(0xFF408ACF)],
  [Color(0xFFFF8AAC), Color(0xFFD95574)],
];
