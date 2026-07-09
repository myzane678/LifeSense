import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_sense/models/life_entry.dart';
import 'package:life_sense/screens/dashboard_screen.dart';
import 'package:life_sense/services/life_storage_service.dart';
import 'package:life_sense/state/life_entry_provider.dart';
import 'package:provider/provider.dart';

class _FakeStorage extends LifeStorageService {
  _FakeStorage([this._preset = const []]);
  final List<LifeEntry> _preset;

  @override
  Future<List<LifeEntry>> loadEntries() async => _preset;

  @override
  Future<void> saveEntry(LifeEntry entry) async {}

  @override
  Future<void> saveEntries(List<LifeEntry> entries) async {}

  @override
  Future<void> clearEntries() async {}
}

Widget _wrapDashboard(LifeEntryProvider provider) {
  return ChangeNotifierProvider<LifeEntryProvider>.value(
    value: provider,
    child: MaterialApp(
      routes: {
        '/check-in': (_) => const Scaffold(body: Text('check-in')),
        '/history': (_) => const Scaffold(body: Text('history')),
        '/settings': (_) => const Scaffold(body: Text('settings')),
      },
      home: const DashboardScreen(),
    ),
  );
}

void main() {
  testWidgets('首页无记录时显示空状态引导卡', (tester) async {
    final provider = LifeEntryProvider(storageService: _FakeStorage())
      ..loadEntries();
    await tester.pumpWidget(_wrapDashboard(provider));
    await tester.pumpAndSettle();

    expect(find.text('LifeSense'), findsOneWidget);
    expect(find.text('今天还没有记录'), findsOneWidget);
    expect(find.text('立即记录'), findsOneWidget);
    expect(find.text('查看历史'), findsOneWidget);
  });

  testWidgets('首页有今日记录时显示 ScoreCard', (tester) async {
    final entry = LifeEntry(
      id: '1',
      createdAt: DateTime.now(),
      mood: 4,
      energy: 4,
      stress: 2,
      focus: 4,
      sleepHours: 8,
      waterCups: 8,
      activity: '学习',
      note: '',
      score: 80,
      status: '状态良好',
      suggestion: '保持现状，继续加油',
    );

    final provider = LifeEntryProvider(storageService: _FakeStorage([entry]))
      ..loadEntries();
    await tester.pumpWidget(_wrapDashboard(provider));
    await tester.pumpAndSettle();

    expect(find.text('80'), findsWidgets);
    expect(find.text('状态良好'), findsOneWidget);
    expect(find.text('保持现状，继续加油'), findsOneWidget);
  });
}
