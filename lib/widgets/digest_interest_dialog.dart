import 'package:flutter/material.dart';

import '../services/digest_preferences_service.dart';

Future<List<String>?> showDigestInterestDialog(
  BuildContext context, {
  required List<String> initialIds,
  required String title,
  required String description,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (context) => _DigestInterestDialog(
      initialIds: initialIds,
      title: title,
      description: description,
    ),
  );
}

class _DigestInterestDialog extends StatefulWidget {
  const _DigestInterestDialog({
    required this.initialIds,
    required this.title,
    required this.description,
  });

  final List<String> initialIds;
  final String title;
  final String description;

  @override
  State<_DigestInterestDialog> createState() => _DigestInterestDialogState();
}

class _DigestInterestDialogState extends State<_DigestInterestDialog> {
  late final Set<String> selected = widget.initialIds.toSet();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.description),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final interest in DigestPreferencesService.interests)
                  FilterChip(
                    label: Text(interest.label),
                    selected: selected.contains(interest.id),
                    onSelected: (value) => _toggle(interest.id, value),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('暂时跳过'),
        ),
        FilledButton(
          onPressed: selected.isEmpty ? null : () => Navigator.pop(context, selected.toList()),
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _toggle(String id, bool value) {
    setState(() {
      if (!value) {
        selected.remove(id);
      } else if (selected.length < DigestPreferencesService.maxSelection) {
        selected.add(id);
      }
    });
  }
}
