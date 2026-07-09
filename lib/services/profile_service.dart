import 'package:agconnect_auth/agconnect_auth.dart';
import 'package:agconnect_clouddb/agconnect_clouddb.dart';

import '../models/user_profile.dart';
import 'clouddb_zone_service.dart';

class ProfileService {
  ProfileService();

  static const _objectTypeName = 'UserProfile';

  Future<UserProfile?> loadProfile() async {
    final user = await AGCAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return null;

    final zone = await CloudDBZoneService.instance.getZone();
    final query = AGConnectCloudDBQuery(_objectTypeName)
      ..equalTo('userID', uid);
    final snapshot = await zone.executeQuery(
      query: query,
      policy: AGConnectCloudDBZoneQueryPolicy.POLICY_QUERY_FROM_CLOUD_ONLY,
    );
    if (snapshot.snapshotObjects.isEmpty) return null;
    return UserProfile.fromJson(snapshot.snapshotObjects.first);
  }

  Future<void> saveProfile({
    required String nickname,
    required String avatarPath,
  }) async {
    final user = await AGCAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return;

    final profile = UserProfile(
      userID: uid,
      nickname: nickname,
      avatarPath: avatarPath,
      updatedAt: DateTime.now(),
    );
    final zone = await CloudDBZoneService.instance.getZone();
    await zone.executeUpsert(
      objectTypeName: _objectTypeName,
      entries: [profile.toJson()],
    );
  }
}
