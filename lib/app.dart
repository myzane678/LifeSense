import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/life_entry.dart';
import 'screens/check_in_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/entry_detail_screen.dart';
import 'screens/daily_digest_screen.dart';
import 'screens/edit_entry_screen.dart';
import 'screens/history_screen.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/weekly_report_screen.dart';
import 'services/auth_service.dart';
import 'services/digest_preferences_service.dart';
import 'services/reminder_service.dart';
import 'services/user_settings_service.dart';
import 'state/life_entry_provider.dart';
import 'state/profile_provider.dart';

class LifeSenseApp extends StatelessWidget {
  const LifeSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeSense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      routes: {
        '/': (_) => const _AuthGate(),
        '/check-in': (_) => const CheckInScreen(),
        '/history': (_) => const HistoryScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/weekly-report': (_) => const WeeklyReportScreen(),
        '/digest': (_) => const DailyDigestScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/detail') {
          return MaterialPageRoute<void>(
            builder: (_) =>
                EntryDetailScreen(entry: settings.arguments as LifeEntry),
          );
        }
        if (settings.name == '/edit') {
          return MaterialPageRoute<bool>(
            builder: (_) =>
                EditEntryScreen(entry: settings.arguments as LifeEntry),
          );
        }
        return null;
      },
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _started = false;
  bool _sessionInitialized = false;
  int _sessionGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authService = context.watch<AuthService>();
    if (!_started) {
      _started = true;
      _initializeAuth(authService);
    }
    if (!authService.isSignedIn) {
      if (_sessionInitialized) {
        _sessionGeneration++;
        context.read<DigestPreferencesService>().resetSession();
      }
      _sessionInitialized = false;
    } else if (authService.isInitialized) {
      _initializeSession(authService);
    }
  }

  Future<void> _initializeAuth(AuthService authService) async {
    await authService.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _initializeSession(AuthService authService) async {
    if (_sessionInitialized) return;
    _sessionInitialized = true;
    final entryProvider = context.read<LifeEntryProvider>();
    final reminderService = context.read<ReminderService>();
    final digestPrefs = context.read<DigestPreferencesService>();
    final profileProvider = context.read<ProfileProvider>();
    if (authService.isGuestMode) {
      entryProvider.setGuestMode(true);
      await digestPrefs.initializeForUser('guest');
      await reminderService.initialize();
      await entryProvider.loadGuestEntries();
      return;
    }

    final uid = authService.currentUser?.uid;
    if (uid == null) return;
    final generation = ++_sessionGeneration;
    UserSettingsRecord? cloudSettings;
    try {
      cloudSettings = await UserSettingsService.instance.loadForUser(uid);
    } catch (_) {}
    if (!mounted ||
        generation != _sessionGeneration ||
        authService.currentUser?.uid != uid) {
      return;
    }
    if (cloudSettings != null) {
      await UserSettingsService.instance.applyReminderSettings(cloudSettings);
    }
    await digestPrefs.initializeForUser(uid, cloudRecord: cloudSettings);
    if (!mounted ||
        generation != _sessionGeneration ||
        authService.currentUser?.uid != uid) {
      return;
    }
    await reminderService.initialize();
    await entryProvider.loadEntries();
    await profileProvider.loadCloudProfile();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    if (!authService.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!authService.isSignedIn) return const LoginScreen();
    return const DashboardScreen();
  }
}
