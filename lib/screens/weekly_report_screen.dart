import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/weekly_report.dart';
import '../state/life_entry_provider.dart';
import '../services/weekly_goals_service.dart';

class WeeklyReportScreen extends StatelessWidget {
  const WeeklyReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<LifeEntryProvider>().weeklyReports;
    final weeklyGoals = context.watch<WeeklyGoalsService>();
    return Scaffold(
      appBar: AppBar(title: const Text('周报')),
      body: reports.isEmpty
          ? _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: reports.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _WeeklyCard(
                report: reports[index],
                goalsService: index == 0 ? weeklyGoals : null,
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 56,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text('还没有周报数据', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '记录一周后即可生成周报',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.report, this.goalsService});

  final WeeklyReport report;
  final WeeklyGoalsService? goalsService;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final score = report.avgScore;

    Color scoreColor;
    if (score >= 80) {
      scoreColor = colorScheme.primary;
    } else if (score >= 60) {
      scoreColor = colorScheme.tertiary;
    } else {
      scoreColor = colorScheme.error;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.weekLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '共记录 ${report.recordCount} 天',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$score',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: scoreColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '周均分',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: [
                _MetricRow(
                  icon: Icons.mood,
                  label: '心情',
                  value: report.avgMood.toStringAsFixed(1),
                  suffix: '/5',
                ),
                _MetricRow(
                  icon: Icons.bolt,
                  label: '精力',
                  value: report.avgEnergy.toStringAsFixed(1),
                  suffix: '/5',
                ),
                _MetricRow(
                  icon: Icons.psychology_outlined,
                  label: '压力',
                  value: report.avgStress.toStringAsFixed(1),
                  suffix: '/5',
                ),
                _MetricRow(
                  icon: Icons.center_focus_strong_outlined,
                  label: '专注',
                  value: report.avgFocus.toStringAsFixed(1),
                  suffix: '/5',
                ),
                _MetricRow(
                  icon: Icons.bedtime_outlined,
                  label: '睡眠',
                  value: report.avgSleep.toStringAsFixed(1),
                  suffix: 'h',
                ),
                _MetricRow(
                  icon: Icons.water_drop_outlined,
                  label: '饮水',
                  value: report.avgWater.toStringAsFixed(1),
                  suffix: '杯',
                ),
              ],
            ),
            if (goalsService != null) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              _WeeklyGoalsSection(
                goals: goalsService!.goals,
                plan: goalsService!.actionPlanFor(report),
                report: report,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeeklyGoalsSection extends StatelessWidget {
  const _WeeklyGoalsSection({
    required this.goals,
    required this.plan,
    required this.report,
  });

  final WeeklyGoals goals;
  final WeeklyActionPlan plan;
  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progressItems = <String>[
      if (goals.sleepHours != null)
        '睡眠 ${report.avgSleep.toStringAsFixed(1)}/${goals.sleepHours!.toStringAsFixed(1)}h',
      if (goals.waterCups != null)
        '饮水 ${report.avgWater.toStringAsFixed(1)}/${goals.waterCups}杯',
      if (goals.focus != null)
        '专注 ${report.avgFocus.toStringAsFixed(1)}/${goals.focus}分',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('本周目标', style: Theme.of(context).textTheme.titleSmall),
        if (progressItems.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            progressItems.join(' · '),
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.flag_outlined, size: 20, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    plan.message,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.suffix,
  });

  final IconData icon;
  final String label;
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '$value$suffix',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
