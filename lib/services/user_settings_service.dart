import 'package:agconnect_auth/agconnect_auth.dart';
import 'package:agconnect_clouddb/agconnect_clouddb.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'clouddb_zone_service.dart';

class UserSettingsRecord {
  const UserSettingsRecord({
    required this.digestSelectedIds,
    required this.reminderEnabled,
    required this.reminderHour,
    required this.reminderMinute,
  });

  final List<String> digestSelectedIds;
  final bool? reminderEnabled;
  final int? reminderHour;
  final int? reminderMinute;
}

abstract class UserSettingsRemoteStore {
  Future<UserSettingsRecord?> load(String uid);
  Future<void> save(String uid, UserSettingsRecord record);
  Future<void> delete(String uid);
}

class CloudDBUserSettingsRemoteStore implements UserSettingsRemoteStore {
  static const _objectTypeName = 'UserSettings';

  @override
  Future<UserSettingsRecord?> load(String uid) async {
    final zone = await CloudDBZoneService.instance.getZone();
    final query = AGConnectCloudDBQuery(_objectTypeName)
      ..equalTo('userID', uid);
    final snapshot = await zone.executeQuery(
      query: query,
      policy: AGConnectCloudDBZoneQueryPolicy.POLICY_QUERY_FROM_CLOUD_ONLY,
    );
    if (snapshot.snapshotObjects.isEmpty) return null;
    final data = Map<String, dynamic>.from(snapshot.snapshotObjects.first);
    final ids = (data['digestSelectedIds'] as String? ?? '')
        .split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    return UserSettingsRecord(
      digestSelectedIds: ids,
      reminderEnabled: data['reminderEnabled'] as bool?,
      reminderHour: data['reminderHour'] as int?,
      reminderMinute: data['reminderMinute'] as int?,
    );
  }

  @override
  Future<void> save(String uid, UserSettingsRecord record) async {
    final zone = await CloudDBZoneService.instance.getZone();
    await zone.executeUpsert(
      objectTypeName: _objectTypeName,
      entries: [
        {
          'userID': uid,
          'digestSelectedIds': record.digestSelectedIds.join(','),
          'reminderEnabled': record.reminderEnabled ?? false,
          'reminderHour': record.reminderHour ?? 21,
          'reminderMinute': record.reminderMinute ?? 0,
        },
      ],
    );
  }

  @override
  Future<void> delete(String uid) async {
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
}

class UserSettingsService {
  UserSettingsService({UserSettingsRemoteStore? remoteStore})
    : _remoteStore = remoteStore ?? CloudDBUserSettingsRemoteStore();

  static final UserSettingsService instance = UserSettingsService();

  static const _reminderEnabledKey = 'daily_reminder_enabled';
  static const _reminderHourKey = 'daily_reminder_hour';
  static const _reminderMinuteKey = 'daily_reminder_minute';

  final UserSettingsRemoteStore _remoteStore;

  Future<String?> currentUserId() async =>
      (await AGCAuth.instance.currentUser)?.uid;

  Future<UserSettingsRecord?> loadForUser(String uid) => _remoteStore.load(uid);

  Future<void> applyReminderSettings(UserSettingsRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    if (record.reminderEnabled != null) {
      await prefs.setBool(_reminderEnabledKey, record.reminderEnabled!);
    }
    if (record.reminderHour != null) {
      await prefs.setInt(_reminderHourKey, record.reminderHour!);
    }
    if (record.reminderMinute != null) {
      await prefs.setInt(_reminderMinuteKey, record.reminderMinute!);
    }
  }

  Future<void> saveDigestSelectedIds(String uid, List<String> ids) async {
    final existing = await _remoteStore.load(uid);
    final prefs = await SharedPreferences.getInstance();
    await _remoteStore.save(
      uid,
      UserSettingsRecord(
        digestSelectedIds: ids,
        reminderEnabled:
            existing?.reminderEnabled ?? prefs.getBool(_reminderEnabledKey),
        reminderHour: existing?.reminderHour ?? prefs.getInt(_reminderHourKey),
        reminderMinute:
            existing?.reminderMinute ?? prefs.getInt(_reminderMinuteKey),
      ),
    );
  }

  Future<void> syncReminderSettings() async {
    final uid = await currentUserId();
    if (uid == null) return;
    final existing = await _remoteStore.load(uid);
    final prefs = await SharedPreferences.getInstance();
    await _remoteStore.save(
      uid,
      UserSettingsRecord(
        digestSelectedIds: existing?.digestSelectedIds ?? const [],
        reminderEnabled: prefs.getBool(_reminderEnabledKey),
        reminderHour: prefs.getInt(_reminderHourKey),
        reminderMinute: prefs.getInt(_reminderMinuteKey),
      ),
    );
  }

  Future<void> deleteForUser(String uid) => _remoteStore.delete(uid);
}
