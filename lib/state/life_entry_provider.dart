import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/life_entry.dart';
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

  bool get isGuestMode => _isGuestMode;

  void setGuestMode(bool value) {
    _isGuestMode = value;
    if (value) _syncStatus = SyncStatus.localOnly;
    notifyListeners();
  }

  List<LifeEntry> get entries => List.unmodifiable(_entries);
  bool get isLoading => _isLoading;
  SyncStatus get syncStatus => _syncStatus;

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
      _syncStatus = _storageService.lastLoadUsedLocalCache
          ? SyncStatus.localCache
          : SyncStatus.synced;
    } on TimeoutException {
      _entries.clear();
      _syncStatus = SyncStatus.localCache;
    } catch (_) {
      _entries.clear();
      _syncStatus = SyncStatus.localCache;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
      _syncStatus = SyncStatus.synced;
      notifyListeners();
    } catch (_) {
      _syncStatus = SyncStatus.localCache;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> restoreFromCloud() async {
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
    _syncStatus = SyncStatus.localCache;
    await _storageService
        .deleteEntry(entry)
        .timeout(const Duration(seconds: 8));
    notifyListeners();
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
