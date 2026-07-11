import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_sense/models/life_entry.dart';
import 'package:life_sense/screens/daily_digest_screen.dart';
import 'package:life_sense/services/digest_preferences_service.dart';
import 'package:life_sense/services/life_storage_service.dart';
import 'package:life_sense/services/news_service.dart';
import 'package:life_sense/state/life_entry_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStorage extends LifeStorageService {
  _FakeStorage(this._entries);
  final List<LifeEntry> _entries;

  @override
  Future<List<LifeEntry>> loadEntries() async => _entries;
}

LifeEntry _entry(String note) {
  return LifeEntry(
    id: '1',
    createdAt: DateTime.now(),
    mood: 4,
    energy: 4,
    stress: 2,
    focus: 4,
    sleepHours: 7,
    waterCups: 6,
    activity: '学习',
    note: note,
    score: 80,
    status: '状态良好',
    suggestion: '保持节奏',
  );
}

void main() {
  testWidgets('健康生活和学习工具箱显示不同本地内容', (tester) async {
    SharedPreferences.setMockInitialValues({
      'digest_interest_prompt_seen': true,
      'digest_selected_interest_ids_test-user': ['health'],
    });
    final preferences = DigestPreferencesService();
    await preferences.initializeForUser('test-user');
    final provider = LifeEntryProvider(
      storageService: _FakeStorage([_entry('最近压力有点大，睡晚也比较累。')]),
    );
    await provider.loadEntries();
    final newsService = NewsService(
      client: MockClient((_) async => http.Response('', 500)),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DigestPreferencesService>.value(
            value: preferences,
          ),
          ChangeNotifierProvider<LifeEntryProvider>.value(value: provider),
        ],
        child: MaterialApp(home: DailyDigestScreen(newsService: newsService)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('健康生活'), findsOneWidget);
    expect(find.text('学习工具箱'), findsOneWidget);
    expect(find.text('健康建议'), findsOneWidget);
    expect(find.text('学习工具'), findsNothing);
    expect(find.text('睡眠优化三件事'), findsOneWidget);

    await tester.tap(find.text('学习工具箱'));
    await tester.pumpAndSettle();

    expect(find.text('学习工具'), findsOneWidget);
    expect(find.text('番茄工作法'), findsOneWidget);
    expect(find.text('健康建议'), findsNothing);
  });
}
