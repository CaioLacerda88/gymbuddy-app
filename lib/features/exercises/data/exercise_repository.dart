import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/data/base_repository.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/local_storage/cache_service.dart';
import '../../../core/local_storage/hive_service.dart';
import '../models/exercise.dart';

class ExerciseRepository extends BaseRepository {
  const ExerciseRepository(this._client, this._cache);

  final supabase.SupabaseClient _client;
  final CacheService _cache;

  supabase.SupabaseQueryBuilder get _exercises => _client.from('exercises');

  /// Builds a deterministic cache key from optional filters.
  static String _cacheKey({
    MuscleGroup? muscleGroup,
    EquipmentType? equipmentType,
  }) {
    if (muscleGroup == null && equipmentType == null) return 'all';
    final parts = <String>[];
    if (muscleGroup != null) parts.add('muscle=${muscleGroup.name}');
    if (equipmentType != null) parts.add('equip=${equipmentType.name}');
    return parts.join('&');
  }

  /// Fetch exercises, optionally filtered by muscle group and equipment type.
  ///
  /// Uses read-through caching: returns cached data on network failure.
  Future<List<Exercise>> getExercises({
    MuscleGroup? muscleGroup,
    EquipmentType? equipmentType,
  }) async {
    final key = _cacheKey(
      muscleGroup: muscleGroup,
      equipmentType: equipmentType,
    );
    final cached = _cache.read<List<Exercise>>(
      HiveService.exerciseCache,
      key,
      (json) => (json as List)
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

    try {
      final fresh = await mapException(() async {
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

      // Fire-and-forget cache write.
      _cache.write(
        HiveService.exerciseCache,
        key,
        fresh.map((e) => e.toJson()).toList(),
      );

      return fresh;
    } catch (e) {
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Escapes special Postgres LIKE/ILIKE pattern characters.
  String _escapeLikePattern(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  /// Search exercises by name (case-insensitive), with optional filters.
  ///
  /// On network failure, falls back to filtering the cached "all" entry
  /// in-memory. If no cache is available, rethrows the original error.
  Future<List<Exercise>> searchExercises(
    String query, {
    MuscleGroup? muscleGroup,
    EquipmentType? equipmentType,
  }) async {
    try {
      return await mapException(() async {
        final escaped = _escapeLikePattern(query);
        var q = _exercises
            .select()
            .isFilter('deleted_at', null)
            .ilike('name', '%$escaped%');
        if (muscleGroup != null) {
          q = q.eq('muscle_group', muscleGroup.name);
        }
        if (equipmentType != null) {
          q = q.eq('equipment_type', equipmentType.name);
        }
        final data = await q.order('name');
        return data.map(Exercise.fromJson).toList();
      });
    } catch (e) {
      // Offline fallback: filter the "all" cache in-memory.
      final cached = _cache.read<List<Exercise>>(
        HiveService.exerciseCache,
        'all',
        (json) => (json as List)
            .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      if (cached == null) rethrow;

      final lowerQuery = query.toLowerCase();
      return cached.where((exercise) {
        if (!exercise.name.toLowerCase().contains(lowerQuery)) return false;
        if (muscleGroup != null && exercise.muscleGroup != muscleGroup) {
          return false;
        }
        if (equipmentType != null && exercise.equipmentType != equipmentType) {
          return false;
        }
        return true;
      }).toList();
    }
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
    String? description,
    String? formTips,
  }) {
    return mapException(() async {
      try {
        final payload = <String, dynamic>{
          'name': name,
          'muscle_group': muscleGroup.name,
          'equipment_type': equipmentType.name,
          'is_default': false,
          'user_id': userId,
        };
        if (description != null && description.isNotEmpty) {
          payload['description'] = description;
        }
        if (formTips != null && formTips.isNotEmpty) {
          payload['form_tips'] = formTips;
        }
        final data = await _exercises.insert(payload).select().single();
        _cache.clearBox(HiveService.exerciseCache);
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
      _cache.clearBox(HiveService.exerciseCache);
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
