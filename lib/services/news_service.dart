import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../models/news_item.dart';

class NewsService {
  static const _cachePrefix = 'news_cache_';
  static const _cacheTtlMs = 3600000; // 1 小时

  // RSS 数据源
  static const _feeds = {
    'tech': (
      url: 'https://www.ithome.com/rss/',
      source: 'IT之家',
    ),
    'ai': (
      url: 'https://sspai.com/feed',
      source: '少数派',
    ),
    'kr': (
      url: 'https://36kr.com/feed',
      source: '36氪',
    ),
  };

  // 获取指定 feed 的新闻，优先读本地缓存
  Future<List<NewsItem>> fetchFeed(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_cachePrefix$key';
    final tsKey = '${cacheKey}_ts';

    final cachedTs = prefs.getInt(tsKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now - cachedTs < _cacheTtlMs) {
      final cached = prefs.getString(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return _deserialize(cached);
      }
    }

    final feed = _feeds[key];
    if (feed == null) return [];

    try {
      final response = await http
          .get(Uri.parse(feed.url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return _fallbackCache(prefs, cacheKey);

      final items = _parseRss(response.body, feed.source);
      if (items.isNotEmpty) {
        await prefs.setString(cacheKey, _serialize(items));
        await prefs.setInt(tsKey, now);
      }
      return items;
    } catch (_) {
      return _fallbackCache(prefs, cacheKey);
    }
  }

  List<NewsItem> _fallbackCache(SharedPreferences prefs, String key) {
    final cached = prefs.getString(key);
    if (cached != null && cached.isNotEmpty) return _deserialize(cached);
    return [];
  }

  List<NewsItem> _parseRss(String body, String source) {
    try {
      final doc = XmlDocument.parse(body);
      final items = doc.findAllElements('item');
      final result = <NewsItem>[];

      for (final item in items.take(8)) {
        final title = _text(item, 'title');
        final link = _text(item, 'link');
        final desc = _stripHtml(_text(item, 'description'));
        final pubDate = _parseDate(_text(item, 'pubDate'));
        if (title.isEmpty || link.isEmpty) continue;
        result.add(NewsItem(
          title: title,
          summary: desc.length > 100 ? '${desc.substring(0, 100)}…' : desc,
          link: link,
          source: source,
          publishedAt: pubDate,
        ));
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  String _text(XmlElement el, String tag) {
    try {
      return el.findElements(tag).first.innerText.trim();
    } catch (_) {
      return '';
    }
  }

  // 去除 HTML 标签
  String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&nbsp;', ' ').trim();

  DateTime _parseDate(String raw) {
    try {
      return DateTime.parse(raw);
    } catch (_) {
      try {
        // RSS 日期格式：Wed, 09 Jul 2025 10:00:00 +0800
        return DateTime.now();
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  String _serialize(List<NewsItem> items) => jsonEncode(
        items
            .map((e) => {
                  'title': e.title,
                  'summary': e.summary,
                  'link': e.link,
                  'source': e.source,
                  'publishedAt': e.publishedAt.toIso8601String(),
                })
            .toList(),
      );

  List<NewsItem> _deserialize(String json) {
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return NewsItem(
          title: m['title'] as String,
          summary: m['summary'] as String,
          link: m['link'] as String,
          source: m['source'] as String,
          publishedAt: DateTime.parse(m['publishedAt'] as String),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
