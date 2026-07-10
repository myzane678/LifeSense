import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/life_entry.dart';
import '../state/life_entry_provider.dart';

class EditEntryScreen extends StatefulWidget {
  const EditEntryScreen({super.key, required this.entry});

  final LifeEntry entry;

  @override
  State<EditEntryScreen> createState() => _EditEntryScreenState();
}

class _EditEntryScreenState extends State<EditEntryScreen> {
  late int mood;
  late int energy;
  late int stress;
  late int focus;
  late String activity;
  bool isSaving = false;
  late final TextEditingController sleepController;
  late final TextEditingController waterController;
  late final TextEditingController noteController;

  @override
  void initState() {
    super.initState();
    mood = widget.entry.mood;
    energy = widget.entry.energy;
    stress = widget.entry.stress;
    focus = widget.entry.focus;
    activity = widget.entry.activity;
    sleepController = TextEditingController(
      text: widget.entry.sleepHours % 1 == 0
          ? widget.entry.sleepHours.round().toString()
          : widget.entry.sleepHours.toString(),
    );
    waterController = TextEditingController(
      text: widget.entry.waterCups.toString(),
    );
    noteController = TextEditingController(text: widget.entry.note);
  }

  @override
  void dispose() {
    sleepController.dispose();
    waterController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final sleepVal = double.tryParse(sleepController.text.trim());
    final waterVal = int.tryParse(waterController.text.trim());
    if (sleepVal == null || sleepVal < 0 || sleepVal > 24) {
      _showMessage('请输入 0 到 24 之间的睡眠时长');
      return;
    }
    if (waterVal == null || waterVal < 0 || waterVal > 50) {
      _showMessage('请输入 0 到 50 之间的饮水杯数');
      return;
    }

    setState(() => isSaving = true);
    final updated = LifeEntry(
      id: widget.entry.id,
      createdAt: DateTime.now(),
      mood: mood,
      energy: energy,
      stress: stress,
      focus: focus,
      sleepHours: sleepVal,
      waterCups: waterVal,
      activity: activity,
      note: noteController.text.trim(),
      score: widget.entry.score,
      status: widget.entry.status,
      suggestion: widget.entry.suggestion,
    );

    try {
      final (oldScore, oldStatus, newScore, newStatus) =
          await context.read<LifeEntryProvider>().updateEntry(updated);
      if (!mounted) return;
      await _showCompareDialog(oldScore, oldStatus, newScore, newStatus);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        _showMessage('保存失败，请稍后再试');
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> _showCompareDialog(
    int oldScore,
    String oldStatus,
    int newScore,
    String newStatus,
  ) async {
    final diff = newScore - oldScore;
    final diffText = diff > 0 ? '+$diff' : '$diff';
    final cs = Theme.of(context).colorScheme;
    Color diffColor;
    if (diff > 0) {
      diffColor = cs.primary;
    } else if (diff < 0) {
      diffColor = cs.error;
    } else {
      diffColor = cs.onSurfaceVariant;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改结果'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('分数'),
                Row(
                  children: [
                    Text('$oldScore',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                    const Text(' → '),
                    Text('$newScore',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Text(
                      diffText,
                      style: TextStyle(
                          color: diffColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
            if (oldStatus != newStatus) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('状态'),
                  Row(
                    children: [
                      Text(oldStatus,
                          style: TextStyle(color: cs.onSurfaceVariant)),
                      const Text(' → '),
                      Text(newStatus,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('编辑记录')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            _SectionCard(
              title: '状态评分',
              child: Column(
                children: [
                  _EmojiRater(
                    label: '心情',
                    value: mood,
                    emojis: const ['😞', '😕', '😐', '🙂', '😄'],
                    onChanged: (v) => setState(() => mood = v),
                  ),
                  const SizedBox(height: 12),
                  _EmojiRater(
                    label: '精力',
                    value: energy,
                    emojis: const ['🪫', '😴', '🙂', '⚡', '🔥'],
                    onChanged: (v) => setState(() => energy = v),
                  ),
                  const SizedBox(height: 12),
                  _EmojiRater(
                    label: '压力',
                    value: stress,
                    emojis: const ['😌', '🙂', '😬', '😰', '🤯'],
                    onChanged: (v) => setState(() => stress = v),
                  ),
                  const SizedBox(height: 12),
                  _EmojiRater(
                    label: '专注',
                    value: focus,
                    emojis: const ['🌀', '😑', '🙂', '🎯', '🧠'],
                    onChanged: (v) => setState(() => focus = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '今日数据',
              child: Column(
                children: [
                  _NumberStepperField(
                    controller: sleepController,
                    label: '睡眠时长',
                    unit: '小时',
                    min: 0,
                    max: 24,
                    step: 0.5,
                  ),
                  const Divider(height: 24),
                  _NumberStepperField(
                    controller: waterController,
                    label: '饮水',
                    unit: '杯',
                    min: 0,
                    max: 50,
                    step: 1,
                    integerOnly: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '活动与备注',
              child: Column(
                children: [
                  _ActivityChips(
                    value: activity,
                    onChanged: (v) => setState(() => activity = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: '今天有什么想记录的？（选填）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: isSaving ? null : _save,
              child: Text(isSaving ? '保存中...' : '保存修改'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmojiRater extends StatelessWidget {
  const _EmojiRater({
    required this.label,
    required this.value,
    required this.emojis,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<String> emojis;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 1; i <= 5; i++)
                GestureDetector(
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value == i
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHigh,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emojis[i - 1],
                      style: TextStyle(fontSize: value == i ? 22 : 18),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NumberStepperField extends StatefulWidget {
  const _NumberStepperField({
    required this.controller,
    required this.label,
    required this.unit,
    required this.min,
    required this.max,
    required this.step,
    this.integerOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final String unit;
  final double min;
  final double max;
  final double step;
  final bool integerOnly;

  @override
  State<_NumberStepperField> createState() => _NumberStepperFieldState();
}

class _NumberStepperFieldState extends State<_NumberStepperField> {
  double get value =>
      double.tryParse(widget.controller.text.trim()) ?? widget.min;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentValue = value;
    return Row(
      children: [
        Expanded(child: Text(widget.label)),
        IconButton(
          onPressed: currentValue > widget.min
              ? () => _updateValue(currentValue - widget.step)
              : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 112,
          child: TextField(
            controller: widget.controller,
            keyboardType: TextInputType.numberWithOptions(
              decimal: !widget.integerOnly,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              suffixText: widget.unit,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        IconButton(
          onPressed: currentValue < widget.max
              ? () => _updateValue(currentValue + widget.step)
              : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  void _updateValue(double nextValue) {
    final clamped = nextValue.clamp(widget.min, widget.max);
    widget.controller.text = widget.integerOnly
        ? clamped.round().toString()
        : clamped.toStringAsFixed(clamped % 1 == 0 ? 0 : 1);
  }
}

class _ActivityChips extends StatelessWidget {
  const _ActivityChips({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = ['学习', '运动', '休息', '社交', '工作', '其他'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final opt in options)
          ChoiceChip(
            label: Text(opt),
            selected: value == opt,
            onSelected: (_) => onChanged(opt),
          ),
      ],
    );
  }
}
