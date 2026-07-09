import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/life_entry.dart';
import '../widgets/metric_tile.dart';
import '../widgets/score_card.dart';

class EntryDetailScreen extends StatelessWidget {
  const EntryDetailScreen({super.key, required this.entry});

  final LifeEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(DateFormat('M月d日').format(entry.createdAt))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ScoreCard(score: entry.score, status: entry.status),
          const SizedBox(height: 12),
          // 建议卡
          Card(
            elevation: 0,
            color: cs.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, color: cs.secondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.suggestion,
                      style: TextStyle(color: cs.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 指标网格
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
            children: [
              MetricTile(
                label: '心情',
                value: '${entry.mood}/5',
                icon: Icons.mood,
              ),
              MetricTile(
                label: '精力',
                value: '${entry.energy}/5',
                icon: Icons.bolt,
              ),
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
          ),
          const SizedBox(height: 12),
          // 活动 & 时间
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _InfoRow(
                    Icons.directions_run_outlined,
                    '主要活动',
                    entry.activity,
                  ),
                  const Divider(height: 20),
                  _InfoRow(
                    Icons.access_time_outlined,
                    '记录时间',
                    DateFormat('yyyy-MM-dd HH:mm').format(entry.createdAt),
                  ),
                ],
              ),
            ),
          ),
          if (entry.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_outlined, color: cs.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(child: Text(entry.note)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
        const Spacer(),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
