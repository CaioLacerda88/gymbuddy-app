import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/local_storage/cache_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:gymbuddy_app/features/workouts/data/workout_repository.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('WorkoutRepository cached workout count', () {
    late Directory tempDir;
    late WorkoutRepository repo;
    const cache = CacheService();
    const testUserId = 'user-001';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_workout_count_');
      Hive.init(tempDir.path);
      await Hive.openBox<dynamic>('user_prefs');
      repo = WorkoutRepository(_MockSupabaseClient(), cache);
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('getCachedWorkoutCount returns null when no cached value', () {
      final result = repo.getCachedWorkoutCount(testUserId);
      expect(result, isNull);
    });

    test('incrementCachedWorkoutCount starts from 0 when no cache', () {
      repo.incrementCachedWorkoutCount(testUserId);

      final result = repo.getCachedWorkoutCount(testUserId);
      expect(result, 1);
    });

    test('incrementCachedWorkoutCount increments existing value', () {
      // Seed with 5
      cache.write('user_prefs', 'finished_workout_count:$testUserId', 5);

      repo.incrementCachedWorkoutCount(testUserId);

      final result = repo.getCachedWorkoutCount(testUserId);
      expect(result, 6);
    });

    test('multiple increments accumulate', () {
      repo.incrementCachedWorkoutCount(testUserId);
      repo.incrementCachedWorkoutCount(testUserId);
      repo.incrementCachedWorkoutCount(testUserId);

      final result = repo.getCachedWorkoutCount(testUserId);
      expect(result, 3);
    });
  });
}
