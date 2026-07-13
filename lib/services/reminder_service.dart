import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'platform_capabilities.dart';
import 'user_settings_service.dart';

class ReminderService extends ChangeNotifier {
  static const _promptSeenKey = 'daily_reminder_prompt_seen';
  static const _enabledKey = 'daily_reminder_enabled';
  static const _hourKey = 'daily_reminder_hour';
  static const _minuteKey = 'daily_reminder_minute';
  static const _schedulePendingKey = 'daily_reminder_schedule_pending';
  static const _notificationId = 2100;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _promptSeen = false;
  bool _enabled = false;
  bool _schedulePending = false;
  int _hour = 21;
  int _minute = 0;

  bool get isInitialized => _isInitialized;
  bool get promptSeen => _promptSeen;
  bool get enabled => _enabled;
  bool get schedulePending => _schedulePending;
  TimeOfDay get reminderTime => TimeOfDay(hour: _hour, minute: _minute);

  String get reminderTimeText =>
      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _promptSeen = prefs.getBool(_promptSeenKey) ?? false;
    _enabled = prefs.getBool(_enabledKey) ?? false;
    _hour = prefs.getInt(_hourKey) ?? 21;
    _minute = prefs.getInt(_minuteKey) ?? 0;
    _schedulePending = prefs.getBool(_schedulePendingKey) ?? false;
    if (isWindowsLocalMode) {
      _enabled = false;
      _isInitialized = true;
      notifyListeners();
      return;
    }

    tz.initializeTimeZones();
    await _setLocalTimeZone();
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );
    await _notifications.initialize(initializationSettings);

    _isInitialized = true;

    if (_enabled) await _scheduleWithRecovery();
    notifyListeners();
  }

  Future<void> markPromptSeen() async {
    final prefs = await SharedPreferences.getInstance();
    _promptSeen = true;
    await prefs.setBool(_promptSeenKey, true);
    notifyListeners();
  }

  Future<bool> enableDailyReminder() async {
    final granted = await _requestPermission();
    if (!granted) return false;

    final prefs = await SharedPreferences.getInstance();
    _enabled = true;
    await prefs.setBool(_enabledKey, true);
    await prefs.setInt(_hourKey, _hour);
    await prefs.setInt(_minuteKey, _minute);
    await _scheduleWithRecovery();
    notifyListeners();
    await _syncSettingsSafely();
    return true;
  }

  Future<void> disableDailyReminder() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = false;
    await prefs.setBool(_enabledKey, false);
    await prefs.setBool(_schedulePendingKey, false);
    _schedulePending = false;
    await _notifications.cancel(_notificationId);
    notifyListeners();
    await _syncSettingsSafely();
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    _hour = time.hour;
    _minute = time.minute;
    await prefs.setInt(_hourKey, _hour);
    await prefs.setInt(_minuteKey, _minute);
    if (_enabled) await _scheduleWithRecovery();
    notifyListeners();
    await _syncSettingsSafely();
  }

  Future<void> retrySchedule() async {
    if (!_enabled || isWindowsLocalMode) return;
    await _scheduleWithRecovery();
    notifyListeners();
  }

  Future<void> _setLocalTimeZone() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {}
  }

  Future<void> _scheduleWithRecovery() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await _scheduleDailyReminder();
      _schedulePending = false;
      await prefs.setBool(_schedulePendingKey, false);
    } catch (_) {
      _schedulePending = true;
      await prefs.setBool(_schedulePendingKey, true);
    }
  }

  Future<void> _syncSettingsSafely() async {
    try {
      await UserSettingsService.instance.syncReminderSettings();
    } catch (_) {}
  }

  Future<bool> _requestPermission() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;
    return await android.requestNotificationsPermission() ?? false;
  }

  Future<void> _scheduleDailyReminder() async {
    await _notifications.zonedSchedule(
      _notificationId,
      '该记录今日状态了',
      '花一分钟看看今天的心情、精力和压力变化。',
      _nextReminderTime(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          '每日记录提醒',
          channelDescription: '每天提醒你记录 LifeSense 状态',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextReminderTime() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      _hour,
      _minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
