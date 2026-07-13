import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weekly_report.dart';
import 'user_settings_service.dart';

enum WeeklyGoalKind { sleep, water, focus }

enum WeeklyActionState { noGoals, insufficientRecords, improve, achieved }

class WeeklyGoals {
  const WeeklyGoals({this.sleepHours, this.waterCups, this.focus});

  final double? sleepHours;
  final int? waterCups;
  final int? focus;

  bool get hasAny => sleepHours != null || waterCups != null || focus != null;
}

class WeeklyActionPlan {
  const WeeklyActionPlan({
    required this.state,
    required this.title,
    required this.message,
    this.kind,
  });

  final WeeklyActionState state;
  final WeeklyGoalKind? kind;
  final String title;
  final String message;
}

class WeeklyGoalsService extends ChangeNotifier {
  WeeklyGoalsService({UserSettingsService? userSettingsService})
    : _userSettingsService =
          userSettingsService ?? UserSettingsService.instance;

  static const minSleepHours = 5.0;
  static const maxSleepHours = 10.0;
  static const minWaterCups = 3;
  static const maxWaterCups = 12;
  static const minFocus = 2;
  static const maxFocus = 5;

  final UserSettingsService _userSettingsService;

  String? _userId;
  WeeklyGoals _goals = const WeeklyGoals();

  WeeklyGoals get goals => _goals;

  String _sleepKey(String uid) => 'weekly_goal_sleep_hours_$uid';
  String _waterKey(String uid) => 'weekly_goal_water_cups_$uid';
  String _focusKey(String uid) => 'weekly_goal_focus_$uid';
  String _pendingKey(String uid) => 'weekly_goals_sync_pending_$uid';

  Future<void> initializeForUser(
    String uid, {
    UserSettingsRecord? cloudRecord,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _userId = uid;
    final localGoals = _readGoals(prefs, uid);
    final isGuest = uid == 'guest';
    final pending = prefs.getBool(_pendingKey(uid)) ?? false;

    if (!isGuest && pending) {
      _goals = localGoals;
      notifyListeners();
      try {
        await _sync(uid, localGoals);
        await prefs.setBool(_pendingKey(uid), false);
      } catch (_) {}
      return;
    }

    final nextGoals = isGuest
        ? localGoals
        : cloudRecord != null
        ? WeeklyGoals(
            sleepHours: cloudRecord.goalSleepHours,
            waterCups: cloudRecord.goalWaterCups,
            focus: cloudRecord.goalFocus,
          )
        : localGoals;
    _goals = nextGoals;
    await _writeGoals(prefs, uid, nextGoals);
    notifyListeners();
  }

  Future<void> setGoals({
    required double? sleepHours,
    required int? waterCups,
    required int? focus,
  }) async {
    final uid = _userId;
    if (uid == null) throw StateError('本周目标尚未初始化');
    final nextGoals = WeeklyGoals(
      sleepHours: _validSleepHours(sleepHours),
      waterCups: _validWaterCups(waterCups),
      focus: _validFocus(focus),
    );
    final prefs = await SharedPreferences.getInstance();
    _goals = nextGoals;
    await _writeGoals(prefs, uid, nextGoals);
    notifyListeners();

    if (uid == 'guest') return;
    await prefs.setBool(_pendingKey(uid), true);
    try {
      await _sync(uid, nextGoals);
      await prefs.setBool(_pendingKey(uid), false);
    } catch (_) {
      rethrow;
    }
  }

  Future<void> retryPendingSync() async {
    final uid = _userId;
    if (uid == null || uid == 'guest') return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_pendingKey(uid)) ?? false)) return;
    await _sync(uid, _goals);
    await prefs.setBool(_pendingKey(uid), false);
  }

  Future<void> clearForUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sleepKey(uid));
    await prefs.remove(_waterKey(uid));
    await prefs.remove(_focusKey(uid));
    await prefs.remove(_pendingKey(uid));
    if (_userId == uid) {
      _goals = const WeeklyGoals();
      notifyListeners();
    }
  }

  void resetSession() {
    _userId = null;
    _goals = const WeeklyGoals();
    notifyListeners();
  }

  WeeklyActionPlan actionPlanFor(WeeklyReport report) {
    if (!_goals.hasAny) {
      return const WeeklyActionPlan(
        state: WeeklyActionState.noGoals,
        title: '设置本周目标',
        message: '在设置中添加睡眠、饮水或专注目标，让周报给出更贴合你的行动建议。',
      );
    }
    if (report.recordCount < 3) {
      return const WeeklyActionPlan(
        state: WeeklyActionState.insufficientRecords,
        title: '继续记录',
        message: '本周记录不足 3 天，继续记录后再判断最需要改善的方向。',
      );
    }

    final gaps = <(WeeklyGoalKind, double)>[];
    if (_goals.sleepHours != null && report.avgSleep < _goals.sleepHours!) {
      gaps.add((
        WeeklyGoalKind.sleep,
        (_goals.sleepHours! - report.avgSleep) / _goals.sleepHours!,
      ));
    }
    if (_goals.waterCups != null && report.avgWater < _goals.waterCups!) {
      gaps.add((
        WeeklyGoalKind.water,
        (_goals.waterCups! - report.avgWater) / _goals.waterCups!,
      ));
    }
    if (_goals.focus != null && report.avgFocus < _goals.focus!) {
      gaps.add((
        WeeklyGoalKind.focus,
        (_goals.focus! - report.avgFocus) / _goals.focus!,
      ));
    }
    if (gaps.isEmpty) {
      return const WeeklyActionPlan(
        state: WeeklyActionState.achieved,
        title: '本周目标已达成',
        message: '三项状态都保持得不错，下周继续沿用现在的节奏。',
      );
    }

    gaps.sort((a, b) {
      final byGap = b.$2.compareTo(a.$2);
      if (byGap != 0) return byGap;
      return a.$1.index.compareTo(b.$1.index);
    });
    final kind = gaps.first.$1;
    return switch (kind) {
      WeeklyGoalKind.sleep => WeeklyActionPlan(
        state: WeeklyActionState.improve,
        kind: kind,
        title: '下周优先改善睡眠',
        message:
            '每晚比平时提前 15 分钟上床，先向 ${_goals.sleepHours!.toStringAsFixed(1)} 小时靠近。',
      ),
      WeeklyGoalKind.water => WeeklyActionPlan(
        state: WeeklyActionState.improve,
        kind: kind,
        title: '下周优先补足饮水',
        message: '把饮水安排在上午、午后和傍晚三个固定时点，逐步达到 ${_goals.waterCups} 杯。',
      ),
      WeeklyGoalKind.focus => WeeklyActionPlan(
        state: WeeklyActionState.improve,
        kind: kind,
        title: '下周优先提升专注',
        message: '每个工作日完成 1 个 25 分钟专注时段，结束后简单记录感受。',
      ),
    };
  }

  WeeklyGoals _readGoals(SharedPreferences prefs, String uid) => WeeklyGoals(
    sleepHours: prefs.getDouble(_sleepKey(uid)),
    waterCups: prefs.getInt(_waterKey(uid)),
    focus: prefs.getInt(_focusKey(uid)),
  );

  Future<void> _writeGoals(
    SharedPreferences prefs,
    String uid,
    WeeklyGoals goals,
  ) async {
    await _writeDouble(prefs, _sleepKey(uid), goals.sleepHours);
    await _writeInt(prefs, _waterKey(uid), goals.waterCups);
    await _writeInt(prefs, _focusKey(uid), goals.focus);
  }

  Future<void> _writeDouble(
    SharedPreferences prefs,
    String key,
    double? value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setDouble(key, value);
    }
  }

  Future<void> _writeInt(
    SharedPreferences prefs,
    String key,
    int? value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setInt(key, value);
    }
  }

  Future<void> _sync(String uid, WeeklyGoals goals) =>
      _userSettingsService.saveWeeklyGoals(
        uid,
        sleepHours: goals.sleepHours,
        waterCups: goals.waterCups,
        focus: goals.focus,
      );

  double? _validSleepHours(double? value) =>
      value != null && value >= minSleepHours && value <= maxSleepHours
      ? value
      : null;

  int? _validWaterCups(int? value) =>
      value != null && value >= minWaterCups && value <= maxWaterCups
      ? value
      : null;

  int? _validFocus(int? value) =>
      value != null && value >= minFocus && value <= maxFocus ? value : null;
}
