import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/weekly_goals_service.dart';

Future<WeeklyGoals?> showWeeklyGoalsEditor(BuildContext context) async {
  final goals = context.read<WeeklyGoalsService>().goals;
  final sleepController = TextEditingController(
    text: goals.sleepHours?.toStringAsFixed(1) ?? '',
  );
  final waterController = TextEditingController(
    text: goals.waterCups?.toString() ?? '',
  );
  final focusController = TextEditingController(
    text: goals.focus?.toString() ?? '',
  );
  final nextGoals = await showDialog<WeeklyGoals>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('本周目标'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: sleepController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '睡眠目标（5–10 小时/日）',
              hintText: '留空表示不设置',
            ),
          ),
          TextField(
            controller: waterController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '饮水目标（3–12 杯/日）',
              hintText: '留空表示不设置',
            ),
          ),
          TextField(
            controller: focusController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '专注目标（2–5 分）',
              hintText: '留空表示不设置',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            WeeklyGoals(
              sleepHours: double.tryParse(sleepController.text.trim()),
              waterCups: int.tryParse(waterController.text.trim()),
              focus: int.tryParse(focusController.text.trim()),
            ),
          ),
          child: const Text('保存'),
        ),
      ],
    ),
  );
  sleepController.dispose();
  waterController.dispose();
  focusController.dispose();
  return nextGoals;
}
