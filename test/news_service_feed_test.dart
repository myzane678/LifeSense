import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_sense/services/news_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _rss(
  List<({String title, String summary, String link, DateTime date})> items,
) {
  return '''<?xml version="1.0"?><rss><channel>${items.map((item) => '<item><title>${item.title}</title><link>${item.link}</link><description>${item.summary}</description><pubDate>${item.date.toIso8601String()}</pubDate></item>').join()}</channel></rss>''';
}

void main() {
  final now = DateTime(2026, 7, 11, 12);

  test('时政热点聚合多条相关内容且不混入无关新闻', () async {
    SharedPreferences.setMockInitialValues({});
    final service = NewsService(
      now: () => now,
      client: MockClient((request) async {
        if (request.url.host == 'www.chinanews.com.cn') {
          return http.Response(
            _rss([
              (
                title: '国务院召开经济政策会议',
                summary: '会议发布新的民生政策。',
                link: 'https://news.example.cn/1',
                date: now.subtract(const Duration(hours: 4)),
              ),
              (
                title: '地方政府推进社保改革',
                summary: '多部门公布社保改革安排。',
                link: 'https://news.example.cn/2',
                date: now.subtract(const Duration(hours: 28)),
              ),
              (
                title: '暑期旅游风光推荐',
                summary: '旅游线路促销活动。',
                link: 'https://news.example.cn/3',
                date: now.subtract(const Duration(hours: 3)),
              ),
            ]),
            200,
            headers: {'content-type': 'application/xml; charset=utf-8'},
          );
        }
        return http.Response(
          _rss([
            (
              title: '国际组织讨论地区安全',
              summary: '联合国有关会议持续举行。',
              link: 'https://bbc.example.com/1',
              date: now.subtract(const Duration(hours: 12)),
            ),
            (
              title: '选举结果引发政策讨论',
              summary: '各方讨论新的外交政策。',
              link: 'https://bbc.example.com/2',
              date: now.subtract(const Duration(days: 4)),
            ),
          ]),
          200,
          headers: {'content-type': 'application/xml; charset=utf-8'},
        );
      }),
    );

    final result = await service.fetchFeedResult('politics');

    expect(result.networkError, isFalse);
    expect(
      result.items.map((item) => item.title),
      containsAll(['国务院召开经济政策会议', '地方政府推进社保改革', '国际组织讨论地区安全']),
    );
    expect(result.items, hasLength(3));
    expect(result.items.map((item) => item.title), isNot(contains('暑期旅游风光推荐')));
    expect(result.items.map((item) => item.source).toSet(), hasLength(2));
  });

  test('强制刷新绕过有效缓存', () async {
    SharedPreferences.setMockInitialValues({});
    var calls = 0;
    final service = NewsService(
      now: () => now,
      client: MockClient((request) async {
        calls++;
        return http.Response(
          _rss([
            (
              title: '国务院发布政策 $calls',
              summary: '民生政策更新。',
              link: 'https://${request.url.host}/$calls',
              date: now.subtract(const Duration(hours: 2)),
            ),
          ]),
          200,
          headers: {'content-type': 'application/xml; charset=utf-8'},
        );
      }),
    );

    final first = await service.fetchFeedResult('politics');
    final cached = await service.fetchFeedResult('politics');
    final refreshed = await service.fetchFeedResult(
      'politics',
      forceRefresh: true,
    );

    expect(first.items.first.title, '国务院发布政策 1');
    expect(cached.items.first.title, '国务院发布政策 1');
    expect(refreshed.items.first.title, '国务院发布政策 3');
    expect(calls, 4);
  });
}
