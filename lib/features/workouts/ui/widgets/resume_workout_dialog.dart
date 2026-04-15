import 'package:flutter/material.dart';

/// Result of the resume workout dialog.
enum ResumeWorkoutResult { resume, discard }

/// Threshold past which a workout is considered "stale" and the dialog
/// surfaces an age line plus stronger copy.
const Duration _staleThreshold = Duration(hours: 6);

/// Returns true when an active workout has been idle long enough (6h+) that
/// resuming it likely means crossing a session boundary.
///
/// Exposed as a package-level function for unit testing. Kept intentionally
/// tiny so the branching in [ResumeWorkoutDialog] stays self-documenting.
bool isStaleWorkout(Duration age) => age >= _staleThreshold;

/// Human-readable age string for the stale-workout dialog body.
///
/// Rules (in order):
///   - `< 1h`              → "less than an hour ago"
///   - `>= 1h`, same day   → "$N hour(s) ago"
///   - previous calendar day (and `< 48h`) → "yesterday at H:MM AM/PM"
///   - `< 7d`              → "$WEEKDAY at H:MM AM/PM"
///   - `>= 7d`             → "$N days ago"
///
/// [now] is injected so tests can assert against a fixed clock.
String formatResumeAge(DateTime startedAt, DateTime now) {
  final age = now.difference(startedAt);

  if (age < const Duration(hours: 1)) {
    return 'less than an hour ago';
  }

  final startedDay = DateTime(startedAt.year, startedAt.month, startedAt.day);
  final today = DateTime(now.year, now.month, now.day);
  final dayDelta = today.difference(startedDay).inDays;

  // Same calendar day → hour count.
  if (dayDelta == 0) {
    final hours = age.inHours;
    return hours == 1 ? '1 hour ago' : '$hours hours ago';
  }

  // Previous calendar day and still within 48h → "yesterday at H:MM".
  if (dayDelta == 1 && age < const Duration(hours: 48)) {
    return 'yesterday at ${_formatClock(startedAt)}';
  }

  // Within the last week → weekday name + clock.
  if (dayDelta < 7) {
    return '${_weekdayName(startedAt.weekday)} at ${_formatClock(startedAt)}';
  }

  // Fallback: coarse day count.
  final days = age.inDays;
  return '$days days ago';
}

String _formatClock(DateTime t) {
  final hour24 = t.hour;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '$hour12:$minute $period';
}

String _weekdayName(int weekday) {
  const names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return names[weekday - 1];
}

/// Dialog shown on app start when a previously active workout is found in Hive.
///
/// Returns [ResumeWorkoutResult.resume] to continue the workout,
/// [ResumeWorkoutResult.discard] to delete it, or `null` if dismissed.
///
/// When the workout is older than [_staleThreshold], the dialog swaps in
/// reworded copy plus a muted line describing when the session was
/// interrupted, and renames the primary action to "Resume anyway".
class ResumeWorkoutDialog extends StatelessWidget {
  const ResumeWorkoutDialog({
    required this.workoutName,
    required this.startedAt,
    super.key,
  });

  final String workoutName;
  final DateTime startedAt;

  static Future<ResumeWorkoutResult?> show(
    BuildContext context, {
    required String workoutName,
    required DateTime startedAt,
  }) {
    return showDialog<ResumeWorkoutResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          ResumeWorkoutDialog(workoutName: workoutName, startedAt: startedAt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final age = now.difference(startedAt);
    final isStale = isStaleWorkout(age);

    return AlertDialog(
      title: Text(isStale ? 'Pick up where you left off?' : 'Resume workout?'),
      content: isStale
          ? Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: workoutName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: '\n'),
                  TextSpan(
                    text: 'was interrupted ${formatResumeAge(startedAt, now)}.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            )
          : Text('"$workoutName" is still in progress.'),
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
          child: Text(isStale ? 'Resume anyway' : 'Resume'),
        ),
      ],
    );
  }
}
