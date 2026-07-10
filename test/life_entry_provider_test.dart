import 'package:flutter_test/flutter_test.dart';
import 'package:life_sense/models/life_entry.dart';
import 'package:life_sense/services/life_storage_service.dart';
import 'package:life_sense/state/life_entry_provider.dart';

class _FakeStorage extends LifeStorageService {
  _FakeStorage(this._entries);
  final List<LifeEntry> _entries;

  @override
  Future<List<LifeEntry>> loadEntries() async => _entries;
}

LifeEntry _entry(String id, DateTime createdAt, {int score = 80}) {
  return LifeEntry(
    id: id,
    createdAt: createdAt,
    mood: 4,
    energy: 4,
    stress: 2,
    focus: 4,
    sleepHours: 7,
    waterCups: 6,
    activity: '学习',
    note: '',
    score: score,
    status: '状态良好',
    suggestion: '保持节奏',
  );
}

void main() {
  test('最近 7 天记录会按日期保留每天最新一条', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    final earlierToday = today.subtract(const Duration(hours: 1));
    final yesterday = today.subtract(const Duration(days: 1));
    final old = today.subtract(const Duration(days: 7));

    final provider = LifeEntryProvider(
      storageService: _FakeStorage([
        LifeEntry(
          id: 'today-new',
          createdAt: today,
          mood: 5,
          energy: 5,
          stress: 1,
          focus: 5,
          sleepHours: 8,
          waterCups: 7,
          activity: '学习',
          note: '',
          score: 90,
          status: '状态良好',
          suggestion: '保持节奏',
        ),
        LifeEntry(
          id: 'today-old',
          createdAt: earlierToday,
          mood: 3,
          energy: 3,
          stress: 2,
          focus: 3,
          sleepHours: 7,
          waterCups: 5,
          activity: '学习',
          note: '',
          score: 70,
          status: '状态普通',
          suggestion: '保持节奏',
        ),
        LifeEntry(
          id: 'yesterday',
          createdAt: yesterday,
          mood: 4,
          energy: 4,
          stress: 2,
          focus: 4,
          sleepHours: 7,
          waterCups: 6,
          activity: '运动',
          note: '',
          score: 80,
          status: '状态普通',
          suggestion: '保持节奏',
        ),
        LifeEntry(
          id: 'old',
          createdAt: old,
          mood: 2,
          energy: 2,
          stress: 4,
          focus: 2,
          sleepHours: 5,
          waterCups: 3,
          activity: '休息',
          note: '',
          score: 40,
          status: '需要休息',
          suggestion: '早点休息',
        ),
      ]),
    );
    await provider.loadEntries();

    final recentEntries = provider.recentSevenDayEntries;

    expect(recentEntries.length, 7);
    expect(recentEntries.whereType<Object>().length, 2);
    expect(recentEntries.last?.id, 'today-new');
    expect(recentEntries[5]?.id, 'yesterday');
  });

  test('连续记录天数会从今天往前计算', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    final provider = LifeEntryProvider(
      storageService: _FakeStorage([
        _entry('today', today),
        _entry('yesterday', today.subtract(const Duration(days: 1))),
        _entry('two-days-ago', today.subtract(const Duration(days: 2))),
      ]),
    );
    await provider.loadEntries();

    expect(provider.consecutiveRecordDays, 3);
  });

  test('缺少今天记录时连续天数为 0', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    final provider = LifeEntryProvider(
      storageService: _FakeStorage([
        _entry('yesterday', today.subtract(const Duration(days: 1))),
        _entry('two-days-ago', today.subtract(const Duration(days: 2))),
      ]),
    );
    await provider.loadEntries();

    expect(provider.consecutiveRecordDays, 0);
  });

  test('同一天多条记录不会重复增加连续天数', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    final provider = LifeEntryProvider(
      storageService: _FakeStorage([
        _entry('today-new', today),
        _entry('today-old', today.subtract(const Duration(hours: 1))),
        _entry('yesterday', today.subtract(const Duration(days: 1))),
      ]),
    );
    await provider.loadEntries();

    expect(provider.consecutiveRecordDays, 2);
  });
}
