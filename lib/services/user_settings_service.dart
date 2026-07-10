import 'package:agconnect_auth/agconnect_auth.dart';
import 'package:agconnect_clouddb/agconnect_clouddb.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'clouddb_zone_service.dart';

class UserSettingsService {
  UserSettingsService._();
  static final UserSettingsService instance = UserSettingsService._();

  static const _objectTypeName = 'UserSettings';

  // 与各 Service 保持一致的 SharedPreferences key
  static const _digestIdsKey = 'digest_selected_interest_ids';
  static const _reminderEnabledKey = 'daily_reminder_enabled';
  static const _reminderHourKey = 'daily_reminder_hour';
  static const _reminderMinuteKey = 'daily_reminder_minute';

  /// 启动时调用：从云端拉取设置并写入本地，供各 Service 初始化时读取
  Future<void> loadAndApply() async {
    try {
      final user = await AGCAuth.instance.currentUser;
      final uid = user?.uid;
      if (uid == null) return;

      final zone = await CloudDBZoneService.instance.getZone();
      final query = AGConnectCloudDBQuery(_objectTypeName)
        ..equalTo('userID', uid);
      final snapshot = await zone.executeQuery(
        query: query,
        policy: AGConnectCloudDBZoneQueryPolicy.POLICY_QUERY_FROM_CLOUD_ONLY,
      );
      if (snapshot.snapshotObjects.isEmpty) return;

      final data = Map<String, dynamic>.from(snapshot.snapshotObjects.first);
      final prefs = await SharedPreferences.getInstance();

      final ids = data['digestSelectedIds'] as String?;
      if (ids != null && ids.isNotEmpty) {
        await prefs.setStringList(_digestIdsKey, ids.split(','));
      }
      final reminderEnabled = data['reminderEnabled'] as bool?;
      if (reminderEnabled != null) {
        await prefs.setBool(_reminderEnabledKey, reminderEnabled);
      }
      final hour = data['reminderHour'] as int?;
      if (hour != null) await prefs.setInt(_reminderHourKey, hour);
      final minute = data['reminderMinute'] as int?;
      if (minute != null) await prefs.setInt(_reminderMinuteKey, minute);
    } catch (_) {
      // 云端不可达时静默失败，使用本地值
    }
  }

  /// 任意设置变更后调用：从本地读取全部设置推到云端
  Future<void> syncToCloud() async {
    try {
      final user = await AGCAuth.instance.currentUser;
      final uid = user?.uid;
      if (uid == null) return;

      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_digestIdsKey) ?? [];
      final enabled = prefs.getBool(_reminderEnabledKey) ?? false;
      final hour = prefs.getInt(_reminderHourKey) ?? 21;
      final minute = prefs.getInt(_reminderMinuteKey) ?? 0;

      final zone = await CloudDBZoneService.instance.getZone();
      await zone.executeUpsert(
        objectTypeName: _objectTypeName,
        entries: [
          {
            'userID': uid,
            'digestSelectedIds': ids.join(','),
            'reminderEnabled': enabled,
            'reminderHour': hour,
            'reminderMinute': minute,
          },
        ],
      );
    } catch (_) {
      // 云端保存失败不中断用户操作
    }
  }
}
