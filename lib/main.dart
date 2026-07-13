import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/agc_service.dart';
import 'services/platform_capabilities.dart';
import 'services/auth_service.dart';
import 'services/digest_preferences_service.dart';
import 'services/reminder_service.dart';
import 'services/user_settings_service.dart';
import 'services/weekly_goals_service.dart';
import 'state/life_entry_provider.dart';
import 'state/profile_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!isWindowsLocalMode) await initializeAgc();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ReminderService()),
        ChangeNotifierProvider(
          create: (_) => DigestPreferencesService(
            userSettingsService: UserSettingsService.instance,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => WeeklyGoalsService(
            userSettingsService: UserSettingsService.instance,
          ),
        ),
        ChangeNotifierProvider(create: (_) => LifeEntryProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()..load()),
      ],
      child: const LifeSenseApp(),
    ),
  );
}
