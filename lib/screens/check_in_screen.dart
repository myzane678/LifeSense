import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/life_entry_provider.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  int mood = 3;
  int energy = 3;
  int stress = 3;
  int focus = 3;
  double sleepHours = 7;
  int waterCups = 6;
  bool isSaving = false;
  final sleepController = TextEditingController(text: '7');
  final waterController = TextEditingController(text: '6');
  final noteController = TextEditingController();
  String activity = '学习';

  @override
  void dispose() {
    sleepController.dispose();
    waterController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final customSleepHours = double.tryParse(sleepController.text.trim());
    final customWaterCups = int.tryParse(waterController.text.trim());
    if (customSleepHours == null ||
        customSleepHours < 0 ||
        customSleepHours > 24) {
      showMessage('请输入 0 到 24 之间的睡眠时长');
      return;
    }
    if (customWaterCups == null ||
        customWaterCups < 0 ||
        customWaterCups > 50) {
      showMessage('请输入 0 到 50 之间的饮水杯数');
      return;
    }

    setState(() => isSaving = true);
    try {
      await context.read<LifeEntryProvider>().addEntry(
        mood: mood,
        energy: energy,
        stress: stress,
        focus: focus,
        sleepHours: customSleepHours,
        waterCups: customWaterCups,
        activity: activity,
        note: noteController.text.trim(),
      );
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (_) {
      if (mounted) {
        showMessage('记录已保存在本机，云同步稍后再试');
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('今日记录')),
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
              onPressed: isSaving ? null : save,
              child: Text(isSaving ? '保存中...' : '保存记录'),
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
    widget.controller.addListener(refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(refresh);
    super.dispose();
  }

  void refresh() {
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
              ? () => updateValue(currentValue - widget.step)
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
              ? () => updateValue(currentValue + widget.step)
              : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  void updateValue(double nextValue) {
    final clampedValue = nextValue.clamp(widget.min, widget.max);
    widget.controller.text = widget.integerOnly
        ? clampedValue.round().toString()
        : clampedValue.toStringAsFixed(clampedValue % 1 == 0 ? 0 : 1);
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
