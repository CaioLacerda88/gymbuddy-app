import 'package:intl/intl.dart';

import '../../features/workouts/models/exercise_set.dart';
import '../../l10n/app_localizations.dart';

/// Static utility methods for formatting workout-related values.
class WorkoutFormatters {
  WorkoutFormatters._();

  static final _volumeFormat = NumberFormat('#,##0', 'en_US');

  /// Format duration like "1h 23m", "45m", or "< 1m".
  static String formatDuration(int? durationSeconds, {AppLocalizations? l10n}) {
    if (durationSeconds == null || durationSeconds <= 0) {
      return l10n?.durationLessThanOneMin ?? '< 1m';
    }

    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m';
    }
    return l10n?.durationLessThanOneMin ?? '< 1m';
  }

  /// Format total volume like "1,234 kg" (or the caller's preferred unit).
  ///
  /// [weightUnit] defaults to `'kg'` to preserve backward compatibility with
  /// call sites that don't yet thread through the user's preference.
  /// When [locale] is provided, uses locale-aware number formatting.
  static String formatVolume(
    double volume, {
    String weightUnit = 'kg',
    String? locale,
  }) {
    final fmt = locale != null ? NumberFormat('#,##0', locale) : _volumeFormat;
    return '${fmt.format(volume.round())} $weightUnit';
  }

  /// Format workout date contextually.
  ///
  /// Returns "Today", "Yesterday", "Mon, Jan 15" (same year),
  /// or "Jan 15, 2025" (different year).
  ///
  /// When [l10n] is provided, uses localized "Today"/"Yesterday" strings.
  /// When [locale] is provided, uses locale-aware date formatting.
  static String formatWorkoutDate(
    DateTime date, {
    AppLocalizations? l10n,
    String? locale,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);

    final diff = today.difference(dateDay).inDays;

    if (diff == 0) return l10n?.today ?? 'Today';
    if (diff == 1) return l10n?.yesterday ?? 'Yesterday';

    if (date.year == now.year) {
      return DateFormat('EEE, MMM d', locale).format(date);
    }
    return DateFormat('MMM d, y', locale).format(date);
  }

  /// Format a date as a relative human-readable string.
  ///
  /// Returns "Today", "Yesterday", "3 days ago", "2w ago", "1mo ago", etc.
  /// Useful for stat card subtitles and compact date displays.
  ///
  /// When [l10n] is provided, uses localized strings.
  static String formatRelativeDate(DateTime date, {AppLocalizations? l10n}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(dateDay).inDays;

    if (diff == 0) return l10n?.today ?? 'Today';
    if (diff == 1) return l10n?.yesterday ?? 'Yesterday';
    if (diff < 7) return l10n?.daysAgo(diff) ?? '$diff days ago';
    if (diff < 30) {
      final weeks = (diff / 7).floor();
      return l10n?.weeksAgoShort(weeks) ?? '${weeks}w ago';
    }
    final months = (diff / 30).floor();
    return l10n?.monthsAgoShort(months) ?? '${months}mo ago';
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
