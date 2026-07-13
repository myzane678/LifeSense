import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/life_entry.dart';
import '../models/weekly_report.dart';
import '../services/life_score_service.dart';
import '../services/life_storage_service.dart';

enum SyncStatus { synced, localCache, syncing, localOnly }

class LifeEntryProvider extends ChangeNotifier {
  LifeEntryProvider({
    LifeStorageService? storageService,
    LifeScoreService? scoreService,
  }) : _storageService = storageService ?? LifeStorageService(),
       _scoreService = scoreService ?? LifeScoreService();

  final LifeStorageService _storageService;
  final LifeScoreService _scoreService;
  final List<LifeEntry> _entries = [];

  bool _isLoading = true;
  SyncStatus _syncStatus = SyncStatus.syncing;
  bool _isGuestMode = false;
  int _pendingSyncCount = 0;
  String? _lastSyncError;

  bool get isGuestMode => _isGuestMode;
  int get pendingSyncCount => _pendingSyncCount;
  bool get hasPendingSync => _pendingSyncCount > 0;
  String? get lastSyncError => _lastSyncError;

  void setGuestMode(bool value) {
    _isGuestMode = value;
    if (value) _syncStatus = SyncStatus.localOnly;
    notifyListeners();
  }

  List<LifeEntry> get entries => List.unmodifiable(_entries);
  bool get isLoading => _isLoading;
  SyncStatus get syncStatus => _syncStatus;

  void _updateSyncState({String? error}) {
    _pendingSyncCount = _storageService.pendingSyncCount;
    _lastSyncError = error;
    _syncStatus = _isGuestMode
        ? SyncStatus.localOnly
        : (_pendingSyncCount > 0 ? SyncStatus.localCache : SyncStatus.synced);
  }

  List<LifeEntry?> get recentSevenDayEntries {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final latestEntryByDate = <DateTime, LifeEntry>{};

    for (final entry in _entries) {
      final entryDate = DateTime(
        entry.createdAt.year,
        entry.createdAt.month,
        entry.createdAt.day,
      );
      final daysAgo = todayDate.difference(entryDate).inDays;
      if (daysAgo < 0 || daysAgo > 6) continue;

      final currentEntry = latestEntryByDate[entryDate];
      if (currentEntry == null ||
          entry.createdAt.isAfter(currentEntry.createdAt)) {
        latestEntryByDate[entryDate] = entry;
      }
    }

    return List.generate(7, (index) {
      final date = todayDate.subtract(Duration(days: 6 - index));
      return latestEntryByDate[date];
    });
  }

  int get consecutiveRecordDays {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final recordedDates = <DateTime>{
      for (final entry in _entries)
        DateTime(
          entry.createdAt.year,
          entry.createdAt.month,
          entry.createdAt.day,
        ),
    };

    var count = 0;
    while (recordedDates.contains(todayDate.subtract(Duration(days: count)))) {
      count++;
    }
    return count;
  }

  LifeEntry? get todayEntry {
    for (final entry in _entries) {
      if (entry.isToday) return entry;
    }
    return null;
  }

  List<WeeklyReport> get weeklyReports {
    if (_entries.isEmpty) return [];

    // 按 ISO 周分组：周一为起点
    final grouped = <DateTime, List<LifeEntry>>{};
    for (final entry in _entries) {
      final d = entry.createdAt;
      final monday = DateTime(
        d.year,
        d.month,
        d.day,
      ).subtract(Duration(days: d.weekday - 1));
      grouped.putIfAbsent(monday, () => []).add(entry);
    }

    final reports =
        grouped.entries
            .map((e) => WeeklyReport.fromEntries(e.value, e.key))
            .toList()
          ..sort((a, b) => b.startDate.compareTo(a.startDate));

    return reports;
  }

  Future<void> loadGuestEntries() async {
    _isLoading = true;
    notifyListeners();
    final loaded = await _storageService.loadGuestEntries();
    _entries
      ..clear()
      ..addAll(loaded);
    _syncStatus = SyncStatus.localOnly;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadEntries() async {
    _isLoading = true;
    notifyListeners();

    try {
      final loadedEntries = await _storageService.loadEntries().timeout(
        const Duration(seconds: 8),
      );
      _entries
        ..clear()
        ..addAll(loadedEntries);
      _pendingSyncCount = _storageService.pendingSyncCount;
      _lastSyncError = null;
      _syncStatus =
          _pendingSyncCount > 0 || _storageService.lastLoadUsedLocalCache
          ? SyncStatus.localCache
          : SyncStatus.synced;
    } on TimeoutException {
      _pendingSyncCount = _storageService.pendingSyncCount;
      _lastSyncError = '同步超时';
      _syncStatus = SyncStatus.localCache;
    } catch (_) {
      _pendingSyncCount = _storageService.pendingSyncCount;
      _lastSyncError = '云同步失败';
      _syncStatus = SyncStatus.localCache;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> recalculateAllEntries() async {
    if (_entries.isEmpty) return;
    final recalculated = _entries.map((e) {
      final score = _scoreService.calculateScore(
        mood: e.mood,
        energy: e.energy,
        stress: e.stress,
        focus: e.focus,
        sleepHours: e.sleepHours,
        waterCups: e.waterCups,
      );
      return LifeEntry(
        id: e.id,
        createdAt: e.createdAt,
        mood: e.mood,
        energy: e.energy,
        stress: e.stress,
        focus: e.focus,
        sleepHours: e.sleepHours,
        waterCups: e.waterCups,
        activity: e.activity,
        note: e.note,
        score: score,
        status: _scoreService.statusFor(
          score: score,
          energy: e.energy,
          stress: e.stress,
          sleepHours: e.sleepHours,
        ),
        suggestion: _scoreService.suggestionFor(
          mood: e.mood,
          energy: e.energy,
          stress: e.stress,
          focus: e.focus,
          sleepHours: e.sleepHours,
          waterCups: e.waterCups,
          score: score,
        ),
      );
    }).toList();

    _entries
      ..clear()
      ..addAll(recalculated);

    if (_isGuestMode) {
      _syncStatus = SyncStatus.localOnly;
      notifyListeners();
      await _storageService.saveGuestEntries(recalculated);
      return;
    }
    _syncStatus = SyncStatus.syncing;
    notifyListeners();
    try {
      await _storageService
          .saveEntries(recalculated)
          .timeout(const Duration(seconds: 15));
      _updateSyncState();
    } catch (_) {
      _updateSyncState(error: '云同步失败');
    }
    notifyListeners();
  }

  // 返回 (旧分数, 旧状态, 新分数, 新状态) 供 UI 展示对比
  Future<(int, String, int, String)> updateEntry(LifeEntry entry) async {
    final oldEntry = _entries.firstWhere(
      (e) => e.id == entry.id,
      orElse: () => entry,
    );
    final oldScore = oldEntry.score;
    final oldStatus = oldEntry.status;
    final score = _scoreService.calculateScore(
      mood: entry.mood,
      energy: entry.energy,
      stress: entry.stress,
      focus: entry.focus,
      sleepHours: entry.sleepHours,
      waterCups: entry.waterCups,
    );
    final updated = LifeEntry(
      id: entry.id,
      createdAt: entry.createdAt,
      mood: entry.mood,
      energy: entry.energy,
      stress: entry.stress,
      focus: entry.focus,
      sleepHours: entry.sleepHours,
      waterCups: entry.waterCups,
      activity: entry.activity,
      note: entry.note,
      score: score,
      status: _scoreService.statusFor(
        score: score,
        energy: entry.energy,
        stress: entry.stress,
        sleepHours: entry.sleepHours,
      ),
      suggestion: _scoreService.suggestionFor(
        mood: entry.mood,
        energy: entry.energy,
        stress: entry.stress,
        focus: entry.focus,
        sleepHours: entry.sleepHours,
        waterCups: entry.waterCups,
        score: score,
      ),
    );

    final idx = _entries.indexWhere((e) => e.id == updated.id);
    if (idx != -1) _entries[idx] = updated;

    if (_isGuestMode) {
      _syncStatus = SyncStatus.localOnly;
      notifyListeners();
      await _storageService.saveGuestEntry(updated);
      return (oldScore, oldStatus, score, updated.status);
    }
    _syncStatus = SyncStatus.syncing;
    notifyListeners();
    try {
      await _storageService
          .saveEntry(updated)
          .timeout(const Duration(seconds: 8));
      _updateSyncState();
    } catch (_) {
      _updateSyncState(error: '云同步失败');
    }
    notifyListeners();
    return (oldScore, oldStatus, score, updated.status);
  }

  Future<void> addEntry({
    required int mood,
    required int energy,
    required int stress,
    required int focus,
    required double sleepHours,
    required int waterCups,
    required String activity,
    required String note,
  }) async {
    final now = DateTime.now();
    final score = _scoreService.calculateScore(
      mood: mood,
      energy: energy,
      stress: stress,
      focus: focus,
      sleepHours: sleepHours,
      waterCups: waterCups,
    );
    final entry = LifeEntry(
      id: now.microsecondsSinceEpoch.toString(),
      createdAt: now,
      mood: mood,
      energy: energy,
      stress: stress,
      focus: focus,
      sleepHours: sleepHours,
      waterCups: waterCups,
      activity: activity,
      note: note,
      score: score,
      status: _scoreService.statusFor(
        score: score,
        energy: energy,
        stress: stress,
        sleepHours: sleepHours,
      ),
      suggestion: _scoreService.suggestionFor(
        mood: mood,
        energy: energy,
        stress: stress,
        focus: focus,
        sleepHours: sleepHours,
        waterCups: waterCups,
        score: score,
      ),
    );

    _entries.insert(0, entry);
    if (_isGuestMode) {
      _syncStatus = SyncStatus.localOnly;
      notifyListeners();
      await _storageService.saveGuestEntry(entry);
      return;
    }
    _syncStatus = SyncStatus.syncing;
    notifyListeners();
    try {
      await _storageService
          .saveEntry(entry)
          .timeout(const Duration(seconds: 8));
      _updateSyncState();
    } catch (_) {
      _updateSyncState(error: '云同步失败');
    }
    notifyListeners();
  }

  Future<bool> restoreFromCloud() async {
    if (hasPendingSync) return false;
    _syncStatus = SyncStatus.syncing;
    notifyListeners();
    final cloudEntries = await _storageService.loadCloudEntries().timeout(
      const Duration(seconds: 8),
    );
    if (cloudEntries.isEmpty) {
      _syncStatus = SyncStatus.localCache;
      notifyListeners();
      return false;
    }
    _entries
      ..clear()
      ..addAll(cloudEntries);
    await _storageService.saveEntries(cloudEntries);
    _syncStatus = SyncStatus.synced;
    notifyListeners();
    return true;
  }

  Future<bool> clearLocalCache() async {
    if (hasPendingSync) return false;
    final cloudEntries = await _storageService.loadCloudEntries().timeout(
      const Duration(seconds: 8),
    );
    if (cloudEntries.isEmpty) {
      _syncStatus = SyncStatus.localCache;
      notifyListeners();
      return false;
    }
    _entries.clear();
    _syncStatus = SyncStatus.localCache;
    await _storageService.clearLocalCache();
    notifyListeners();
    return true;
  }

  Future<void> deleteEntry(LifeEntry entry) async {
    _entries.removeWhere((currentEntry) => currentEntry.id == entry.id);
    if (_isGuestMode) {
      _syncStatus = SyncStatus.localOnly;
      notifyListeners();
      await _storageService.deleteGuestEntry(entry);
      return;
    }
    _syncStatus = SyncStatus.syncing;
    notifyListeners();
    try {
      await _storageService
          .deleteEntry(entry)
          .timeout(const Duration(seconds: 8));
      _updateSyncState();
    } catch (_) {
      _updateSyncState(error: '云同步失败');
    }
    notifyListeners();
  }

  Future<int> retryPendingSync() async {
    if (_isGuestMode) return 0;
    _syncStatus = SyncStatus.syncing;
    notifyListeners();
    try {
      final synced = await _storageService.retryPendingSync();
      _updateSyncState();
      return synced;
    } catch (_) {
      _updateSyncState(error: '云同步失败');
      return 0;
    } finally {
      notifyListeners();
    }
  }

  Future<void> deleteCloudEntries() async {
    _entries.clear();
    await _storageService.deleteCloudEntries();
    _syncStatus = SyncStatus.synced;
    notifyListeners();
  }

  Future<void> clearGuestEntries() async {
    _entries.clear();
    _syncStatus = SyncStatus.localOnly;
    await _storageService.clearGuestEntries();
    notifyListeners();
  }

  Future<void> clearEntries() => deleteCloudEntries();
}
