import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/life_entry.dart';
import '../state/life_entry_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, LifeEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条记录'),
        content: const Text('这只会删除本机缓存中的这条记录，不会删除云端记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<LifeEntryProvider>().deleteEntry(entry);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已删除本机缓存记录')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除失败，请稍后再试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<LifeEntryProvider>().entries;
    return Scaffold(
      appBar: AppBar(title: const Text('历史记录')),
      body: entries.isEmpty
          ? const Center(child: Text('还没有历史记录'))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _HistoryCard(
                  entry: entry,
                  onDelete: () => _confirmDelete(context, entry),
                );
              },
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry, required this.onDelete});

  final LifeEntry entry;
  final VoidCallback onDelete;

  Color _scoreColor(BuildContext context, int score) {
    final cs = Theme.of(context).colorScheme;
    if (score >= 80) return cs.primary;
    if (score >= 60) return cs.tertiary;
    return cs.error;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scoreColor = _scoreColor(context, entry.score);

    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(context, '/detail', arguments: entry),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scoreColor.withAlpha(30),
                child: Text(
                  '${entry.score}',
                  style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.status,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat('yyyy-MM-dd HH:mm').format(entry.createdAt)}  ·  ${entry.activity}',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  _MiniStat(Icons.mood, '${entry.mood}'),
                  const SizedBox(width: 8),
                  _MiniStat(Icons.bolt, '${entry.energy}'),
                  const SizedBox(width: 8),
                  _MiniStat(Icons.bedtime_outlined, '${entry.sleepHours}h'),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, color: cs.error),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ],
    );
  }
}
