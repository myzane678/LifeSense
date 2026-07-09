import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/life_entry.dart';
import '../state/life_entry_provider.dart';
import '../widgets/metric_tile.dart';
import '../widgets/score_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LifeEntryProvider>();
    final entry = provider.todayEntry;
    final now = DateTime.now();
    final days = ['一', '二', '三', '四', '五', '六', '日'];
    final greeting = _greeting(now.hour);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greeting, style: Theme.of(context).textTheme.titleMedium),
            Text(
              '${DateFormat('M月d日').format(now)} · 周${days[now.weekday - 1]}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                // 同步状态（紧凑）
                _SyncStatusBar(status: provider.syncStatus),
                const SizedBox(height: 12),

                // 每日速览入口（顶部显眼位置）
                _DigestBanner(),
                const SizedBox(height: 16),

                // 今日状态区
                if (entry == null) ...[
                  _EmptyState(),
                ] else ...[
                  ScoreCard(score: entry.score, status: entry.status),
                  const SizedBox(height: 10),
                  _SuggestionCard(suggestion: entry.suggestion),
                  const SizedBox(height: 10),
                  _MetricsGrid(entry: entry),
                ],
                const SizedBox(height: 16),

                // 7天趋势
                _SevenDayTrendCard(
                  entries: provider.recentSevenDayEntries,
                  consecutiveDays: provider.consecutiveRecordDays,
                ),
                const SizedBox(height: 20),

                // 快捷操作行
                _QuickActions(),
              ],
            ),
      // 悬浮记录按钮
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/check-in'),
        icon: const Icon(Icons.add),
        label: Text(entry == null ? '立即记录' : '再次记录'),
      ),
    );
  }

  String _greeting(int hour) {
    if (hour < 6) return '夜深了，注意休息';
    if (hour < 11) return '早上好';
    if (hour < 13) return '上午好';
    if (hour < 18) return '下午好';
    if (hour < 22) return '晚上好';
    return '夜深了，注意休息';
  }
}

class _SyncStatusBar extends StatelessWidget {
  const _SyncStatusBar({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, text, color) = switch (status) {
      SyncStatus.synced => (Icons.cloud_done_outlined, '已同步到云端', cs.primary),
      SyncStatus.localCache => (
          Icons.phone_android_outlined,
          '当前显示本机缓存',
          cs.tertiary
        ),
      SyncStatus.syncing => (Icons.sync_outlined, '正在同步', cs.secondary),
      SyncStatus.localOnly => (
          Icons.person_outline,
          '访客模式 · 数据仅存本机',
          cs.secondary
        ),
    };
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _DigestBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.pushNamed(context, '/digest'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.newspaper_outlined,
                    size: 20, color: cs.onPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '每日速览',
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '科技要闻 · 专业动态 · 生活建议',
                      style: TextStyle(
                        color: cs.onPrimaryContainer.withAlpha(160),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        child: Column(
          children: [
            Icon(Icons.self_improvement_outlined, size: 48, color: cs.primary),
            const SizedBox(height: 12),
            Text('今天还没有记录', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '花一分钟记录当前状态，了解自己的生活得分',
              style: TextStyle(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion});

  final String suggestion;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: cs.secondary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                suggestion,
                style: TextStyle(
                    color: cs.onSecondaryContainer, height: 1.5, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.entry});

  final LifeEntry entry;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1,
      children: [
        MetricTile(label: '心情', value: '${entry.mood}/5', icon: Icons.mood),
        MetricTile(label: '精力', value: '${entry.energy}/5', icon: Icons.bolt),
        MetricTile(
            label: '压力',
            value: '${entry.stress}/5',
            icon: Icons.psychology_outlined),
        MetricTile(
            label: '专注',
            value: '${entry.focus}/5',
            icon: Icons.center_focus_strong_outlined),
        MetricTile(
            label: '睡眠',
            value: '${entry.sleepHours}h',
            icon: Icons.bedtime_outlined),
        MetricTile(
            label: '饮水',
            value: '${entry.waterCups}杯',
            icon: Icons.water_drop_outlined),
      ],
    );
  }
}

class _SevenDayTrendCard extends StatelessWidget {
  const _SevenDayTrendCard(
      {required this.entries, required this.consecutiveDays});

  final List<LifeEntry?> entries;
  final int consecutiveDays;

  @override
  Widget build(BuildContext context) {
    final recorded = entries.nonNulls.toList();
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('最近 7 天',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (consecutiveDays > 0) _StreakChip(days: consecutiveDays),
              ],
            ),
            const SizedBox(height: 12),
            if (recorded.isEmpty)
              Text('最近 7 天暂无记录',
                  style: TextStyle(color: cs.onSurfaceVariant))
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TrendStat(
                      label: '平均分',
                      value: _averageScore(recorded).toString()),
                  _TrendStat(
                      label: '记录天数', value: '${recorded.length} 天'),
                  _TrendStat(
                      label: '最高分',
                      value: _highestScore(recorded).toString()),
                ],
              ),
              const SizedBox(height: 18),
              _TrendBars(entries: entries),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendBars extends StatelessWidget {
  const _TrendBars({required this.entries});

  final List<LifeEntry?> entries;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final item in entries) Expanded(child: _TrendBar(entry: item)),
        ],
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({required this.entry});

  final LifeEntry? entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final score = entry?.score;
    final height = score == null ? 8.0 : 18.0 + score * 0.54;

    Color barColor;
    if (score == null) {
      barColor = cs.surfaceContainerHighest;
    } else if (score >= 80) {
      barColor = cs.primary;
    } else if (score >= 60) {
      barColor = cs.tertiary;
    } else {
      barColor = cs.error;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: entry == null
            ? null
            : () =>
                Navigator.pushNamed(context, '/detail', arguments: entry),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(score?.toString() ?? '-',
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                height: height,
                width: 18,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                entry == null
                    ? '-'
                    : DateFormat('M/d').format(entry!.createdAt),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 16, color: cs.primary),
          const SizedBox(width: 4),
          Text(
            '连续 $days 天',
            style: TextStyle(
                color: cs.onPrimaryContainer, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TrendStat extends StatelessWidget {
  const _TrendStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.history_outlined,
            label: '历史记录',
            onTap: () => Navigator.pushNamed(context, '/history'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.bar_chart_outlined,
            label: '查看周报',
            onTap: () => Navigator.pushNamed(context, '/weekly-report'),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(fontSize: 13, color: cs.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

int _averageScore(List<LifeEntry> entries) {
  final total = entries.fold<int>(0, (sum, e) => sum + e.score);
  return (total / entries.length).round();
}

int _highestScore(List<LifeEntry> entries) {
  return entries.map((e) => e.score).reduce((a, b) => a > b ? a : b);
}
