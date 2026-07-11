import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_sense/models/news_item.dart';
import 'package:life_sense/services/news_service.dart';

NewsItem _item({String summary = 'RSS 提供的干净摘要。'}) {
  return NewsItem(
    title: '测试文章',
    summary: summary,
    link: 'https://example.com/post/1',
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
}

List<int> utf8Bytes(String value) => const Utf8Encoder().convert(value);
