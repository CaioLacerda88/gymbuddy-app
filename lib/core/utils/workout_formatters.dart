import 'package:intl/intl.dart';

import '../../features/workouts/models/exercise_set.dart';

/// Static utility methods for formatting workout-related values.
class WorkoutFormatters {
  WorkoutFormatters._();

  static final _volumeFormat = NumberFormat('#,##0', 'en_US');

  /// Format duration like "1h 23m", "45m", or "< 1m".
  static String formatDuration(int? durationSeconds) {
    if (durationSeconds == null || durationSeconds <= 0) return '< 1m';

    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m';
    }
    return '< 1m';
  }

  /// Format total volume like "1,234 kg".
  static String formatVolume(double volume) {
    return '${_volumeFormat.format(volume.round())} kg';
  }

  /// Format workout date contextually.
  ///
  /// Returns "Today", "Yesterday", "Mon, Jan 15" (same year),
  /// or "Jan 15, 2025" (different year).
  static String formatWorkoutDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);

    final diff = today.difference(dateDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';

    if (date.year == now.year) {
      return DateFormat('EEE, MMM d').format(date);
    }
    return DateFormat('MMM d, y').format(date);
  }

  /// Calculate total volume from a list of sets.
  ///
  /// Volume = sum of (weight * reps) for all completed sets.
  static double calculateVolume(List<ExerciseSet> sets) {
    return sets
        .where((s) => s.isCompleted)
        .fold(0.0, (sum, s) => sum + (s.weight ?? 0) * (s.reps ?? 0));
  }
}
