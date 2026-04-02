import 'package:flutter/material.dart';

/// Result of the resume workout dialog.
enum ResumeWorkoutResult { resume, discard }

/// Dialog shown on app start when a previously active workout is found in Hive.
///
/// Returns [ResumeWorkoutResult.resume] to continue the workout,
/// [ResumeWorkoutResult.discard] to delete it, or `null` if dismissed.
class ResumeWorkoutDialog extends StatelessWidget {
  const ResumeWorkoutDialog({required this.workoutName, super.key});

  final String workoutName;

  static Future<ResumeWorkoutResult?> show(
    BuildContext context, {
    required String workoutName,
  }) {
    return showDialog<ResumeWorkoutResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ResumeWorkoutDialog(workoutName: workoutName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Resume Workout?'),
      content: Text('You have an unfinished workout: $workoutName'),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(ResumeWorkoutResult.discard),
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          child: const Text('Discard'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(ResumeWorkoutResult.resume),
          child: const Text('Resume'),
        ),
      ],
    );
  }
}
