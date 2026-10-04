import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// How far the outgoing bubble gradients once a wallpaper has recoloured the
/// accent.
///
/// The two stock palettes disagree here, day is one flat green and night runs
/// blue to purple, so without a level the recoloured bubble would have to pick
/// one of them arbitrarily. These span from barely distinguishable from flat to
/// as wide as the night bubble gets.
enum BubbleGrad {
  /// A shade or two across the whole bubble.
  subtle,

  /// Reads as a gradient without competing with the text on it.
  medium,

  /// The widest run that still leaves the timestamp readable at the bottom.
  strong,
}

// palette pulled from telegram android ThemeColors and darkblue.attheme
class Pal {
  const Pal(this.c, this.dark, {this.seed});
  final List<Color> c;
  final bool dark;

  /// The wallpaper colour this palette was derived from, null for the two stock
  /// palettes. Widgets that replace a stock colour read this rather than guessing
  /// from [accent], which is set whether or not a colour was ever picked.
  final Color? seed;

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

  /// The persona cover gradient for tone [index], on this palette's accent.
  List<Color> avatar(int index) => avatarGradient(accent, index);

  /// Gradient icon tile, on the wallpaper colour once one is set.
  List<Color> iconTile(List<Color> stock) =>
      seed == null ? stock : iconGradient(accent);

  /// Flat fill behind every icon block on the AI pages, so the header disc, the
  /// row tiles and the provider avatars are one colour. Grey when [ready] is
  /// false and no wallpaper colour has been picked.
  Color aiIcon({required bool ready}) => seed == null
      ? (ready ? const Color(0xFF5A9EE8) : const Color(0xFF6E8397))
      : accent;

  /// Bulletin pill. The accent itself will not do, it is solved to read against
  /// the page and leaves white at 2.2:1, so the hue is pushed down to 0.15.
  Color get toastBg {
    if (seed == null) return const Color(0xF2263340);
    final hsl = HSLColor.fromColor(accent);
    return _tone(hsl.hue, hsl.saturation.clamp(0.30, 0.90), 0.15);
  }

  static Pal lerp(Pal a, Pal b, double t) => Pal(
      [for (var i = 0; i < a.c.length; i++) Color.lerp(a.c[i], b.c[i], t)!],
      t > .5 ? b.dark : a.dark);

  /// A copy of this palette recoloured from [seed], which is a colour pulled out
  /// of the user's wallpaper.
  ///
  /// The whole scheme follows the seed, the way a Material You scheme is derived
  /// from one colour, but by way of the [chroma] table rather than by rebuilding
  /// the role list. Each slot keeps the relative luminance it already had and
  /// only trades its hue and saturation for the seed's. That is what keeps this
  /// safe: WCAG contrast is a function of the two luminances alone, so a pair
  /// that read at 4.5:1 before still reads at 4.5:1 after, and no combination of
  /// them can drift into illegibility the way a retuned brightness would.
  ///
  /// The luminance a role does get retuned, the accent and the outgoing bubble,
  /// is solved for rather than set from an HSL lightness. HSL lightness is not
  /// perceptual: yellow and blue at the same lightness differ by a factor of ten
  /// in how bright they look, so a fixed lightness gives a readable bubble for
  /// one seed and white on yellow for the next.
  ///
  /// [grad] picks how far the bubble's own gradient runs. It is not a free
  /// choice: the clock, the ticks and the sender name ride on the bubble and the
  /// bottom stop is the worst surface any of them get, so the day ink is solved
  /// against that stop rather than picked.
  Pal withAccent(Color seed, {BubbleGrad grad = BubbleGrad.medium}) {
    final hsl = HSLColor.fromColor(seed);
    final hue = hsl.hue;
    final sat = hsl.saturation.clamp(0.30, 0.90);

    final c2 = [...c];

    // Re-hue every slot that has a share of the seed, at the luminance it
    // already had and the alpha it already had. Alpha has to come along or the
    // translucent surfaces turn solid.
    for (var i = 0; i < c2.length; i++) {
      final share = _chroma[i];
      if (share == 0) continue;
      final from = c[i];
      final tinted = _tone(hue, sat * share, _relativeLuminance(from));
      c2[i] = tinted.withValues(alpha: from.a);
    }

    // day sits on a white bar and carries black text, night is the reverse, so
    // the two want opposite ends of the range for the same seed
    final accent = _tone(hue, sat, dark ? 0.42 : 0.22);
    c2[8] = accent;
    c2[9] = accent;
    c2[10] = accent;

    // lightest stop first, which is the order BubblePainter hands them to its
    // vertical gradient
    final bubble = <Color>[
      for (final target in (dark ? _nightStops : _dayStops)[grad.index])
        _tone(hue, sat, target),
    ];
    c2[22] = bubble[0];
    c2[23] = bubble[1];
    c2[24] = bubble[2];
    c2[25] = bubble[3];

    if (!dark) {
      // The clock, ticks and name ride on top of the bubble and the stock values
      // are green. They follow the bubble's hue now or they would clash, and
      // they are only allowed to be as dark as the darkest stop will carry, or
      // the timestamp sinks into the bottom of a wide gradient.
      final ink = _tone(hue, sat, math.min(0.12, _inkCeiling(bubble.last)));
      c2[29] = ink; // time out
      c2[30] = ink; // check out
      c2[32] = ink; // line out
      c2[34] = ink; // name out
    }
    // night needs no ink pass: its time, ticks, line and name are already pale
    // stock values, and every stop up here stays far below the point where white
    // text stops reading.
    return Pal(c2, dark, seed: seed);
  }

  /// How much of the seed's saturation each slot takes, as a share of it.
  ///
  /// Material derives a whole scheme from one seed by stacking tonal palettes: the
  /// primary roles carry the chroma, the secondary and tertiary roles step it
  /// down, and the structural roles keep only a trace of the hue. A trace is
  /// what gives a tinted surface rather than a coloured one, and it is why the
  /// background, the bars and the dividers are in here at all.
  ///
  /// Zero leaves the slot on its stock value. That is either a pure overlay whose
  /// colour has to depend on whatever is behind it, the selectors and the glass
  /// hairlines, or a role where the colour is the message rather than the style,
  /// which is why danger and draft stay red no matter what the wallpaper is.
  ///
  /// Indexed to the palette slots, so each entry sits under the same comment as
  /// the colour it governs.
  static const _chroma = <double>[
    0.10, // bg, a trace so a white page reads as belonging to the accent
    0.10, // gray
    0.12, // bar
    0.10, // title
    0.22, // subtitle
    0.10, // icon
    0.10, // divider
    0.00, // selector, black or white over whatever it lands on
    0.00, // accent, solved rather than tinted
    0.00, // send, solved
    0.00, // unread, solved
    0.35, // unread muted
    0.10, // name
    0.18, // msg
    0.18, // date
    0.00, // pinned bg, an alpha overlay
    0.30, // pin icon
    0.25, // mute icon
    0.85, // sent check
    0.00, // draft, red is the message
    0.00, // danger, red is the message
    0.10, // in bubble
    0.00, // out 0, solved
    0.00, // out 1, solved
    0.00, // out 2, solved
    0.00, // out 3, solved
    0.00, // text in, body copy stays neutral
    0.00, // text out, body copy stays neutral
    0.22, // time in
    0.00, // time out, solved in day and left pale at night
    0.00, // check out, as above
    0.85, // line in, the quote rule on an incoming bubble
    0.00, // line out, solved
    0.90, // name in, the sender name on an incoming bubble
    0.00, // name out, solved
    0.45, // service
    0.28, // hint
    0.12, // glass fill
    0.00, // glass stroke, a hairline
    0.35, // glass icon
    1.00, // tab selected, the same family as the accent in stock
    0.10, // tab unselected
    0.75, // wall 0
    0.75, // wall 1
    0.75, // wall 2
    0.75, // wall 3
    0.00, // code in, an alpha overlay
    0.00, // code out, an alpha overlay
    0.10, // sheet
    0.18, // date bold
  ];

  /// Luminance targets for the four bubble stops, one list per level, ordered
  /// lightest first.
  ///
  /// Day sits high because black text rides on it. The subtle row barely
  /// separates from flat, which is what the stock day bubble is; strong runs far
  /// enough to read as a gradient without the bottom stop going muddy.
  static const _dayStops = <List<double>>[
    [0.78, 0.76, 0.74, 0.72], // subtle
    [0.82, 0.77, 0.72, 0.67], // medium
    [0.86, 0.76, 0.64, 0.52], // strong
  ];

  /// The same for night, where white text means the whole bubble stays dark.
  static const _nightStops = <List<double>>[
    [0.13, 0.115, 0.10, 0.085], // subtle
    [0.12, 0.09, 0.07, 0.055], // medium
    [0.16, 0.115, 0.07, 0.035], // strong
  ];

  /// The darkest ink that still clears 4.5:1 against [bubble], as a luminance
  /// target for [_tone].
  static double _inkCeiling(Color bubble) =>
      (_relativeLuminance(bubble) + 0.05) / 4.5 - 0.05;

  /// The colour at this hue and saturation whose relative luminance is as close
  /// to [target] as it can get without going over it.
  ///
  /// Binary search over HSL lightness, which is monotonic in luminance for a
  /// fixed hue and saturation. The loop keeps the invariant that [lo] is the
  /// brightest candidate still under the target, and that is what it returns, so
  /// callers that solve one tone against another can treat the target as a hard
  /// ceiling. Returning the midpoint instead would land on either side of the
  /// target, and two of those overshoots in opposite directions is how
  /// [_inkCeiling] ended up a hair under the contrast it promises.
  ///
  /// 20 steps is well under a 1/255 step in the result and this runs a handful
  /// of times when a wallpaper is applied, never in a frame.
  static Color _tone(double hue, double sat, double target) {
    var lo = 0.0, hi = 1.0;
    for (var i = 0; i < 20; i++) {
      final mid = (lo + hi) / 2;
      if (_relativeLuminance(HSLColor.fromAHSL(1, hue, sat, mid).toColor()) <
          target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return HSLColor.fromAHSL(1, hue, sat, lo).toColor();
  }

  /// WCAG relative luminance.
  static double _relativeLuminance(Color c) {
    double ch(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

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

  /// A colour lifted off the user's wallpaper, or null to keep the stock accent.
  /// Held here rather than in the store so the palette stays the single source
  /// of what the UI paints.
  int? _accent;
  int? get accent => _accent;

  /// How wide the outgoing bubble gradients while [_accent] is set. Carries no
  /// meaning without one, since the stock bubbles keep their own treatment.
  BubbleGrad _grad = BubbleGrad.medium;
  BubbleGrad get grad => _grad;

  /// The palette the widgets actually read. Applying the accent here instead of
  /// baking it into [pal] keeps the day and night animation below untouched:
  /// the fade still runs between the two stock palettes and the accent is laid
  /// over whatever the fade produced.
  Pal get effective =>
      _accent == null ? pal : pal.withAccent(Color(_accent!), grad: _grad);

  /// Idempotent on purpose. main.dart calls this while it builds, and a setter
  /// that notified on an unchanged value would trip the build-phase guard.
  void setAccent(int? argb, [BubbleGrad grad = BubbleGrad.medium]) {
    if (_accent == argb && _grad == grad) return;
    _accent = argb;
    _grad = grad;
    notifyListeners();
  }

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
  const ThemeScope(
      {super.key, required ThemeController controller, required super.child})
      : super(notifier: controller);

  /// The palette for [c], falling back to the ambient controller.
  ///
  /// The fallback is not defensive coding. Menus, sheets and dialogs are pushed
  /// on the root navigator, which sits above the scope this widget installs, so
  /// a plain lookup there returns null and the palette comes from the process
  /// wide controller instead. Without it every popup opened from a page that
  /// wraps itself in its own scope would fail to build.
  static Pal of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier?.effective ??
      themeCtl.effective;
}

extension PalX on BuildContext {
  Pal get p => ThemeScope.of(this);
}

// telegram avatar gradient pairs top to bottom
/// How many cover gradients a persona can be assigned.
const avatarColorCount = 7;

/// The seven persona covers are spread down a lightness ladder rather than
/// around the hue circle, top stop first.
///
/// Solving for a fixed relative luminance instead would collapse the ladder: a
/// saturated blue cannot reach the brightness a saturated yellow can, so every
/// step would clamp to the same blue and the picker would show seven identical
/// swatches. Lightness is directly controllable, so every rung is distinct for
/// every hue.
///
/// The band matches where the fixed gradients used to sit, so the covers keep
/// their brightness character and the white name on top still reads as well as
/// it did.
/// The band the fixed gradients used to occupy, pulled down.
///
/// Their lightest cover was a yellow at 1.68:1 against white, which is where the
/// white name on top of a cover already stopped being readable, so the ladder
/// starts below that rather than at it.
const _avatarLadder = <List<double>>[
  [0.54, 0.38],
  [0.50, 0.34],
  [0.46, 0.30],
  [0.42, 0.26],
  [0.38, 0.22],
  [0.34, 0.18],
  [0.30, 0.14],
];

/// The persona cover gradient for tone [index], on [accent]'s hue.
///
/// The covers used to be seven fixed hue pairs, which left them the one surface
/// in the app that ignored the wallpaper accent. They follow it now, and the
/// ladder keeps the seven telling each other apart.
List<Color> avatarGradient(Color accent, int index) {
  final hsl = HSLColor.fromColor(accent);
  // The saturation cap is a legibility bound, not a style choice. A pure yellow
  // at full chroma drives two channels to the top at once, so it is the brightest
  // colour the ladder can be asked for and the first thing to wash out the white
  // name. Capping here holds every hue to about 2:1 against white.
  final sat = hsl.saturation.clamp(0.34, 0.55);
  final rung = _avatarLadder[index % avatarColorCount];
  return [
    HSLColor.fromAHSL(1, hsl.hue, sat, rung[0]).toColor(),
    HSLColor.fromAHSL(1, hsl.hue, sat, rung[1]).toColor(),
  ];
}

/// Second rung of the cover ladder, which is where the icon tiles take their
/// gradient from: brighter than a cover, so the white glyph keeps its margin.
List<Color> iconGradient(Color accent) => avatarGradient(accent, 1);
