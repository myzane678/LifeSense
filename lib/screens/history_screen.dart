import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/life_entry.dart';
import '../state/life_entry_provider.dart';

enum _ScoreFilter { all, high, mid, low }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _ScoreFilter _filter = _ScoreFilter.all;

  List<LifeEntry> _applyFilter(List<LifeEntry> entries) {
    return switch (_filter) {
      _ScoreFilter.all => entries,
      _ScoreFilter.high => entries.where((e) => e.score >= 80).toList(),
      _ScoreFilter.mid =>
        entries.where((e) => e.score >= 60 && e.score < 80).toList(),
      _ScoreFilter.low => entries.where((e) => e.score < 60).toList(),
    };
  }

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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已删除本机缓存记录')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('删除失败，请稍后再试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<LifeEntryProvider>().entries;
    final filtered = _applyFilter(List<LifeEntry>.from(all));

    return Scaffold(
      appBar: AppBar(title: const Text('历史记录')),
      body: Column(
        children: [
          _FilterBar(
            current: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      all.isEmpty ? '还没有历史记录' : '该分段暂无记录',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      return _HistoryCard(
                        entry: entry,
                        onDelete: () => _confirmDelete(context, entry),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.current, required this.onChanged});

  final _ScoreFilter current;
  final ValueChanged<_ScoreFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      (_ScoreFilter.all, '全部'),
      (_ScoreFilter.high, '优秀 ≥80'),
      (_ScoreFilter.mid, '良好 60-79'),
      (_ScoreFilter.low, '待提升 <60'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          for (final (filter, label) in items) ...[
            FilterChip(
              label: Text(label),
              selected: current == filter,
              onSelected: (_) => onChanged(filter),
            ),
            const SizedBox(width: 8),
          ],
        ],
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
