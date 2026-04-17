import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/data/base_repository.dart';
import '../../../core/local_storage/cache_service.dart';
import '../../../core/local_storage/hive_service.dart';
import '../../exercises/models/exercise.dart';
import '../models/personal_record.dart';

class PRRepository extends BaseRepository {
  const PRRepository(this._client, this._cache);

  final supabase.SupabaseClient _client;
  final CacheService _cache;

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

  /// Fetch all personal records for a user with exercise details (name, equipment).
  ///
  /// Uses a Supabase join to include exercise info in one query.
  Future<
    List<
      ({
        PersonalRecord record,
        String exerciseName,
        EquipmentType equipmentType,
      })
    >
  >
  getRecordsWithExercises(String userId) {
    return mapException(() async {
      final data = await _records
          .select('*, exercises(name, equipment_type)')
          .eq('user_id', userId)
          .order('achieved_at', ascending: false);

      return data.map(_parseRecordWithExercise).toList();
    });
  }

  /// Fetch the most recent personal records for a user with exercise details.
  ///
  /// Uses a Supabase join with a server-side LIMIT to avoid over-fetching.
  Future<
    List<
      ({
        PersonalRecord record,
        String exerciseName,
        EquipmentType equipmentType,
      })
    >
  >
  getRecentRecordsWithExercises(String userId, {int limit = 3}) {
    return mapException(() async {
      final data = await _records
          .select('*, exercises(name, equipment_type)')
          .eq('user_id', userId)
          .order('achieved_at', ascending: false)
          .limit(limit);

      return data.map(_parseRecordWithExercise).toList();
    });
  }

  /// Parse a row with joined exercise data into a typed record.
  static ({
    PersonalRecord record,
    String exerciseName,
    EquipmentType equipmentType,
  })
  _parseRecordWithExercise(Map<String, dynamic> row) {
    final exerciseData = row['exercises'] as Map<String, dynamic>?;
    final exerciseName =
        (exerciseData?['name'] as String?) ?? 'Unknown Exercise';
    final equipmentType = EquipmentType.fromString(
      (exerciseData?['equipment_type'] as String?) ?? 'barbell',
    );

    final recordRow = Map<String, dynamic>.from(row)..remove('exercises');
    final record = PersonalRecord.fromJson(recordRow);

    return (
      record: record,
      exerciseName: exerciseName,
      equipmentType: equipmentType,
    );
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
