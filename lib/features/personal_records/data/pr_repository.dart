import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/data/base_repository.dart';
import '../../../core/local_storage/cache_service.dart';
import '../../../core/local_storage/hive_service.dart';
import '../../exercises/data/exercise_repository.dart';
import '../../exercises/models/exercise.dart';
import '../models/personal_record.dart';

/// Repository for personal record reads and writes.
///
/// **Phase 15f Stage 6 contract:**
/// `getRecordsWithExercises` and `getRecentRecordsWithExercises` no longer use
/// the embedded `exercises(name, equipment_type)` select (the `name` column
/// was dropped in migration 00034). Instead they use a two-step flow:
///   1. fetch personal_records rows alone,
///   2. collect distinct `exercise_id`s and call
///      `ExerciseRepository.getExercisesByIds(locale, userId, ids)` —
///      one batch RPC, N+1 safe.
///
/// Missing exercises (soft-deleted or foreign-owned) silently fall back to
/// `'Unknown Exercise'` + `EquipmentType.barbell` so the UI never crashes.
class PRRepository extends BaseRepository {
  const PRRepository(this._client, this._cache, this._exerciseRepo);

  final supabase.SupabaseClient _client;
  final CacheService _cache;
  final ExerciseRepository _exerciseRepo;

  supabase.SupabaseQueryBuilder get _records =>
      _client.from('personal_records');

  /// Fetch personal records for a list of exercise IDs.
  ///
  /// Returns a map of exerciseId -> list of [PersonalRecord].
  /// Uses read-through caching: returns cached data on network failure.
  Future<Map<String, List<PersonalRecord>>> getRecordsForExercises(
    List<String> exerciseIds,
  ) async {
    if (exerciseIds.isEmpty) return {};

    final key =
        'exercises:${(List<String>.from(exerciseIds)..sort()).join(',')}';
    final cached = _cache.read<Map<String, List<PersonalRecord>>>(
      HiveService.prCache,
      key,
      (json) {
        final map = json as Map<String, dynamic>;
        return map.map(
          (k, v) => MapEntry(
            k,
            (v as List)
                .map((e) => PersonalRecord.fromJson(e as Map<String, dynamic>))
                .toList(),
          ),
        );
      },
    );

    try {
      final fresh = await mapException(() async {
        final data = await _records.select().inFilter(
          'exercise_id',
          exerciseIds,
        );

        final result = <String, List<PersonalRecord>>{};
        for (final row in data) {
          final record = PersonalRecord.fromJson(row);
          (result[record.exerciseId] ??= []).add(record);
        }
        return result;
      });

      // Fire-and-forget cache write.
      _cache.write(
        HiveService.prCache,
        key,
        fresh.map((k, v) => MapEntry(k, v.map((r) => r.toJson()).toList())),
      );

      return fresh;
    } catch (e) {
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Fetch all personal records for a user, ordered by most recent first.
  ///
  /// Uses read-through caching: returns cached data on network failure.
  Future<List<PersonalRecord>> getRecordsForUser(String userId) async {
    final cached = _cache.read<List<PersonalRecord>>(
      HiveService.prCache,
      userId,
      (json) => (json as List)
          .map((e) => PersonalRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

    try {
      final fresh = await mapException(() async {
        final data = await _records
            .select()
            .eq('user_id', userId)
            .order('achieved_at', ascending: false);

        return data.map(PersonalRecord.fromJson).toList();
      });

      // Fire-and-forget cache write.
      _cache.write(
        HiveService.prCache,
        userId,
        fresh.map((r) => r.toJson()).toList(),
      );

      return fresh;
    } catch (e) {
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Fetch all personal records for a user with exercise details
  /// (name, equipment), localized for [locale].
  ///
  /// Two queries: PRs alone, then a batch RPC for the exercises referenced.
  Future<
    List<
      ({
        PersonalRecord record,
        String exerciseName,
        EquipmentType equipmentType,
      })
    >
  >
  getRecordsWithExercises({required String userId, required String locale}) {
    return mapException(() async {
      final data = await _records
          .select()
          .eq('user_id', userId)
          .order('achieved_at', ascending: false);

      return _attachExercises(
        rows: data.cast<Map<String, dynamic>>(),
        userId: userId,
        locale: locale,
      );
    });
  }

  /// Fetch the most recent personal records for a user with exercise details,
  /// localized for [locale].
  ///
  /// Server-side LIMIT applied to the PR query before the batch lookup.
  Future<
    List<
      ({
        PersonalRecord record,
        String exerciseName,
        EquipmentType equipmentType,
      })
    >
  >
  getRecentRecordsWithExercises({
    required String userId,
    required String locale,
    int limit = 3,
  }) {
    return mapException(() async {
      final data = await _records
          .select()
          .eq('user_id', userId)
          .order('achieved_at', ascending: false)
          .limit(limit);

      return _attachExercises(
        rows: data.cast<Map<String, dynamic>>(),
        userId: userId,
        locale: locale,
      );
    });
  }

  /// Resolve `exercise_id` references on a page of PR rows by batch-fetching
  /// the localized exercises and attaching `(name, equipmentType)` to each.
  ///
  /// Missing exercises (soft-deleted, foreign-owned, or visible to the RPC's
  /// visibility predicate but not in the result map for any reason) fall back
  /// to `'Unknown Exercise'` + `EquipmentType.barbell`. Callers must not crash
  /// on absent keys.
  Future<
    List<
      ({
        PersonalRecord record,
        String exerciseName,
        EquipmentType equipmentType,
      })
    >
  >
  _attachExercises({
    required List<Map<String, dynamic>> rows,
    required String userId,
    required String locale,
  }) async {
    if (rows.isEmpty) return const [];

    final exerciseIds = <String>{
      for (final row in rows)
        if (row['exercise_id'] != null) row['exercise_id'] as String,
    }.toList();

    final exerciseMap = exerciseIds.isEmpty
        ? const <String, Exercise>{}
        : await _exerciseRepo.getExercisesByIds(
            locale: locale,
            userId: userId,
            ids: exerciseIds,
          );

    return rows.map((row) {
      final record = PersonalRecord.fromJson(row);
      final ex = exerciseMap[record.exerciseId];
      return (
        record: record,
        exerciseName: ex?.name ?? 'Unknown Exercise',
        equipmentType: ex?.equipmentType ?? EquipmentType.barbell,
      );
    }).toList();
  }

  /// Fetch personal records that were achieved in a specific workout.
  ///
  /// Uses a two-query approach:
  /// 1. Fetch all set IDs belonging to the workout via the
  ///    `workout_exercises` join.
  /// 2. Filter `personal_records` to only those whose `set_id` is in that list.
  Future<List<PersonalRecord>> getPRsForWorkout(
    String workoutId,
    String userId,
  ) {
    return mapException(() async {
      final setRows = await _client
          .from('sets')
          .select('id, workout_exercises!inner(workout_id)')
          .eq('workout_exercises.workout_id', workoutId);

      final setIds = setRows.map<String>((r) => r['id'] as String).toList();

      if (setIds.isEmpty) return [];

      final data = await _records
          .select()
          .eq('user_id', userId)
          .inFilter('set_id', setIds);

      return data.map(PersonalRecord.fromJson).toList();
    });
  }

  /// Get the total count of personal records for a user.
  Future<int> getRecordCount(String userId) {
    return mapException(() async {
      final result = await _records
          .select()
          .eq('user_id', userId)
          .count(supabase.CountOption.exact);
      return result.count;
    });
  }

  /// Delete all personal records for a user.
  Future<void> clearAllRecords(String userId) {
    return mapException(() async {
      await _records.delete().eq('user_id', userId);
      _cache.clearBox(HiveService.prCache);
    });
  }

  /// Upsert personal records.
  ///
  /// Uses the unique constraint on (user_id, exercise_id, record_type) to
  /// update existing records or insert new ones.
  Future<void> upsertRecords(List<PersonalRecord> records) {
    return mapException(() async {
      if (records.isEmpty) return;

      final rows = records.map((r) => r.toJson()).toList();
      await _records.upsert(
        rows,
        onConflict: 'user_id, exercise_id, record_type',
      );
      _cache.clearBox(HiveService.prCache);
    });
  }
}
