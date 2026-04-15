import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/data/base_repository.dart';
import '../../exercises/models/exercise.dart';
import '../models/exercise_set.dart';
import '../models/workout.dart';
import '../models/workout_exercise.dart';

/// Parsed workout detail with exercises and sets.
typedef WorkoutDetail = ({
  Workout workout,
  List<WorkoutExercise> exercises,
  Map<String, List<ExerciseSet>> setsByExercise,
});

class WorkoutRepository extends BaseRepository {
  const WorkoutRepository(this._client);

  final supabase.SupabaseClient _client;

  supabase.SupabaseQueryBuilder get _workouts => _client.from('workouts');

  /// Atomically save a finished workout via the save_workout RPC.
  ///
  /// Supabase wraps each RPC call in a transaction, so all inserts/updates
  /// are atomic — a constraint violation rolls back the entire operation.
  Future<Workout> saveWorkout({
    required Workout workout,
    required List<WorkoutExercise> exercises,
    required List<ExerciseSet> sets,
  }) {
    return mapException(() async {
      final result = await _client.rpc(
        'save_workout',
        params: {
          'p_workout': {
            'id': workout.id,
            'user_id': workout.userId,
            'name': workout.name,
            'finished_at': workout.finishedAt?.toIso8601String(),
            'duration_seconds': workout.durationSeconds,
            'notes': workout.notes,
          },
          'p_exercises': exercises
              .map(
                (e) => {
                  'id': e.id,
                  'workout_id': e.workoutId,
                  'exercise_id': e.exerciseId,
                  'order': e.order,
                  'rest_seconds': e.restSeconds,
                },
              )
              .toList(),
          'p_sets': sets
              .map(
                (s) => {
                  'id': s.id,
                  'workout_exercise_id': s.workoutExerciseId,
                  'set_number': s.setNumber,
                  'reps': s.reps,
                  'weight': s.weight,
                  'rpe': s.rpe,
                  'set_type': s.setType.name,
                  'notes': s.notes,
                  'is_completed': s.isCompleted,
                },
              )
              .toList(),
        },
      );
      return Workout.fromJson(result as Map<String, dynamic>);
    });
  }

  /// Create a new active workout (start of a session).
  Future<Workout> createActiveWorkout({
    required String userId,
    required String name,
  }) {
    return mapException(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      final data = await _workouts
          .insert({
            'user_id': userId,
            'name': name,
            'started_at': now,
            'is_active': true,
          })
          .select()
          .single();
      return Workout.fromJson(data);
    });
  }

  /// Get the user's currently active workout, if any.
  Future<Workout?> getActiveWorkout(String userId) {
    return mapException(() async {
      final data = await _workouts
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();
      if (data == null) return null;
      return Workout.fromJson(data);
    });
  }

  /// Get paginated workout history (finished workouts only).
  ///
  /// Joins exercise names in a single query so each returned [Workout] has
  /// [Workout.exerciseSummary] pre-populated (e.g. "Bench Press, Squat +2").
  Future<List<Workout>> getWorkoutHistory(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) {
    return mapException(() async {
      final data = await _workouts
          .select('*, workout_exercises(order, exercise:exercises(name))')
          .eq('user_id', userId)
          .eq('is_active', false)
          .not('finished_at', 'is', null)
          .order('finished_at', ascending: false)
          .range(offset, offset + limit - 1);
      return data.map(_workoutFromHistoryRow).toList();
    });
  }

  /// Maps a history query row (with joined workout_exercises) to a [Workout]
  /// with [Workout.exerciseSummary] populated.
  static Workout _workoutFromHistoryRow(Map<String, dynamic> row) {
    final workout = Workout.fromJson(row);
    final summary = buildExerciseSummary(
      row['workout_exercises'] as List<dynamic>? ?? [],
    );
    return workout.copyWith(exerciseSummary: summary.isEmpty ? null : summary);
  }

  /// Builds a summary string like "Bench Press, Squat, Deadlift +2" from
  /// a list of joined workout_exercise rows that each contain an `exercise`
  /// sub-object with a `name` field.
  ///
  /// Exercises are sorted by their `order` field before naming.
  static String buildExerciseSummary(List<dynamic> workoutExercises) {
    if (workoutExercises.isEmpty) return '';

    // Sort by `order` to list exercises in the order they were performed.
    final sorted = [...workoutExercises]
      ..sort((a, b) {
        final aOrder = (a as Map<String, dynamic>)['order'] as int? ?? 0;
        final bOrder = (b as Map<String, dynamic>)['order'] as int? ?? 0;
        return aOrder.compareTo(bOrder);
      });

    // Collect exercise names, skipping any rows with missing join data.
    final names = <String>[];
    for (final item in sorted) {
      final exercise = (item as Map<String, dynamic>)['exercise'];
      if (exercise == null) continue;
      final name = (exercise as Map<String, dynamic>)['name'] as String?;
      if (name != null && name.isNotEmpty) names.add(name);
    }

    if (names.isEmpty) return '';

    const maxShown = 3;
    if (names.length <= maxShown) return names.join(', ');

    final shown = names.take(maxShown).join(', ');
    final remaining = names.length - maxShown;
    return '$shown +$remaining';
  }

  /// Get full workout detail with exercises and sets, parsed into typed data.
  Future<WorkoutDetail> getWorkoutDetail(String workoutId) {
    return mapException(() async {
      final data = await _workouts
          .select('*, workout_exercises(*, exercise:exercises(*), sets(*))')
          .eq('id', workoutId)
          .single();
      return parseWorkoutDetail(data);
    });
  }

  /// One row in the per-exercise progress query.
  ///
  /// Returned in `finished_at` order (ascending). The chart provider buckets
  /// these per user-local calendar date and selects the max completed
  /// working-set weight per bucket.
  ///
  /// [finishedAt] — UTC timestamp from `workouts.finished_at`.
  /// [sets] — raw sets from `workout_exercises.sets` (unfiltered; the
  /// `isCompletedWorkingSet` predicate is applied client-side so the filter
  /// logic stays co-located with PR detection).
  static List<({DateTime finishedAt, List<ExerciseSet> sets})>
  _parseExerciseHistoryRows(List<dynamic> rows) {
    final result = <({DateTime finishedAt, List<ExerciseSet> sets})>[];
    for (final row in rows) {
      final map = row as Map<String, dynamic>;
      final workout = map['workouts'] as Map<String, dynamic>?;
      final finishedAtStr = workout?['finished_at'] as String?;
      if (finishedAtStr == null) continue;
      final finishedAt = DateTime.parse(finishedAtStr);
      final setsData = map['sets'] as List<dynamic>? ?? [];
      final sets = setsData
          .map((s) => ExerciseSet.fromJson(s as Map<String, dynamic>))
          .toList();
      result.add((finishedAt: finishedAt, sets: sets));
    }
    return result;
  }

  /// Fetch finished-workout history for a single [exerciseId] belonging to
  /// [userId].
  ///
  /// Returns one entry per `workout_exercises` row (one per session that
  /// logged this exercise), sorted ascending by `workouts.finished_at`.
  /// When [since] is non-null, only sessions finished on or after [since]
  /// are returned (used for the 90-day window).
  ///
  /// RLS-scoped to the current user via `workouts.user_id = userId`. The
  /// explicit `.eq('user_id', userId)` on the inner-joined workouts table
  /// matches the pattern used by [getFinishedWorkoutsSince] — Supabase RLS
  /// is the hard guarantee, this filter is defence-in-depth.
  Future<List<({DateTime finishedAt, List<ExerciseSet> sets})>>
  getExerciseHistory(
    String exerciseId, {
    required String userId,
    DateTime? since,
  }) {
    return mapException(() async {
      var query = _client
          .from('workout_exercises')
          .select('sets(*), workouts!inner(finished_at, user_id, is_active)')
          .eq('exercise_id', exerciseId)
          .eq('workouts.user_id', userId)
          .eq('workouts.is_active', false)
          .not('workouts.finished_at', 'is', null);

      if (since != null) {
        query = query.gte('workouts.finished_at', since.toIso8601String());
      }

      final data = await query.order(
        'finished_at',
        referencedTable: 'workouts',
        ascending: true,
      );

      return _parseExerciseHistoryRows(data);
    });
  }

  /// Batch-fetch the most recent completed sets for given exercise IDs.
  /// Returns a map of exerciseId -> list of sets from the last workout.
  ///
  /// Note: relies on Supabase returning rows ordered by the `finished_at DESC`
  /// clause. The `seen` set deduplicates to keep only the first (most recent)
  /// entry per exercise.
  Future<Map<String, List<ExerciseSet>>> getLastWorkoutSets(
    List<String> exerciseIds,
  ) {
    return mapException(() async {
      if (exerciseIds.isEmpty) return {};

      final data = await _client
          .from('workout_exercises')
          .select('exercise_id, sets(*), workouts!inner(finished_at)')
          .inFilter('exercise_id', exerciseIds)
          .not('workouts.finished_at', 'is', null)
          .order('finished_at', referencedTable: 'workouts', ascending: false);

      final result = <String, List<ExerciseSet>>{};
      final seen = <String>{};

      for (final row in data) {
        final exerciseId = row['exercise_id'] as String;
        if (seen.contains(exerciseId)) continue;
        seen.add(exerciseId);

        final setsData = row['sets'] as List<dynamic>? ?? [];
        result[exerciseId] = setsData
            .map((s) => ExerciseSet.fromJson(s as Map<String, dynamic>))
            .toList();
      }
      return result;
    });
  }

  /// Get the total count of finished workouts for a user.
  Future<int> getFinishedWorkoutCount(String userId) {
    return mapException(() async {
      final result = await _workouts
          .select()
          .eq('user_id', userId)
          .eq('is_active', false)
          .not('finished_at', 'is', null)
          .count(supabase.CountOption.exact);
      return result.count;
    });
  }

  /// Discard (delete) an active workout.
  Future<void> discardWorkout(String workoutId, {required String userId}) {
    return mapException(() async {
      await _workouts.delete().eq('id', workoutId).eq('user_id', userId);
    });
  }

  /// Get finished workouts for a user that were completed on or after [since].
  ///
  /// Filters on `finished_at` (not `started_at`) so volume is attributed to
  /// the week the workout was *completed*. A workout started Sunday 23:45 and
  /// finished Monday 00:10 counts as Monday's week.
  ///
  /// Used by the week volume provider to fetch all completed workouts
  /// from the current week. Returns workout details with sets so volume
  /// can be calculated client-side.
  Future<List<WorkoutDetail>> getFinishedWorkoutsSince(
    String userId,
    DateTime since,
  ) {
    return mapException(() async {
      final data = await _workouts
          .select('*, workout_exercises(*, exercise:exercises(*), sets(*))')
          .eq('user_id', userId)
          .eq('is_active', false)
          .not('finished_at', 'is', null)
          .gte('finished_at', since.toIso8601String())
          .order('finished_at', ascending: false);
      return data.map(parseWorkoutDetail).toList();
    });
  }

  /// Delete all finished, non-active workouts for a user.
  ///
  /// Active workouts (in-progress) are never deleted.
  /// Cascade-deletes workout_exercises and sets via FK constraints.
  Future<void> clearHistory(String userId) {
    return mapException(() async {
      await _workouts
          .delete()
          .eq('user_id', userId)
          .eq('is_active', false)
          .not('finished_at', 'is', null);
    });
  }

  /// Parse a workout detail response into structured data.
  static WorkoutDetail parseWorkoutDetail(Map<String, dynamic> data) {
    final workout = Workout.fromJson(data);
    final exercisesData = data['workout_exercises'] as List<dynamic>? ?? [];

    final exercises = <WorkoutExercise>[];
    final setsByExercise = <String, List<ExerciseSet>>{};

    for (final weData in exercisesData) {
      final weMap = weData as Map<String, dynamic>;

      Exercise? exercise;
      if (weMap['exercise'] != null) {
        exercise = Exercise.fromJson(weMap['exercise'] as Map<String, dynamic>);
      }

      final we = WorkoutExercise.fromJson(weMap).copyWith(exercise: exercise);
      exercises.add(we);

      final setsData = weMap['sets'] as List<dynamic>? ?? [];
      setsByExercise[we.id] =
          setsData
              .map((s) => ExerciseSet.fromJson(s as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => a.setNumber.compareTo(b.setNumber));
    }

    exercises.sort((a, b) => a.order.compareTo(b.order));
    return (
      workout: workout,
      exercises: exercises,
      setsByExercise: setsByExercise,
    );
  }
}
