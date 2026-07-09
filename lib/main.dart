import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/agc_service.dart';
import 'services/auth_service.dart';
import 'state/life_entry_provider.dart';
import 'state/profile_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeAgc();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LifeEntryProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()..load()),
      ],
      child: const LifeSenseApp(),
    ),
  );
}
