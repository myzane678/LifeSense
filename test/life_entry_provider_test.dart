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
}
