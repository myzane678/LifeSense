import 'package:agconnect_clouddb/agconnect_clouddb.dart';

class CloudDBZoneService {
  CloudDBZoneService._();
  static final CloudDBZoneService instance = CloudDBZoneService._();

  static const _zoneName = 'lifeSense';

  AGConnectCloudDBZone? _zone;

  Future<AGConnectCloudDBZone> getZone() async {
    final existingZone = _zone;
    if (existingZone != null) return existingZone;

    final cloudDB = AGConnectCloudDB.getInstance();
    await cloudDB.initialize();
    await cloudDB.createObjectType();
    _zone = await cloudDB.openCloudDBZone(
      zoneConfig: AGConnectCloudDBZoneConfig(zoneName: _zoneName),
    );
    return _zone!;
  }
}
