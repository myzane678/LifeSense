import 'dart:convert';

import 'package:agconnect_auth/agconnect_auth.dart';
import 'package:agconnect_clouddb/agconnect_clouddb.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/life_entry.dart';
import 'clouddb_zone_service.dart';

abstract class LifeEntryRemoteStore {
  Future<List<LifeEntry>> load(String uid);
  Future<void> upsert(String uid, LifeEntry entry);
  Future<void> delete(String uid, String entryId);
}

class CloudDBLifeEntryRemoteStore implements LifeEntryRemoteStore {
  static const _objectTypeName = 'LifeEntry';

  @override
  Future<List<LifeEntry>> load(String uid) async {
    final zone = await CloudDBZoneService.instance.getZone();
    final query = AGConnectCloudDBQuery(_objectTypeName)
      ..equalTo('userID', uid)
      ..orderBy('createdAt', ascending: false);
    final snapshot = await zone.executeQuery(
      query: query,
      policy: AGConnectCloudDBZoneQueryPolicy.POLICY_QUERY_FROM_CLOUD_ONLY,
    );
    return snapshot.snapshotObjects
        .map((item) => LifeEntry.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<void> upsert(String uid, LifeEntry entry) async {
    final zone = await CloudDBZoneService.instance.getZone();
    await zone.executeUpsert(
      objectTypeName: _objectTypeName,
      entries: [
        {...entry.toJson(), 'userID': uid},
      ],
    );
  }

  @override
  Future<void> delete(String uid, String entryId) async {
    final zone = await CloudDBZoneService.instance.getZone();
    final query = AGConnectCloudDBQuery(_objectTypeName)
      ..equalTo('userID', uid)
      ..equalTo('id', entryId);
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
}

class LifeStorageService {
  LifeStorageService({
    LifeEntryRemoteStore? remoteStore,
    Future<String?> Function()? userIdLoader,
  }) : _remoteStore = remoteStore ?? CloudDBLifeEntryRemoteStore(),
       _userIdLoader = userIdLoader ?? _loadCurrentUserId;

  static const _cachePrefix = 'life_entries_';
  static const _queuePrefix = 'life_sync_ops_';
  static const _guestCacheKey = 'life_entries_guest';

  final LifeEntryRemoteStore _remoteStore;
  final Future<String?> Function() _userIdLoader;

  bool lastLoadUsedLocalCache = false;
  int _pendingSyncCount = 0;

  int get pendingSyncCount => _pendingSyncCount;

  Future<List<LifeEntry>> loadEntries() async {
    final uid = await _userIdLoader();
    if (uid == null) return [];

    final localEntries = await _loadLocalEntries(uid);
    await _refreshPendingCount(uid);
    try {
      await _flush(uid);
      final cloudEntries = await _remoteStore.load(uid);
      final mergedEntries = _applyPendingOperations(
        cloudEntries,
        await _loadQueue(uid),
      );
      await _saveLocalEntries(uid, mergedEntries);
      lastLoadUsedLocalCache = _pendingSyncCount > 0;
      return mergedEntries;
    } catch (_) {
      lastLoadUsedLocalCache = true;
      return _applyPendingOperations(localEntries, await _loadQueue(uid));
    }
  }

  Future<List<LifeEntry>> loadCloudEntries() async {
    final uid = await _userIdLoader();
    if (uid == null) return [];
    return _remoteStore.load(uid);
  }

  Future<bool> saveEntry(LifeEntry entry) async {
    final uid = await _userIdLoader();
    if (uid == null) return true;
    await _mergeLocalEntry(uid, entry);
    await _replaceOperation(uid, _LifeSyncOperation.upsert(entry));
    await _flush(uid);
    return _pendingSyncCount == 0;
  }

  Future<bool> saveEntries(List<LifeEntry> entries) async {
    final uid = await _userIdLoader();
    if (uid == null || entries.isEmpty) return true;
    await _saveLocalEntries(uid, entries);
    for (final entry in entries) {
      await _replaceOperation(uid, _LifeSyncOperation.upsert(entry));
    }
    await _flush(uid);
    return _pendingSyncCount == 0;
  }

  Future<bool> deleteEntry(LifeEntry entry) async {
    final uid = await _userIdLoader();
    if (uid == null) return true;
    final entries = await _loadLocalEntries(uid);
    await _saveLocalEntries(
      uid,
      entries.where((currentEntry) => currentEntry.id != entry.id).toList(),
    );
    await _replaceOperation(uid, _LifeSyncOperation.delete(entry.id));
    await _flush(uid);
    return _pendingSyncCount == 0;
  }

  Future<int> retryPendingSync() async {
    final uid = await _userIdLoader();
    if (uid == null) return 0;
    return _flush(uid);
  }

  Future<void> clearLocalCache() async {
    final uid = await _userIdLoader();
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_cachePrefix$uid');
  }

  Future<void> deleteCloudEntries() async {
    final uid = await _userIdLoader();
    if (uid == null) return;
    final entries = await _remoteStore.load(uid);
    for (final entry in entries) {
      await _remoteStore.delete(uid, entry.id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_cachePrefix$uid');
    await prefs.remove('$_queuePrefix$uid');
    _pendingSyncCount = 0;
  }

  Future<List<LifeEntry>> loadLocalEntriesForTesting(String uid) =>
      _loadLocalEntries(uid);

  Future<List<LifeEntry>> loadGuestEntries() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeEntries(prefs.getString(_guestCacheKey));
  }

  Future<void> saveGuestEntry(LifeEntry entry) async {
    final entries = await loadGuestEntries();
    final byId = <String, LifeEntry>{for (final item in entries) item.id: item};
    byId[entry.id] = entry;
    await _saveGuestEntries(byId.values.toList());
  }

  Future<void> deleteGuestEntry(LifeEntry entry) async {
    final entries = await loadGuestEntries();
    await _saveGuestEntries(
      entries.where((item) => item.id != entry.id).toList(),
    );
  }

  Future<void> saveGuestEntries(List<LifeEntry> entries) =>
      _saveGuestEntries(entries);

  Future<void> clearGuestEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestCacheKey);
  }

  Future<int> _flush(String uid) async {
    var synced = 0;
    var queue = await _loadQueue(uid);
    while (queue.isNotEmpty) {
      final operation = queue.first;
      try {
        if (operation.isDelete) {
          await _remoteStore.delete(uid, operation.entryId);
        } else {
          await _remoteStore.upsert(uid, operation.entry!);
        }
      } catch (_) {
        break;
      }
      queue = queue.sublist(1);
      synced += 1;
      await _saveQueue(uid, queue);
    }
    _pendingSyncCount = queue.length;
    return synced;
  }

  Future<void> _replaceOperation(
    String uid,
    _LifeSyncOperation operation,
  ) async {
    final queue = await _loadQueue(uid);
    queue.removeWhere((current) => current.entryId == operation.entryId);
    queue.add(operation);
    await _saveQueue(uid, queue);
    _pendingSyncCount = queue.length;
  }

  Future<void> _refreshPendingCount(String uid) async {
    _pendingSyncCount = (await _loadQueue(uid)).length;
  }

  Future<List<_LifeSyncOperation>> _loadQueue(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_queuePrefix$uid');
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (item) => _LifeSyncOperation.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> _saveQueue(String uid, List<_LifeSyncOperation> queue) async {
    final prefs = await SharedPreferences.getInstance();
    if (queue.isEmpty) {
      await prefs.remove('$_queuePrefix$uid');
      return;
    }
    await prefs.setString(
      '$_queuePrefix$uid',
      jsonEncode(queue.map((item) => item.toJson()).toList()),
    );
  }

  List<LifeEntry> _applyPendingOperations(
    List<LifeEntry> entries,
    List<_LifeSyncOperation> queue,
  ) {
    final byId = <String, LifeEntry>{
      for (final entry in entries) entry.id: entry,
    };
    for (final operation in queue) {
      if (operation.isDelete) {
        byId.remove(operation.entryId);
      } else {
        byId[operation.entryId] = operation.entry!;
      }
    }
    return _sortEntries(byId.values);
  }

  Future<void> _mergeLocalEntry(String uid, LifeEntry entry) async {
    final entries = await _loadLocalEntries(uid);
    final byId = <String, LifeEntry>{for (final item in entries) item.id: item};
    byId[entry.id] = entry;
    await _saveLocalEntries(uid, byId.values.toList());
  }

  Future<List<LifeEntry>> _loadLocalEntries(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeEntries(prefs.getString('$_cachePrefix$uid'));
  }

  Future<void> _saveLocalEntries(String uid, List<LifeEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_cachePrefix$uid',
      jsonEncode(_sortEntries(entries).map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> _saveGuestEntries(List<LifeEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _guestCacheKey,
      jsonEncode(_sortEntries(entries).map((entry) => entry.toJson()).toList()),
    );
  }

  List<LifeEntry> _decodeEntries(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return _sortEntries(
      decoded.map((item) => LifeEntry.fromJson(item as Map<String, dynamic>)),
    );
  }

  List<LifeEntry> _sortEntries(Iterable<LifeEntry> entries) {
    final sorted = entries.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  static Future<String?> _loadCurrentUserId() async =>
      (await AGCAuth.instance.currentUser)?.uid;
}

class _LifeSyncOperation {
  const _LifeSyncOperation._({
    required this.kind,
    required this.entryId,
    this.entry,
  });

  factory _LifeSyncOperation.upsert(LifeEntry entry) =>
      _LifeSyncOperation._(kind: 'upsert', entryId: entry.id, entry: entry);

  factory _LifeSyncOperation.delete(String entryId) =>
      _LifeSyncOperation._(kind: 'delete', entryId: entryId);

  factory _LifeSyncOperation.fromJson(Map<String, dynamic> json) =>
      _LifeSyncOperation._(
        kind: json['kind'] as String,
        entryId: json['entryId'] as String,
        entry: json['entry'] == null
            ? null
            : LifeEntry.fromJson(json['entry'] as Map<String, dynamic>),
      );

  final String kind;
  final String entryId;
  final LifeEntry? entry;

  bool get isDelete => kind == 'delete';

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'entryId': entryId,
    if (entry != null) 'entry': entry!.toJson(),
  };
}
