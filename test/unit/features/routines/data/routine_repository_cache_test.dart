import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/local_storage/cache_service.dart';
import 'package:gymbuddy_app/core/local_storage/hive_service.dart';
import 'package:gymbuddy_app/features/routines/data/routine_repository.dart';
import 'package:hive/hive.dart';

import '../../../../fixtures/test_factories.dart';
import '../../../_helpers/fake_supabase.dart';

void main() {
  late Directory tempDir;
  late CacheService cache;
  late Box<dynamic> routineBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('routine_cache_test_');
    Hive.init(tempDir.path);
    routineBox = await Hive.openBox<dynamic>(HiveService.routineCache);
    cache = const CacheService();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('RoutineRepository cache - getRoutines', () {
    test(
      'cache preserves resolved exercises through envelope roundtrip',
      () async {
        // Build the cache envelope as the repo would write it:
        // { routines: [...], exercises: { id -> exerciseJson } }
        final exerciseJson = TestExerciseFactory.create(
          id: 'ex-bench',
          name: 'Bench Press',
          equipmentType: 'barbell',
        );
        final routineJson = TestRoutineFactory.create(
          id: 'r-001',
          name: 'Push Day',
          exercises: [
            TestRoutineExerciseFactory.create(exerciseId: 'ex-bench'),
          ],
        );
        final envelope = {
          'routines': [routineJson],
          'exercises': {'ex-bench': exerciseJson},
        };
        await routineBox.put('user-001', jsonEncode(envelope));

        // Create repo with a failing client to force cache read.
        final client = FakeRoutingSupabaseClient({
          'workout_templates': FakeQueryBuilder(error: Exception('offline')),
          'exercises': FakeQueryBuilder(error: Exception('offline')),
        });
        final repo = RoutineRepository(client, cache);

        final result = await repo.getRoutines('user-001');

        expect(result, hasLength(1));
        expect(result[0].name, 'Push Day');
        expect(result[0].exercises[0].exercise, isNotNull);
        expect(result[0].exercises[0].exercise!.name, 'Bench Press');
      },
    );

    test(
      'network failure returns cached routines with resolved exercises',
      () async {
        // Build cache envelope with two exercises.
        final ex1 = TestExerciseFactory.create(id: 'ex-1', name: 'Squat');
        final ex2 = TestExerciseFactory.create(id: 'ex-2', name: 'Deadlift');
        final routineJson = TestRoutineFactory.create(
          id: 'r-002',
          name: 'Leg Day',
          exercises: [
            TestRoutineExerciseFactory.create(exerciseId: 'ex-1'),
            TestRoutineExerciseFactory.create(exerciseId: 'ex-2'),
          ],
        );
        final envelope = {
          'routines': [routineJson],
          'exercises': {'ex-1': ex1, 'ex-2': ex2},
        };
        await routineBox.put('user-001', jsonEncode(envelope));

        final client = FakeRoutingSupabaseClient({
          'workout_templates': FakeQueryBuilder(error: Exception('offline')),
          'exercises': FakeQueryBuilder(error: Exception('offline')),
        });
        final repo = RoutineRepository(client, cache);

        final result = await repo.getRoutines('user-001');

        expect(result, hasLength(1));
        expect(result[0].exercises[0].exercise?.name, 'Squat');
        expect(result[0].exercises[1].exercise?.name, 'Deadlift');
      },
    );

    test('rethrows when no cache and network fails', () async {
      final client = FakeRoutingSupabaseClient({
        'workout_templates': FakeQueryBuilder(error: Exception('offline')),
        'exercises': FakeQueryBuilder(error: Exception('offline')),
      });
      final repo = RoutineRepository(client, cache);

      expect(() => repo.getRoutines('user-001'), throwsA(isA<Exception>()));
    });

    test(
      'cached routine with no exercises reads back with empty exercise list',
      () async {
        final routineJson = TestRoutineFactory.create(
          id: 'r-empty',
          name: 'Empty Routine',
          exercises: [],
        );
        final envelope = {
          'routines': [routineJson],
          'exercises': <String, dynamic>{},
        };
        await routineBox.put('user-001', jsonEncode(envelope));

        final client = FakeRoutingSupabaseClient({
          'workout_templates': FakeQueryBuilder(error: Exception('offline')),
          'exercises': FakeQueryBuilder(error: Exception('offline')),
        });
        final repo = RoutineRepository(client, cache);

        final result = await repo.getRoutines('user-001');

        expect(result, hasLength(1));
        expect(result[0].name, 'Empty Routine');
        expect(result[0].exercises, isEmpty);
      },
    );

    test(
      'fresh data is written and readable on subsequent offline call',
      () async {
        final exerciseRow = TestExerciseFactory.create(
          id: 'ex-w',
          name: 'Written Exercise',
        );
        final templateRow = TestRoutineFactory.create(
          id: 'r-written',
          name: 'Written Routine',
          exercises: [TestRoutineExerciseFactory.create(exerciseId: 'ex-w')],
        );

        // First call: network succeeds — repo writes cache.
        final onlineClient = FakeRoutingSupabaseClient({
          'workout_templates': FakeQueryBuilder(data: [templateRow]),
          'exercises': FakeQueryBuilder(data: [exerciseRow]),
        });
        await RoutineRepository(onlineClient, cache).getRoutines('user-001');

        // Second call: network fails — must return data from cache.
        final offlineClient = FakeRoutingSupabaseClient({
          'workout_templates': FakeQueryBuilder(error: Exception('offline')),
          'exercises': FakeQueryBuilder(error: Exception('offline')),
        });
        final result = await RoutineRepository(
          offlineClient,
          cache,
        ).getRoutines('user-001');

        expect(result, hasLength(1));
        expect(result[0].name, 'Written Routine');
        expect(result[0].exercises[0].exercise?.name, 'Written Exercise');
      },
    );
  });
}
