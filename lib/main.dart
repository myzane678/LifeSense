import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/agc_service.dart';
import 'services/auth_service.dart';
import 'services/digest_preferences_service.dart';
import 'services/reminder_service.dart';
import 'services/user_settings_service.dart';
import 'state/life_entry_provider.dart';
import 'state/profile_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeAgc();
  // 从云端拉取设置写入本地，之后各 Service 初始化时直接读本地
  await UserSettingsService.instance.loadAndApply();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ReminderService()..initialize()),
        ChangeNotifierProvider(create: (_) => DigestPreferencesService()..initialize()),
        ChangeNotifierProvider(create: (_) => LifeEntryProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()..load()),
      ],
      child: const LifeSenseApp(),
    ),
  );
}
