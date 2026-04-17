import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/data/base_repository.dart';
import '../../../core/local_storage/cache_service.dart';
import '../../../core/local_storage/hive_service.dart';
import '../../exercises/models/exercise.dart';
import '../models/routine.dart';

class RoutineRepository extends BaseRepository {
  const RoutineRepository(this._client, this._cache);

  final supabase.SupabaseClient _client;
  final CacheService _cache;

  supabase.SupabaseQueryBuilder get _templates =>
      _client.from('workout_templates');

  /// Fetch routines owned by [userId] plus all default routines, newest first.
  ///
  /// Uses read-through caching: returns cached data on network failure.
  Future<List<Routine>> getRoutines(String userId) async {
    final cached = _readCachedRoutines(userId);

    try {
      final fresh = await mapException(() async {
        final data = await _templates
            .select()
            .or('user_id.eq.$userId,is_default.eq.true')
            .order('created_at', ascending: false);

        final routines = data.map(_parseRoutineRow).toList();
        return _resolveExercises(routines);
      });

      // Fire-and-forget cache write.
      _writeCachedRoutines(userId, fresh);

      return fresh;
    } catch (e) {
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Fetch a single routine by [id] with exercise details resolved.
  Future<Routine> getRoutine(String id) {
    return mapException(() async {
      final data = await _templates.select().eq('id', id).single();
      final routine = _parseRoutineRow(data);
      final resolved = await _resolveExercises([routine]);
      return resolved.first;
    });
  }

  /// Insert a new user-created routine and return it with exercises resolved.
  Future<Routine> createRoutine({
    required String userId,
    required String name,
    required List<RoutineExercise> exercises,
  }) {
    return mapException(() async {
      final data = await _templates
          .insert({
            'user_id': userId,
            'name': name,
            'is_default': false,
            'exercises': exercises.map((e) => e.toJson()).toList(),
          })
          .select()
          .single();

      final routine = _parseRoutineRow(data);
      final resolved = await _resolveExercises([routine]);
      _cache.delete(HiveService.routineCache, userId);
      return resolved.first;
    });
  }

  /// Update [name] and [exercises] for the given routine (user_id must match).
  Future<Routine> updateRoutine({
    required String id,
    required String userId,
    required String name,
    required List<RoutineExercise> exercises,
  }) {
    return mapException(() async {
      final data = await _templates
          .update({
            'name': name,
            'exercises': exercises.map((e) => e.toJson()).toList(),
          })
          .eq('id', id)
          .eq('user_id', userId)
          .select()
          .single();

      final routine = _parseRoutineRow(data);
      final resolved = await _resolveExercises([routine]);
      _cache.delete(HiveService.routineCache, userId);
      return resolved.first;
    });
  }

  /// Delete a user-created routine. Fails silently if [id] doesn't exist or
  /// belongs to a different user. Default routines are never matched because
  /// they have no user_id equal to [userId].
  Future<void> deleteRoutine(String id, {required String userId}) {
    return mapException(() async {
      await _templates
          .delete()
          .eq('id', id)
          .eq('user_id', userId)
          .eq('is_default', false);
      _cache.delete(HiveService.routineCache, userId);
    });
  }

  // ---------------------------------------------------------------------------
  // Cache helpers
  // ---------------------------------------------------------------------------

  /// Writes routines to cache with a separate exercise map so that
  /// [RoutineExercise.exercise] (excluded from `toJson()`) survives roundtrip.
  void _writeCachedRoutines(String userId, List<Routine> routines) {
    final exerciseMap = <String, Map<String, dynamic>>{};
    for (final r in routines) {
      for (final re in r.exercises) {
        if (re.exercise != null) {
          exerciseMap[re.exerciseId] = re.exercise!.toJson();
        }
      }
    }
    _cache.write(HiveService.routineCache, userId, {
      'routines': routines.map((r) => r.toJson()).toList(),
      'exercises': exerciseMap,
    });
  }

  /// Reads routines from cache, re-resolving exercise references from the
  /// stored exercise map.
  List<Routine>? _readCachedRoutines(String userId) {
    return _cache.read<List<Routine>>(HiveService.routineCache, userId, (json) {
      final map = json as Map<String, dynamic>;
      final routineList = (map['routines'] as List)
          .map((e) => Routine.fromJson(e as Map<String, dynamic>))
          .toList();
      final exercises = (map['exercises'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, Exercise.fromJson(v as Map<String, dynamic>)),
      );
      return routineList.map((routine) {
        final resolved = routine.exercises.map((re) {
          final exercise = exercises[re.exerciseId];
          return exercise != null ? re.copyWith(exercise: exercise) : re;
        }).toList();
        return routine.copyWith(exercises: resolved);
      }).toList();
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Parse a raw Supabase row into a [Routine].
  ///
  /// Supabase returns JSONB columns as native Dart lists/maps, so
  /// [Routine.fromJson] handles the exercises array directly.
  static Routine _parseRoutineRow(Map<String, dynamic> row) {
    return Routine.fromJson(row);
  }

  /// Resolve [RoutineExercise.exercise] for every exercise in [routines] by
  /// batch-fetching exercise rows and copying them onto each [RoutineExercise].
  Future<List<Routine>> _resolveExercises(List<Routine> routines) async {
    final exerciseMap = await _fetchExerciseMap(routines);

    return routines.map((routine) {
      final resolved = routine.exercises.map((re) {
        final exercise = exerciseMap[re.exerciseId];
        return exercise != null ? re.copyWith(exercise: exercise) : re;
      }).toList();
      return routine.copyWith(exercises: resolved);
    }).toList();
  }

  /// Collects all unique exercise IDs referenced by [routines], queries the
  /// exercises table (including soft-deleted rows so names are always available),
  /// and returns a map of id → [Exercise].
  Future<Map<String, Exercise>> _fetchExerciseMap(
    List<Routine> routines,
  ) async {
    final ids = <String>{
      for (final r in routines)
        for (final re in r.exercises) re.exerciseId,
    };

    if (ids.isEmpty) return {};

    final data = await _client
        .from('exercises')
        .select()
        .inFilter('id', ids.toList());

    return {
      for (final row in data) row['id'] as String: Exercise.fromJson(row),
    };
  }
}
