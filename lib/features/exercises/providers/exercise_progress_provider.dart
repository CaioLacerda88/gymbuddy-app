import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../auth/providers/auth_providers.dart';
import '../../workouts/models/exercise_set.dart';
import '../../workouts/providers/workout_providers.dart';
import '../../workouts/utils/set_filters.dart';
import '../models/progress_point.dart';

/// Time window for the per-exercise progress chart.
enum TimeWindow {
  last90Days,
  allTime;

  /// Cutoff date (inclusive, user-local) for filtering workouts. `null` means
  /// "no cutoff" (allTime).
  DateTime? cutoffFrom(DateTime now) {
    return switch (this) {
      TimeWindow.last90Days => now.subtract(const Duration(days: 90)),
      TimeWindow.allTime => null,
    };
  }
}

/// Key for [exerciseProgressProvider] — an exercise + a time window.
///
/// Freezed would be overkill here; the two fields are enough for stable
/// equality and the class stays near its only consumer.
class ExerciseProgressKey {
  const ExerciseProgressKey({required this.exerciseId, required this.window});

  final String exerciseId;
  final TimeWindow window;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseProgressKey &&
          exerciseId == other.exerciseId &&
          window == other.window;

  @override
  int get hashCode => Object.hash(exerciseId, window);
}

/// Currently-selected time window for the progress chart. UI-local state —
/// no persistence needed, the 90-day default is cheap to re-render on every
/// detail-sheet open.
final progressTimeWindowProvider = StateProvider<TimeWindow>(
  (ref) => TimeWindow.last90Days,
);

/// Per-exercise weight-over-time series.
///
/// Groups the raw session history by user-local calendar date and takes the
/// max completed working-set weight per day, matching the predicate used by
/// `PRDetectionService` (see `set_filters.dart`). Days with no qualifying
/// sets do not produce a point.
///
/// `ref.keepAlive()` matches the pattern from `workoutCountProvider` — the
/// detail sheet is opened and closed frequently and the underlying query is
/// stable per user. Invalidate explicitly on workout save/discard if it
/// becomes necessary; for v1 the data is stale-on-reopen only within a very
/// short window (the user has to finish a workout and re-open the sheet
/// within the same Riverpod container lifetime), which matches user
/// expectation for a passive "glance" surface.
final exerciseProgressProvider = FutureProvider.autoDispose
    .family<List<ProgressPoint>, ExerciseProgressKey>((ref, key) async {
      ref.keepAlive();

      final userId = ref.read(authRepositoryProvider).currentUser?.id;
      if (userId == null) return const [];

      final repo = ref.watch(workoutRepositoryProvider);
      final since = key.window.cutoffFrom(DateTime.now());
      final rows = await repo.getExerciseHistory(
        key.exerciseId,
        userId: userId,
        since: since,
      );

      return buildProgressPoints(rows);
    });

/// Convert raw `(finishedAt, sets)` history into plottable progress points.
///
/// Public for unit tests — the grouping/max-per-day logic is the provider's
/// real behaviour and is worth asserting without a mocked repository.
List<ProgressPoint> buildProgressPoints(
  List<({DateTime finishedAt, List<ExerciseSet> sets})> rows,
) {
  // Dedupe + max-per-day in a single pass.
  // Key: (year, month, day) in *device local* time — matches how the PR
  // section renders dates on-screen, so chart x-axis and PR detail stay
  // visually consistent.
  final byDay = <_DayKey, _DayAgg>{};

  for (final row in rows) {
    final local = row.finishedAt.toLocal();
    final key = _DayKey(local.year, local.month, local.day);

    for (final set in row.sets) {
      if (!isCompletedWorkingSet(set)) continue;
      final weight = set.weight ?? 0;
      if (weight <= 0) continue; // bodyweight-only sets don't chart (v1)

      final existing = byDay[key];
      if (existing == null || weight > existing.weight) {
        byDay[key] = _DayAgg(
          date: DateTime(local.year, local.month, local.day),
          weight: weight,
          reps: set.reps ?? 0,
        );
      }
    }
  }

  final points =
      byDay.values
          .map(
            (agg) => ProgressPoint(
              date: agg.date,
              weight: agg.weight,
              sessionReps: agg.reps,
            ),
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  return points;
}

/// Private key type — calendar-date tuple for `byDay` map.
class _DayKey {
  const _DayKey(this.year, this.month, this.day);
  final int year;
  final int month;
  final int day;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _DayKey &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

/// Private aggregate — day-local best weight + reps for that weight.
class _DayAgg {
  const _DayAgg({required this.date, required this.weight, required this.reps});
  final DateTime date;
  final double weight;
  final int reps;
}
