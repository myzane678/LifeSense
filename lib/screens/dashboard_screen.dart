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
    return Scaffold(
      appBar: AppBar(
        title: const Text('LifeSense'),
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
              padding: const EdgeInsets.all(20),
              children: [
                _SyncStatusCard(status: provider.syncStatus),
                const SizedBox(height: 12),
                if (entry == null) ...[
                  _EmptyState(),
                ] else ...[
                  ScoreCard(score: entry.score, status: entry.status),
                  const SizedBox(height: 12),
                  _SuggestionCard(suggestion: entry.suggestion),
                  const SizedBox(height: 12),
                  _MetricsGrid(entry: entry),
                ],
                const SizedBox(height: 24),
                _SevenDayTrendCard(
                  entries: provider.recentSevenDayEntries,
                  consecutiveDays: provider.consecutiveRecordDays,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pushNamed(context, '/check-in'),
                  child: const Text('立即记录'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, '/history'),
                  child: const Text('查看历史'),
                ),
              ],
            ),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, text, color) = switch (status) {
      SyncStatus.synced => (
        Icons.cloud_done_outlined,
        '已同步到云端',
        colorScheme.primary,
      ),
      SyncStatus.localCache => (
        Icons.phone_android_outlined,
        '当前显示本机缓存',
        colorScheme.tertiary,
      ),
      SyncStatus.syncing => (
        Icons.sync_outlined,
        '正在同步',
        colorScheme.secondary,
      ),
      SyncStatus.localOnly => (
        Icons.person_outline,
        '访客模式 · 数据仅存本机',
        colorScheme.secondary,
      ),
    };

    return Card(
      elevation: 0,
      color: color.withAlpha(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.self_improvement_outlined,
              size: 48,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text('今天还没有记录', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '花一分钟记录当前状态，了解自己的生活得分',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: colorScheme.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                suggestion,
                style: TextStyle(color: colorScheme.onSecondaryContainer),
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
          icon: Icons.psychology_outlined,
        ),
        MetricTile(
          label: '专注',
          value: '${entry.focus}/5',
          icon: Icons.center_focus_strong_outlined,
        ),
        MetricTile(
          label: '睡眠',
          value: '${entry.sleepHours}h',
          icon: Icons.bedtime_outlined,
        ),
        MetricTile(
          label: '饮水',
          value: '${entry.waterCups}杯',
          icon: Icons.water_drop_outlined,
        ),
      ],
    );
  }
}

class _SevenDayTrendCard extends StatelessWidget {
  const _SevenDayTrendCard({
    required this.entries,
    required this.consecutiveDays,
  });

  final List<LifeEntry?> entries;
  final int consecutiveDays;

  @override
  Widget build(BuildContext context) {
    final recordedEntries = entries.nonNulls.toList();
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('最近 7 天', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (consecutiveDays > 0) _StreakChip(days: consecutiveDays),
              ],
            ),
            const SizedBox(height: 12),
            if (recordedEntries.isEmpty)
              Text(
                '最近 7 天暂无记录',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TrendStat(
                    label: '平均分',
                    value: _averageScore(recordedEntries).toString(),
                  ),
                  _TrendStat(
                    label: '记录天数',
                    value: '${recordedEntries.length} 天',
                  ),
                  _TrendStat(
                    label: '最高分',
                    value: _highestScore(recordedEntries).toString(),
                  ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final date = entry?.createdAt;
    final score = entry?.score;
    final height = score == null ? 8.0 : 18.0 + score * 0.54;

    // 根据分数段配色：>=80 primary，>=60 tertiary，其余 error
    Color barColor;
    if (score == null) {
      barColor = colorScheme.surfaceContainerHighest;
    } else if (score >= 80) {
      barColor = colorScheme.primary;
    } else if (score >= 60) {
      barColor = colorScheme.tertiary;
    } else {
      barColor = colorScheme.error;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: entry == null
            ? null
            : () => Navigator.pushNamed(context, '/detail', arguments: entry),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                score?.toString() ?? '-',
                style: Theme.of(context).textTheme.labelSmall,
              ),
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
                date == null ? '-' : DateFormat('M/d').format(date),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            '连续 $days 天',
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

int _averageScore(List<LifeEntry> entries) {
  final total = entries.fold<int>(0, (sum, entry) => sum + entry.score);
  return (total / entries.length).round();
}

int _highestScore(List<LifeEntry> entries) {
  return entries.map((entry) => entry.score).reduce((a, b) => a > b ? a : b);
}
