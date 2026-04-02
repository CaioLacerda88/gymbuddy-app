import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/data/base_repository.dart';
import '../../exercises/models/exercise.dart';
import '../models/exercise_set.dart';
import '../models/workout.dart';
import '../models/workout_exercise.dart';

class WorkoutRepository extends BaseRepository {
  const WorkoutRepository(this._client);

  final supabase.SupabaseClient _client;

  supabase.SupabaseQueryBuilder get _workouts => _client.from('workouts');

  /// Atomically save a finished workout via the save_workout RPC.
  Future<Workout> saveWorkout({
    required Map<String, dynamic> workout,
    required List<Map<String, dynamic>> exercises,
    required List<Map<String, dynamic>> sets,
  }) {
    return mapException(() async {
      final result = await _client.rpc(
        'save_workout',
        params: {
          'p_workout': workout,
          'p_exercises': exercises,
          'p_sets': sets,
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
  Future<List<Workout>> getWorkoutHistory(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) {
    return mapException(() async {
      final data = await _workouts
          .select()
          .eq('user_id', userId)
          .eq('is_active', false)
          .not('finished_at', 'is', null)
          .order('finished_at', ascending: false)
          .range(offset, offset + limit - 1);
      return data.map(Workout.fromJson).toList();
    });
  }

  /// Get full workout detail with exercises and sets.
  Future<Map<String, dynamic>> getWorkoutDetail(String workoutId) {
    return mapException(() async {
      final data = await _workouts
          .select('*, workout_exercises(*, exercise:exercises(*), sets(*))')
          .eq('id', workoutId)
          .single();
      return data;
    });
  }

  /// Batch-fetch the most recent completed sets for given exercise IDs.
  /// Returns a map of exerciseId -> list of sets from the last workout.
  Future<Map<String, List<ExerciseSet>>> getLastWorkoutSets(
    List<String> exerciseIds,
  ) {
    return mapException(() async {
      if (exerciseIds.isEmpty) return {};

      // Find the most recent finished workout_exercises for each exercise
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

  /// Discard (delete) an active workout.
  Future<void> discardWorkout(String workoutId) {
    return mapException(() async {
      await _workouts.delete().eq('id', workoutId);
    });
  }

  /// Parse a workout detail response into structured data.
  static ({
    Workout workout,
    List<WorkoutExercise> exercises,
    Map<String, List<ExerciseSet>> setsByExercise,
  })
  parseWorkoutDetail(Map<String, dynamic> data) {
    final workout = Workout.fromJson(data);
    final exercisesData = data['workout_exercises'] as List<dynamic>? ?? [];

    final exercises = <WorkoutExercise>[];
    final setsByExercise = <String, List<ExerciseSet>>{};

    for (final weData in exercisesData) {
      final weMap = weData as Map<String, dynamic>;

      // Parse exercise if joined
      Exercise? exercise;
      if (weMap['exercise'] != null) {
        exercise = Exercise.fromJson(weMap['exercise'] as Map<String, dynamic>);
      }

      final we = WorkoutExercise.fromJson(weMap).copyWith(exercise: exercise);
      exercises.add(we);

      // Parse sets
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
