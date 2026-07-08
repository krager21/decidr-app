import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local-notification reminders — the app's only return hooks.
///
/// Three fixed slots (never more, so notification hygiene stays
/// polite):
///  * daily ritual   — "your cards are waiting", opt-in, user-chosen
///    time, silenced automatically on days something was completed
///    (callers pass that in when rescheduling)
///  * tonight        — one-off follow-up on the card the user chose
///    ("did you end up doing X?"); resolution happens in-app on next
///    open, which works identically on every platform
///  * lapse rescue   — rescheduled ~6 days out on every launch, so it
///    only ever fires for a user who stopped opening the app
///
/// Everything is a no-op on unsupported platforms (web) and when the
/// user denies the OS permission. All methods are safe to call
/// unconditionally.
class ReminderService {
  static const int _dailyId = 1;
  static const int _tonightId = 2;
  static const int _lapseId = 3;

  /// Local notifications exist on iOS/macOS/Android; the web build
  /// gets nothing (the GitHub Pages surface stays notification-free).
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.android);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'decidr_reminders',
      'Reminders',
      channelDescription: 'Daily deal reminders and activity follow-ups',
      importance: Importance.defaultImportance,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );

  /// Initialize the plugin and timezone database. Never throws; on
  /// failure the service degrades to a no-op.
  Future<void> init() async {
    if (!isSupported || _initialized) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name.identifier));
      } catch (_) {
        // Fall back to the package default (UTC) — reminders still
        // fire, just anchored to UTC wall-clock.
      }
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings: initSettings);
      _initialized = true;
    } catch (e) {
      debugPrint('ReminderService init failed: $e');
    }
  }

  /// Ask the OS for notification permission. Returns whether granted.
  Future<bool> requestPermission() async {
    if (!_initialized) return false;
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          final ios = _plugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
          return await ios?.requestPermissions(
                  alert: true, badge: true, sound: true) ??
              false;
        case TargetPlatform.macOS:
          final macos = _plugin.resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>();
          return await macos?.requestPermissions(
                  alert: true, badge: true, sound: true) ??
              false;
        case TargetPlatform.android:
          final android = _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
          return await android?.requestNotificationsPermission() ?? false;
        default:
          return false;
      }
    } catch (e) {
      debugPrint('ReminderService permission request failed: $e');
      return false;
    }
  }

  /// Schedule (or move) the repeating daily deal reminder.
  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    if (!_initialized) return;
    try {
      final next = nextInstanceOf(time, DateTime.now());
      await _plugin.zonedSchedule(
        id: _dailyId,
        title: 'Your cards are waiting',
        body: 'Thirty seconds of questions, one good idea for '
            '${time.hour < 12 ? 'today' : 'tonight'}.',
        scheduledDate: tz.TZDateTime.from(next, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('scheduleDailyReminder failed: $e');
    }
  }

  Future<void> cancelDailyReminder() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: _dailyId);
    } catch (_) {}
  }

  /// One-off follow-up on tonight's chosen card.
  Future<void> scheduleTonightReminder(String activityTitle) async {
    if (!_initialized) return;
    try {
      final at = tonightInstant(DateTime.now());
      await _plugin.zonedSchedule(
        id: _tonightId,
        title: 'Did you end up doing it?',
        body: '"$activityTitle" — open Decidr to check it off.',
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('scheduleTonightReminder failed: $e');
    }
  }

  /// Re-arm the lapse-rescue notification ~6 days out. Called on every
  /// launch, so it only ever fires for a user who stopped opening the
  /// app. [hookTitle] personalizes the copy (e.g. a favorite's title).
  Future<void> rescheduleLapseRescue({String? hookTitle}) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: _lapseId);
      final at = DateTime.now().add(const Duration(days: 6));
      await _plugin.zonedSchedule(
        id: _lapseId,
        title: 'The deck misses you',
        body: hookTitle == null
            ? 'One tap, three cards, one good idea.'
            : '"$hookTitle" is still in your deck.',
        scheduledDate: tz.TZDateTime.from(
          DateTime(at.year, at.month, at.day, 18, 30),
          tz.local,
        ),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('rescheduleLapseRescue failed: $e');
    }
  }

  /// Next wall-clock occurrence of [time] strictly after [now].
  @visibleForTesting
  static DateTime nextInstanceOf(TimeOfDay time, DateTime now) {
    var candidate =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  /// When "tonight" is: 19:00 today if that's still ahead, otherwise
  /// two hours from now, but never past 22:30 (then it's 19:00
  /// tomorrow — nobody wants a midnight nudge).
  @visibleForTesting
  static DateTime tonightInstant(DateTime now) {
    final sevenPm = DateTime(now.year, now.month, now.day, 19);
    if (now.isBefore(sevenPm)) return sevenPm;
    final inTwoHours = now.add(const Duration(hours: 2));
    final lateCap = DateTime(now.year, now.month, now.day, 22, 30);
    if (inTwoHours.isBefore(lateCap)) return inTwoHours;
    return sevenPm.add(const Duration(days: 1));
  }
}
