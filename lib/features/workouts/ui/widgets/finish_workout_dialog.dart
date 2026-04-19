import 'package:flutter/material.dart';

/// Result returned when the user confirms finishing a workout.
class FinishWorkoutResult {
  const FinishWorkoutResult({this.notes});

  final String? notes;
}

/// Dialog shown when the user taps "Finish" on the active workout screen.
///
/// Warns about incomplete sets and allows adding optional notes.
/// Returns a [FinishWorkoutResult] on confirm, or `null` on cancel.
class FinishWorkoutDialog extends StatefulWidget {
  const FinishWorkoutDialog({required this.incompleteCount, super.key});

  final int incompleteCount;

  static Future<FinishWorkoutResult?> show(
    BuildContext context, {
    required int incompleteCount,
  }) {
    return showDialog<FinishWorkoutResult>(
      context: context,
      builder: (_) => FinishWorkoutDialog(incompleteCount: incompleteCount),
    );
  }

  @override
  State<FinishWorkoutDialog> createState() => _FinishWorkoutDialogState();
}

class _FinishWorkoutDialogState extends State<FinishWorkoutDialog> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Finish Workout?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.incompleteCount > 0) ...[
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You have ${widget.incompleteCount} incomplete '
                    'set${widget.incompleteCount == 1 ? '' : 's'}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Semantics(
            container: true,
            identifier: 'workout-notes',
            label: 'Workout notes',
            child: TextField(
              controller: _notesController,
              maxLength: 1000,
              decoration: const InputDecoration(
                hintText: 'Add notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
        ],
      ),
      actions: [
        Semantics(
          container: true,
          identifier: 'workout-keep-going',
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep Going'),
          ),
        ),
        Semantics(
          container: true,
          identifier: 'workout-dialog-finish',
          label: 'Save and finish workout',
          child: FilledButton(
            onPressed: () {
              final notes = _notesController.text.trim();
              Navigator.of(
                context,
              ).pop(FinishWorkoutResult(notes: notes.isEmpty ? null : notes));
            },
            child: const Text('Save & Finish'),
          ),
        ),
      ],
    );
  }
}
