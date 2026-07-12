import 'dart:convert';

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

String _rss(List<({String title, String link, DateTime date})> items) {
  return '''<?xml version="1.0"?><rss><channel>${items.map((item) => '<item><title>${item.title}</title><link>${item.link}</link><description>学习笔记整理。</description><pubDate>${item.date.toIso8601String()}</pubDate></item>').join()}</channel></rss>''';
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

  testWidgets('新闻详情使用屏幕注入的服务获取全文', (tester) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.clear();
    await sharedPreferences.setBool('digest_interest_prompt_seen', true);
    await sharedPreferences.setStringList(
      'digest_selected_interest_ids_test-user',
      ['study'],
    );
    final now = DateTime.now();
    await sharedPreferences.setString(
      'news_cache_v14_study',
      jsonEncode([
        {
          'title': '学习方法测试新闻',
          'summary': '缓存中的摘要内容',
          'link': 'https://example.com/article',
          'source': '少数派',
          'publishedAt': now.toIso8601String(),
        },
      ]),
    );
    await sharedPreferences.setInt(
      'news_cache_v14_study_ts',
      now.millisecondsSinceEpoch,
    );
    final preferences = DigestPreferencesService();
    await preferences.initializeForUser('test-user');
    final provider = LifeEntryProvider(storageService: _FakeStorage(const []));
    await provider.loadEntries();
    final newsService = NewsService(
      client: MockClient((request) async {
        if (request.url.host == 'example.com') {
          return http.Response.bytes(
            utf8.encode('''
<html><body><article>
<p>注入服务返回的完整正文，用于验证详情弹窗不会改用全局单例服务。</p>
<p>第二段补充上下文，确保正文抽取会保留这个可读内容。</p>
</article></body></html>
'''),
            200,
          );
        }
        return http.Response('', 500);
      }),
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

    expect(find.text('学习方法测试新闻'), findsOneWidget);
    await tester.tap(find.text('学习方法测试新闻'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(find.textContaining('注入服务返回的完整正文'), findsOneWidget);
  });

  testWidgets('新闻列表支持下拉刷新且使用最新内容优先显示', (tester) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.clear();
    await sharedPreferences.setBool('digest_interest_prompt_seen', true);
    await sharedPreferences.setStringList(
      'digest_selected_interest_ids_test-user',
      ['politics'],
    );
    var calls = 0;
    final preferences = DigestPreferencesService();
    await preferences.initializeForUser('test-user');
    final provider = LifeEntryProvider(storageService: _FakeStorage(const []));
    await provider.loadEntries();
    final newsService = NewsService(
      client: MockClient((_) async {
        calls++;
        final newest = DateTime(2026, 7, 12, 8, 30);
        final older = DateTime(2026, 7, 11, 20, 13);
        return http.Response.bytes(
          utf8.encode(_rss([
            (
              title: '国务院召开经济政策会议',
              link: 'https://example.com/new',
              date: newest,
            ),
            (
              title: '国际组织讨论地区安全',
              link: 'https://example.com/old',
              date: older,
            ),
          ])),
          200,
          headers: {'content-type': 'application/xml; charset=utf-8'},
        );
      }),
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

    expect(find.text('国务院召开经济政策会议'), findsOneWidget);
    expect(find.text('国际组织讨论地区安全'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();

    expect(calls, greaterThanOrEqualTo(2));
    expect(find.text('国务院召开经济政策会议'), findsOneWidget);
  });
}
