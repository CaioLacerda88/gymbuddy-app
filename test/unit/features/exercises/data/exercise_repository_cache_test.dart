import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/local_storage/cache_service.dart';
import 'package:gymbuddy_app/core/local_storage/hive_service.dart';
import 'package:gymbuddy_app/features/exercises/data/exercise_repository.dart';
import 'package:gymbuddy_app/features/exercises/models/exercise.dart';
import 'package:hive/hive.dart';

import '../../../../fixtures/test_factories.dart';
import '../../../_helpers/fake_supabase.dart';

void main() {
  late Directory tempDir;
  late CacheService cache;
  late Box<dynamic> exerciseBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('exercise_cache_test_');
    Hive.init(tempDir.path);
    exerciseBox = await Hive.openBox<dynamic>(HiveService.exerciseCache);
    cache = const CacheService();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('ExerciseRepository cache — getExercises', () {
    test('writes to cache on network success', () async {
      final exerciseData = [
        TestExerciseFactory.create(id: 'ex-1', name: 'Bench Press'),
        TestExerciseFactory.create(
          id: 'ex-2',
          name: 'Squat',
          muscleGroup: 'legs',
        ),
      ];
      final client = FakeSupabaseClient(FakeQueryBuilder(data: exerciseData));
      final repo = ExerciseRepository(client, cache);

      await repo.getExercises();

      // Verify the cache box now has an entry under key "all".
      final raw = exerciseBox.get('all');
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw as String) as List;
      expect(decoded, hasLength(2));
    });

    test('returns cached data on network failure', () async {
      // Pre-populate cache.
      final exerciseJson = [
        TestExerciseFactory.create(id: 'ex-cached', name: 'Cached Press'),
      ];
      await exerciseBox.put('all', jsonEncode(exerciseJson));

      // Create repo with a client that throws.
      final client = FakeSupabaseClient(
        FakeQueryBuilder(error: Exception('network down')),
      );
      final repo = ExerciseRepository(client, cache);

      final result = await repo.getExercises();

      expect(result, hasLength(1));
      expect(result[0].name, 'Cached Press');
    });

    test('rethrows when no cache and network fails', () async {
      final client = FakeSupabaseClient(
        FakeQueryBuilder(error: Exception('network down')),
      );
      final repo = ExerciseRepository(client, cache);

      await expectLater(repo.getExercises(), throwsA(isA<Exception>()));
    });

    test('cache key uses composite filter', () async {
      final exerciseData = [
        TestExerciseFactory.create(
          id: 'ex-1',
          name: 'Bench Press',
          muscleGroup: 'chest',
          equipmentType: 'barbell',
        ),
      ];
      final client = FakeSupabaseClient(FakeQueryBuilder(data: exerciseData));
      final repo = ExerciseRepository(client, cache);

      await repo.getExercises(
        muscleGroup: MuscleGroup.chest,
        equipmentType: EquipmentType.barbell,
      );

      final raw = exerciseBox.get('muscle=chest&equip=barbell');
      expect(raw, isNotNull);
    });

    test('cache key for muscle-only filter (no equipment)', () async {
      final client = FakeSupabaseClient(FakeQueryBuilder(data: []));
      final repo = ExerciseRepository(client, cache);

      await repo.getExercises(muscleGroup: MuscleGroup.legs);

      final raw = exerciseBox.get('muscle=legs');
      expect(raw, isNotNull, reason: 'muscle-only key must be "muscle=<name>"');
    });

    test('cache key for equipment-only filter (no muscle group)', () async {
      final client = FakeSupabaseClient(FakeQueryBuilder(data: []));
      final repo = ExerciseRepository(client, cache);

      await repo.getExercises(equipmentType: EquipmentType.dumbbell);

      final raw = exerciseBox.get('equip=dumbbell');
      expect(
        raw,
        isNotNull,
        reason: 'equipment-only key must be "equip=<name>"',
      );
    });

    test(
      'fresh data is readable from cache on subsequent offline call',
      () async {
        final exerciseData = [
          TestExerciseFactory.create(id: 'ex-fresh', name: 'Fresh Press'),
        ];
        // First call: network succeeds and writes to cache.
        final onlineClient = FakeSupabaseClient(
          FakeQueryBuilder(data: exerciseData),
        );
        await ExerciseRepository(onlineClient, cache).getExercises();

        // Second call: network fails — must return data from cache written above.
        final offlineClient = FakeSupabaseClient(
          FakeQueryBuilder(error: Exception('offline')),
        );
        final result = await ExerciseRepository(
          offlineClient,
          cache,
        ).getExercises();

        expect(result, hasLength(1));
        expect(result[0].name, 'Fresh Press');
      },
    );
  });

  group('ExerciseRepository cache — searchExercises', () {
    test(
      'falls back to in-memory filter over "all" cache when offline',
      () async {
        // Pre-populate the "all" cache with varied exercises.
        final allExercises = [
          TestExerciseFactory.create(id: 'ex-1', name: 'Bench Press'),
          TestExerciseFactory.create(
            id: 'ex-2',
            name: 'Squat',
            muscleGroup: 'legs',
          ),
          TestExerciseFactory.create(
            id: 'ex-3',
            name: 'Overhead Press',
            muscleGroup: 'shoulders',
          ),
        ];
        await exerciseBox.put('all', jsonEncode(allExercises));

        final client = FakeSupabaseClient(
          FakeQueryBuilder(error: Exception('offline')),
        );
        final repo = ExerciseRepository(client, cache);

        final result = await repo.searchExercises('press');

        expect(result, hasLength(2));
        expect(
          result.map((e) => e.name),
          containsAll(['Bench Press', 'Overhead Press']),
        );
      },
    );

    test('applies muscleGroup filter on in-memory fallback', () async {
      final allExercises = [
        TestExerciseFactory.create(
          id: 'ex-1',
          name: 'Bench Press',
          muscleGroup: 'chest',
        ),
        TestExerciseFactory.create(
          id: 'ex-2',
          name: 'Overhead Press',
          muscleGroup: 'shoulders',
        ),
      ];
      await exerciseBox.put('all', jsonEncode(allExercises));

      final client = FakeSupabaseClient(
        FakeQueryBuilder(error: Exception('offline')),
      );
      final repo = ExerciseRepository(client, cache);

      final result = await repo.searchExercises(
        'press',
        muscleGroup: MuscleGroup.chest,
      );

      expect(result, hasLength(1));
      expect(result[0].name, 'Bench Press');
    });

    test('applies equipmentType filter on in-memory fallback', () async {
      final allExercises = [
        TestExerciseFactory.create(
          id: 'ex-1',
          name: 'Bench Press',
          equipmentType: 'barbell',
        ),
        TestExerciseFactory.create(
          id: 'ex-2',
          name: 'Dumbbell Press',
          equipmentType: 'dumbbell',
        ),
      ];
      await exerciseBox.put('all', jsonEncode(allExercises));

      final client = FakeSupabaseClient(
        FakeQueryBuilder(error: Exception('offline')),
      );
      final repo = ExerciseRepository(client, cache);

      final result = await repo.searchExercises(
        'press',
        equipmentType: EquipmentType.barbell,
      );

      expect(result, hasLength(1));
      expect(result[0].name, 'Bench Press');
    });

    test(
      'rethrows when network fails and no "all" cache entry exists',
      () async {
        // No cache pre-populated.
        final client = FakeSupabaseClient(
          FakeQueryBuilder(error: Exception('offline')),
        );
        final repo = ExerciseRepository(client, cache);

        await expectLater(
          repo.searchExercises('press'),
          throwsA(isA<Exception>()),
        );
      },
    );
  });
}
