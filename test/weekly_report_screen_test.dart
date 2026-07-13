import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_sense/models/life_entry.dart';
import 'package:life_sense/screens/weekly_report_screen.dart';
import 'package:life_sense/services/life_storage_service.dart';
import 'package:life_sense/services/user_settings_service.dart';
import 'package:life_sense/services/weekly_goals_service.dart';
import 'package:life_sense/state/life_entry_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStorage extends LifeStorageService {
  _FakeStorage(this.entries);

  final List<LifeEntry> entries;

  @override
  Future<List<LifeEntry>> loadEntries() async => entries;
}

class _FakeRemoteStore implements UserSettingsRemoteStore {
  @override
  Future<void> delete(String uid) async {}

  @override
  Future<UserSettingsRecord?> load(String uid) async => null;

  @override
  Future<void> save(String uid, UserSettingsRecord record) async {}
}

LifeEntry _entry(String id, DateTime date, {double sleepHours = 6}) =>
    LifeEntry(
      id: id,
      createdAt: date,
      mood: 4,
      energy: 4,
      stress: 2,
      focus: 3,
      sleepHours: sleepHours,
      waterCups: 5,
      activity: '学习',
      note: '',
      score: 80,
      status: '状态良好',
      suggestion: '保持节奏',
    );

void main() {
  testWidgets('仅最新周报显示目标进度和下周行动', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final now = DateTime.now();
    final currentMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final entries = [
      for (var day = 0; day < 3; day += 1)
        _entry('current-$day', currentMonday.add(Duration(days: day))),
      for (var day = 0; day < 3; day += 1)
        _entry('past-$day', currentMonday.subtract(Duration(days: 7 - day))),
    ];
    final provider = LifeEntryProvider(storageService: _FakeStorage(entries));
    await provider.loadEntries();
    final goals = WeeklyGoalsService(
      userSettingsService: UserSettingsService(remoteStore: _FakeRemoteStore()),
    );
    await goals.initializeForUser('guest');
    await goals.setGoals(sleepHours: 8, waterCups: null, focus: null);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LifeEntryProvider>.value(value: provider),
          ChangeNotifierProvider<WeeklyGoalsService>.value(value: goals),
        ],
        child: const MaterialApp(home: WeeklyReportScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本周目标'), findsOneWidget);
    expect(find.text('下周优先改善睡眠'), findsOneWidget);
    expect(find.text('每晚比平时提前 15 分钟上床，先向 8.0 小时靠近。'), findsOneWidget);
  });
}
