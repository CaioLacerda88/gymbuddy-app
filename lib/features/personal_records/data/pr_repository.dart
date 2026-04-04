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

      return data.map((row) {
        final exerciseData = row['exercises'] as Map<String, dynamic>?;
        final exerciseName =
            (exerciseData?['name'] as String?) ?? 'Unknown Exercise';
        final equipmentType = EquipmentType.fromString(
          (exerciseData?['equipment_type'] as String?) ?? 'barbell',
        );

        // Remove the nested exercises key before parsing the record.
        final recordRow = Map<String, dynamic>.from(row)..remove('exercises');
        final record = PersonalRecord.fromJson(recordRow);

        return (
          record: record,
          exerciseName: exerciseName,
          equipmentType: equipmentType,
        );
      }).toList();
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
