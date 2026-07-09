import 'dart:convert';

import 'package:agconnect_auth/agconnect_auth.dart';
import 'package:agconnect_clouddb/agconnect_clouddb.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/life_entry.dart';
import 'clouddb_zone_service.dart';

class LifeStorageService {
  LifeStorageService();

  static const _objectTypeName = 'LifeEntry';
  static const _cachePrefix = 'life_entries_';
  static const _guestCacheKey = 'life_entries_guest';

  bool lastLoadUsedLocalCache = false;
  bool lastSaveSynced = true;

  Future<List<LifeEntry>> loadEntries() async {
    final user = await AGCAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return [];

    try {
      final entries = await loadCloudEntries();
      lastLoadUsedLocalCache = false;
      if (entries.isNotEmpty) await _saveLocalEntries(uid, entries);
      if (entries.isNotEmpty) return entries;
    } catch (_) {
      lastLoadUsedLocalCache = true;
      return _loadLocalEntries(uid);
    }

    lastLoadUsedLocalCache = true;
    return _loadLocalEntries(uid);
  }

  Future<List<LifeEntry>> loadCloudEntries() async {
    final user = await AGCAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return [];

    final zone = await CloudDBZoneService.instance.getZone();
    final query = AGConnectCloudDBQuery(_objectTypeName)
      ..equalTo('userID', uid)
      ..orderBy('createdAt', ascending: false);
    final snapshot = await zone.executeQuery(
      query: query,
      policy: AGConnectCloudDBZoneQueryPolicy.POLICY_QUERY_FROM_CLOUD_ONLY,
    );
    return snapshot.snapshotObjects.map(_entryFromCloud).toList();
  }

  Future<void> saveEntry(LifeEntry entry) async {
    final user = await AGCAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return;

    await _mergeLocalEntry(uid, entry);
    final zone = await CloudDBZoneService.instance.getZone();
    await zone.executeUpsert(
      objectTypeName: _objectTypeName,
      entries: [_entryToCloud(entry, uid)],
    );
    lastSaveSynced = true;
  }

  Future<void> saveEntries(List<LifeEntry> entries) async {
    final user = await AGCAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null || entries.isEmpty) return;

    await _saveLocalEntries(uid, entries);
    final zone = await CloudDBZoneService.instance.getZone();
    await zone.executeUpsert(
      objectTypeName: _objectTypeName,
      entries: entries.map((entry) => _entryToCloud(entry, uid)).toList(),
    );
    lastSaveSynced = true;
  }

  Future<void> clearLocalCache() async {
    final user = await AGCAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_cachePrefix$uid');
  }

  Future<void> deleteEntry(LifeEntry entry) async {
    final user = await AGCAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return;

    final localEntries = await _loadLocalEntries(uid);
    await _saveLocalEntries(
      uid,
      localEntries
          .where((currentEntry) => currentEntry.id != entry.id)
          .toList(),
    );
  }

  Future<void> deleteCloudEntries() async {
    final user = await AGCAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return;

    await clearLocalCache();
    final zone = await CloudDBZoneService.instance.getZone();
    final query = AGConnectCloudDBQuery(_objectTypeName)
      ..equalTo('userID', uid);
    final snapshot = await zone.executeQuery(
      query: query,
      policy: AGConnectCloudDBZoneQueryPolicy.POLICY_QUERY_FROM_CLOUD_ONLY,
    );
    if (snapshot.snapshotObjects.isEmpty) return;
    await zone.executeDelete(
      objectTypeName: _objectTypeName,
      entries: snapshot.snapshotObjects,
    );
  }

  Future<void> clearEntries() => deleteCloudEntries();

  // ── 访客模式（无账号，纯本地） ──────────────────────────────

  Future<List<LifeEntry>> loadGuestEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonText = prefs.getString(_guestCacheKey);
    if (jsonText == null || jsonText.isEmpty) return [];
    final decoded = jsonDecode(jsonText) as List<dynamic>;
    return decoded
        .map((item) => LifeEntry.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> saveGuestEntry(LifeEntry entry) async {
    final entries = await loadGuestEntries();
    final byId = <String, LifeEntry>{
      for (final e in entries) e.id: e,
      entry.id: entry,
    };
    await _saveGuestEntries(byId.values.toList());
  }

  Future<void> deleteGuestEntry(LifeEntry entry) async {
    final entries = await loadGuestEntries();
    await _saveGuestEntries(
      entries.where((e) => e.id != entry.id).toList(),
    );
  }

  Future<void> saveGuestEntries(List<LifeEntry> entries) =>
      _saveGuestEntries(entries);

  Future<void> clearGuestEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestCacheKey);
  }

  Future<void> _saveGuestEntries(List<LifeEntry> entries) async {
    final sorted = [...entries]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _guestCacheKey,
      jsonEncode(sorted.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _mergeLocalEntry(String uid, LifeEntry entry) async {
    final entries = await _loadLocalEntries(uid);
    final entriesById = <String, LifeEntry>{
      for (final currentEntry in entries) currentEntry.id: currentEntry,
      entry.id: entry,
    };
    await _saveLocalEntries(uid, entriesById.values.toList());
  }

  Future<List<LifeEntry>> _loadLocalEntries(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonText = prefs.getString('$_cachePrefix$uid');
    if (jsonText == null || jsonText.isEmpty) return [];
    final decoded = jsonDecode(jsonText) as List<dynamic>;
    final entries =
        decoded
            .map((item) => LifeEntry.fromJson(item as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<void> _saveLocalEntries(String uid, List<LifeEntry> entries) async {
    final sortedEntries = [...entries]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_cachePrefix$uid',
      jsonEncode(sortedEntries.map((entry) => entry.toJson()).toList()),
    );
  }

  Map<String, dynamic> _entryToCloud(LifeEntry entry, String uid) {
    return {...entry.toJson(), 'userID': uid};
  }

  LifeEntry _entryFromCloud(Map<String, dynamic> json) {
    return LifeEntry.fromJson(json);
  }
}
