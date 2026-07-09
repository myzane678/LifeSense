import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/life_entry.dart';
import 'screens/check_in_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/entry_detail_screen.dart';
import 'screens/history_screen.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';
import 'services/auth_service.dart';
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
      routes: {
        '/': (_) => const _AuthGate(),
        '/check-in': (_) => const CheckInScreen(),
        '/history': (_) => const HistoryScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/detail') {
          return MaterialPageRoute<void>(
            builder: (_) =>
                EntryDetailScreen(entry: settings.arguments as LifeEntry),
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final authService = context.read<AuthService>();
    final entryProvider = context.read<LifeEntryProvider>();
    final profileProvider = context.read<ProfileProvider>();
    _initialize(authService, entryProvider, profileProvider);
  }

  Future<void> _initialize(
    AuthService authService,
    LifeEntryProvider entryProvider,
    ProfileProvider profileProvider,
  ) async {
    await authService.initialize();
    if (!mounted || !authService.isSignedIn) return;
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
