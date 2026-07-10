import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/news_item.dart';
import '../services/digest_preferences_service.dart';
import '../services/news_service.dart';
import '../state/life_entry_provider.dart';

class DailyDigestScreen extends StatefulWidget {
  const DailyDigestScreen({super.key});

  @override
  State<DailyDigestScreen> createState() => _DailyDigestScreenState();
}

class _DailyDigestScreenState extends State<DailyDigestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _newsService = NewsService();
  List<_DigestTab> _tabs = const [];

  // 各 tab 的加载状态和数据
  final _data = <String, List<NewsItem>>{};
  final _loading = <String, bool>{};
  final _networkError = <String, bool>{};
  bool _isPreparingTabs = true;

  @override
  void initState() {
    super.initState();
    _tabs = _buildTabs(DigestPreferencesService.defaultSelectedIds);
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _loadInitialTabs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final preferences = context.watch<DigestPreferencesService>();
    if (!preferences.isInitialized) return;
    final nextTabs = _buildTabs(preferences.selectedIds);
    if (_sameTabs(_tabs, nextTabs)) return;
    final oldIndex = _tabController.index;
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _tabs = nextTabs;
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: oldIndex.clamp(0, _tabs.length - 1),
    );
    _tabController.addListener(_handleTabChanged);
    _loadInitialTabs();
  }

  void _handleTabChanged() {
    if (!_tabController.indexIsChanging) {
      _loadTab(_tabs[_tabController.index]);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialTabs() async {
    final newsTabs = _tabs.where((tab) => !tab.isLocal).toList();
    setState(() => _isPreparingTabs = true);
    // 只等第一个 Tab 加载完即显示，其余后台静默加载
    if (newsTabs.isNotEmpty) await _loadTab(newsTabs.first);
    if (!mounted) return;
    setState(() => _isPreparingTabs = false);
    if (newsTabs.length > 1) {
      await Future.wait(newsTabs.skip(1).map(_loadTab));
      if (!mounted) return;
    }
    _hideEmptyNewsTabs();
  }

  void _hideEmptyNewsTabs() {
    final visibleTabs = [
      for (final tab in _tabs)
        if (tab.isLocal ||
            _networkError[tab.id] == true ||
            (_data[tab.id]?.isNotEmpty ?? false))
          tab,
    ];
    if (visibleTabs.isEmpty || _sameTabs(_tabs, visibleTabs)) return;

    final oldIndex = _tabController.index;
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _tabs = visibleTabs;
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: oldIndex.clamp(0, _tabs.length - 1),
    );
    _tabController.addListener(_handleTabChanged);
    setState(() {});
  }

  Future<void> _loadTab(_DigestTab tab) async {
    if (tab.isLocal) return;
    if (_loading[tab.id] == true) return;
    if (_data[tab.id] != null) return;

    setState(() => _loading[tab.id] = true);
    try {
      final result = await _newsService.fetchFeedResult(tab.feedKey);
      if (mounted) {
        setState(() {
          _data[tab.id] = result.items;
          _loading[tab.id] = false;
          _networkError[tab.id] = result.networkError;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading[tab.id] = false;
          _networkError[tab.id] = true;
        });
      }
    }
  }

  Future<void> _refresh(_DigestTab tab) async {
    _data.remove(tab.id);
    await _loadTab(tab);
  }

  List<String> _hiddenEmptyLabels() {
    final preferences = context.watch<DigestPreferencesService>();
    if (!preferences.isInitialized) return const [];
    final visibleIds = _tabs.map((tab) => tab.id).toSet();
    return [
      for (final interest in preferences.selectedInterests)
        if (!visibleIds.contains(interest.id) &&
            _networkError[interest.id] != true &&
            (_data[interest.id]?.isEmpty ?? false))
          interest.label,
    ];
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
        bottom: _isPreparingTabs
            ? null
            : TabBar(
                controller: _tabController,
                tabs: [for (final t in _tabs) Tab(text: t.label)],
              ),
      ),
      body: _isPreparingTabs
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          for (final t in _tabs)
            t.isLocal
                ? _TipsTab(hiddenLabels: _hiddenEmptyLabels())
                : _NewsTab(
                    label: t.label,
                    items: _data[t.id],
                    isLoading: _loading[t.id] == true,
                    hasNetworkError: _networkError[t.id] == true,
                    onRefresh: () => _refresh(t),
                  ),
        ],
      ),
    );
  }
}

class _DigestTab {
  const _DigestTab({
    required this.id,
    required this.label,
    required this.feedKey,
    this.isLocal = false,
  });

  final String id;
  final String label;
  final String feedKey;
  final bool isLocal;
}

List<_DigestTab> _buildTabs(List<String> selectedIds) {
  return [
    for (final id in selectedIds)
      if (DigestPreferencesService.interestById(id) case final interest?)
        _DigestTab(
          id: interest.id,
          label: interest.label,
          feedKey: interest.feedKey,
          isLocal: interest.feedKey == 'tips',
        ),
    const _DigestTab(
      id: 'toolbox',
      label: '学习工具箱',
      feedKey: 'tips',
      isLocal: true,
    ),
  ];
}

bool _sameTabs(List<_DigestTab> a, List<_DigestTab> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id) return false;
  }
  return true;
}

class _NewsTab extends StatelessWidget {
  const _NewsTab({
    required this.label,
    required this.items,
    required this.isLoading,
    required this.hasNetworkError,
    required this.onRefresh,
  });

  final String label;
  final List<NewsItem>? items;
  final bool isLoading;
  final bool hasNetworkError;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (hasNetworkError) {
      return _NewsEmptyState(
        icon: Icons.wifi_off_outlined,
        title: '网络连接失败',
        subtitle: '请检查网络后稍后再试',
        actionText: '重试',
        onRefresh: onRefresh,
      );
    }
    if (items == null || items!.isEmpty) {
      return _NewsEmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: '今天暂无符合“$label”的内容',
        subtitle: '已过滤掉不属于该分类的新闻',
        actionText: '刷新看看',
        onRefresh: onRefresh,
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

class _NewsEmptyState extends StatelessWidget {
  const _NewsEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionText,
    required this.onRefresh,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionText;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onRefresh, child: Text(actionText)),
          ],
        ),
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
        onTap: () => _showNewsDetail(context, item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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
                    _formatPublishTime(item.publishedAt),
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

class _NewsDetailSheet extends StatefulWidget {
  const _NewsDetailSheet({required this.item});

  final NewsItem item;

  @override
  State<_NewsDetailSheet> createState() => _NewsDetailSheetState();
}

class _NewsDetailSheetState extends State<_NewsDetailSheet> {
  late final Future<String> _summaryFuture = NewsService().fetchArticleSummary(
    widget.item,
  );

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            item.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          FutureBuilder<String>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              final summary = snapshot.data?.trim();
              if (snapshot.connectionState != ConnectionState.done) {
                return Text(
                  '正在整理简要内容…',
                  style: TextStyle(color: cs.onSurfaceVariant),
                );
              }
              if (summary == null || summary.isEmpty) {
                return Text(
                  '该来源暂未提供可概括内容。',
                  style: TextStyle(color: cs.onSurfaceVariant),
                );
              }
              return Text(
                summary,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.55),
              );
            },
          ),
          const SizedBox(height: 18),
          _NewsMetaRow(label: '来源', value: item.source),
          const SizedBox(height: 8),
          _NewsMetaRow(
            label: '发布时间',
            value: DateFormat('M月d日 HH:mm').format(item.publishedAt),
          ),
          const SizedBox(height: 14),
          Text('原文链接', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          SelectableText(
            item.link,
            style: TextStyle(color: cs.primary, fontSize: 13),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => _openNewsLink(context, item.link),
            icon: const Icon(Icons.open_in_new),
            label: const Text('打开原网页'),
          ),
        ],
      ),
    );
  }
}

void _showNewsDetail(BuildContext context, NewsItem item) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _NewsDetailSheet(item: item),
  );
}

String _formatPublishTime(DateTime t) {
  // 时间为 00:00 说明来源 RSS 只含日期，只显示日期避免误导
  if (t.hour == 0 && t.minute == 0) {
    return DateFormat('M/d').format(t);
  }
  return '发布 ${DateFormat('HH:mm').format(t)}';
}

Future<void> _openNewsLink(BuildContext context, String link) async {
  final uri = Uri.tryParse(link);
  if (uri == null || !uri.hasScheme) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('无法打开链接，请稍后再试')));
    return;
  }
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('无法打开链接，请稍后再试')));
  }
}

class _NewsMetaRow extends StatelessWidget {
  const _NewsMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}

class _TipsTab extends StatelessWidget {
  const _TipsTab({required this.hiddenLabels});

  final List<String> hiddenLabels;

  // 备注关键词分类
  static const _stressWords = ['压力', '焦虑', '紧张', '烦', '累', '崩', '难受', '难', '卷'];
  static const _sleepWords = ['失眠', '没睡', '睡晚', '睡少', '熬夜', '困', '疲惫'];
  static const _studyWords = [
    '考试',
    '课设',
    '作业',
    '实验',
    '复习',
    '备考',
    '项目',
    '论文',
    '答辩',
  ];
  static const _goodWords = ['开心', '顺利', '完成', '不错', '好', '棒', '休息', '放松'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LifeEntryProvider>();
    final recentEntries = provider.entries.where((e) {
      final diff = DateTime.now().difference(e.createdAt).inDays;
      return diff <= 7;
    }).toList();

    final notes = recentEntries
        .map((e) => e.note)
        .where((n) => n.isNotEmpty)
        .toList();

    final analysis = _analyzeNotes(notes, recentEntries);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (hiddenLabels.isNotEmpty) ...[
          _HiddenDigestNotice(labels: hiddenLabels),
          const SizedBox(height: 16),
        ],
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
      insight =
          '过去 7 天备注中多次提到压力相关内容。'
          '建议每天预留 10 分钟用于放松（呼吸法/散步），'
          '并把大任务拆分成每日可完成的小步骤，减少"任务山"带来的焦虑感。';
    } else if (sleepHits >= 2) {
      mainTheme = '睡眠欠佳';
      insight =
          '最近备注显示睡眠不规律。'
          '建议固定起床时间（即使周末），睡前 1 小时停止使用手机，'
          '这比强迫自己早睡更有效，身体会自然调整入睡时间。';
    } else if (studyHits >= 2) {
      mainTheme = '学习任务密集';
      insight =
          '最近有较多学习/考试相关记录。'
          '建议用艾宾浩斯曲线安排复习计划，'
          '优先复习 1 天和 3 天前的内容，避免临时抱佛脚。'
          '每个番茄钟后做 5 分钟的空白休息（不刷手机）效果更好。';
    } else if (goodHits >= 3) {
      mainTheme = '状态积极';
      insight =
          '最近备注整体偏正向，状态不错。'
          '趁状态好推进最重要的长期任务，'
          '同时记录下今天哪些习惯让你感觉良好，方便之后复现这种状态。';
    } else if (notes.length >= 3) {
      mainTheme = '持续记录';
      insight =
          '已连续记录备注 ${notes.length} 条，坚持得很好。'
          '建议每周回顾一次，找出让自己状态好和状态差的共同因素，'
          '针对性调整日常习惯。';
    } else {
      return null;
    }

    return _NoteAnalysis(
      theme: mainTheme,
      insight: insight,
      noteCount: notes.length,
    );
  }

  static const _tools = [
    _Tip(
      icon: Icons.timer_outlined,
      category: '专注',
      title: '番茄工作法',
      body:
          '25 分钟专注 + 5 分钟休息 = 1 个番茄。\n'
          '每完成 4 个番茄钟休息 15-30 分钟。\n'
          '每天 4-6 个番茄钟比"连续死磕"效率高约 30%。',
    ),
    _Tip(
      icon: Icons.psychology_outlined,
      category: '记忆',
      title: '间隔重复复习法',
      body:
          '新知识在 1天 → 3天 → 7天 → 21天后各复习一次。\n'
          '特别适合电路原理、控制理论、信号处理等公式推导内容。\n'
          '推荐工具：Anki 或手写索引卡片。',
    ),
    _Tip(
      icon: Icons.self_improvement_outlined,
      category: '减压',
      title: '4-7-8 呼吸法',
      body:
          '吸气 4 秒 → 屏息 7 秒 → 呼气 8 秒，循环 4 次。\n'
          '激活副交感神经系统，5 分钟内有效降低焦虑感。\n'
          '考前/提交作业前均可用。',
    ),
    _Tip(
      icon: Icons.directions_walk_outlined,
      category: '专注恢复',
      title: '20-20-20 护眼法',
      body:
          '每用眼 20 分钟，看 6 米外物体 20 秒。\n'
          '同时起身活动 1 分钟，防止久坐导致的专注力下滑。\n'
          '编程/画图时尤其适用。',
    ),
    _Tip(
      icon: Icons.water_drop_outlined,
      category: '身体',
      title: '每小时喝水',
      body:
          '轻度脱水（-1.5% 体重水分）使注意力下降 13%。\n'
          '目标：每天 8 杯（约 2000ml）。\n'
          '设手机提醒，每小时喝一杯，效果比渴了再喝好得多。',
    ),
    _Tip(
      icon: Icons.bedtime_outlined,
      category: '睡眠',
      title: '睡眠优化三件事',
      body:
          '① 固定起床时间（比固定睡眠时间更重要）\n'
          '② 睡前 1 小时停止使用发光屏幕\n'
          '③ 睡前写下明日 3 件最重要的事，清空"待机焦虑"',
    ),
  ];
}

class _HiddenDigestNotice extends StatelessWidget {
  const _HiddenDigestNotice({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withAlpha(120)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.filter_alt_off_outlined,
            size: 18,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${labels.join('、')} 今日暂无匹配内容',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
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
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tip.category,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tip.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tip.body,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.5,
                    ),
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
