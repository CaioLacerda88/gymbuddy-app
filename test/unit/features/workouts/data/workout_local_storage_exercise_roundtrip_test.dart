// Tests that expose BUG-001: exercise name (Exercise object) is lost when
// ActiveWorkoutState is persisted to Hive and restored.
//
// WorkoutExercise.toJson() currently uses @JsonKey(includeToJson: false) on the
// exercise field, so exercise data is stripped during serialization. After
// deserialization the exercise field is null and the UI falls back to
// displaying "Exercise" instead of the real name.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/local_storage/hive_service.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';
import 'package:repsaga/features/workouts/data/workout_local_storage.dart';
import 'package:repsaga/features/workouts/models/active_workout_state.dart';
import 'package:repsaga/features/workouts/models/workout_exercise.dart';
import 'package:repsaga/features/workouts/models/workout.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../fixtures/test_factories.dart';

ActiveWorkoutState _stateWithNamedExercise({
  required String exerciseName,
  required String equipmentType,
}) {
  final workout = Workout.fromJson(TestWorkoutFactory.create(isActive: true));

  final exercise = Exercise.fromJson(
    TestExerciseFactory.create(
      id: 'ex-bench',
      name: exerciseName,
      equipmentType: equipmentType,
    ),
  );

  final workoutExercise = WorkoutExercise(
    id: 'we-001',
    workoutId: workout.id,
    exerciseId: exercise.id,
    order: 0,
    exercise: exercise,
  );

  final activeExercise = ActiveWorkoutExercise(
    workoutExercise: workoutExercise,
    sets: const [],
  );

  return ActiveWorkoutState(workout: workout, exercises: [activeExercise]);
}

void main() {
  group('WorkoutLocalStorage — exercise name round-trip (BUG-001)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_bug001_');
      Hive.init(tempDir.path);
      await Hive.openBox<dynamic>(HiveService.activeWorkout);
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test(
      'exercise name survives Hive save-restore cycle (exposes BUG-001)',
      () async {
        // Given: a workout with a named exercise (Bench Press)
        final original = _stateWithNamedExercise(
          exerciseName: 'Bench Press',
          equipmentType: 'barbell',
        );
        expect(
          original.exercises[0].workoutExercise.exercise?.name,
          'Bench Press',
          reason: 'Precondition: exercise name is set before save',
        );

        // When: saved and restored from Hive (simulating app backgrounding)
        final storage = WorkoutLocalStorage();
        await storage.saveActiveWorkout(original);
        final restored = storage.loadActiveWorkout();

        // Then: the exercise name must survive the round-trip.
        // BUG-001: this assertion FAILS because WorkoutExercise.toJson() has
        // @JsonKey(includeToJson: false) on the exercise field, so the name is
        // dropped during serialization and restored as null.
        expect(restored, isNotNull);
        expect(
          restored!.exercises[0].workoutExercise.exercise,
          isNotNull,
          reason:
              'BUG-001: exercise field is null after restore because '
              'WorkoutExercise.toJson() omits it via @JsonKey(includeToJson: false)',
        );
        expect(
          restored.exercises[0].workoutExercise.exercise!.name,
          'Bench Press',
        );
      },
    );

    test(
      'exercise equipment type survives Hive save-restore cycle (exposes BUG-001)',
      () async {
        final original = _stateWithNamedExercise(
          exerciseName: 'Squat',
          equipmentType: 'barbell',
        );

        final storage = WorkoutLocalStorage();
        await storage.saveActiveWorkout(original);
        final restored = storage.loadActiveWorkout();

        // BUG-001: equipment type is also lost because the whole exercise object
        // is stripped. Smart set defaults will also be broken after restore.
        expect(restored!.exercises[0].workoutExercise.exercise, isNotNull);
        expect(
          restored.exercises[0].workoutExercise.exercise!.equipmentType,
          EquipmentType.barbell,
        );
      },
    );

    test(
      'WorkoutExercise.toJson() includes exercise key (exposes BUG-001 root cause)',
      () {
        final exercise = Exercise.fromJson(
          TestExerciseFactory.create(id: 'ex-001', name: 'Deadlift'),
        );
        final workoutExercise = WorkoutExercise(
          id: 'we-001',
          workoutId: 'w-001',
          exerciseId: 'ex-001',
          order: 0,
          exercise: exercise,
        );

        final json = workoutExercise.toJson();

        // BUG-001 root cause: exercise key is absent from toJson() output
        expect(
          json.containsKey('exercise'),
          isTrue,
          reason:
              'BUG-001: WorkoutExercise.toJson() must include the exercise field '
              'so that Hive serialization can restore it. Currently @JsonKey('
              'includeToJson: false) strips it.',
        );
        expect(json['exercise'], isNotNull);
        expect((json['exercise'] as Map<String, dynamic>)['name'], 'Deadlift');
      },
    );
  });
}
