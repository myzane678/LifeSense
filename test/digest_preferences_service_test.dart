import 'package:flutter_test/flutter_test.dart';
import 'package:life_sense/services/digest_preferences_service.dart';
import 'package:life_sense/services/user_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRemoteStore implements UserSettingsRemoteStore {
  final records = <String, UserSettingsRecord>{};
  bool failSave = false;

  @override
  Future<void> delete(String uid) async {
    records.remove(uid);
  }

  @override
  Future<UserSettingsRecord?> load(String uid) async => records[uid];

  @override
  Future<void> save(String uid, UserSettingsRecord record) async {
    if (failSave) throw StateError('offline');
    records[uid] = record;
  }
}

void main() {
  test('空本地时按账号从云端恢复兴趣方向', () async {
    SharedPreferences.setMockInitialValues({});
    final remote = _FakeRemoteStore()
      ..records['user-a'] = const UserSettingsRecord(
        digestSelectedIds: ['politics', 'health'],
        reminderEnabled: true,
        reminderHour: 8,
        reminderMinute: 30,
      );
    final preferences = DigestPreferencesService(
      userSettingsService: UserSettingsService(remoteStore: remote),
    );

    await preferences.initializeForUser(
      'user-a',
      cloudRecord: await remote.load('user-a'),
    );

    expect(preferences.selectedIds, ['politics', 'health']);
  });

  test('账号缓存隔离且云保存失败保留待同步选择', () async {
    SharedPreferences.setMockInitialValues({});
    final remote = _FakeRemoteStore();
    final preferences = DigestPreferencesService(
      userSettingsService: UserSettingsService(remoteStore: remote),
    );

    await preferences.initializeForUser('user-a');
    await preferences.setSelectedIds(['politics']);
    await preferences.initializeForUser('user-b');
    expect(
      preferences.selectedIds,
      DigestPreferencesService.defaultSelectedIds,
    );

    await preferences.initializeForUser('user-a');
    remote.failSave = true;
    await expectLater(
      preferences.setSelectedIds(['health', 'politics']),
      throwsStateError,
    );
    expect(preferences.selectedIds, ['health', 'politics']);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('digest_interest_sync_pending_user-a'), isTrue);
  });

  test('待同步本地选择不会被旧云数据覆盖', () async {
    SharedPreferences.setMockInitialValues({
      'digest_selected_interest_ids_user-a': ['politics'],
      'digest_interest_sync_pending_user-a': true,
    });
    final remote = _FakeRemoteStore()
      ..records['user-a'] = const UserSettingsRecord(
        digestSelectedIds: ['health'],
        reminderEnabled: false,
        reminderHour: 21,
        reminderMinute: 0,
      );
    final preferences = DigestPreferencesService(
      userSettingsService: UserSettingsService(remoteStore: remote),
    );

    await preferences.initializeForUser(
      'user-a',
      cloudRecord: await remote.load('user-a'),
    );

    expect(preferences.selectedIds, ['politics']);
    expect(remote.records['user-a']!.digestSelectedIds, ['politics']);
  });
}
