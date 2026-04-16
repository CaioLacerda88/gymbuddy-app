import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../workouts/models/exercise_set.dart';
import '../../workouts/providers/workout_providers.dart';
import '../../workouts/utils/set_filters.dart';
import '../models/progress_point.dart';
import '../utils/e1rm.dart';

/// Time window for the per-exercise progress chart.
enum TimeWindow {
  last30Days,
  last90Days,
  allTime;

  /// Cutoff date (inclusive, user-local) for filtering workouts. `null` means
  /// "no cutoff" (allTime).
  DateTime? cutoffFrom(DateTime now) {
    return switch (this) {
      TimeWindow.last30Days => now.subtract(const Duration(days: 30)),
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

/// Result of [buildExerciseProgressData] / [exerciseProgressProvider].
///
/// - [rawPoints] — one per user-local calendar date with a qualifying set,
///   ranked by max raw weight. `.weight` carries the heaviest completed
///   working-set weight for that day (kg or lbs per user profile).
/// - [e1rmPoints] — one per user-local calendar date, ranked by max Epley
///   e1RM across that day's completed working sets. `.weight` carries the
///   e1RM value (same unit). The ranking differs from [rawPoints]: a day
///   with `(100 kg × 10)` (e1RM 133.3) and `(110 kg × 3)` (e1RM 121) keeps
///   the 110 set in [rawPoints] but the 100 set in [e1rmPoints]. Picking
///   the correct series per metric is the whole point of the split —
///   re-mapping [rawPoints] would under-report e1RM peaks (review BLOCKER).
/// - [workoutCount] — number of distinct `workouts` rows in the window that
///   contained at least one completed working set with weight > 0. This is
///   what the chart's trend-copy row uses to disambiguate "1 workout" from
///   "N workouts same day" (BL-1 fix, folded into BL-3 acceptance #14). A
///   user who logged 2 workouts on one day should see `"2 workouts logged"`,
///   not `"1 session logged"`.
typedef ExerciseProgressData = ({
  List<ProgressPoint> rawPoints,
  List<ProgressPoint> e1rmPoints,
  int workoutCount,
});

/// Per-exercise weight-over-time series.
///
/// Groups the raw session history by user-local calendar date and takes the
/// max completed working-set weight per day, matching the predicate used by
/// `PRDetectionService` (see `set_filters.dart`). Days with no qualifying
/// sets do not produce a point.
///
/// `ref.keepAlive()` matches the pattern from `workoutCountProvider` — the
/// detail sheet is opened and closed frequently and the underlying query is
/// stable per user. `ActiveWorkoutNotifier.finishWorkout` explicitly
/// `ref.invalidate`s this family after a successful save so a user who
/// finishes a workout and re-opens the detail sheet in the same session
/// sees fresh data.
final exerciseProgressProvider = FutureProvider.autoDispose
    .family<ExerciseProgressData, ExerciseProgressKey>((ref, key) async {
      ref.keepAlive();

      final userId = ref.read(authRepositoryProvider).currentUser?.id;
      if (userId == null) {
        return (
          rawPoints: const <ProgressPoint>[],
          e1rmPoints: const <ProgressPoint>[],
          workoutCount: 0,
        );
      }

      final repo = ref.watch(workoutRepositoryProvider);
      // Intentional capture: the cutoff is resolved once per provider read so
      // the window doesn't drift mid-session. A user who opens the detail
      // sheet at 23:59 and keeps it open past midnight still sees the window
      // they opened with; `ActiveWorkoutNotifier.finishWorkout` explicitly
      // invalidates this family so a re-open after save recomputes `now`.
      // Do not lift to a top-level constant — it would never refresh.
      final since = key.window.cutoffFrom(DateTime.now());
      final rows = await repo.getExerciseHistory(
        key.exerciseId,
        userId: userId,
        since: since,
      );

      return buildExerciseProgressData(rows);
    });

/// Build the full [ExerciseProgressData] bundle from raw history rows.
///
/// Thin composite over [buildProgressPoints] (raw-weight series +
/// workoutCount) and [toE1RmSeries] (e1RM series). Both series run over the
/// same rows so they stay in sync, but each is ranked independently — see
/// [ExerciseProgressData] for why re-mapping the raw series would misreport
/// e1RM peaks (review BLOCKER).
ExerciseProgressData buildExerciseProgressData(
  List<({DateTime finishedAt, List<ExerciseSet> sets})> rows,
) {
  final raw = buildProgressPoints(rows);
  final e1rm = toE1RmSeries(rows);
  return (
    rawPoints: raw.points,
    e1rmPoints: e1rm,
    workoutCount: raw.workoutCount,
  );
}

/// Narrow result shape for [buildProgressPoints] — the raw-weight series and
/// its qualifying-workout count. Kept separate from [ExerciseProgressData]
/// so this helper can still be unit-tested without pulling the e1RM series
/// into every assertion.
typedef RawProgressPoints = ({List<ProgressPoint> points, int workoutCount});

/// Convert raw `(finishedAt, sets)` history into the raw-weight series.
///
/// Public for unit tests — the grouping/max-per-day logic is the provider's
/// real behaviour and is worth asserting without a mocked repository.
///
/// Returns both the aggregated [ProgressPoint] list AND the raw count of
/// workouts that qualified (had at least one completed working set with
/// weight > 0). See [ExerciseProgressData] for the BL-1 rationale.
RawProgressPoints buildProgressPoints(
  List<({DateTime finishedAt, List<ExerciseSet> sets})> rows,
) {
  // Dedupe + max-per-day in a single pass.
  // Key: (year, month, day) in *device local* time — matches how the PR
  // section renders dates on-screen, so chart x-axis and PR detail stay
  // visually consistent.
  final byDay = <_DayKey, _DayAgg>{};
  var workoutCount = 0;

  for (final row in rows) {
    final local = row.finishedAt.toLocal();
    final key = _DayKey(local.year, local.month, local.day);

    var rowQualifies = false;
    for (final set in row.sets) {
      if (!isCompletedWorkingSet(set)) continue;
      final weight = set.weight ?? 0;
      if (weight <= 0) continue; // bodyweight-only sets don't chart (v1)

      rowQualifies = true;
      final existing = byDay[key];
      if (existing == null || weight > existing.weight) {
        byDay[key] = _DayAgg(
          date: DateTime(local.year, local.month, local.day),
          weight: weight,
          reps: set.reps ?? 0,
        );
      }
    }
    if (rowQualifies) workoutCount++;
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
  return (points: points, workoutCount: workoutCount);
}

/// Same-shape series as [buildProgressPoints] but plots **e1RM** per day
/// instead of raw max weight.
///
/// This is what the chart plots when the metric toggle is set to "e1RM"
/// (the BL-3 primary metric). Uses the Epley formula via [e1RM] so a
/// programming switch from 5×5 → 3×10 doesn't misrepresent strength as a
/// line drop.
///
/// [ProgressPoint.weight] carries the e1RM value here — the chart reads it
/// as `y`, so the model field is reused rather than introducing a parallel
/// type. [ProgressPoint.sessionReps] is the rep count of the set that
/// produced the day's peak e1RM.
List<ProgressPoint> toE1RmSeries(
  List<({DateTime finishedAt, List<ExerciseSet> sets})> rows,
) {
  final byDay = <_DayKey, _DayAgg>{};

  for (final row in rows) {
    final local = row.finishedAt.toLocal();
    final key = _DayKey(local.year, local.month, local.day);

    for (final set in row.sets) {
      if (!isCompletedWorkingSet(set)) continue;
      final weight = set.weight ?? 0;
      if (weight <= 0) continue;
      final reps = set.reps ?? 0;
      final value = e1RM(weight, reps);
      if (value <= 0) continue;

      final existing = byDay[key];
      if (existing == null || value > existing.weight) {
        byDay[key] = _DayAgg(
          date: DateTime(local.year, local.month, local.day),
          weight: value,
          reps: reps,
        );
      }
    }
  }

  return byDay.values
      .map(
        (agg) => ProgressPoint(
          date: agg.date,
          weight: agg.weight,
          sessionReps: agg.reps,
        ),
      )
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
}

/// The point with the highest weight value in [points].
///
/// Used by the chart widget to render the gold PR ring on the peak dot.
/// Returns `null` when [points] is empty so callers can short-circuit to
/// the empty state.
ProgressPoint? peakPoint(List<ProgressPoint> points) {
  if (points.isEmpty) return null;
  var peak = points.first;
  for (final p in points.skip(1)) {
    if (p.weight > peak.weight) peak = p;
  }
  return peak;
}

/// Difference between the last and first point's weight (`last - first`).
///
/// Used by the chart widget's trend-copy row ("Up 5 kg in 30d",
/// "Down 2 kg", "Holding steady"). Returns `null` when fewer than two
/// points exist — there is no meaningful trend from a single observation.
double? trendDelta(List<ProgressPoint> points) {
  if (points.length < 2) return null;
  return points.last.weight - points.first.weight;
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
