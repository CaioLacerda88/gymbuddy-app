import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/local_storage/hive_service.dart';
import 'package:gymbuddy_app/features/workouts/data/workout_local_storage.dart';
import 'package:gymbuddy_app/features/workouts/models/active_workout_state.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../fixtures/test_factories.dart';

void main() {
  group('WorkoutLocalStorage', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_test_');
      Hive.init(tempDir.path);
      await Hive.openBox<dynamic>(HiveService.activeWorkout);
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    ActiveWorkoutState makeState({int exerciseCount = 0}) {
      final json = exerciseCount > 0
          ? TestActiveWorkoutStateFactory.createWithExercises(
              exerciseCount: exerciseCount,
              setsPerExercise: 2,
            )
          : TestActiveWorkoutStateFactory.create();
      return ActiveWorkoutState.fromJson(json);
    }

    group('saveActiveWorkout and loadActiveWorkout', () {
      test('round-trips a state with no exercises', () async {
        final storage = WorkoutLocalStorage();
        final state = makeState();

        await storage.saveActiveWorkout(state);
        final loaded = storage.loadActiveWorkout();

        expect(loaded, isNotNull);
        expect(loaded!.workout.id, state.workout.id);
        expect(loaded.exercises, isEmpty);
      });

      test('round-trips a state with exercises and sets', () async {
        final storage = WorkoutLocalStorage();
        final state = makeState(exerciseCount: 2);

        await storage.saveActiveWorkout(state);
        final loaded = storage.loadActiveWorkout();

        expect(loaded, isNotNull);
        expect(loaded!.exercises, hasLength(2));
        expect(loaded.exercises[0].sets, hasLength(2));
        expect(loaded.exercises[1].sets, hasLength(2));
      });

      test('overwrites previous state on second save', () async {
        final storage = WorkoutLocalStorage();
        final first = makeState();
        final second = ActiveWorkoutState.fromJson(
          TestActiveWorkoutStateFactory.create(
            workout: TestWorkoutFactory.create(
              id: 'workout-002',
              name: 'Second Workout',
              isActive: true,
            ),
          ),
        );

        await storage.saveActiveWorkout(first);
        await storage.saveActiveWorkout(second);
        final loaded = storage.loadActiveWorkout();

        expect(loaded!.workout.id, 'workout-002');
        expect(loaded.workout.name, 'Second Workout');
      });
    });

    group('loadActiveWorkout', () {
      test('returns null when box is empty', () {
        final storage = WorkoutLocalStorage();

        final result = storage.loadActiveWorkout();

        expect(result, isNull);
      });

      test('returns null on schema version mismatch', () async {
        final storage = WorkoutLocalStorage();
        final state = makeState();
        await storage.saveActiveWorkout(state);

        // Overwrite schema version with a future version.
        final box = Hive.box<dynamic>(HiveService.activeWorkout);
        await box.put('schema_version', 99);

        final result = storage.loadActiveWorkout();

        expect(result, isNull);
      });

      test('returns null when schema version key is absent', () {
        final storage = WorkoutLocalStorage();

        // Box is empty, so schema version key is absent.
        final result = storage.loadActiveWorkout();

        expect(result, isNull);
      });

      test('returns null on corrupt JSON', () async {
        final storage = WorkoutLocalStorage();
        final box = Hive.box<dynamic>(HiveService.activeWorkout);
        await box.put('schema_version', 1);
        await box.put('current_workout', 'this is not valid json {{{');

        final result = storage.loadActiveWorkout();

        expect(result, isNull);
      });

      test(
        'returns null when workout key is absent but schema version is set',
        () async {
          final storage = WorkoutLocalStorage();
          final box = Hive.box<dynamic>(HiveService.activeWorkout);
          await box.put('schema_version', 1);

          final result = storage.loadActiveWorkout();

          expect(result, isNull);
        },
      );
    });

    group('clearActiveWorkout', () {
      test('removes persisted workout data', () async {
        final storage = WorkoutLocalStorage();
        final state = makeState();
        await storage.saveActiveWorkout(state);

        await storage.clearActiveWorkout();

        expect(storage.loadActiveWorkout(), isNull);
      });

      test('clears both workout and schema version keys', () async {
        final storage = WorkoutLocalStorage();
        final state = makeState();
        await storage.saveActiveWorkout(state);

        await storage.clearActiveWorkout();

        final box = Hive.box<dynamic>(HiveService.activeWorkout);
        expect(box.get('current_workout'), isNull);
        expect(box.get('schema_version'), isNull);
      });

      test('is safe to call when box is already empty', () async {
        final storage = WorkoutLocalStorage();

        // Should not throw.
        await storage.clearActiveWorkout();

        expect(storage.loadActiveWorkout(), isNull);
      });
    });

    group('hasActiveWorkout', () {
      test('returns false when box is empty', () {
        final storage = WorkoutLocalStorage();

        expect(storage.hasActiveWorkout, false);
      });

      test('returns true after saving a workout', () async {
        final storage = WorkoutLocalStorage();
        final state = makeState();

        await storage.saveActiveWorkout(state);

        expect(storage.hasActiveWorkout, true);
      });

      test('returns false after clearing', () async {
        final storage = WorkoutLocalStorage();
        final state = makeState();
        await storage.saveActiveWorkout(state);

        await storage.clearActiveWorkout();

        expect(storage.hasActiveWorkout, false);
      });

      test('returns false when schema version does not match', () async {
        final storage = WorkoutLocalStorage();
        final state = makeState();
        await storage.saveActiveWorkout(state);

        // Corrupt the schema version.
        final box = Hive.box<dynamic>(HiveService.activeWorkout);
        await box.put('schema_version', 99);

        expect(storage.hasActiveWorkout, false);
      });

      test(
        'returns false when workout key is absent despite valid schema version',
        () async {
          final storage = WorkoutLocalStorage();
          final box = Hive.box<dynamic>(HiveService.activeWorkout);
          await box.put('schema_version', 1);

          expect(storage.hasActiveWorkout, false);
        },
      );
    });
  });
}
