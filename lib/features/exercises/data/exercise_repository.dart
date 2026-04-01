import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/data/base_repository.dart';
import '../../../core/exceptions/app_exception.dart';
import '../models/exercise.dart';

class ExerciseRepository extends BaseRepository {
  const ExerciseRepository(this._client);

  final supabase.SupabaseClient _client;

  supabase.SupabaseQueryBuilder get _exercises => _client.from('exercises');

  /// Fetch exercises, optionally filtered by muscle group and equipment type.
  Future<List<Exercise>> getExercises({
    MuscleGroup? muscleGroup,
    EquipmentType? equipmentType,
  }) {
    return mapException(() async {
      var query = _exercises.select().isFilter('deleted_at', null);
      if (muscleGroup != null) {
        query = query.eq('muscle_group', muscleGroup.name);
      }
      if (equipmentType != null) {
        query = query.eq('equipment_type', equipmentType.name);
      }
      final data = await query.order('name');
      return data.map(Exercise.fromJson).toList();
    });
  }

  /// Search exercises by name (case-insensitive), with optional filters.
  Future<List<Exercise>> searchExercises(
    String query, {
    MuscleGroup? muscleGroup,
    EquipmentType? equipmentType,
  }) {
    return mapException(() async {
      var q = _exercises
          .select()
          .isFilter('deleted_at', null)
          .ilike('name', '%$query%');
      if (muscleGroup != null) {
        q = q.eq('muscle_group', muscleGroup.name);
      }
      if (equipmentType != null) {
        q = q.eq('equipment_type', equipmentType.name);
      }
      final data = await q.order('name');
      return data.map(Exercise.fromJson).toList();
    });
  }

  /// Get a single exercise by ID.
  Future<Exercise> getExerciseById(String id) {
    return mapException(() async {
      final data = await _exercises.select().eq('id', id).single();
      return Exercise.fromJson(data);
    });
  }

  /// Create a user-defined exercise.
  Future<Exercise> createExercise({
    required String name,
    required MuscleGroup muscleGroup,
    required EquipmentType equipmentType,
    required String userId,
  }) {
    return mapException(() async {
      try {
        final data = await _exercises
            .insert({
              'name': name,
              'muscle_group': muscleGroup.name,
              'equipment_type': equipmentType.name,
              'is_default': false,
              'user_id': userId,
            })
            .select()
            .single();
        return Exercise.fromJson(data);
      } on supabase.PostgrestException catch (e) {
        if (e.code == '23505') {
          throw const ValidationException(
            'An exercise with this name already exists',
            field: 'name',
          );
        }
        rethrow;
      }
    });
  }

  /// Soft-delete an exercise by setting deleted_at.
  Future<void> softDeleteExercise(String id, {required String userId}) {
    return mapException(() async {
      await _exercises
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', id)
          .eq('user_id', userId);
    });
  }

  /// Get recent exercises (user-created + defaults), ordered by most recent.
  Future<List<Exercise>> recentExercises(String userId, {int limit = 10}) {
    return mapException(() async {
      final data = await _exercises
          .select()
          .isFilter('deleted_at', null)
          .or('user_id.eq.$userId,is_default.eq.true')
          .order('created_at', ascending: false)
          .limit(limit);
      return data.map(Exercise.fromJson).toList();
    });
  }
}
