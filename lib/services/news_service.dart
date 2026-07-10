import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../models/news_item.dart';

class NewsFetchResult {
  const NewsFetchResult({required this.items, required this.networkError});

  final List<NewsItem> items;
  final bool networkError;
}

class NewsService {
  static const _cachePrefix = 'news_cache_v7_';
  static const _cacheTtlMs = 3600000;
  static const _maxItems = 8;

  static const _categories = {
    'frontier': _FeedCategory(
      sources: [
        _FeedSource('https://www.ithome.com/rss/', 'IT之家'),
        _FeedSource('https://36kr.com/feed', '36氪'),
        _FeedSource('https://sspai.com/feed', '少数派'),
      ],
      includeKeywords: [
        'AI',
        '人工智能',
        '大模型',
        '模型',
        'Agent',
        '智能体',
        '生成式',
        '机器学习',
        '芯片',
        '半导体',
        '算力',
        '机器人',
        '自动驾驶',
        '航天',
        '火箭',
        '操作系统',
        '开源',
        '研发',
        '量产',
        '科研',
        '国家科学技术进步奖',
      ],
      excludeKeywords: [
        '联名',
        '洛天依',
        '二次元',
        '周边',
        '手办',
        '促销',
        '优惠',
        '开售',
        '配色',
        '演唱会',
        '皮肤',
        '盲盒',
        '耳机',
        '音箱',
        '手机壳',
      ],
    ),
    'study': _FeedCategory(
      sources: [
        _FeedSource('https://sspai.com/feed', '少数派'),
        _FeedSource('https://36kr.com/feed', '36氪'),
      ],
      includeKeywords: [
        '学习方法',
        '学习效率',
        '复习',
        '预习',
        '笔记',
        '课程',
        '考试',
        '知识管理',
        '时间管理',
        '复盘',
        '背单词',
        '备考',
        '刷题',
        '自习',
        '专注',
        '记忆',
        '错题',
        '阅读方法',
      ],
      excludeKeywords: [
        '融资',
        '量产',
        '芯片',
        '半导体',
        '火箭',
        '航天',
        '汽车',
        '手机',
        '电脑',
        '桌面',
        '灯光',
        '设备',
        '旅行',
        '出行',
        '饮品',
        'DIY',
        '家居',
        '消费',
        '大模型',
        'Agent',
        '智能体',
        'AI',
        '人工智能',
        '促销',
        '优惠',
        '联名',
        '娱乐',
      ],
      allowFallback: false,
    ),
    'business': _FeedCategory(
      sources: [_FeedSource('https://36kr.com/feed', '36氪')],
      includeKeywords: [
        '财经',
        '商业',
        '公司',
        '财报',
        '融资',
        '消费',
        '市场',
        '投资',
        '创业',
        '产业',
        '营收',
        '利润',
        '供应链',
        '品牌',
        '电商',
        '零售',
      ],
      excludeKeywords: ['明星', '娱乐', '联名', '促销', 'AI', '人工智能', '大模型'],
    ),
    'career': _FeedCategory(
      sources: [
        _FeedSource('https://36kr.com/feed', '36氪'),
        _FeedSource('https://sspai.com/feed', '少数派'),
      ],
      includeKeywords: [
        '职业',
        '职场',
        '招聘',
        '实习',
        '就业',
        '校招',
        '秋招',
        '春招',
        '岗位',
        '人才',
        '简历',
        '面试',
        '求职',
        '毕业生',
        '职业规划',
      ],
      excludeKeywords: [
        '娱乐',
        '明星',
        '联名',
        '促销',
        '芯片',
        '火箭',
        '航天',
        '汽车',
        '财报',
        '融资',
        '消费',
        '销量',
        '上市失败',
        '管理层',
        '大公司',
        '产业',
        '供应链',
      ],
      allowFallback: false,
    ),
    'product': _FeedCategory(
      sources: [
        _FeedSource('https://sspai.com/feed', '少数派'),
        _FeedSource('https://36kr.com/feed', '36氪'),
      ],
      includeKeywords: [
        '设计',
        '产品',
        '交互',
        '体验',
        'UX',
        'UI',
        '创意',
        '界面',
        '原型',
        '可用性',
        '工作流',
        '工具',
      ],
      excludeKeywords: ['促销', '优惠', '联名', '娱乐', '芯片', '火箭', '航天'],
      allowFallback: false,
    ),
    'campus': _FeedCategory(
      sources: [
        _FeedSource('https://sspai.com/feed', '少数派'),
        _FeedSource('https://36kr.com/feed', '36氪'),
      ],
      includeKeywords: [
        '校园',
        '大学生',
        '实习',
        '考研',
        '竞赛',
        '毕业',
        '就业',
        '学习',
        '教育',
        '奖学金',
        '保研',
        '社团',
      ],
      excludeKeywords: ['娱乐', '明星', '联名', '促销', '芯片', '火箭', '航天'],
      allowFallback: false,
    ),
    'kr': _FeedCategory(
      sources: [_FeedSource('https://36kr.com/feed', '36氪')],
      includeKeywords: ['公司', '商业', '融资', '消费', '市场', '创业', '产业'],
      excludeKeywords: ['娱乐', '明星', '联名', '促销'],
    ),
    'politics': _FeedCategory(
      sources: [
        _FeedSource('http://www.people.com.cn/rss/politics.xml', '人民日报'),
        _FeedSource('http://www.people.com.cn/rss/society.xml', '人民日报'),
      ],
      includeKeywords: [
        '发展',
        '政策',
        '改革',
        '经济',
        '民生',
        '社会',
        '科技',
        '教育',
        '就业',
        '创新',
        '建设',
        '治理',
        '安全',
        '环境',
        '医疗',
        '脱贫',
        '乡村',
        '青年',
        '法治',
        '数字',
      ],
      excludeKeywords: ['广告', '促销', '娱乐', '明星', '八卦'],
      allowFallback: true,
    ),
  };

  Future<String> fetchArticleSummary(NewsItem item) async {
    try {
      final response = await http
          .get(Uri.parse(item.link))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return item.summary;
      final body = utf8.decode(response.bodyBytes);
      final article = _extractArticleText(body);
      if (article.length < 80) return item.summary;
      return _summarizeArticle(article);
    } catch (_) {
      return item.summary;
    }
  }

  String _extractArticleText(String html) {
    // 先去掉脚本、样式和导航结构，再做内容提取
    final stripped = html
        .replaceAll(
          RegExp(r'<script[^>]*>[\s\S]*?<\/script>', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'<style[^>]*>[\s\S]*?<\/style>', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(
            r'<(?:nav|header|footer|aside|menu)[^>]*>[\s\S]*?<\/(?:nav|header|footer|aside|menu)>',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          // 删除列表结构，避免速览目录、导航列表混入正文提取
          RegExp(r'<(?:ul|ol)[^>]*>[\s\S]*?<\/(?:ul|ol)>', caseSensitive: false),
          '',
        );

    final candidates = [
      RegExp(r'<article[^>]*>([\s\S]*?)<\/article>', caseSensitive: false),
      RegExp(
        r'<div[^>]+class="[^"]*(?:post_content|post-content|article-content|news-content|content)[^"]*"[^>]*>([\s\S]*?)<\/div>',
        caseSensitive: false,
      ),
      RegExp(
        r'<section[^>]+class="[^"]*(?:article|content)[^"]*"[^>]*>([\s\S]*?)<\/section>',
        caseSensitive: false,
      ),
    ];

    for (final pattern in candidates) {
      final match = pattern.firstMatch(stripped);
      if (match == null) continue;
      final text = _cleanHtmlText(match.group(1)!);
      if (text.length >= 80) return text;
    }

    // 提取所有 <p> 标签内容，比整页兜底干净得多
    final pTexts = RegExp(r'<p[^>]*>([\s\S]*?)<\/p>', caseSensitive: false)
        .allMatches(stripped)
        .map((m) => _cleanHtmlText(m.group(1)!))
        .where((t) => t.length >= 40)
        .toList();
    if (pTexts.isNotEmpty) {
      final joined = pTexts.join(' ');
      if (joined.length >= 80) return joined;
    }

    return _cleanHtmlText(stripped);
  }

  String _cleanHtmlText(String html) {
    var text = html
        .replaceAll(
          RegExp(r'<script[^>]*>[\s\S]*?<\/script>', caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'<style[^>]*>[\s\S]*?<\/style>', caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'<noscript[^>]*>[\s\S]*?<\/noscript>', caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'<(?:nav|header|footer|aside)[^>]*>[\s\S]*?<\/(?:nav|header|footer|aside)>', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    return _decodeHtmlEntities(text).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _summarizeArticle(String text) {
    final sentences = text
        .split(RegExp(r'(?<=[。！？!?])'))
        .map((e) => e.trim())
        .where((e) => e.length >= 12)
        .where((e) => !_isBoilerplate(e))
        .toList();

    // 贪心拼接：加入下一句不超限才加，保证不截断句子中间
    final buffer = StringBuffer();
    for (final s in sentences) {
      if (buffer.length + s.length > 320) break;
      buffer.write(s);
      if (buffer.length >= 100) break; // 够长就停，避免堆砌太多
    }

    if (buffer.isEmpty) {
      // 无句号结构（列表式内容）：取前 200 字兜底
      return text.length > 200 ? '${text.substring(0, 200)}…' : text;
    }
    return buffer.toString();
  }

  bool _isBoilerplate(String text) {
    const keywords = [
      '版权所有',
      'Copyright',
      'ICP备',
      '广告',
      '分享至',
      '扫一扫',
      '下载客户端',
      '打开微信',
      '首页',
      '设置',
      '订阅',
      'RSS订阅',
      '投稿',
      '搜索',
      'App客户端',
      'IT圈',
      '最会买',
      '责任编辑',
      '作者：',
      '来源：',
      '评论：',
      '相关推荐',
      '注册',
    ];
    return keywords.any(text.contains);
  }

  String _decodeHtmlEntities(String text) => text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  Future<List<NewsItem>> fetchFeed(String key) async {
    return (await fetchFeedResult(key)).items;
  }

  Future<NewsFetchResult> fetchFeedResult(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_cachePrefix$key';
    final tsKey = '${cacheKey}_ts';
    final cachedTs = prefs.getInt(tsKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now - cachedTs < _cacheTtlMs) {
      final cached = prefs.getString(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return NewsFetchResult(
          items: _deserialize(cached),
          networkError: false,
        );
      }
    }

    final category = _categories[key];
    if (category == null) {
      return const NewsFetchResult(items: [], networkError: false);
    }

    try {
      final candidates = <NewsItem>[];
      var fetchedAnySource = false;
      for (final source in category.sources) {
        final response = await http
            .get(Uri.parse(source.url))
            .timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) continue;
        fetchedAnySource = true;
        candidates.addAll(
          _parseRss(utf8.decode(response.bodyBytes), source.name),
        );
      }

      if (!fetchedAnySource) {
        final cached = _fallbackCache(prefs, cacheKey);
        return NewsFetchResult(items: cached, networkError: cached.isEmpty);
      }

      final items = _selectItems(candidates, category);
      if (items.isNotEmpty) {
        await prefs.setString(cacheKey, _serialize(items));
        await prefs.setInt(tsKey, now);
      }
      return NewsFetchResult(items: items, networkError: false);
    } catch (_) {
      final cached = _fallbackCache(prefs, cacheKey);
      return NewsFetchResult(items: cached, networkError: cached.isEmpty);
    }
  }

  List<NewsItem> _selectItems(
    List<NewsItem> candidates,
    _FeedCategory category,
  ) {
    final deduped = <String, _ScoredNewsItem>{};
    final fallback = <String, _ScoredNewsItem>{};

    for (final item in candidates) {
      final text = '${item.title} ${item.summary}';
      if (text.contains('�')) continue;
      if (_hasAny(text, category.excludeKeywords)) continue;
      final keywordScore = _keywordScore(item, category);
      final key = _dedupeKey(item);
      if (key.isEmpty) continue;
      final scored = _ScoredNewsItem(
        item,
        keywordScore + _freshnessScore(item),
      );
      if (keywordScore > 0) {
        final existing = deduped[key];
        if (existing == null || scored.score > existing.score) {
          deduped[key] = scored;
        }
      } else {
        fallback.putIfAbsent(key, () => scored);
      }
    }

    final selected = deduped.values.toList()
      ..sort((a, b) {
        final scoreCompare = b.score.compareTo(a.score);
        if (scoreCompare != 0) return scoreCompare;
        return b.item.publishedAt.compareTo(a.item.publishedAt);
      });

    if (category.allowFallback && selected.length < 4) {
      selected.addAll(fallback.values.take(4 - selected.length));
    }

    return selected.take(_maxItems).map((e) => e.item).toList();
  }

  int _keywordScore(NewsItem item, _FeedCategory category) {
    var score = 0;
    for (final keyword in category.includeKeywords) {
      if (_containsKeyword(item.title, keyword)) score += 3;
      if (_containsKeyword(item.summary, keyword)) score += 1;
    }
    return score;
  }

  int _freshnessScore(NewsItem item) {
    final hours = DateTime.now().difference(item.publishedAt).inHours;
    return hours >= 0 && hours <= 24 ? 1 : 0;
  }

  bool _hasAny(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (_containsKeyword(text, keyword)) return true;
    }
    return false;
  }

  bool _containsKeyword(String text, String keyword) {
    return text.toLowerCase().contains(keyword.toLowerCase());
  }

  String _dedupeKey(NewsItem item) {
    final uri = Uri.tryParse(item.link);
    final linkKey = uri == null ? '' : '${uri.host}${uri.path}'.toLowerCase();
    if (linkKey.isNotEmpty) return linkKey;
    return item.title.replaceAll(RegExp(r'\s+'), '').toLowerCase();
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

      for (final item in items.take(12)) {
        final title = _text(item, 'title');
        final link = _text(item, 'link');
        final desc = _stripHtml(_text(item, 'description'));
        final pubDate = _parseDate(_text(item, 'pubDate'));
        if (title.isEmpty || link.isEmpty) continue;
        result.add(
          NewsItem(
            title: title,
            summary: desc.length > 100 ? '${desc.substring(0, 100)}…' : desc,
            link: link,
            source: source,
            publishedAt: pubDate,
          ),
        );
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

  String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&nbsp;', ' ').trim();

  DateTime _parseDate(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return DateTime.now();
    final parsed = DateTime.tryParse(normalized);
    if (parsed != null) return parsed.toLocal();

    final rssMatch = RegExp(
      r'^[A-Za-z]{3},\s+(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+([+-]\d{4}|GMT)$',
    ).firstMatch(normalized);
    if (rssMatch == null) return DateTime.now();

    final month = _monthNumber(rssMatch.group(2)!);
    if (month == null) return DateTime.now();
    final offset = rssMatch.group(7)!;
    final isoOffset = offset == 'GMT'
        ? 'Z'
        : '${offset.substring(0, 3)}:${offset.substring(3)}';
    final iso =
        '${rssMatch.group(3)!}-${month.toString().padLeft(2, '0')}-'
        '${rssMatch.group(1)!.padLeft(2, '0')}T${rssMatch.group(4)!}:'
        '${rssMatch.group(5)!}:${rssMatch.group(6)!}$isoOffset';
    return DateTime.tryParse(iso)?.toLocal() ?? DateTime.now();
  }

  int? _monthNumber(String month) {
    const months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    return months[month];
  }

  String _serialize(List<NewsItem> items) => jsonEncode(
    items
        .map(
          (e) => {
            'title': e.title,
            'summary': e.summary,
            'link': e.link,
            'source': e.source,
            'publishedAt': e.publishedAt.toIso8601String(),
          },
        )
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

class _FeedSource {
  const _FeedSource(this.url, this.name);
  final String url;
  final String name;
}

class _FeedCategory {
  const _FeedCategory({
    required this.sources,
    required this.includeKeywords,
    required this.excludeKeywords,
    this.allowFallback = true,
  });

  final List<_FeedSource> sources;
  final List<String> includeKeywords;
  final List<String> excludeKeywords;
  final bool allowFallback;
}

class _ScoredNewsItem {
  const _ScoredNewsItem(this.item, this.score);
  final NewsItem item;
  final int score;
}
