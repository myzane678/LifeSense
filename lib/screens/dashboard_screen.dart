import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/life_entry.dart';
import '../services/digest_preferences_service.dart';
import '../services/reminder_service.dart';
import '../services/weekly_goals_service.dart';
import '../state/life_entry_provider.dart';
import '../widgets/metric_tile.dart';
import '../widgets/digest_interest_dialog.dart';
import '../widgets/score_card.dart';
import '../widgets/weekly_goals_editor.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showFirstUsePrompts());
  }

  Future<void> _showFirstUsePrompts() async {
    final handledReminder = await _showReminderPrompt();
    if (handledReminder || !mounted) return;
    await _showDigestInterestPrompt();
  }

  Future<bool> _showReminderPrompt() async {
    if (!mounted) return false;
    final reminder = context.read<ReminderService>();
    if (!reminder.isInitialized || reminder.promptSeen) return false;

    final enable = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('开启每日提醒？'),
        content: Text(
          '每天 ${reminder.reminderTimeText} 提醒你记录今日状态，帮助保持连续追踪。之后可在设置中调整时间。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('暂不开启'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('开启提醒'),
          ),
        ],
      ),
    );
    if (!mounted || enable == null) return false;
    await reminder.markPromptSeen();
    if (!enable) return true;
    await _chooseTimeAndEnableReminder(reminder);
    return true;
  }

  Future<void> _showDigestInterestPrompt() async {
    if (!mounted) return;
    final preferences = context.read<DigestPreferencesService>();
    if (!preferences.isInitialized || preferences.promptSeen) return;

    final selected = await showDigestInterestDialog(
      context,
      initialIds: preferences.selectedIds,
      title: '选择你关心的内容',
      description: '每日速览会优先展示这些方向。先选 1-3 个，之后可在设置里修改。',
    );
    if (!mounted) return;
    await preferences.markPromptSeen();
    if (selected == null) return;
    await preferences.setSelectedIds(selected);
  }

  Future<void> _enableReminderFromStrip(ReminderService reminder) async {
    await _chooseTimeAndEnableReminder(reminder);
  }

  Future<void> _chooseTimeAndEnableReminder(ReminderService reminder) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: reminder.reminderTime,
    );
    if (picked == null || !mounted) return;
    await reminder.setReminderTime(picked);
    final granted = await reminder.enableDailyReminder();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(granted ? '每日提醒已开启' : '未获得通知权限，可稍后在设置中开启')),
    );
  }

  Future<void> _editWeeklyGoals() async {
    final nextGoals = await showWeeklyGoalsEditor(context);
    if (nextGoals == null || !mounted) return;
    final goalsService = context.read<WeeklyGoalsService>();
    final isGuest = context.read<LifeEntryProvider>().isGuestMode;
    try {
      await goalsService.setGoals(
        sleepHours: nextGoals.sleepHours,
        waterCups: nextGoals.waterCups,
        focus: nextGoals.focus,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isGuest ? '本周目标已保存到本机' : '本周目标已更新并同步到云端')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已保存到本机，云同步失败'),
          action: SnackBarAction(
            label: '重试',
            onPressed: () => goalsService.retryPendingSync(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LifeEntryProvider>();
    final weeklyGoals = context.watch<WeeklyGoalsService>();
    final reminder = context.watch<ReminderService>();
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
                _SyncStatusBar(provider: provider),
                const SizedBox(height: 8),
                _MotivationLine(),
                if (reminder.isInitialized && !reminder.enabled) ...[
                  const SizedBox(height: 10),
                  _ReminderPromptStrip(
                    onEnable: () => _enableReminderFromStrip(reminder),
                  ),
                ],
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
                const SizedBox(height: 10),
                _WeeklyGoalsCard(
                  goals: weeklyGoals.goals,
                  onTap: _editWeeklyGoals,
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

class _MotivationLine extends StatelessWidget {
  static const _quotes = [
    '行胜于言。——鲁迅',
    '生活明朗，万物可爱。——汪曾祺',
    '种一棵树最好的时间是十年前，其次是现在。',
    '凡是过往，皆为序章。——莎士比亚',
    '保持热爱，奔赴山海。',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final quote = _quotes[now.day % _quotes.length];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.auto_awesome_outlined, size: 15, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            quote,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReminderPromptStrip extends StatelessWidget {
  const _ReminderPromptStrip({required this.onEnable});

  final VoidCallback onEnable;

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
        children: [
          Icon(Icons.notifications_none_outlined, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '开启每日记录提醒，避免忘记打卡',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          TextButton(onPressed: onEnable, child: const Text('开启')),
        ],
      ),
    );
  }
}

class _SyncStatusBar extends StatelessWidget {
  const _SyncStatusBar({required this.provider});

  final LifeEntryProvider provider;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (provider.syncStatus == SyncStatus.synced) {
      return const SizedBox.shrink();
    }
    if (provider.syncStatus == SyncStatus.syncing) {
      return _statusRow(
        context,
        icon: Icons.sync_outlined,
        text: '正在同步',
        color: cs.secondary,
      );
    }
    if (provider.syncStatus == SyncStatus.localOnly) {
      return _statusRow(
        context,
        icon: Icons.person_outline,
        text: '访客模式 · 数据仅存本机',
        color: cs.secondary,
      );
    }
    return Row(
      children: [
        Icon(Icons.cloud_off_outlined, size: 14, color: cs.error),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '有 ${provider.pendingSyncCount} 项待同步',
            style: TextStyle(
              fontSize: 12,
              color: cs.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TextButton(
          onPressed: () => provider.retryPendingSync(),
          child: const Text('重试'),
        ),
      ],
    );
  }

  Widget _statusRow(
    BuildContext context, {
    required IconData icon,
    required String text,
    required Color color,
  }) => Row(
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class _DigestBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final digestPreferences = context.watch<DigestPreferencesService>();
    final digestSubtitle =
        digestPreferences.isInitialized &&
            digestPreferences.selectedInterests.isNotEmpty
        ? '${digestPreferences.selectedLabelText} · 学习工具箱'
        : '前沿内容 · 学习工具箱';
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
                child: Icon(
                  Icons.newspaper_outlined,
                  size: 20,
                  color: cs.onPrimary,
                ),
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
                      digestSubtitle,
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
                  color: cs.onSecondaryContainer,
                  height: 1.5,
                  fontSize: 13,
                ),
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
                Text('最近 7 天', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (consecutiveDays > 0) _StreakChip(days: consecutiveDays),
              ],
            ),
            const SizedBox(height: 12),
            if (recorded.isEmpty)
              Text('最近 7 天暂无记录', style: TextStyle(color: cs.onSurfaceVariant))
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TrendStat(
                    label: '平均分',
                    value: _averageScore(recorded).toString(),
                  ),
                  _TrendStat(label: '记录天数', value: '${recorded.length} 天'),
                  _TrendStat(
                    label: '最高分',
                    value: _highestScore(recorded).toString(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _TrendInsightLine(
                text: _trendInsightText(recorded, consecutiveDays),
              ),
              const SizedBox(height: 14),
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
      height: 118,
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
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendInsightLine extends StatelessWidget {
  const _TrendInsightLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.insights_outlined, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
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
              Text(label, style: TextStyle(fontSize: 13, color: cs.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

String _trendInsightText(List<LifeEntry> entries, int consecutiveDays) {
  if (consecutiveDays >= 3) {
    return '已连续记录 $consecutiveDays 天，节奏正在建立';
  }
  if (entries.length == 1) return '已开始记录，继续积累趋势';

  final avgStress =
      entries.fold<int>(0, (sum, e) => sum + e.stress) / entries.length;
  if (avgStress >= 4) return '压力偏高，今天放慢一点';

  final avgSleep =
      entries.fold<double>(0, (sum, e) => sum + e.sleepHours) / entries.length;
  if (avgSleep < 6) return '睡眠偏少，优先补休';

  final middle = entries.length ~/ 2;
  final earlier = entries.take(middle).toList();
  final later = entries.skip(middle).toList();
  final earlierAvg = _averageScore(earlier);
  final laterAvg = _averageScore(later);
  final diff = laterAvg - earlierAvg;

  if (diff >= 3) return '状态较前几天上升，继续保持';
  if (diff <= -3) return '状态较前几天回落，注意休息';
  return '状态整体平稳';
}

int _averageScore(List<LifeEntry> entries) {
  final total = entries.fold<int>(0, (sum, e) => sum + e.score);
  return (total / entries.length).round();
}

int _highestScore(List<LifeEntry> entries) {
  return entries.map((e) => e.score).reduce((a, b) => a > b ? a : b);
}

class _WeeklyGoalsCard extends StatelessWidget {
  const _WeeklyGoalsCard({required this.goals, required this.onTap});
  final WeeklyGoals goals;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = <String>[
      if (goals.sleepHours != null)
        "睡眠 ${goals.sleepHours!.toStringAsFixed(1)}h",
      if (goals.waterCups != null) "饮水 ${goals.waterCups}杯",
      if (goals.focus != null) "专注 ${goals.focus}分",
    ];
    return Card(
      elevation: 0,
      color: cs.secondaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.flag_outlined, color: cs.secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("本周目标", style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      items.isEmpty ? "设置睡眠、饮水与专注目标" : items.join(" · "),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSecondaryContainer.withAlpha(190),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: cs.onSecondaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}
