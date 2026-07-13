import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../models/news_item.dart';

class ArticleDetail {
  const ArticleDetail({required this.content, this.publishedAt});
  final String content;
  final DateTime? publishedAt;
}

class NewsFetchResult {
  const NewsFetchResult({required this.items, required this.networkError});

  final List<NewsItem> items;
  final bool networkError;
}

class NewsService {
  static const _cachePrefix = 'news_cache_v18_';
  static const _cacheTtlMs = 3600000;
  static const _maxItems = 10;
  static const _maxArticlePages = 12;
  static const _articleFetchBudget = Duration(seconds: 30);

  static final NewsService instance = NewsService._();
  NewsService._({http.Client? client, DateTime Function()? now})
    : _client = client ?? http.Client(),
      _now = now ?? DateTime.now;
  factory NewsService({http.Client? client, DateTime Function()? now}) =>
      client != null || now != null
      ? NewsService._(client: client, now: now)
      : instance;

  final http.Client _client;
  final DateTime Function() _now;

  // link → 从网页提取的准确发布时间（供列表刷新使用）
  final Map<String, DateTime> _detailTimeCache = {};

  static const _sharedSources = [
    _FeedSource('https://www.ithome.com/rss/', 'IT之家'),
    _FeedSource('https://www.ifanr.com/feed', '爱范儿'),
    _FeedSource('https://www.tmtpost.com/feed', '钛媒体'),
    _FeedSource('https://36kr.com/feed', '36氪'),
    _FeedSource('https://sspai.com/feed', '少数派'),
    _FeedSource('https://www.chinanews.com.cn/rss/importnews.xml', '中新网'),
    _FeedSource('https://feeds.bbci.co.uk/zhongwen/simp/rss.xml', 'BBC中文'),
  ];

  static const _categories = {
    'frontier': _FeedCategory(
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
      includeKeywords: [
        '效率',
        '工具',
        '效率工具',
        '时间管理',
        '知识管理',
        '工作流',
        '自动化',
        '待办',
        '日程',
        '笔记',
        '文档',
        '复盘',
        '专注',
        '协作',
        '生产力',
        '信息整理',
        '阅读工具',
        '搜索',
        '整理',
        '方法',
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
        '旅游',
        '游记',
        '景点',
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
        '美食',
        '摄影',
        '穿搭',
      ],
      allowFallback: true,
      titleMatchRequired: false,
    ),
    'business': _FeedCategory(
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
      includeKeywords: [
        '成长',
        '规划',
        '长期主义',
        '能力',
        '自我管理',
        '目标',
        '复盘',
        '习惯',
        '沟通',
        '表达',
        '决策',
        '认知',
        '学习力',
        '职业',
        '职场',
        '求职',
        '简历',
        '面试',
        '实习',
        '就业',
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
      allowFallback: true,
    ),
    'product': _FeedCategory(
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
      excludeKeywords: [
        '促销',
        '优惠',
        '联名',
        '娱乐',
        '芯片',
        '火箭',
        '航天',
        'AI',
        '人工智能',
        '大模型',
        '模型',
        'Agent',
        '智能体',
        '机器人',
        '自动驾驶',
        '融资',
        '财报',
        '营收',
        '供应链',
        '量产',
        '汽车',
        '手机',
        '硬件',
      ],
      allowFallback: true,
    ),
    'campus': _FeedCategory(
      includeKeywords: [
        '教育部',
        '教育政策',
        '教育改革',
        '高等教育',
        '高校',
        '大学',
        '职业教育',
        '人才培养',
        '课程',
        '教学',
        '招生',
        '考试',
        '学生资助',
        '毕业生',
        '青年就业',
        '就业服务',
        '教师',
        '科研',
        '学科',
        '产教融合',
      ],
      excludeKeywords: [
        '公园',
        '散步',
        '音乐',
        '专辑',
        '苹果',
        'OpenAI',
        '旅游',
        '风光',
        '娱乐',
        '明星',
        '联名',
        '促销',
        '芯片',
        '火箭',
        '航天',
      ],
      allowFallback: false,
    ),
    'kr': _FeedCategory(
      includeKeywords: ['公司', '商业', '融资', '消费', '市场', '创业', '产业'],
      excludeKeywords: ['娱乐', '明星', '联名', '促销'],
    ),
    'politics': _FeedCategory(
      includeKeywords: [
        '习近平',
        '国务院',
        '政府',
        '外交部',
        '中央',
        '全国人大',
        '政协',
        '政策',
        '发布',
        '会议',
        '改革',
        '治理',
        '法治',
        '民生',
        '就业',
        '医疗',
        '教育',
        '社保',
        '财政',
        '央行',
        '乡村振兴',
        '经济',
        '中美',
        '外交',
        '国际',
        '联合国',
        '选举',
        '安全',
        '制裁',
        '冲突',
      ],
      excludeKeywords: [
        '广告',
        '促销',
        '娱乐',
        '明星',
        '八卦',
        '体育',
        '赛事',
        '越野赛',
        '旅游',
        '风光',
        '新书',
        '开店',
        '生日快乐',
        'CEO',
        '粉笔',
      ],
      allowFallback: true,
      maxAgeDays: 3,
      relatedBackfillMaxAgeDays: 7,
      relatedMinItems: 3,
    ),
  };

  Future<ArticleDetail> fetchArticleDetail(NewsItem item) async {
    // 36氪快讯是多条聚合页，直接用 RSS 数据
    if (item.link.contains('newsflashes')) {
      return ArticleDetail(
        content: item.summary,
        publishedAt: item.publishedAt,
      );
    }
    final initialUri = Uri.tryParse(item.link);
    if (initialUri == null || !_isInitialArticleUri(initialUri)) {
      return ArticleDetail(
        content: item.summary,
        publishedAt: item.publishedAt,
      );
    }

    final visited = <String>{};
    final pages = <String>[];
    final deadline = _now().add(_articleFetchBudget);
    var currentUri = initialUri;
    DateTime? publishedAt;
    try {
      for (var page = 0; page < _maxArticlePages; page++) {
        final key = _articleUriKey(currentUri);
        if (!visited.add(key)) break;

        final remaining = deadline.difference(_now());
        if (remaining <= Duration.zero) break;
        final requestTimeout = remaining < const Duration(seconds: 10)
            ? remaining
            : const Duration(seconds: 10);
        final response = await _client.get(currentUri).timeout(requestTimeout);
        if (response.statusCode != 200) break;

        final body = utf8.decode(response.bodyBytes);
        if (page == 0) {
          publishedAt = _sanitizePublishedTime(
            _extractPublishedTime(body),
            item.publishedAt,
          );
        }
        final extraction = _extractArticlePage(body, currentUri);
        final article = extraction.text;
        if (article.isEmpty || _looksPollutedArticle(article)) break;
        pages.add(article);
        final nextPage = extraction.nextPage;
        if (nextPage == null || visited.contains(_articleUriKey(nextPage))) {
          break;
        }
        currentUri = nextPage;
      }
    } catch (_) {
      // 已提取的正文仍可用，首屏请求失败时回退 RSS 摘要。
    }

    final content = _mergeArticlePages(pages);
    final safePublishedAt = publishedAt ?? item.publishedAt;
    if (safePublishedAt != item.publishedAt) {
      _detailTimeCache[item.link] = safePublishedAt;
    }
    return ArticleDetail(
      content: content.isNotEmpty ? content : item.summary,
      publishedAt: safePublishedAt,
    );
  }

  _ArticlePageExtraction _extractArticlePage(String html, Uri currentUri) {
    final document = html_parser.parse(html);
    _removeDomNoise(document);
    final text = _extractArticleTextFromDom(document);
    return _ArticlePageExtraction(
      text: text.isNotEmpty ? text : _extractArticleText(html),
      nextPage: _extractSafeNextPageUri(document, currentUri),
    );
  }

  Uri? _extractSafeNextPageUri(dom.Document document, Uri currentUri) {
    dom.Element? next;
    for (final element in document.querySelectorAll('*')) {
      if (element.localName != 'link' && element.localName != 'a') continue;
      final rel = element.attributes['rel']?.split(RegExp(r'\s+')) ?? const [];
      if (rel.contains('next')) {
        next = element;
        break;
      }
    }
    final href = next?.attributes['href'];
    if (href == null || href.isEmpty || href.startsWith('#')) return null;
    final candidate = currentUri.resolve(href);
    return _isSafeArticleUri(candidate, currentUri.host) ? candidate : null;
  }

  bool _isInitialArticleUri(Uri uri) {
    return (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  bool _isSafeArticleUri(Uri uri, String originHost) {
    return uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.host == originHost &&
        uri.userInfo.isEmpty;
  }

  String _articleUriKey(Uri uri) => uri.removeFragment().toString();

  String _mergeArticlePages(List<String> pages) {
    final seen = <String>{};
    final paragraphs = <String>[];
    for (final page in pages) {
      for (final paragraph in page.split(RegExp(r'\n{2,}'))) {
        final trimmed = paragraph.trim();
        final key = trimmed.replaceAll(RegExp(r'\s+'), '');
        if (key.isNotEmpty && seen.add(key)) paragraphs.add(trimmed);
      }
    }
    return paragraphs.join('\n\n');
  }

  /// 若该链接已被打开过，返回从网页提取的准确时间，否则返回 null
  DateTime? getDetailTime(String link) => _detailTimeCache[link];

  // 兜底校验：抽取时间超过"现在"5分钟 或比RSS时间晚超6小时，说明抓到了渲染时间
  DateTime _sanitizePublishedTime(DateTime? extracted, DateTime rssTime) {
    if (extracted == null) return rssTime;
    final now = DateTime.now();
    if (extracted.isAfter(now.add(const Duration(minutes: 5)))) return rssTime;
    if (extracted.isAfter(rssTime.add(const Duration(hours: 6)))) {
      return rssTime;
    }
    return extracted;
  }

  DateTime? _extractPublishedTime(String html) {
    // 最优先：<time datetime="..."> 语义标签
    final timeTagMatch = RegExp(
      r'<time\b[^>]*\bdatetime="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);
    if (timeTagMatch != null) {
      final dt = DateTime.tryParse(timeTagMatch.group(1)!);
      if (dt != null) return dt.toLocal();
    }

    // 优先读 JSON-LD datePublished
    final jsonLdMatch = RegExp(
      r'"datePublished"\s*:\s*"([^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);
    if (jsonLdMatch != null) {
      final dt = DateTime.tryParse(jsonLdMatch.group(1)!);
      if (dt != null) return dt.toLocal();
    }

    // Open Graph / 通用 meta
    for (final attr in [
      r'property="article:published_time"\s+content="([^"]+)"',
      r'name="publish_time"\s+content="([^"]+)"',
      r'name="publishdate"\s+content="([^"]+)"',
      r'itemprop="datePublished"\s+content="([^"]+)"',
    ]) {
      final m = RegExp(attr, caseSensitive: false).firstMatch(html);
      if (m != null) {
        final dt = DateTime.tryParse(m.group(1)!);
        if (dt != null) return dt.toLocal();
      }
    }

    // 常见中文时间格式（36氪/IT之家/少数派）
    final cnPatterns = [
      RegExp(r'(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})'),
      RegExp(r'(\d{4})年(\d{2})月(\d{2})日\s*(\d{2}):(\d{2})'),
    ];
    for (final pat in cnPatterns) {
      final m = pat.firstMatch(html);
      if (m != null) {
        final dt = DateTime.tryParse(
          '${m.group(1)!}-${m.group(2)!}-${m.group(3)!}T${m.group(4)!}:${m.group(5)!}:00+08:00',
        );
        if (dt != null) return dt.toLocal();
      }
    }
    return null;
  }

  String _extractArticleText(String html) {
    final document = html_parser.parse(html);
    final domText = _extractArticleTextFromDom(document);
    if (domText.isNotEmpty) return domText;

    final stripped = _removeNoiseBlocks(html);
    final primary = _extractFromPrimaryArticleContainers(stripped);
    if (primary.isNotEmpty) return primary;
    final candidates = <_ArticleCandidate>[];

    for (final pattern in [
      RegExp(r'<article\b([^>]*)>([\s\S]*?)<\/article>', caseSensitive: false),
      RegExp(r'<main\b([^>]*)>([\s\S]*?)<\/main>', caseSensitive: false),
      RegExp(
        r'<(?:div|section)\b([^>]*)>([\s\S]*?)<\/(?:div|section)>',
        caseSensitive: false,
      ),
    ]) {
      for (final match in pattern.allMatches(stripped)) {
        final attrs = match.group(1) ?? '';
        final block = match.group(2)!;
        if (pattern.pattern.contains('div|section') &&
            !_looksLikeArticle(attrs)) {
          continue;
        }
        final paragraphs = _extractParagraphs(block);
        final text = _trimArticleNoise(paragraphs.join('\n\n'));
        final score = _candidateScore(text, block, attrs);
        final minLength =
            pattern.pattern.startsWith('<article') || _looksLikeArticle(attrs)
            ? 1
            : 120;
        if (text.length >= minLength && score > 0) {
          candidates.add(_ArticleCandidate(text, score));
        }
      }
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.isNotEmpty ? candidates.first.text : '';
  }

  String _extractArticleTextFromDom(dom.Document document) {
    _removeDomNoise(document);

    final selectors = [
      'article',
      '#rwb_zw',
      '#articleContent',
      '#artibody',
      '#contentText',
      '#mainContent',
      '.article-content',
      '.article_content',
      '.article-body',
      '.article_body',
      '.article-detail',
      '.detail-content',
      '.detail_content',
      '.contentText',
      '.content-text',
      '.content_text',
      '.text_con',
      '.text-content',
      '.news-content',
      '.news_text',
      '.TRS_Editor',
      '.Custom_UnionStyle',
      '.left_zw',
    ];

    _ArticleCandidate? best;
    for (final selector in selectors) {
      for (final element in document.querySelectorAll(selector)) {
        final text = _trimArticleNoise(
          _paragraphsFromElement(element).join('\n\n'),
        );
        if (text.isEmpty) continue;
        final score = _domArticleScore(text, element);
        if (best == null || score > best.score) {
          best = _ArticleCandidate(text, score);
        }
      }
    }
    return best?.text ?? '';
  }

  void _removeDomNoise(dom.Document document) {
    const selectors = [
      'script',
      'style',
      'noscript',
      'svg',
      'iframe',
      'form',
      'button',
      'input',
      'select',
      'textarea',
      'nav',
      'header',
      'footer',
      'aside',
      '.recommend',
      '.share',
      '.comment',
      '.sidebar',
      '.hot',
      '.rank',
      '.latest',
      '#recommend',
      '#share',
      '#comment',
      '#sidebar',
    ];
    for (final selector in selectors) {
      for (final element in document.querySelectorAll(selector).toList()) {
        element.remove();
      }
    }
  }

  List<String> _paragraphsFromElement(dom.Element element) {
    final result = <String>[];
    final seen = <String>{};
    final paragraphNodes = element.querySelectorAll(
      'p, h1, h2, h3, blockquote',
    );
    final nodes = paragraphNodes.isNotEmpty ? paragraphNodes : [element];
    for (final node in nodes) {
      final text = node.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      final normalized = text.replaceAll(RegExp(r'\s+'), '');
      if (normalized.isEmpty || seen.contains(normalized)) continue;
      if (_isNoisyParagraph(text, node.outerHtml)) continue;
      seen.add(normalized);
      result.add(text);
    }
    return result;
  }

  int _domArticleScore(String text, dom.Element element) {
    var score = text.length;
    score += RegExp(r'[。！？!?]').allMatches(text).length * 30;
    score += element.querySelectorAll('p').length * 40;
    final attrs = '${element.id} ${element.className}'.toLowerCase();
    if (RegExp(
      r'(article|content|text|body|detail|trs_editor)',
    ).hasMatch(attrs)) {
      score += 300;
    }
    if (_looksLikeListingContent(text, element.outerHtml, attrs)) {
      score -= text.length + 1200;
    }
    return score;
  }

  String _extractFromPrimaryArticleContainers(String html) {
    final patterns = [
      RegExp(
        r'<(?:div|section|article)\b([^>]*(?:id|class)="[^"]*(?:article[-_ ]?content|article[-_ ]?body|content[-_ ]?text|contentText|text[-_ ]?con|text[-_ ]?content|main[-_ ]?content|detail[-_ ]?content|detail[-_ ]?body|news[-_ ]?text|news[-_ ]?content)[^"]*"[^>]*)>([\s\S]*?)<\/(?:div|section|article)>',
        caseSensitive: false,
      ),
      RegExp(r'<article\b([^>]*)>([\s\S]*?)<\/article>', caseSensitive: false),
    ];

    _ArticleCandidate? best;
    for (final pattern in patterns) {
      for (final match in pattern.allMatches(html)) {
        final attrs = match.group(1) ?? '';
        final block = match.group(2)!;
        if (_isContainerNoise(attrs)) continue;
        final text = _trimArticleNoise(_extractParagraphs(block).join('\n\n'));
        if (text.isEmpty) continue;
        final score = _candidateScore(text, block, attrs) + 500;
        if (best == null || score > best.score) {
          best = _ArticleCandidate(text, score);
        }
      }
    }
    return best?.text ?? '';
  }

  String _trimArticleNoise(String text) {
    final paragraphs = text
        .split(RegExp(r'\n{2,}'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final kept = <String>[];
    for (var index = 0; index < paragraphs.length; index++) {
      final paragraph = paragraphs[index];
      if (_isArticleTailNoise(paragraph) ||
          _looksLikeTailCluster(paragraphs, index)) {
        if (kept.isNotEmpty) break;
        continue;
      }
      kept.add(paragraph);
    }
    return kept.join('\n\n').trim();
  }

  bool _looksLikeTailCluster(List<String> paragraphs, int index) {
    if (!_looksLikeRelatedTitle(paragraphs[index])) return false;
    var runLength = 0;
    for (var i = index; i < paragraphs.length && i < index + 4; i++) {
      if (_looksLikeRelatedTitle(paragraphs[i]) ||
          _isArticleTailNoise(paragraphs[i])) {
        runLength += 1;
      } else {
        break;
      }
    }
    return runLength >= 3;
  }

  bool _looksLikeRelatedTitle(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), '');
    if (compact.length < 10 || compact.length > 90) return false;
    if (RegExp(r'[。；;]').hasMatch(compact)) return false;
    if (RegExp(r'\d{4}年\d{2}月\d{2}日').hasMatch(compact)) return true;
    return RegExp(
      r'[：:？?！!|/]|网友|美国|中国|台军|台风|火箭|大学|生日快乐|CEO|开店|欧洲|特斯拉|Model|Optimus|DeepSeek|iPhone|ESG',
    ).hasMatch(compact);
  }

  bool _isArticleTailNoise(String text) {
    if (RegExp(r'\d{4}年\d{2}月\d{2}日\s+\d{2}:\d{2}:\d{2}').hasMatch(text)) {
      return true;
    }
    const markers = [
      '相关推荐',
      '推荐阅读',
      '相关新闻',
      '更多新闻',
      '热门新闻',
      '延伸阅读',
      '责任编辑',
      '原标题',
      '[编辑:',
      '【编辑:',
      '编辑：',
      '编辑:',
    ];
    if (markers.any(text.contains)) return true;
    final punctuationCount = RegExp(r'[。！？!?]').allMatches(text).length;
    final titleLike = text.length <= 45 && punctuationCount == 0;
    final clickbait = RegExp(r'[？?！!：:]').hasMatch(text);
    return titleLike && clickbait;
  }

  String _removeNoiseBlocks(String html) {
    var result = html;
    for (final tag in [
      'script',
      'style',
      'noscript',
      'svg',
      'iframe',
      'form',
      'button',
      'input',
      'select',
      'textarea',
      'nav',
      'header',
      'footer',
      'aside',
      'menu',
    ]) {
      result = result.replaceAll(
        RegExp('<$tag\\b[^>]*>[\\s\\S]*?<\\/$tag>', caseSensitive: false),
        ' ',
      );
      result = result.replaceAll(
        RegExp('<$tag\\b[^>]*/?>', caseSensitive: false),
        ' ',
      );
    }
    return result;
  }

  bool _looksLikeArticle(String attrs) {
    final value = attrs.toLowerCase();
    if (_isContainerNoise(value)) return false;
    return RegExp(
      r'(article[-_ ]?(content|body|detail)?|post[-_ ]?content|entry[-_ ]?content|detail[-_ ]?(content|body)|rich-text|markdown|prose|text[-_ ]?con|contenttext|news[-_ ]?(text|content))',
    ).hasMatch(value);
  }

  bool _isContainerNoise(String attrs) {
    return RegExp(
      r'(comment|share|author|profile|recommend|sidebar|footer|header|nav|rank|hot|roll|latest)',
    ).hasMatch(attrs.toLowerCase());
  }

  List<String> _extractParagraphs(String html) {
    final result = <String>[];
    final seen = <String>{};
    final blocks = RegExp(
      r'<(?:p|h1|h2|h3|blockquote)\b[^>]*>([\s\S]*?)<\/(?:p|h1|h2|h3|blockquote)>',
      caseSensitive: false,
    ).allMatches(html);

    for (final match in blocks) {
      final raw = match.group(1)!;
      final text = _cleanHtmlText(raw);
      final normalized = text.replaceAll(RegExp(r'\s+'), '');
      if (normalized.isEmpty || seen.contains(normalized)) continue;
      if (_isNoisyParagraph(text, raw)) continue;
      seen.add(normalized);
      result.add(text);
    }

    if (result.isNotEmpty) return result;
    final text = _cleanHtmlText(html);
    return _isNoisyParagraph(text, html) ? const [] : [text];
  }

  int _candidateScore(String text, String html, String attrs) {
    var score = text.length;
    score += RegExp(r'[。！？!?\.]').allMatches(text).length * 20;
    score += RegExp(r'<p\b', caseSensitive: false).allMatches(html).length * 30;

    final attr = attrs.toLowerCase();
    if (RegExp(
      r'(article|content|post|body|entry|detail|rich-text)',
    ).hasMatch(attr)) {
      score += 180;
    }
    if (RegExp(
      r'(comment|share|author|profile|recommend|related|sidebar|footer|header|nav)',
    ).hasMatch(attr)) {
      score -= 500;
    }

    final linkText = RegExp(
      r'<a\b[^>]*>([\s\S]*?)<\/a>',
      caseSensitive: false,
    ).allMatches(html).map((m) => _cleanHtmlText(m.group(1)!)).join();
    if (text.isNotEmpty && linkText.length / text.length > 0.25) score -= 500;

    score -= _boilerplateHits(text) * 120;
    if (_looksLikeListingContent(text, html, attrs)) score -= text.length + 800;
    return score;
  }

  bool _looksPollutedArticle(String text) {
    final paragraphs = text
        .split(RegExp(r'\n{2,}'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (paragraphs.length < 6) return false;

    var titleLikeRun = 0;
    for (final paragraph in paragraphs) {
      if (_looksLikeRelatedTitle(paragraph)) {
        titleLikeRun += 1;
        if (titleLikeRun >= 3) return true;
      } else {
        titleLikeRun = 0;
      }
    }
    return false;
  }

  bool _looksLikeListingContent(String text, String html, String attrs) {
    final paragraphs = text
        .split(RegExp(r'\n{2,}'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (paragraphs.length < 8) return false;

    final shortLines = paragraphs.where((line) => line.length <= 34).length;
    final articleLines = paragraphs.where((line) {
      return line.length >= 45 && RegExp(r'[。！？]$').hasMatch(line);
    }).length;
    final listTags = RegExp(
      r'<(?:li|ul|ol)\b',
      caseSensitive: false,
    ).allMatches(html).length;
    final listingAttr = RegExp(
      r'(list|recommend|related|hot|rank|sidebar|channel|scroll|roll|latest)',
    ).hasMatch(attrs.toLowerCase());

    return shortLines / paragraphs.length > 0.65 &&
        articleLines <= 2 &&
        (listTags >= 3 || listingAttr);
  }

  bool _isNoisyParagraph(String text, String rawHtml) {
    if (text.length < 12) return true;
    final compact = text.replaceAll(RegExp(r'\s+'), '');
    if (compact.length < 20 && _boilerplateHits(text) > 0) return true;
    if (_boilerplateHits(text) >= 2) return true;

    final linkText = RegExp(
      r'<a\b[^>]*>([\s\S]*?)<\/a>',
      caseSensitive: false,
    ).allMatches(rawHtml).map((m) => _cleanHtmlText(m.group(1)!)).join();
    return text.isNotEmpty && linkText.length / text.length > 0.35;
  }

  String _cleanHtmlText(String html) {
    var text = _removeNoiseBlocks(html).replaceAll(RegExp(r'<[^>]+>'), ' ');
    return _decodeHtmlEntities(text).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  int _boilerplateHits(String text) {
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
      '推荐阅读',
      '注册',
      '登录',
      '关注',
      '分享',
      '收藏',
      '举报',
      '微博',
      '微信',
      '复制链接',
      '点击下方按钮',
      '少数派帐号',
      '少数派作者',
      '联合作者',
      '日夜间',
      '随系统',
      '去APP听音频',
      '跟内行聊见解',
      '今日热点导览',
      '听全文',
      '关注作者',
      '一级市场金融',
      '推送和解读',
      '聚焦全球优秀',
    ];
    return keywords.where(text.contains).length;
  }

  String _decodeHtmlEntities(String text) {
    final named = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&ldquo;', '“')
        .replaceAll('&rdquo;', '”')
        .replaceAll('&lsquo;', '‘')
        .replaceAll('&rsquo;', '’')
        .replaceAll('&hellip;', '…');
    return named.replaceAllMapped(RegExp(r'&#(x?[0-9a-fA-F]+);'), (match) {
      final raw = match.group(1)!;
      final code = raw.startsWith('x') || raw.startsWith('X')
          ? int.tryParse(raw.substring(1), radix: 16)
          : int.tryParse(raw);
      return code == null ? match.group(0)! : String.fromCharCode(code);
    });
  }

  Future<List<NewsItem>> fetchFeed(
    String key, {
    bool forceRefresh = false,
  }) async {
    return (await fetchFeedResult(key, forceRefresh: forceRefresh)).items;
  }

  Future<NewsFetchResult> fetchFeedResult(
    String key, {
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_cachePrefix$key';
    final tsKey = '${cacheKey}_ts';
    final cachedTs = prefs.getInt(tsKey) ?? 0;
    final now = _now().millisecondsSinceEpoch;

    if (!forceRefresh && now - cachedTs < _cacheTtlMs) {
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
      // 并发请求所有源，避免某个源超时拖垮整个分区
      final results = await Future.wait(
        _sharedSources.map((source) async {
          try {
            final response = await _client
                .get(Uri.parse(source.url))
                .timeout(const Duration(seconds: 10));
            if (response.statusCode != 200) return <NewsItem>[];
            final body = utf8.decode(response.bodyBytes);
            return _parseRss(body, source.name);
          } catch (_) {
            return <NewsItem>[];
          }
        }),
      );

      final candidates = results.expand((list) => list).toList();
      final fetchedAnySource = candidates.isNotEmpty;

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

  // 全局广告/促销标题模式，不区分分类
  static const _adTitlePatterns = [
    '上新',
    '来玩~',
    '等你来玩',
    '欢迎体验',
    '限时',
    '免费领',
    '立即领取',
    '福利',
    '优惠券',
    '扫码',
    '添加微信',
    '点击领取',
    '小程序上线',
    '小程序上新',
    '内测',
    '报名',
    '招募',
    '抽奖',
    '联名款',
  ];

  bool _looksLikeAd(NewsItem item) {
    final title = item.title;
    return _adTitlePatterns.any(title.contains);
  }

  List<NewsItem> _selectItems(
    List<NewsItem> candidates,
    _FeedCategory category,
  ) {
    final selectedByKey = <String, _ScoredNewsItem>{};
    final relatedBackfillByKey = <String, _ScoredNewsItem>{};
    final recent = <String, _ScoredNewsItem>{};

    for (final item in candidates) {
      if (item.summary.trim().isEmpty) continue;
      final text = '${item.title} ${item.summary}';
      if (text.contains('�')) continue;
      if (_hasAny(text, category.excludeKeywords)) continue;
      if (_looksLikeAd(item)) continue;
      final ageHours = _now().difference(item.publishedAt).inHours;
      if (ageHours < 0 ||
          ageHours > category.effectiveRelatedBackfillMaxAgeDays * 24) {
        continue;
      }
      final keywordScore = _keywordScore(item, category);
      final key = _dedupeKey(item);
      if (key.isEmpty) continue;
      final scored = _ScoredNewsItem(
        item,
        keywordScore + _freshnessScore(item),
      );
      if (keywordScore > 0) {
        final target = ageHours <= category.maxAgeDays * 24
            ? selectedByKey
            : relatedBackfillByKey;
        final existing = target[key];
        if (existing == null || scored.score > existing.score) {
          target[key] = scored;
        }
      } else if (ageHours <= category.maxAgeDays * 24) {
        recent.putIfAbsent(key, () => scored);
      }
    }

    final selected = _sortScoredItems(selectedByKey.values);
    if (selected.length < category.relatedMinItems) {
      final selectedKeys = selectedByKey.keys;
      selected.addAll(
        _sortScoredItems(relatedBackfillByKey.values)
            .where((item) => !selectedKeys.contains(_dedupeKey(item.item)))
            .take(category.relatedMinItems - selected.length),
      );
    }

    if (category.allowFallback && selected.length < _maxItems) {
      selected.addAll(
        _sortScoredItems(recent.values).take(_maxItems - selected.length),
      );
    }

    final balanced = _balanceBySource(selected, maxItems: _maxItems);
    balanced.sort((a, b) {
      final timeCompare = b.item.publishedAt.compareTo(a.item.publishedAt);
      if (timeCompare != 0) return timeCompare;
      return b.score.compareTo(a.score);
    });
    return balanced.map((e) => e.item).toList();
  }

  List<_ScoredNewsItem> _sortScoredItems(Iterable<_ScoredNewsItem> items) {
    return items.toList()..sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return b.item.publishedAt.compareTo(a.item.publishedAt);
    });
  }

  List<_ScoredNewsItem> _balanceBySource(
    List<_ScoredNewsItem> items, {
    required int maxItems,
  }) {
    final grouped = <String, List<_ScoredNewsItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.item.source, () => []).add(item);
    }
    final sources = grouped.keys.toList()
      ..sort((a, b) {
        final aFirst = grouped[a]!.first;
        final bFirst = grouped[b]!.first;
        final scoreCompare = bFirst.score.compareTo(aFirst.score);
        if (scoreCompare != 0) return scoreCompare;
        return bFirst.item.publishedAt.compareTo(aFirst.item.publishedAt);
      });

    final result = <_ScoredNewsItem>[];
    var index = 0;
    while (result.length < maxItems) {
      var added = false;
      for (final source in sources) {
        final sourceItems = grouped[source]!;
        if (index >= sourceItems.length) continue;
        result.add(sourceItems[index]);
        added = true;
        if (result.length >= maxItems) break;
      }
      if (!added) break;
      index++;
    }
    return result;
  }

  int _keywordScore(NewsItem item, _FeedCategory category) {
    var score = 0;
    for (final keyword in category.includeKeywords) {
      if (_containsKeyword(item.title, keyword)) {
        score += 3;
      } else if (!category.titleMatchRequired &&
          _containsKeyword(item.summary, keyword)) {
        score += 1;
      }
    }
    return score;
  }

  int _freshnessScore(NewsItem item) {
    final hours = _now().difference(item.publishedAt).inHours;
    if (hours < 0) return 0;
    if (hours <= 6) return 5;
    if (hours <= 24) return 3;
    if (hours <= 48) return 1;
    return 0;
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

      for (final item in items.take(40)) {
        final title = _text(item, 'title');
        final link = _text(item, 'link');
        final desc = _stripHtml(_text(item, 'description'));
        final pubDate = _parseDate(_text(item, 'pubDate'));
        if (title.isEmpty || link.isEmpty) continue;
        result.add(
          NewsItem(
            title: title,
            summary: desc,
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

  String _stripHtml(String html) => _decodeHtmlEntities(
    html.replaceAll(RegExp(r'<[^>]*>'), ' '),
  ).replaceAll(RegExp(r'\s+'), ' ').trim();

  DateTime _parseDate(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return DateTime(1970);

    final parsed = DateTime.tryParse(normalized);
    if (parsed != null) return parsed.toLocal();

    // RFC-822: "Wed, 10 Jul 2026 12:34:56 +0800" 或 "... CST"
    final rssMatch = RegExp(
      r'^[A-Za-z]{3},\s+(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+([+-]\d{4}|GMT|CST|UTC)$',
    ).firstMatch(normalized);
    if (rssMatch == null) return DateTime(1970);

    final month = _monthNumber(rssMatch.group(2)!);
    if (month == null) return DateTime(1970);
    final offset = rssMatch.group(7)!;
    final isoOffset = switch (offset) {
      'GMT' || 'UTC' => 'Z',
      'CST' => '+08:00',
      _ => '${offset.substring(0, 3)}:${offset.substring(3)}',
    };
    final iso =
        '${rssMatch.group(3)!}-${month.toString().padLeft(2, '0')}-'
        '${rssMatch.group(1)!.padLeft(2, '0')}T${rssMatch.group(4)!}:'
        '${rssMatch.group(5)!}:${rssMatch.group(6)!}$isoOffset';
    return DateTime.tryParse(iso)?.toLocal() ?? DateTime(1970);
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

class _ArticlePageExtraction {
  const _ArticlePageExtraction({required this.text, this.nextPage});
  final String text;
  final Uri? nextPage;
}

class _FeedSource {
  const _FeedSource(this.url, this.name);
  final String url;
  final String name;
}

class _FeedCategory {
  const _FeedCategory({
    required this.includeKeywords,
    required this.excludeKeywords,
    this.allowFallback = true,
    this.maxAgeDays = 7,
    this.relatedBackfillMaxAgeDays,
    this.relatedMinItems = 0,
    this.titleMatchRequired = false,
  });

  final List<String> includeKeywords;
  final List<String> excludeKeywords;
  final bool allowFallback;
  final int maxAgeDays;
  final int? relatedBackfillMaxAgeDays;
  final int relatedMinItems;

  int get effectiveRelatedBackfillMaxAgeDays =>
      relatedBackfillMaxAgeDays ?? maxAgeDays;

  /// 为 true 时关键词必须命中标题，命中摘要不算
  final bool titleMatchRequired;
}

class _ArticleCandidate {
  const _ArticleCandidate(this.text, this.score);
  final String text;
  final int score;
}

class _ScoredNewsItem {
  const _ScoredNewsItem(this.item, this.score);
  final NewsItem item;
  final int score;
}
