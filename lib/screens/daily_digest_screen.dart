import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/news_item.dart';
import '../services/news_service.dart';
import '../state/life_entry_provider.dart';

class DailyDigestScreen extends StatefulWidget {
  const DailyDigestScreen({super.key});

  @override
  State<DailyDigestScreen> createState() => _DailyDigestScreenState();
}

class _DailyDigestScreenState extends State<DailyDigestScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _newsService = NewsService();

  // 各 tab 的加载状态和数据
  final _data = <String, List<NewsItem>>{};
  final _loading = <String, bool>{};
  final _error = <String, bool>{};

  static const _tabs = [
    (key: 'tech', label: '科技要闻'),
    (key: 'ai', label: '专业动态'),
    (key: 'tips', label: '学习工具箱'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadTab(_tabs[_tabController.index].key);
      }
    });
    _loadTab('tech');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTab(String key) async {
    if (key == 'tips') return; // 生活建议本地生成，无需加载
    if (_loading[key] == true) return;
    if (_data[key] != null) return;

    setState(() => _loading[key] = true);
    try {
      final items = await _newsService.fetchFeed(key == 'tech' ? 'tech' : 'ai');
      if (mounted) {
        setState(() {
          _data[key] = items;
          _loading[key] = false;
          _error[key] = items.isEmpty;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading[key] = false; _error[key] = true; });
    }
  }

  Future<void> _refresh(String key) async {
    _data.remove(key);
    await _loadTab(key);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = ['一', '二', '三', '四', '五', '六', '日'];
    final weekday = days[now.weekday - 1];
    final today = '${DateFormat('M月d日').format(now)} · 周$weekday';
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('每日速览'),
            Text(today, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [for (final t in _tabs) Tab(text: t.label)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final t in _tabs)
            t.key == 'tips'
                ? _TipsTab()
                : _NewsTab(
                    items: _data[t.key],
                    isLoading: _loading[t.key] == true,
                    hasError: _error[t.key] == true,
                    onRefresh: () => _refresh(t.key),
                  ),
        ],
      ),
    );
  }
}

class _NewsTab extends StatelessWidget {
  const _NewsTab({
    required this.items,
    required this.isLoading,
    required this.hasError,
    required this.onRefresh,
  });

  final List<NewsItem>? items;
  final bool isLoading;
  final bool hasError;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (hasError || items == null || items!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_outlined,
                size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text('暂时无法获取内容'),
            const SizedBox(height: 8),
            TextButton(onPressed: onRefresh, child: const Text('重试')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items!.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _NewsCard(item: items![index]),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () async {
          final uri = Uri.tryParse(item.link);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (item.summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.summary,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.circle, size: 6, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    item.source,
                    style: TextStyle(fontSize: 11, color: cs.primary),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('HH:mm').format(item.publishedAt),
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.open_in_new, size: 12, color: cs.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipsTab extends StatelessWidget {
  // 备注关键词分类
  static const _stressWords = ['压力', '焦虑', '紧张', '烦', '累', '崩', '难受', '难', '卷'];
  static const _sleepWords = ['失眠', '没睡', '睡晚', '睡少', '熬夜', '困', '疲惫'];
  static const _studyWords = ['考试', '课设', '作业', '实验', '复习', '备考', '项目', '论文', '答辩'];
  static const _goodWords = ['开心', '顺利', '完成', '不错', '好', '棒', '休息', '放松'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LifeEntryProvider>();
    final recentEntries = provider.entries
        .where((e) {
          final diff = DateTime.now().difference(e.createdAt).inDays;
          return diff <= 7;
        })
        .toList();

    final notes = recentEntries
        .map((e) => e.note)
        .where((n) => n.isNotEmpty)
        .toList();

    final analysis = _analyzeNotes(notes, recentEntries);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 备注分析卡
        if (analysis != null) ...[
          _NoteAnalysisCard(analysis: analysis),
          const SizedBox(height: 16),
        ],
        // 工具箱标题
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            '学习工具',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        for (final tip in _tools) ...[
          _TipCard(tip: tip),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  _NoteAnalysis? _analyzeNotes(List<String> notes, List<dynamic> entries) {
    if (notes.isEmpty) return null;

    final combined = notes.join(' ');
    int stressHits = 0, sleepHits = 0, studyHits = 0, goodHits = 0;

    for (final w in _stressWords) {
      if (combined.contains(w)) stressHits++;
    }
    for (final w in _sleepWords) {
      if (combined.contains(w)) sleepHits++;
    }
    for (final w in _studyWords) {
      if (combined.contains(w)) studyHits++;
    }
    for (final w in _goodWords) {
      if (combined.contains(w)) goodHits++;
    }

    // 找出备注中提及最多的主题
    String mainTheme;
    String insight;
    if (stressHits >= 2) {
      mainTheme = '压力偏高';
      insight = '过去 7 天备注中多次提到压力相关内容。'
          '建议每天预留 10 分钟用于放松（呼吸法/散步），'
          '并把大任务拆分成每日可完成的小步骤，减少"任务山"带来的焦虑感。';
    } else if (sleepHits >= 2) {
      mainTheme = '睡眠欠佳';
      insight = '最近备注显示睡眠不规律。'
          '建议固定起床时间（即使周末），睡前 1 小时停止使用手机，'
          '这比强迫自己早睡更有效，身体会自然调整入睡时间。';
    } else if (studyHits >= 2) {
      mainTheme = '学习任务密集';
      insight = '最近有较多学习/考试相关记录。'
          '建议用艾宾浩斯曲线安排复习计划，'
          '优先复习 1 天和 3 天前的内容，避免临时抱佛脚。'
          '每个番茄钟后做 5 分钟的空白休息（不刷手机）效果更好。';
    } else if (goodHits >= 3) {
      mainTheme = '状态积极';
      insight = '最近备注整体偏正向，状态不错。'
          '趁状态好推进最重要的长期任务，'
          '同时记录下今天哪些习惯让你感觉良好，方便之后复现这种状态。';
    } else if (notes.length >= 3) {
      mainTheme = '持续记录';
      insight = '已连续记录备注 ${notes.length} 条，坚持得很好。'
          '建议每周回顾一次，找出让自己状态好和状态差的共同因素，'
          '针对性调整日常习惯。';
    } else {
      return null;
    }

    return _NoteAnalysis(theme: mainTheme, insight: insight, noteCount: notes.length);
  }

  static const _tools = [
    _Tip(
      icon: Icons.timer_outlined,
      category: '专注',
      title: '番茄工作法',
      body: '25 分钟专注 + 5 分钟休息 = 1 个番茄。\n'
          '每完成 4 个番茄钟休息 15-30 分钟。\n'
          '每天 4-6 个番茄钟比"连续死磕"效率高约 30%。',
    ),
    _Tip(
      icon: Icons.psychology_outlined,
      category: '记忆',
      title: '间隔重复复习法',
      body: '新知识在 1天 → 3天 → 7天 → 21天后各复习一次。\n'
          '特别适合电路原理、控制理论、信号处理等公式推导内容。\n'
          '推荐工具：Anki 或手写索引卡片。',
    ),
    _Tip(
      icon: Icons.self_improvement_outlined,
      category: '减压',
      title: '4-7-8 呼吸法',
      body: '吸气 4 秒 → 屏息 7 秒 → 呼气 8 秒，循环 4 次。\n'
          '激活副交感神经系统，5 分钟内有效降低焦虑感。\n'
          '考前/提交作业前均可用。',
    ),
    _Tip(
      icon: Icons.directions_walk_outlined,
      category: '专注恢复',
      title: '20-20-20 护眼法',
      body: '每用眼 20 分钟，看 6 米外物体 20 秒。\n'
          '同时起身活动 1 分钟，防止久坐导致的专注力下滑。\n'
          '编程/画图时尤其适用。',
    ),
    _Tip(
      icon: Icons.water_drop_outlined,
      category: '身体',
      title: '每小时喝水',
      body: '轻度脱水（-1.5% 体重水分）使注意力下降 13%。\n'
          '目标：每天 8 杯（约 2000ml）。\n'
          '设手机提醒，每小时喝一杯，效果比渴了再喝好得多。',
    ),
    _Tip(
      icon: Icons.bedtime_outlined,
      category: '睡眠',
      title: '睡眠优化三件事',
      body: '① 固定起床时间（比固定睡眠时间更重要）\n'
          '② 睡前 1 小时停止使用发光屏幕\n'
          '③ 睡前写下明日 3 件最重要的事，清空"待机焦虑"',
    ),
  ];
}

class _NoteAnalysis {
  const _NoteAnalysis({
    required this.theme,
    required this.insight,
    required this.noteCount,
  });

  final String theme;
  final String insight;
  final int noteCount;
}

class _NoteAnalysisCard extends StatelessWidget {
  const _NoteAnalysisCard({required this.analysis});

  final _NoteAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_outlined, color: cs.tertiary, size: 18),
                const SizedBox(width: 8),
                Text(
                  '近 7 天备注分析 · ${analysis.theme}',
                  style: TextStyle(
                    color: cs.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              analysis.insight,
              style: TextStyle(
                color: cs.onTertiaryContainer,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '基于最近 ${analysis.noteCount} 条备注',
              style: TextStyle(
                color: cs.onTertiaryContainer.withAlpha(150),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tip {
  const _Tip({
    required this.icon,
    required this.category,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String category;
  final String title;
  final String body;
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip});

  final _Tip tip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(tip.icon, size: 20, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tip.category,
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSecondaryContainer,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tip.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tip.body,
                    style:
                        TextStyle(color: cs.onSurfaceVariant, fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


