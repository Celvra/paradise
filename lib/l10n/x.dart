import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'gen/l10n.dart';
import 'gen/l10n_en.dart';

export 'gen/l10n.dart';

extension L10nX on BuildContext {
  AppLocalizations get l => AppLocalizations.of(this);
}

/// Places that have no BuildContext, the store writing service messages and
/// the date helpers in data/models, still need the active language. [sync] is
/// called from [L10nSync] on every locale change, the same trick the palette
/// plays with the global themeCtl.
class L10n {
  static AppLocalizations _current = AppLocalizationsEn();

  static AppLocalizations get current => _current;

  /// Cache of the intl formatters, building a DateFormat per call is wasteful
  /// because each one parses the pattern and the locale data on construction.
  /// The language is baked into the value, so a change of language must clear
  /// the map, otherwise a new locale would keep reusing the old formatters.
  static final Map<String, DateFormat> _dates = {};
  static final Map<String, NumberFormat> _numbers = {};

  static void sync(AppLocalizations value) {
    if (identical(value, _current)) return;
    _current = value;
    _dates.clear();
    _numbers.clear();
  }

  static DateFormat date([String? pattern]) => _dates.putIfAbsent('${_current.localeName}|$pattern', () => DateFormat(pattern, localeTag));

  static NumberFormat number([String? pattern]) => _numbers.putIfAbsent('${_current.localeName}|$pattern', () => NumberFormat(pattern, localeTag));

  /// The active language as an intl locale string, 'en' / 'zh' / 'zh_TW'.
  ///
  /// intl ships no zh_Hant symbol data, so asking for it falls back to zh and
  /// the date parts come out simplified shaped: 周日 where Traditional wants
  /// 週日. zh_TW is the intl locale that actually carries the traditional
  /// symbols, and it covers the HK and MO readers too since they share the
  /// glyphs.
  static String get localeTag {
    final name = _current.localeName;
    if (name == 'zh_Hant') return 'zh_TW';
    return name;
  }
}

/// Keeps [L10n] in step with the delegate that MaterialApp installed.
class L10nSync extends StatefulWidget {
  const L10nSync({super.key, required this.child});

  final Widget child;

  @override
  State<L10nSync> createState() => _L10nSyncState();
}

class _L10nSyncState extends State<L10nSync> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // nullable-getter is off, so the ancestor is always there under MaterialApp
    L10n.sync(AppLocalizations.of(context));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}