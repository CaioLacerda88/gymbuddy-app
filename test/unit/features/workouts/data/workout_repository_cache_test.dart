import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/local_storage/cache_service.dart';
import 'package:repsaga/core/local_storage/hive_service.dart';
import 'package:repsaga/features/workouts/data/workout_repository.dart';
import 'package:hive/hive.dart';

import '../../../../fixtures/test_factories.dart';
import '../../../_helpers/fake_supabase.dart';

void main() {
  late Directory tempDir;
  late CacheService cache;
  late Box<dynamic> historyBox;
  late Box<dynamic> lastSetsBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('workout_cache_test_');
    Hive.init(tempDir.path);
    historyBox = await Hive.openBox<dynamic>(HiveService.workoutHistoryCache);
    lastSetsBox = await Hive.openBox<dynamic>(HiveService.lastSetsCache);
    cache = const CacheService();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('WorkoutRepository cache - getWorkoutHistory', () {
    // The cache is only active when offset==0 AND limit>=50 (the "refresh
    // pass"). Default UI fetches (limit=20) intentionally skip the cache to
    // avoid a small fetch overwriting a richer 50-item cache entry.

    test('cache preserves exerciseSummary through roundtrip', () async {
      // Pre-populate cache with a workout that has _exercise_summary.
      final workoutJson = TestWorkoutFactory.create(
        id: 'w-1',
        name: 'Push Day',
      );
      workoutJson['_exercise_summary'] = 'Bench Press, Squat';
      await historyBox.put('user-001', jsonEncode([workoutJson]));

      // Create repo with a failing client to force cache read.
      final client = FakeSupabaseClient(
        FakeQueryBuilder(error: Exception('offline')),
      );
      final repo = WorkoutRepository(client, cache);

      // Must use limit >= 50 to trigger the cache path.
      final result = await repo.getWorkoutHistory('user-001', limit: 50);

      expect(result, hasLength(1));
      expect(result[0].id, 'w-1');
      expect(result[0].exerciseSummary, 'Bench Press, Squat');
    });

    test('does not cache when limit < 50 (default UI fetch)', () async {
      final workoutData = [
        {
          ...TestWorkoutFactory.create(id: 'w-1'),
          'workout_exercises': <dynamic>[],
        },
      ];
      final client = FakeSupabaseClient(FakeQueryBuilder(data: workoutData));
      final repo = WorkoutRepository(client, cache);

      // Default limit (20) — must NOT write to cache.
      await repo.getWorkoutHistory('user-001');

      final raw = historyBox.get('user-001');
      expect(raw, isNull, reason: 'limit < 50 must not write to cache');
    });

    test('does not cache when offset > 0', () async {
      final workoutData = [
        {
          ...TestWorkoutFactory.create(id: 'w-1'),
          'workout_exercises': <dynamic>[],
        },
      ];
      final client = FakeSupabaseClient(FakeQueryBuilder(data: workoutData));
      final repo = WorkoutRepository(client, cache);

      // offset > 0 — must NOT cache even with limit >= 50.
      await repo.getWorkoutHistory('user-001', limit: 50, offset: 5);

      final raw = historyBox.get('user-001');
      expect(raw, isNull, reason: 'offset > 0 must not write to cache');
    });

    test('network failure returns cached data (limit >= 50)', () async {
      final workoutJson = TestWorkoutFactory.create(id: 'w-cached');
      await historyBox.put('user-001', jsonEncode([workoutJson]));

      final client = FakeSupabaseClient(
        FakeQueryBuilder(error: Exception('offline')),
      );
      final repo = WorkoutRepository(client, cache);

      // Must use limit >= 50 to trigger the cache path.
      final result = await repo.getWorkoutHistory('user-001', limit: 50);

      expect(result, hasLength(1));
      expect(result[0].id, 'w-cached');
    });

    test('rethrows when no cache and network fails', () async {
      final client = FakeSupabaseClient(
        FakeQueryBuilder(error: Exception('offline')),
      );
      final repo = WorkoutRepository(client, cache);

      // With limit >= 50, cache is checked but empty → must rethrow.
      await expectLater(
        repo.getWorkoutHistory('user-001', limit: 50),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'rethrows even with default limit when no cache (limit < 50 bypasses cache)',
      () async {
        final client = FakeSupabaseClient(
          FakeQueryBuilder(error: Exception('offline')),
        );
        final repo = WorkoutRepository(client, cache);

        // Default limit (20) — cache is bypassed entirely, error always propagates.
        await expectLater(
          repo.getWorkoutHistory('user-001'),
          throwsA(isA<Exception>()),
        );
      },
    );

    test(
      'fresh data is written and readable on subsequent offline call',
      () async {
        final workoutData = [
          {
            ...TestWorkoutFactory.create(id: 'w-written'),
            'workout_exercises': <dynamic>[],
          },
        ];
        // First call: network succeeds and writes to cache (limit >= 50).
        final onlineClient = FakeSupabaseClient(
          FakeQueryBuilder(data: workoutData),
        );
        await WorkoutRepository(
          onlineClient,
          cache,
        ).getWorkoutHistory('user-001', limit: 50);

        // Second call: network fails — must return data from cache written above.
        final offlineClient = FakeSupabaseClient(
          FakeQueryBuilder(error: Exception('offline')),
        );
        final result = await WorkoutRepository(
          offlineClient,
          cache,
        ).getWorkoutHistory('user-001', limit: 50);

        expect(result, hasLength(1));
        expect(result[0].id, 'w-written');
      },
    );
  });

  group('WorkoutRepository cache - getLastWorkoutSets', () {
    test('cache roundtrip works', () async {
      // Pre-populate cache with sets data.
      final setsData = {
        'exercise-001': [
          TestSetFactory.create(id: 'set-1', reps: 10, weight: 80.0),
          TestSetFactory.create(
            id: 'set-2',
            setNumber: 2,
            reps: 8,
            weight: 85.0,
          ),
        ],
      };
      const key = 'exercise-001';
      await lastSetsBox.put(key, jsonEncode(setsData));

      // Create repo with a failing client to force cache read.
      final client = FakeSupabaseClient(
        FakeQueryBuilder(error: Exception('offline')),
      );
      final repo = WorkoutRepository(client, cache);

      final result = await repo.getLastWorkoutSets(['exercise-001']);

      expect(result.containsKey('exercise-001'), isTrue);
      expect(result['exercise-001'], hasLength(2));
      expect(result['exercise-001']![0].reps, 10);
      expect(result['exercise-001']![0].weight, 80.0);
      expect(result['exercise-001']![1].reps, 8);
    });

    test('network failure returns cached data', () async {
      final setsData = {
        'ex-1': [TestSetFactory.create(id: 's-1', reps: 5, weight: 100.0)],
      };
      await lastSetsBox.put('ex-1', jsonEncode(setsData));

      final client = FakeSupabaseClient(
        FakeQueryBuilder(error: Exception('offline')),
      );
      final repo = WorkoutRepository(client, cache);

      final result = await repo.getLastWorkoutSets(['ex-1']);

      expect(result['ex-1'], hasLength(1));
      expect(result['ex-1']![0].weight, 100.0);
    });

    test(
      'returns empty map immediately for empty exercise IDs list (no cache interaction)',
      () async {
        // No cache seeded, no network call expected.
        final client = FakeSupabaseClient(FakeQueryBuilder());
        final repo = WorkoutRepository(client, cache);

        final result = await repo.getLastWorkoutSets([]);

        expect(result, isEmpty);
        // Verify nothing was written to cache.
        expect(lastSetsBox.isEmpty, isTrue);
      },
    );

    test('rethrows when no cache and network fails', () async {
      final client = FakeSupabaseClient(
        FakeQueryBuilder(error: Exception('offline')),
      );
      final repo = WorkoutRepository(client, cache);

      await expectLater(
        repo.getLastWorkoutSets(['ex-missing']),
        throwsA(isA<Exception>()),
      );
    });

    test('cache key is sorted IDs — order-independent lookup', () async {
      // Pre-populate using the sorted key ("ex-1,ex-2").
      final setsData = {
        'ex-1': [TestSetFactory.create(id: 's-1', reps: 5, weight: 100.0)],
        'ex-2': [TestSetFactory.create(id: 's-2', reps: 8, weight: 60.0)],
      };
      await lastSetsBox.put('ex-1,ex-2', jsonEncode(setsData));

      final client = FakeSupabaseClient(
        FakeQueryBuilder(error: Exception('offline')),
      );
      final repo = WorkoutRepository(client, cache);

      // Pass IDs in reverse order — repo sorts them to build the cache key.
      final result = await repo.getLastWorkoutSets(['ex-2', 'ex-1']);

      expect(result.containsKey('ex-1'), isTrue);
      expect(result.containsKey('ex-2'), isTrue);
    });
  });
}
