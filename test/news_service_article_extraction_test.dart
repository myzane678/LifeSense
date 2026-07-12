import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_sense/models/news_item.dart';
import 'package:life_sense/services/news_service.dart';

NewsItem _item({
  String summary = 'RSS 提供的干净摘要。',
  String link = 'https://example.com/post/1',
  String title = '测试文章',
}) {
  return NewsItem(
    title: title,
    summary: summary,
    link: link,
    source: '少数派',
    publishedAt: DateTime(2026, 7, 10),
  );
}

void main() {
  test('文章正文抽取会过滤作者关注分享等页面噪声', () async {
    final service = NewsService(
      client: MockClient((_) async {
        return http.Response.bytes(
          utf8Bytes('''
<html>
<body>
<header>首页 搜索 登录 注册</header>
<nav>推荐 阅读 分享</nav>
<article class="post-content">
  <div class="author-card">主作者 关注 少数派作者 如果没有问你的意见 就不要在停车场拉屎</div>
  <p>真正的正文第一段介绍格拉纳达旅行的日与夜，描述城市街巷、阳光和旅途中的观察。</p>
  <p>真正的正文第二段继续展开安达卢西亚的历史、建筑和当地生活，让读者理解这趟旅行的核心体验。</p>
  <p>真正的正文第三段总结从土耳其回来后的感受，并说明为什么夏天适合去西班牙感受阳光。</p>
  <div class="share-box">微信扫码分享 分享到微博 点击下方按钮可复制链接 收藏 举报</div>
</article>
<footer>相关推荐 下载客户端 Copyright</footer>
</body>
</html>
'''),
          200,
        );
      }),
    );

    final detail = await service.fetchArticleDetail(_item());
    final summary = detail.content;

    expect(summary, contains('真正的正文第一段'));
    expect(summary, isNot(contains('关注')));
    expect(summary, isNot(contains('分享')));
    expect(summary, isNot(contains('停车场拉屎')));
    expect(summary, isNot(contains('下载客户端')));
  });

  test('长正文摘要不会从句子中间硬截断', () async {
    final service = NewsService(
      client: MockClient((_) async {
        return http.Response.bytes(
          utf8Bytes('''
<html><body><article>
<p>第一段说明学习方法需要先建立稳定节奏，再根据课程难度安排复习顺序，这样可以减少临时抱佛脚带来的压力。</p>
<p>第二段强调每天固定时间复盘错题，把错误原因和触发条件写清楚，下一次遇到同类题目时就能更快识别。</p>
<p>第三段建议把大任务拆成几个番茄钟，完成后进行离屏休息，让注意力恢复后再继续推进。</p>
</article></body></html>
'''),
          200,
        );
      }),
    );

    final detail = await service.fetchArticleDetail(_item());
    final summary = detail.content;

    expect(RegExp(r'[。！？…]$').hasMatch(summary), isTrue);
    expect(summary, isNot(contains('触发条…')));
  });

  test('标题列表不会被误判为文章正文', () async {
    final service = NewsService(
      client: MockClient((_) async {
        return http.Response.bytes(
          utf8Bytes('''
<html><body>
<section class="latest-news-list">
<ul>
<li>孟凡辰：美国对华政策已进入更多实阶段</li>
<li>中国汽车驶入“扎根世界”新阶段</li>
<li>张雪：好想在台湾开个店，一定会开</li>
<li>台军校试办卫哨外包，网友：会不会被大陆笑死啊</li>
<li>美国眼中的欧洲有多“糟”？北约峰会乱成一锅粥</li>
<li>和平温室岂容“恶魔”孵化</li>
<li>中国独创火箭网系回收方案：天外精准归航，海上柔网揽箭</li>
<li>这所“窑洞大学”，为何让来访外国军官深受触动？</li>
<li>阿嚏！阿嚏！谁来救救“过敏星人”？</li>
<li>74周岁生日快乐！东北林业大学，太宝藏了吧！</li>
</ul>
</section>
<article class="article-content">
<p>真正的正文第一段介绍政策变化背后的现实背景，说明不同地区如何根据自身条件推进工作。</p>
<p>真正的正文第二段继续展开具体措施，包括组织协调、资源投入和基层执行方式。</p>
<p>真正的正文第三段总结这些安排对普通读者的影响，并说明后续仍需要观察落实效果。</p>
</article>
</body></html>
'''),
          200,
        );
      }),
    );

    final detail = await service.fetchArticleDetail(
      _item(summary: 'RSS 备用摘要。'),
    );

    expect(detail.content, contains('真正的正文第一段'));
    expect(detail.content, isNot(contains('孟凡辰')));
    expect(detail.content, isNot(contains('中国汽车驶入')));
  });

  test('正文后面的无关标题列表会被截断', () async {
    final service = NewsService(
      client: MockClient((_) async {
        return http.Response.bytes(
          utf8Bytes('''
<html><body><article>
<p>真正的正文第一段介绍政策变化背后的现实背景，说明不同地区如何根据自身条件推进工作。</p>
<p>真正的正文第二段继续展开具体措施，包括组织协调、资源投入和基层执行方式。</p>
<p>真正的正文第三段总结这些安排对普通读者的影响，并说明后续仍需要观察落实效果。</p>
<p>新华社记者</p>
<p>特斯拉 46 天拆除 Model S/X 产线，为 Optimus 人形机器人量产铺路</p>
<p>早报 | 曝苹果折叠屏 iPhone 已在量产/DeepSeek 或自研 AI 推理芯片/今年 618 手机销量同比下滑 13%</p>
<p>【ESG-V 评级观察】上海上市公司价值重估：金融科创抬升上限，先进制造与城市服务分化显现</p>
</article></body></html>
'''),
          200,
        );
      }),
    );

    final detail = await service.fetchArticleDetail(_item());

    expect(detail.content, contains('真正的正文第一段'));
    expect(detail.content, contains('真正的正文第三段'));
    expect(detail.content, isNot(contains('特斯拉 46 天拆除')));
    expect(detail.content, isNot(contains('DeepSeek 或自研')));
    expect(detail.content, isNot(contains('ESG-V')));
  });

  test('少数派派早报保留完整的多条新闻', () async {
    final service = NewsService(
      client: MockClient((_) async {
        return http.Response.bytes(
          utf8Bytes('''
<html><body><article>
<h1>派早报：蔚来 ES8 大五座版正式上市等</h1>
<div class="article-content">
<h2>蔚来 ES8 大五座版正式上市</h2>
<p>蔚来于七月九日正式发布 ES8 大五座版，并公布了售价、交付时间和电池租用方案等关键信息。</p>
<p>新车围绕乘坐舒适性和储物空间调整，同时提供多种内饰主题和座椅调节配置。</p>
<p>动力系统采用高压架构与双电机四驱，续航、功率和智能座舱配置均有明确升级。</p>
<p>来源 少数派</p>
<h2>OpenAI 发布 GPT-5.6 系列模型等</h2>
<p>后续文章特有文本：OpenAI 宣布推出新的智能体产品，并调整桌面应用的功能入口。</p>
<p>后续文章继续说明模型发布时间、产品迁移安排和面向不同订阅用户的开放节奏。</p>
<p>后续文章最后补充浏览器支持计划与相关服务调整，内容不属于蔚来新闻详情。</p>
<p>来源 少数派</p>
</div></article></body></html>
'''),
          200,
        );
      }),
    );

    final detail = await service.fetchArticleDetail(
      _item(
        link: 'https://sspai.com/post/112143',
        title: '派早报：蔚来 ES8 大五座版正式上市等',
        summary: '蔚来 ES8 大五座版发布。',
      ),
    );

    expect(detail.content, contains('蔚来于七月九日'));
    expect(detail.content, contains('后续文章特有文本'));
    expect(detail.content, contains('后续文章最后补充浏览器支持计划'));
  });

  test('普通少数派文章保留后续二级小节', () async {
    final service = NewsService(
      client: MockClient((_) async {
        return http.Response.bytes(
          utf8Bytes('''
<html><body><article>
<h1>如何整理长期学习笔记</h1>
<h2>建立稳定的归档方式</h2>
<p>第一节详细说明如何按课程、主题和任务阶段整理学习材料，并通过统一命名减少以后检索与复盘时的额外成本。</p>
<p>第一节继续解释每周归档和定期清理的重要性，让长期积累的笔记始终保持清晰、可访问和便于更新。</p>
<h2>安排周期性复盘</h2>
<p>第二节特有文本说明复盘时应记录理解变化、遗漏问题和下一步行动，从而让原始资料逐渐转化为可复用的知识结构。</p>
<p>第二节继续补充如何结合错题、项目记录和阅读摘要发现知识缺口，并在后续计划中优先处理。</p>
</article></body></html>
'''),
          200,
        );
      }),
    );

    final detail = await service.fetchArticleDetail(
      _item(link: 'https://sspai.com/post/100001', title: '如何整理长期学习笔记'),
    );

    expect(detail.content, contains('第二节特有文本'));
  });

  test('普通少数派长文不会截断阈值之后的正文', () async {
    final paragraphs = List.generate(
      24,
      (index) =>
          '<p>第${index + 1}段持续补充少数派长文的背景、方法、例子和结论，确保读者可以完整阅读每个章节中的上下文与具体细节。</p>',
    ).join();
    final service = NewsService(
      client: MockClient((_) async {
        return http.Response.bytes(
          utf8Bytes('<html><body><article>$paragraphs</article></body></html>'),
          200,
        );
      }),
    );

    final detail = await service.fetchArticleDetail(
      _item(link: 'https://sspai.com/post/100002', title: '完整的长篇教程'),
    );

    expect(detail.content, contains('第24段持续补充少数派长文'));
  });

  test('显式同域分页会合并续页并去除重复段落', () async {
    final requests = <Uri>[];
    final service = NewsService(
      client: MockClient((request) async {
        requests.add(request.url);
        if (request.url.queryParameters['page'] != '2') {
          return http.Response.bytes(
            utf8Bytes('''
<html><head><link rel="next" href="?page=2"></head><body>
<article><p>第一页第一段完整说明了这个主题的背景、目标和需要留意的现实条件，并进一步解释参与者应当如何根据实际情况安排资源、协调进度和持续复盘，避免在执行过程中遗漏关键限制。</p>
<p>跨页重复段落用于验证合并逻辑不会让相同内容在详情中出现两次，同时补充了阶段性检查、风险记录和沟通机制等必要背景说明。</p></article>
</body></html>
'''),
            200,
          );
        }
        return http.Response.bytes(
          utf8Bytes('''
<html><body><article>
<p>跨页重复段落用于验证合并逻辑不会让相同内容在详情中出现两次，同时补充了阶段性检查、风险记录和沟通机制等必要背景说明。</p>
<p>续页新增段落补充了实施过程中的关键步骤、时间安排和后续评估方式。</p>
</article></body></html>
'''),
          200,
        );
      }),
    );

    final detail = await service.fetchArticleDetail(
      _item(link: 'https://example.com/post/1'),
    );

    expect(detail.content, contains('第一页第一段'));
    expect(detail.content, contains('续页新增段落'));
    expect(RegExp('跨页重复段落用于验证合并逻辑').allMatches(detail.content).length, 1);
    expect(requests, [
      Uri.parse('https://example.com/post/1'),
      Uri.parse('https://example.com/post/1?page=2'),
    ]);
  });

  test('普通下一篇链接、非安全链接和失败续页不会影响首页正文', () async {
    final requests = <Uri>[];
    final service = NewsService(
      client: MockClient((request) async {
        requests.add(request.url);
        if (request.url.path == '/post/1') {
          return http.Response.bytes(
            utf8Bytes('''
<html><head><link rel="next" href="https://other.example.com/page/2"></head>
<body><article><p>首页正文包含足够长的说明内容，用于验证跨域分页链接会被安全策略拒绝而不发起请求。</p>
<p>首页第二段继续解释当前页面应当保持可读，即便页面上还存在普通的下一篇文章链接。</p></article>
<a href="https://example.com/post/next">下一篇文章</a></body></html>
'''),
            200,
          );
        }
        throw StateError('不应请求后续链接');
      }),
    );

    final detail = await service.fetchArticleDetail(
      _item(link: 'https://example.com/post/1'),
    );

    expect(detail.content, contains('首页正文包含足够长'));
    expect(requests, [Uri.parse('https://example.com/post/1')]);
  });

  test('分页续页失败时保留首页正文', () async {
    final service = NewsService(
      client: MockClient((request) async {
        if (request.url.queryParameters['page'] == '2') {
          return http.Response('服务异常', 500);
        }
        return http.Response.bytes(
          utf8Bytes('''
<html><head><link rel="next" href="?page=2"></head><body><article>
<p>首页正文在续页服务异常时仍然必须保留，不能退回不完整的 RSS 摘要，并且需要让读者看到完整的背景说明、问题范围和处理原则，避免因为后续页面故障丢失已经成功提取的有效信息。</p>
<p>首页第二段提供额外信息，确保正文长度满足详情抽取的最小要求，同时说明失败续页不应改变已经得到的首页阅读体验。</p>
</article></body></html>
'''),
          200,
        );
      }),
    );

    final detail = await service.fetchArticleDetail(
      _item(link: 'https://example.com/post/1'),
    );

    expect(detail.content, contains('首页正文在续页服务异常时仍然必须保留'));
  });

  test('分页会拒绝 HTTP、用户信息、循环链接并限制总页数', () async {
    final requests = <Uri>[];
    final service = NewsService(
      client: MockClient((request) async {
        requests.add(request.url);
        final page = request.url.queryParameters['page'];
        final pageNumber = int.tryParse(page ?? '1') ?? 1;
        final next = pageNumber < 13 ? '?page=${pageNumber + 1}' : '?page=1';
        return http.Response.bytes(
          utf8Bytes('''
<html><head><link rel="next" href="$next"></head><body><article>
<p>第${page ?? '一'}页的正文内容足够长，用于验证循环保护和总页数限制会阻止无限抓取，同时保留此前已经获得的有效段落。</p>
<p>这段说明补充了当前页面的背景、处理边界和预期结果，确保它能通过详情正文的最小长度校验。</p>
</article></body></html>
'''),
          200,
        );
      }),
    );

    final detail = await service.fetchArticleDetail(
      _item(link: 'https://example.com/post/1'),
    );

    expect(detail.content, contains('第一页的正文内容'));
    expect(detail.content, contains('第2页的正文内容'));
    expect(detail.content, contains('第12页的正文内容'));
    expect(detail.content, isNot(contains('第13页的正文内容')));
    expect(requests, hasLength(12));
  });

  test('初始 HTTP 原文仍可提取，但不会跟随 HTTP 续页', () async {
    final requests = <Uri>[];
    final service = NewsService(
      client: MockClient((request) async {
        requests.add(request.url);
        return http.Response.bytes(
          utf8Bytes('''
<html><head><link rel="next" href="?page=2"></head><body><article>
<p>HTTP 原文首屏仍应按原有行为提取可读正文，但自动续页必须坚持 HTTPS 限制，不能扩大网络请求的安全边界。</p>
<p>第二段补充了当前信息的背景、范围和阅读价值，确保页面内容满足详情正文的最小长度要求。</p>
</article></body></html>
'''),
          200,
        );
      }),
    );

    final detail = await service.fetchArticleDetail(
      _item(link: 'http://example.com/post/1'),
    );

    expect(detail.content, contains('HTTP 原文首屏仍应按原有行为提取'));
    expect(requests, [Uri.parse('http://example.com/post/1')]);
  });

  test('分页会拒绝 HTTP 和带用户信息的续页地址', () async {
    final requests = <Uri>[];
    final service = NewsService(
      client: MockClient((request) async {
        requests.add(request.url);
        return http.Response.bytes(
          utf8Bytes('''
<html><head><link rel="next" href="http://example.com/post/2"></head><body><article>
<p>正文内容足够长，用于验证 HTTP 续页地址不会绕过 HTTPS 限制并触发额外请求，同时不会影响当前页面已经成功获得的可读正文。</p>
<p>第二段继续说明安全校验应当拒绝包含降级协议或用户信息的分页地址。</p>
</article></body></html>
'''),
          200,
        );
      }),
    );

    final httpDetail = await service.fetchArticleDetail(
      _item(link: 'https://example.com/post/1'),
    );
    expect(httpDetail.content, contains('正文内容足够长'));
    expect(requests, hasLength(1));

    final userInfoService = NewsService(
      client: MockClient((_) async {
        return http.Response.bytes(
          utf8Bytes('''
<html><head><link rel="next" href="https://attacker@example.com/post/2"></head><body><article>
<p>正文内容足够长，用于验证带用户信息的续页地址会被拒绝而不影响首屏正文，并说明请求地址必须保持同一主机、HTTPS 协议和空用户信息，才能被视作可信的文章分页。</p>
<p>第二段继续提供足够的上下文和细节，确保当前详情仍按正常路径展示已提取的有效正文内容。</p>
</article></body></html>
'''),
          200,
        );
      }),
    );
    final userInfoDetail = await userInfoService.fetchArticleDetail(
      _item(link: 'https://example.com/post/1'),
    );
    expect(userInfoDetail.content, contains('带用户信息的续页地址'));
  });
}

List<int> utf8Bytes(String value) => const Utf8Encoder().convert(value);
