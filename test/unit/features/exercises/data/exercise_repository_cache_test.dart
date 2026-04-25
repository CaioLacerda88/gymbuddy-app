// Phase 15f Stage 6: cache keys are now locale-prefixed
// (`'<locale>:all'`, `'<locale>:muscle=chest'`, etc.) so en/pt entries
// coexist. Network calls go through the RPC fake; the cache layer behavior
// (read-through, offline fallback, fire-and-forget write) is otherwise
// identical to pre-Stage-6.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/local_storage/cache_service.dart';
import 'package:repsaga/core/local_storage/hive_service.dart';
import 'package:repsaga/features/exercises/data/exercise_repository.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';
import 'package:hive/hive.dart';

import '../../../../fixtures/rpc_fakes.dart';
import '../../../../fixtures/test_factories.dart';

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
    test('writes locale-prefixed key on network success', () async {
      final exerciseData = [
        TestExerciseFactory.create(id: 'ex-1', name: 'Bench Press'),
        TestExerciseFactory.create(
          id: 'ex-2',
          name: 'Squat',
          muscleGroup: 'legs',
          slug: 'squat',
        ),
      ];
      final client = FakeRpcClient()
        ..registerRpc('fn_exercises_localized', (_) => exerciseData);
      final repo = ExerciseRepository(client, cache);

      await repo.getExercises(locale: 'en', userId: 'user-001');

      // Cache key now includes locale.
      final raw = exerciseBox.get('en:all');
      expect(raw, isNotNull, reason: 'cache key should be locale-prefixed');
      final decoded = jsonDecode(raw as String) as List;
      expect(decoded, hasLength(2));
    });

    test('returns cached data on network failure', () async {
      // Pre-populate cache under the locale-prefixed key.
      final exerciseJson = [
        TestExerciseFactory.create(id: 'ex-cached', name: 'Cached Press'),
      ];
      await exerciseBox.put('en:all', jsonEncode(exerciseJson));

      // RPC throws.
      final client = FakeRpcClient()
        ..registerRpc(
          'fn_exercises_localized',
          (_) => throw Exception('network down'),
        );
      final repo = ExerciseRepository(client, cache);

      final result = await repo.getExercises(locale: 'en', userId: 'user-001');

      expect(result, hasLength(1));
      expect(result[0].name, 'Cached Press');
    });

    test('en cache does not satisfy pt request', () async {
      // Pre-populate "en:all" only.
      await exerciseBox.put(
        'en:all',
        jsonEncode([TestExerciseFactory.create(id: 'ex-en', name: 'EN entry')]),
      );

      // pt request hits the RPC and fails — must NOT fall back to en cache.
      final client = FakeRpcClient()
        ..registerRpc(
          'fn_exercises_localized',
          (_) => throw Exception('network down'),
        );
      final repo = ExerciseRepository(client, cache);

      await expectLater(
        repo.getExercises(locale: 'pt', userId: 'user-001'),
        throwsA(isA<Exception>()),
        reason: 'pt request must not pick up en-cached data',
      );
    });

    test('rethrows when no cache and network fails', () async {
      final client = FakeRpcClient()
        ..registerRpc(
          'fn_exercises_localized',
          (_) => throw Exception('network down'),
        );
      final repo = ExerciseRepository(client, cache);

      await expectLater(
        repo.getExercises(locale: 'en', userId: 'user-001'),
        throwsA(isA<Exception>()),
      );
    });

    test('cache key uses locale + composite filter', () async {
      final exerciseData = [
        TestExerciseFactory.create(
          id: 'ex-1',
          name: 'Bench Press',
          muscleGroup: 'chest',
          equipmentType: 'barbell',
        ),
      ];
      final client = FakeRpcClient()
        ..registerRpc('fn_exercises_localized', (_) => exerciseData);
      final repo = ExerciseRepository(client, cache);

      await repo.getExercises(
        locale: 'en',
        userId: 'user-001',
        muscleGroup: MuscleGroup.chest,
        equipmentType: EquipmentType.barbell,
      );

      final raw = exerciseBox.get('en:muscle=chest&equip=barbell');
      expect(raw, isNotNull);
    });

    test('cache key for muscle-only filter (no equipment)', () async {
      final client = FakeRpcClient()
        ..registerRpc('fn_exercises_localized', (_) => []);
      final repo = ExerciseRepository(client, cache);

      await repo.getExercises(
        locale: 'pt',
        userId: 'user-001',
        muscleGroup: MuscleGroup.legs,
      );

      final raw = exerciseBox.get('pt:muscle=legs');
      expect(
        raw,
        isNotNull,
        reason: 'muscle-only key must be "pt:muscle=legs"',
      );
    });

    test('cache key for equipment-only filter (no muscle group)', () async {
      final client = FakeRpcClient()
        ..registerRpc('fn_exercises_localized', (_) => []);
      final repo = ExerciseRepository(client, cache);

      await repo.getExercises(
        locale: 'en',
        userId: 'user-001',
        equipmentType: EquipmentType.dumbbell,
      );

      final raw = exerciseBox.get('en:equip=dumbbell');
      expect(
        raw,
        isNotNull,
        reason: 'equipment-only key must be "en:equip=dumbbell"',
      );
    });

    test(
      'fresh data is readable from cache on subsequent offline call',
      () async {
        final exerciseData = [
          TestExerciseFactory.create(id: 'ex-fresh', name: 'Fresh Press'),
        ];
        // First call: RPC succeeds and writes to cache.
        final onlineClient = FakeRpcClient()
          ..registerRpc('fn_exercises_localized', (_) => exerciseData);
        await ExerciseRepository(
          onlineClient,
          cache,
        ).getExercises(locale: 'en', userId: 'user-001');

        // Second call: RPC fails — must return data from cache written above.
        final offlineClient = FakeRpcClient()
          ..registerRpc(
            'fn_exercises_localized',
            (_) => throw Exception('offline'),
          );
        final result = await ExerciseRepository(
          offlineClient,
          cache,
        ).getExercises(locale: 'en', userId: 'user-001');

        expect(result, hasLength(1));
        expect(result[0].name, 'Fresh Press');
      },
    );
  });

  group('ExerciseRepository cache — searchExercises', () {
    test(
      'falls back to in-memory filter over locale "all" cache when offline',
      () async {
        // Pre-populate the "en:all" cache with varied exercises.
        final allExercises = [
          TestExerciseFactory.create(id: 'ex-1', name: 'Bench Press'),
          TestExerciseFactory.create(
            id: 'ex-2',
            name: 'Squat',
            muscleGroup: 'legs',
            slug: 'squat',
          ),
          TestExerciseFactory.create(
            id: 'ex-3',
            name: 'Overhead Press',
            muscleGroup: 'shoulders',
            slug: 'overhead_press',
          ),
        ];
        await exerciseBox.put('en:all', jsonEncode(allExercises));

        final client = FakeRpcClient()
          ..registerRpc(
            'fn_search_exercises_localized',
            (_) => throw Exception('offline'),
          );
        final repo = ExerciseRepository(client, cache);

        final result = await repo.searchExercises(
          locale: 'en',
          userId: 'user-001',
          query: 'press',
        );

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
          slug: 'overhead_press',
        ),
      ];
      await exerciseBox.put('en:all', jsonEncode(allExercises));

      final client = FakeRpcClient()
        ..registerRpc(
          'fn_search_exercises_localized',
          (_) => throw Exception('offline'),
        );
      final repo = ExerciseRepository(client, cache);

      final result = await repo.searchExercises(
        locale: 'en',
        userId: 'user-001',
        query: 'press',
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
          slug: 'dumbbell_press',
        ),
      ];
      await exerciseBox.put('en:all', jsonEncode(allExercises));

      final client = FakeRpcClient()
        ..registerRpc(
          'fn_search_exercises_localized',
          (_) => throw Exception('offline'),
        );
      final repo = ExerciseRepository(client, cache);

      final result = await repo.searchExercises(
        locale: 'en',
        userId: 'user-001',
        query: 'press',
        equipmentType: EquipmentType.barbell,
      );

      expect(result, hasLength(1));
      expect(result[0].name, 'Bench Press');
    });

    test(
      'rethrows when network fails and no locale "all" cache entry exists',
      () async {
        // No cache pre-populated.
        final client = FakeRpcClient()
          ..registerRpc(
            'fn_search_exercises_localized',
            (_) => throw Exception('offline'),
          );
        final repo = ExerciseRepository(client, cache);

        await expectLater(
          repo.searchExercises(
            locale: 'en',
            userId: 'user-001',
            query: 'press',
          ),
          throwsA(isA<Exception>()),
        );
      },
    );
  });
}
