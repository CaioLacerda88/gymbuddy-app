import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/data/base_repository.dart';
import '../../exercises/models/exercise.dart';
import '../models/personal_record.dart';

class PRRepository extends BaseRepository {
  const PRRepository(this._client);

  final supabase.SupabaseClient _client;

  supabase.SupabaseQueryBuilder get _records =>
      _client.from('personal_records');

  /// Fetch personal records for a list of exercise IDs.
  ///
  /// Returns a map of exerciseId -> list of [PersonalRecord].
  Future<Map<String, List<PersonalRecord>>> getRecordsForExercises(
    List<String> exerciseIds,
  ) {
    return mapException(() async {
      if (exerciseIds.isEmpty) return {};

      final data = await _records.select().inFilter('exercise_id', exerciseIds);

      final result = <String, List<PersonalRecord>>{};
      for (final row in data) {
        final record = PersonalRecord.fromJson(row);
        (result[record.exerciseId] ??= []).add(record);
      }
      return result;
    });
  }

  /// Fetch all personal records for a user, ordered by most recent first.
  Future<List<PersonalRecord>> getRecordsForUser(String userId) {
    return mapException(() async {
      final data = await _records
          .select()
          .eq('user_id', userId)
          .order('achieved_at', ascending: false);

      return data.map(PersonalRecord.fromJson).toList();
    });
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
    });
  }
}
