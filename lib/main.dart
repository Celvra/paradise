import 'dart:async';

import 'package:flutter/material.dart' show MaterialApp, ThemeData, NoSplash;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'core/theme.dart';
import 'data/ai_config.dart';
import 'data/human/notifications.dart';
import 'data/store.dart';
import 'ui/human_data_pages.dart' show appNav, askToolPermission;
import 'l10n/x.dart';
import 'ui/ai_model_picker.dart' show AiScope;
import 'ui/dialogs_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final store = await Store.load();
  final ai = await AiConfig.load();
  store.attachAi(ai);
  // The wallpaper accent lives in the store but colours the palette, so the two
  // are kept in step here rather than either reaching into the other: once at
  // startup for the saved value, then on every store change. setAccent is a
  // no-op when the value has not moved, so the other notifications this listens
  // to cost nothing.
  themeCtl.setAccent(store.wallpaperColor, BubbleGrad.values[store.wallpaperBubbleGrad]);
  store.addListener(() => themeCtl.setAccent(store.wallpaperColor, BubbleGrad.values[store.wallpaperBubbleGrad]));
  // humanized layer: notifications, the tool permission dialog, the scheduler
  // heartbeat and the periodic background job for killed-app delivery
  await Notifier.instance.init();
  store.human!.askHandler = askToolPermission;
  store.startHuman();
  unawaited(registerBackground());
  runApp(TgApp(store: store, ai: ai));
}

// android reports zh_TW and zh_HK without a script tag often enough that the
// default resolution hands traditional users the simplified table
Locale? resolveLocale(Locale? device, Iterable<Locale> supported) {
  if (device?.languageCode == 'zh' && device?.scriptCode == null) {
    const trad = ['TW', 'HK', 'MO'];
    if (trad.contains(device!.countryCode)) return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
  }
  return basicLocaleListResolution(<Locale>[if (device != null) device], supported);
}

class TgApp extends StatelessWidget {
  const TgApp({super.key, required this.store, required this.ai});
  final Store store;
  final AiConfig ai;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: AiScope(
        config: ai,
        child: ThemeScope(
          controller: themeCtl,
          child: Builder(builder: (context) {
          // Both dependencies have to be taken here, and neither of them is
          // obvious. context.p only subscribes to the palette, so a language
          // change would notify the store and rebuild the pages underneath
          // while MaterialApp kept the old locale and its delegate tree with
          // it, which reads as "the change lands after a restart". Reading the
          // store registers it, so MaterialApp is rebuilt and the whole
          // Localizations subtree follows in the same frame.
          final p = context.p;
          final st = context.store;
          final dark = p.dark;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: const Color(0x00000000),
              systemNavigationBarColor: const Color(0x00000000),
              statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
              systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
              systemNavigationBarContrastEnforced: false,
            ),
            child: MaterialApp(
              onGenerateTitle: (context) => context.l.appTitle,
              navigatorKey: appNav,
              debugShowCheckedModeBanner: false,
              locale: st.locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              localeResolutionCallback: resolveLocale,
              theme: ThemeData(splashFactory: NoSplash.splashFactory),
              builder: (context, child) => L10nSync(
                child: DefaultTextStyle(
                  style: const TextStyle(fontSize: 16, color: Color(0xFF000000), decoration: TextDecoration.none, fontWeight: FontWeight.w400),
                  child: child!,
                ),
              ),
              home: const DialogsPage(),
            ),
          );
        }),
        ),
      ),
    );
  }
}