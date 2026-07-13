import 'package:flutter_test/flutter_test.dart';
import 'package:life_sense/models/life_entry.dart';
import 'package:life_sense/models/weekly_report.dart';
import 'package:life_sense/services/user_settings_service.dart';
import 'package:life_sense/services/weekly_goals_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRemoteStore implements UserSettingsRemoteStore {
  final records = <String, UserSettingsRecord>{};
  bool failSave = false;

  @override
  Future<void> delete(String uid) async => records.remove(uid);

  @override
  Future<UserSettingsRecord?> load(String uid) async => records[uid];

  @override
  Future<void> save(String uid, UserSettingsRecord record) async {
    if (failSave) throw StateError('offline');
    records[uid] = record;
  }
}

LifeEntry _entry({
  required String id,
  required DateTime createdAt,
  double sleepHours = 7,
  int waterCups = 6,
  int focus = 4,
}) => LifeEntry(
  id: id,
  createdAt: createdAt,
  mood: 4,
  energy: 4,
  stress: 2,
  focus: focus,
  sleepHours: sleepHours,
  waterCups: waterCups,
  activity: '学习',
  note: '',
  score: 80,
  status: '状态良好',
  suggestion: '保持节奏',
);

WeeklyReport _report({
  int count = 3,
  double sleep = 6,
  double water = 5,
  double focus = 3,
}) {
  final monday = DateTime(2026, 7, 13);
  return WeeklyReport.fromEntries(
    List.generate(
      count,
      (index) => _entry(
        id: '$index',
        createdAt: monday.add(Duration(days: index)),
        sleepHours: sleep,
        waterCups: water.round(),
        focus: focus.round(),
      ),
    ),
    monday,
  );
}

void main() {
  test('云端恢复目标并保留兴趣和提醒字段', () async {
    SharedPreferences.setMockInitialValues({});
    final remote = _FakeRemoteStore()
      ..records['user-a'] = const UserSettingsRecord(
        digestSelectedIds: ['study'],
        reminderEnabled: true,
        reminderHour: 8,
        reminderMinute: 30,
        goalSleepHours: 8,
        goalWaterCups: 8,
        goalFocus: 4,
      );
    final goals = WeeklyGoalsService(
      userSettingsService: UserSettingsService(remoteStore: remote),
    );

    await goals.initializeForUser(
      'user-a',
      cloudRecord: await remote.load('user-a'),
    );
    await goals.setGoals(sleepHours: 7.5, waterCups: 9, focus: 5);

    expect(goals.goals.sleepHours, 7.5);
    expect(remote.records['user-a']!.digestSelectedIds, ['study']);
    expect(remote.records['user-a']!.reminderHour, 8);
    expect(remote.records['user-a']!.goalWaterCups, 9);
  });

  test('云同步失败后保留本机目标并在下次初始化重试', () async {
    SharedPreferences.setMockInitialValues({});
    final remote = _FakeRemoteStore();
    final service = UserSettingsService(remoteStore: remote);
    final goals = WeeklyGoalsService(userSettingsService: service);
    await goals.initializeForUser('user-a');
    remote.failSave = true;

    await expectLater(
      goals.setGoals(sleepHours: 8, waterCups: null, focus: null),
      throwsStateError,
    );
    expect(goals.goals.sleepHours, 8);

    remote.failSave = false;
    final restored = WeeklyGoalsService(userSettingsService: service);
    await restored.initializeForUser('user-a');
    expect(restored.goals.sleepHours, 8);
    expect(remote.records['user-a']!.goalSleepHours, 8);
  });

  test('已有云端设置时空目标会覆盖旧本机缓存', () async {
    SharedPreferences.setMockInitialValues({
      'weekly_goal_sleep_hours_user-a': 8.0,
    });
    final goals = WeeklyGoalsService(
      userSettingsService: UserSettingsService(remoteStore: _FakeRemoteStore()),
    );

    await goals.initializeForUser(
      'user-a',
      cloudRecord: const UserSettingsRecord(
        digestSelectedIds: [],
        reminderEnabled: false,
        reminderHour: 21,
        reminderMinute: 0,
      ),
    );

    expect(goals.goals.hasAny, isFalse);
  });

  test('选择相对差距最大的目标，并用固定顺序打破平局', () async {
    SharedPreferences.setMockInitialValues({});
    final goals = WeeklyGoalsService(
      userSettingsService: UserSettingsService(remoteStore: _FakeRemoteStore()),
    );
    await goals.initializeForUser('guest');
    await goals.setGoals(sleepHours: 8, waterCups: 8, focus: 4);

    final plan = goals.actionPlanFor(_report(sleep: 6, water: 6, focus: 3));

    expect(plan.state, WeeklyActionState.improve);
    expect(plan.kind, WeeklyGoalKind.sleep);
    expect(plan.title, '下周优先改善睡眠');
  });

  test('无目标、记录不足和全部达标显示对应状态', () async {
    SharedPreferences.setMockInitialValues({});
    final goals = WeeklyGoalsService(
      userSettingsService: UserSettingsService(remoteStore: _FakeRemoteStore()),
    );
    await goals.initializeForUser('guest');
    expect(goals.actionPlanFor(_report()).state, WeeklyActionState.noGoals);

    await goals.setGoals(sleepHours: 8, waterCups: null, focus: null);
    expect(
      goals.actionPlanFor(_report(count: 2)).state,
      WeeklyActionState.insufficientRecords,
    );
    expect(
      goals.actionPlanFor(_report(sleep: 8)).state,
      WeeklyActionState.achieved,
    );
  });
}
