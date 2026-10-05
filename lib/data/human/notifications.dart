import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

import '../ai_config.dart';
import '../store.dart';

// Local notifications and the background half of proactive messages.
//
// Three layers keep scheduled messages alive when the app is not in front:
//  1. a local notification is scheduled for every open task, so even a killed
//     app nudges the user at the right moment (OS alarm, survives the process)
//  2. a WorkManager periodic job wakes the app every ~15 minutes, runs the due
//     tasks headless through the real engine and posts the actual message
//  3. the server queue (see /api/schedule in the web backend) is polled by the
//     same job as a last resort when the OS killed the alarms (aggressive OEMs)

const _channel = AndroidNotificationDetails('lib3_messages', 'Messages', channelDescription: 'Messages from your assistants', importance: Importance.high, priority: Priority.high);
const _details = NotificationDetails(android: _channel);

int notifId(String key) => key.hashCode & 0x7fffffff;

class Notifier {
  Notifier._();
  static final Notifier instance = Notifier._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
      // The ask moved into the onboarding permissions step: requesting here
      // fired the system dialog on the very first launch, before the wizard
      // could explain why, and the wizard would then ask a second time.
      _ready = true;
    } catch (_) {
      // desktop and test runs have no notification plugin, stay silent
    }
  }

  /// The system permission ask, invoked by the onboarding permissions step.
  /// Returns whether notifications are allowed afterwards. Safe to call when
  /// the plugin never came up: a test run answers true so the step shows done.
  Future<bool> requestPermission() async {
    if (!_ready) return true;
    try {
      final impl = await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await impl?.requestNotificationsPermission() ?? true;
      return granted;
    } catch (_) {
      return true;
    }
  }

  Future<void> show(String key, String title, String body) async {
    if (!_ready) return;
    try {
      await _plugin.show(notifId(key), title, body, _details);
    } catch (_) {}
  }

  /// "recall" for the notification shade: the message is withdrawn there too
  Future<void> cancel(String key) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(notifId(key));
    } catch (_) {}
  }

  Future<void> schedule(String key, int atMs, String title, String body) async {
    if (!_ready) return;
    try {
      await _plugin.zonedSchedule(
        notifId(key),
        title,
        body,
        tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, atMs),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }
}

const bgTaskName = 'lib3.proactive.sweep';

/// WorkManager entry point, runs in its own isolate.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();
      await Notifier.instance.init();
      final store = await Store.load();
      final ai = await AiConfig.load();
      store.attachAi(ai);
      await store.runDueHeadless();
    } catch (_) {
      return Future.value(false);
    }
    return Future.value(true);
  });
}

Future<void> registerBackground() async {
  try {
    await Workmanager().initialize(backgroundDispatcher);
    await Workmanager().registerPeriodicTask(bgTaskName, bgTaskName, frequency: const Duration(minutes: 15), existingWorkPolicy: ExistingPeriodicWorkPolicy.update);
  } catch (_) {
    // unsupported platform
  }
}
