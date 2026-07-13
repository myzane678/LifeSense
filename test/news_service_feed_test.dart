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
    expect(result.items.map((item) => item.title).toList(), [
      '国务院召开经济政策会议',
      '国际组织讨论地区安全',
      '地方政府推进社保改革',
    ]);
    expect(result.items, hasLength(3));
    expect(result.items.map((item) => item.title), isNot(contains('暑期旅游风光推荐')));
    expect(result.items.map((item) => item.source).toSet(), hasLength(2));
  });

  test('空摘要条目不会进入新闻列表', () async {
    SharedPreferences.setMockInitialValues({});
    final service = NewsService(
      now: () => now,
      client: MockClient(
        (request) async => http.Response(
          _rss([
            (
              title: '高校人才培养计划',
              summary: '',
              link: 'https://${request.url.host}/empty',
              date: now.subtract(const Duration(hours: 1)),
            ),
            (
              title: '高校人才培养改革',
              summary: '教育改革与人才培养工作持续推进。',
              link: 'https://${request.url.host}/complete',
              date: now.subtract(const Duration(hours: 2)),
            ),
          ]),
          200,
          headers: {'content-type': 'application/xml; charset=utf-8'},
        ),
      ),
    );

    final result = await service.fetchFeedResult('campus');

    expect(result.items.map((item) => item.title), isNot(contains('高校人才培养计划')));
    expect(result.items, isNotEmpty);
  });

  test('不同标签请求同一公共实时新闻源池', () async {
    SharedPreferences.setMockInitialValues({});
    final requestedHosts = <String>[];
    final service = NewsService(
      now: () => now,
      client: MockClient((request) async {
        requestedHosts.add(request.url.host);
        if (request.url.host == 'education.news.cn' ||
            request.url.host == 'www.moe.gov.cn' ||
            request.url.host == 'edu.people.com.cn') {
          return http.Response(
            '<html><body><a href="/20260710/article/c.html">教育部部署高校毕业生就业服务</a></body></html>',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }
        return http.Response(
          _rss([
            (
              title: '教育部部署高校毕业生就业服务',
              summary: '高校毕业生就业和人才培养工作持续推进。',
              link: 'https://${request.url.host}/news',
              date: now.subtract(const Duration(hours: 1)),
            ),
          ]),
          200,
          headers: {'content-type': 'application/xml; charset=utf-8'},
        );
      }),
    );

    await service.fetchFeedResult('campus', forceRefresh: true);
    final educationHosts = [...requestedHosts]..sort();
    requestedHosts.clear();
    await service.fetchFeedResult('study', forceRefresh: true);
    final studyHosts = [...requestedHosts]..sort();

    expect(studyHosts, educationHosts);
  });

  test('通用分类会用近期正常内容补满 10 条', () async {
    SharedPreferences.setMockInitialValues({});
    final service = NewsService(
      now: () => now,
      client: MockClient((request) async {
        return http.Response(
          _rss([
            for (var i = 0; i < 12; i++)
              (
                title: i == 0 ? '效率工具帮助整理每日任务' : '通用内容观察 $i',
                summary: i == 0 ? '时间管理和知识管理工具。' : '近期值得关注的正常内容。',
                link: 'https://${request.url.host}/generic-$i',
                date: now.subtract(Duration(hours: i)),
              ),
          ]),
          200,
          headers: {'content-type': 'application/xml; charset=utf-8'},
        );
      }),
    );

    for (final key in ['study', 'career', 'politics']) {
      final result = await service.fetchFeedResult(key, forceRefresh: true);
      expect(result.networkError, isFalse, reason: key);
      expect(result.items, hasLength(10), reason: key);
    }
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

    expect(cached.items.first.title, first.items.first.title);
    expect(refreshed.items.first.title, isNot(first.items.first.title));
    expect(calls, greaterThan(2));
  });
}
