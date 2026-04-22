// Serialization round-trip tests for all Freezed models that pass through
// Hive or Supabase.
//
// Systematic gap exposed by the PR-27 regression analysis:
// - The general round-trip tests in workout_models_test.dart and
//   workout_local_storage_test.dart use TestActiveWorkoutStateFactory, which
//   never attaches a real Exercise object to WorkoutExercise. This means those
//   tests could not catch BUG-001 (exercise name lost after Hive restore).
// - Nullable fields (restSeconds, weight, reps, rpe, notes) were not
//   verified to survive the jsonEncode/jsonDecode cycle.
// - This file covers these gaps as a regression guard: tests here should catch
//   any future annotation change that silently strips a field from toJson().

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/local_storage/hive_service.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';
import 'package:repsaga/features/workouts/data/workout_local_storage.dart';
import 'package:repsaga/features/workouts/models/active_workout_state.dart';
import 'package:repsaga/features/workouts/models/exercise_set.dart';
import 'package:repsaga/features/workouts/models/set_type.dart';
import 'package:repsaga/features/workouts/models/workout.dart';
import 'package:repsaga/features/workouts/models/workout_exercise.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../fixtures/test_factories.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Encode → decode a single step, matching how WorkoutLocalStorage persists.
Map<String, dynamic> _jsonRoundTrip(Map<String, dynamic> input) {
  return jsonDecode(jsonEncode(input)) as Map<String, dynamic>;
}

Exercise _makeExercise({
  String id = 'ex-001',
  String name = 'Bench Press',
  String muscleGroup = 'chest',
  String equipmentType = 'barbell',
}) {
  return Exercise.fromJson(
    TestExerciseFactory.create(
      id: id,
      name: name,
      muscleGroup: muscleGroup,
      equipmentType: equipmentType,
    ),
  );
}

WorkoutExercise _makeWorkoutExercise({
  required String id,
  required String workoutId,
  required String exerciseId,
  Exercise? exercise,
  int order = 0,
  int? restSeconds,
}) {
  return WorkoutExercise(
    id: id,
    workoutId: workoutId,
    exerciseId: exerciseId,
    order: order,
    restSeconds: restSeconds,
    exercise: exercise,
  );
}

ExerciseSet _makeSet({
  String id = 'set-001',
  String workoutExerciseId = 'we-001',
  int setNumber = 1,
  double? weight,
  int? reps,
  int? rpe,
  SetType setType = SetType.working,
  String? notes,
  bool isCompleted = false,
}) {
  return ExerciseSet(
    id: id,
    workoutExerciseId: workoutExerciseId,
    setNumber: setNumber,
    weight: weight,
    reps: reps,
    rpe: rpe,
    setType: setType,
    notes: notes,
    isCompleted: isCompleted,
    createdAt: DateTime.utc(2026, 1, 1, 10),
  );
}

// ---------------------------------------------------------------------------
// WorkoutExercise round-trip
// ---------------------------------------------------------------------------

void main() {
  group('WorkoutExercise serialization round-trip', () {
    test('exercise field with name survives toJson → fromJson', () {
      final exercise = _makeExercise(name: 'Squat', equipmentType: 'barbell');
      final we = _makeWorkoutExercise(
        id: 'we-001',
        workoutId: 'w-001',
        exerciseId: exercise.id,
        exercise: exercise,
      );

      final restored = WorkoutExercise.fromJson(_jsonRoundTrip(we.toJson()));

      expect(
        restored.exercise,
        isNotNull,
        reason:
            'exercise field must be included in toJson output so it can '
            'be restored — a regression of BUG-001 would make this null',
      );
      expect(restored.exercise!.name, 'Squat');
      expect(restored.exercise!.equipmentType, EquipmentType.barbell);
    });

    test('exercise field null survives round-trip', () {
      final we = _makeWorkoutExercise(
        id: 'we-002',
        workoutId: 'w-001',
        exerciseId: 'ex-001',
      );

      final restored = WorkoutExercise.fromJson(_jsonRoundTrip(we.toJson()));

      expect(restored.exercise, isNull);
    });

    test('null restSeconds survives round-trip', () {
      final we = _makeWorkoutExercise(
        id: 'we-003',
        workoutId: 'w-001',
        exerciseId: 'ex-001',
        restSeconds: null,
      );

      final restored = WorkoutExercise.fromJson(_jsonRoundTrip(we.toJson()));

      expect(restored.restSeconds, isNull);
    });

    test('non-null restSeconds survives round-trip', () {
      final we = _makeWorkoutExercise(
        id: 'we-004',
        workoutId: 'w-001',
        exerciseId: 'ex-001',
        restSeconds: 120,
      );

      final restored = WorkoutExercise.fromJson(_jsonRoundTrip(we.toJson()));

      expect(restored.restSeconds, 120);
    });

    test('all Exercise fields survive nested round-trip', () {
      final exercise = Exercise.fromJson(
        TestExerciseFactory.create(
          id: 'ex-deadlift',
          name: 'Deadlift',
          muscleGroup: 'back',
          equipmentType: 'barbell',
          description: 'A hip hinge movement.',
          formTips: 'Keep neutral spine\nPush the floor away',
        ),
      );
      final we = _makeWorkoutExercise(
        id: 'we-005',
        workoutId: 'w-001',
        exerciseId: exercise.id,
        exercise: exercise,
      );

      final restored = WorkoutExercise.fromJson(_jsonRoundTrip(we.toJson()));

      expect(restored.exercise!.name, 'Deadlift');
      expect(restored.exercise!.muscleGroup, MuscleGroup.back);
      expect(restored.exercise!.equipmentType, EquipmentType.barbell);
      expect(restored.exercise!.description, 'A hip hinge movement.');
      expect(
        restored.exercise!.formTips,
        'Keep neutral spine\nPush the floor away',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // ExerciseSet round-trip
  // ---------------------------------------------------------------------------

  group('ExerciseSet serialization round-trip', () {
    test('null weight and null reps survive round-trip', () {
      final set = _makeSet(weight: null, reps: null);

      final restored = ExerciseSet.fromJson(_jsonRoundTrip(set.toJson()));

      expect(restored.weight, isNull);
      expect(restored.reps, isNull);
    });

    test('null rpe survives round-trip', () {
      final set = _makeSet(weight: 80.0, reps: 5, rpe: null);

      final restored = ExerciseSet.fromJson(_jsonRoundTrip(set.toJson()));

      expect(restored.rpe, isNull);
    });

    test('null notes survives round-trip', () {
      final set = _makeSet(notes: null);

      final restored = ExerciseSet.fromJson(_jsonRoundTrip(set.toJson()));

      expect(restored.notes, isNull);
    });

    test('all SetType values survive round-trip', () {
      for (final type in SetType.values) {
        final set = _makeSet(setType: type);
        final restored = ExerciseSet.fromJson(_jsonRoundTrip(set.toJson()));
        expect(
          restored.setType,
          type,
          reason: 'SetType.${type.name} must survive jsonEncode/jsonDecode',
        );
      }
    });

    test('isCompleted true and false both survive round-trip', () {
      final completed = _makeSet(isCompleted: true);
      final incomplete = _makeSet(isCompleted: false);

      expect(
        ExerciseSet.fromJson(_jsonRoundTrip(completed.toJson())).isCompleted,
        isTrue,
      );
      expect(
        ExerciseSet.fromJson(_jsonRoundTrip(incomplete.toJson())).isCompleted,
        isFalse,
      );
    });

    test('fractional weight (e.g. 82.5 kg) survives round-trip', () {
      final set = _makeSet(weight: 82.5, reps: 5);

      final restored = ExerciseSet.fromJson(_jsonRoundTrip(set.toJson()));

      expect(restored.weight, 82.5);
    });
  });

  // ---------------------------------------------------------------------------
  // ActiveWorkoutState full round-trip WITH named exercises
  // ---------------------------------------------------------------------------

  group('ActiveWorkoutState full round-trip with embedded Exercise objects', () {
    test(
      'exercise names survive toJson → jsonEncode → jsonDecode → fromJson',
      () {
        final workout = Workout.fromJson(
          TestWorkoutFactory.create(id: 'w-rt-001', isActive: true),
        );
        final bench = _makeExercise(
          id: 'ex-bench',
          name: 'Bench Press',
          equipmentType: 'barbell',
        );
        final squat = _makeExercise(
          id: 'ex-squat',
          name: 'Squat',
          equipmentType: 'barbell',
        );

        final we1 = _makeWorkoutExercise(
          id: 'we-001',
          workoutId: workout.id,
          exerciseId: bench.id,
          exercise: bench,
          order: 0,
          restSeconds: 90,
        );
        final we2 = _makeWorkoutExercise(
          id: 'we-002',
          workoutId: workout.id,
          exerciseId: squat.id,
          exercise: squat,
          order: 1,
          restSeconds: 120,
        );

        final state = ActiveWorkoutState(
          workout: workout,
          exercises: [
            ActiveWorkoutExercise(workoutExercise: we1, sets: const []),
            ActiveWorkoutExercise(workoutExercise: we2, sets: const []),
          ],
        );

        final restored = ActiveWorkoutState.fromJson(
          _jsonRoundTrip(state.toJson()),
        );

        expect(
          restored.exercises[0].workoutExercise.exercise?.name,
          'Bench Press',
          reason:
              'Exercise name for first exercise must survive the full '
              'encode→decode cycle (regression guard for BUG-001)',
        );
        expect(restored.exercises[1].workoutExercise.exercise?.name, 'Squat');
        expect(restored.exercises[0].workoutExercise.restSeconds, 90);
        expect(restored.exercises[1].workoutExercise.restSeconds, 120);
      },
    );

    test(
      'exercise equipment type survives round-trip (needed for smart defaults after restore)',
      () {
        final workout = Workout.fromJson(
          TestWorkoutFactory.create(id: 'w-rt-002', isActive: true),
        );
        final dumbbell = _makeExercise(
          id: 'ex-db',
          name: 'Dumbbell Curl',
          equipmentType: 'dumbbell',
        );
        final we = _makeWorkoutExercise(
          id: 'we-001',
          workoutId: workout.id,
          exerciseId: dumbbell.id,
          exercise: dumbbell,
        );

        final state = ActiveWorkoutState(
          workout: workout,
          exercises: [
            ActiveWorkoutExercise(workoutExercise: we, sets: const []),
          ],
        );

        final restored = ActiveWorkoutState.fromJson(
          _jsonRoundTrip(state.toJson()),
        );

        expect(
          restored.exercises[0].workoutExercise.exercise?.equipmentType,
          EquipmentType.dumbbell,
          reason:
              'Equipment type must survive round-trip so that smart set '
              'defaults can be applied after an app restore',
        );
      },
    );

    test('sets with all data survive round-trip inside ActiveWorkoutState', () {
      final workout = Workout.fromJson(
        TestWorkoutFactory.create(id: 'w-rt-003', isActive: true),
      );
      final exercise = _makeExercise(id: 'ex-001', name: 'OHP');
      final we = _makeWorkoutExercise(
        id: 'we-001',
        workoutId: workout.id,
        exerciseId: exercise.id,
        exercise: exercise,
      );
      final sets = [
        _makeSet(
          id: 'set-001',
          workoutExerciseId: 'we-001',
          setNumber: 1,
          weight: 60.0,
          reps: 8,
          setType: SetType.warmup,
          isCompleted: true,
        ),
        _makeSet(
          id: 'set-002',
          workoutExerciseId: 'we-001',
          setNumber: 2,
          weight: 80.0,
          reps: 5,
          rpe: 8,
          setType: SetType.working,
          notes: 'felt strong',
          isCompleted: false,
        ),
      ];

      final state = ActiveWorkoutState(
        workout: workout,
        exercises: [ActiveWorkoutExercise(workoutExercise: we, sets: sets)],
      );

      final restored = ActiveWorkoutState.fromJson(
        _jsonRoundTrip(state.toJson()),
      );

      final restoredSets = restored.exercises[0].sets;
      expect(restoredSets, hasLength(2));
      expect(restoredSets[0].weight, 60.0);
      expect(restoredSets[0].setType, SetType.warmup);
      expect(restoredSets[0].isCompleted, isTrue);
      expect(restoredSets[1].weight, 80.0);
      expect(restoredSets[1].rpe, 8);
      expect(restoredSets[1].notes, 'felt strong');
      expect(restoredSets[1].isCompleted, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Hive persistence round-trip WITH named exercises
  //
  // These tests go through WorkoutLocalStorage (jsonEncode → Hive → jsonDecode)
  // to catch any regression introduced at the persistence layer, not just
  // in-memory serialization.
  // ---------------------------------------------------------------------------

  group('WorkoutLocalStorage Hive round-trip with embedded Exercise names', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_srt_');
      Hive.init(tempDir.path);
      await Hive.openBox<dynamic>(HiveService.activeWorkout);
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test(
      'multiple exercises with different names all survive Hive save/load',
      () async {
        final storage = WorkoutLocalStorage();
        final workout = Workout.fromJson(
          TestWorkoutFactory.create(id: 'w-hive-001', isActive: true),
        );

        final exercises = [
          ('ex-A', 'Romanian Deadlift', 'barbell'),
          ('ex-B', 'Dumbbell Row', 'dumbbell'),
          ('ex-C', 'Pull-up', 'bodyweight'),
        ];

        final activeExercises = exercises.indexed.map((entry) {
          final (i, (exId, name, equip)) = entry;
          final ex = _makeExercise(id: exId, name: name, equipmentType: equip);
          final we = _makeWorkoutExercise(
            id: 'we-$i',
            workoutId: workout.id,
            exerciseId: exId,
            exercise: ex,
            order: i,
          );
          return ActiveWorkoutExercise(workoutExercise: we, sets: const []);
        }).toList();

        final state = ActiveWorkoutState(
          workout: workout,
          exercises: activeExercises,
        );

        await storage.saveActiveWorkout(state);
        final loaded = storage.loadActiveWorkout();

        expect(loaded, isNotNull);
        expect(loaded!.exercises, hasLength(3));
        expect(
          loaded.exercises[0].workoutExercise.exercise?.name,
          'Romanian Deadlift',
        );
        expect(
          loaded.exercises[1].workoutExercise.exercise?.name,
          'Dumbbell Row',
        );
        expect(loaded.exercises[2].workoutExercise.exercise?.name, 'Pull-up');
        expect(
          loaded.exercises[1].workoutExercise.exercise?.equipmentType,
          EquipmentType.dumbbell,
        );
        expect(
          loaded.exercises[2].workoutExercise.exercise?.equipmentType,
          EquipmentType.bodyweight,
        );
      },
    );

    test(
      'sets with weights survive Hive save/load alongside named exercises',
      () async {
        final storage = WorkoutLocalStorage();
        final workout = Workout.fromJson(
          TestWorkoutFactory.create(id: 'w-hive-002', isActive: true),
        );
        final exercise = _makeExercise(id: 'ex-bench', name: 'Bench Press');
        final we = _makeWorkoutExercise(
          id: 'we-001',
          workoutId: workout.id,
          exerciseId: exercise.id,
          exercise: exercise,
        );
        final sets = [
          _makeSet(
            id: 's-001',
            workoutExerciseId: 'we-001',
            setNumber: 1,
            weight: 100.0,
            reps: 5,
            isCompleted: true,
          ),
          _makeSet(
            id: 's-002',
            workoutExerciseId: 'we-001',
            setNumber: 2,
            weight: 100.0,
            reps: 4,
            isCompleted: false,
          ),
        ];

        final state = ActiveWorkoutState(
          workout: workout,
          exercises: [ActiveWorkoutExercise(workoutExercise: we, sets: sets)],
        );

        await storage.saveActiveWorkout(state);
        final loaded = storage.loadActiveWorkout();

        expect(
          loaded!.exercises[0].workoutExercise.exercise?.name,
          'Bench Press',
        );
        expect(loaded.exercises[0].sets, hasLength(2));
        expect(loaded.exercises[0].sets[0].weight, 100.0);
        expect(loaded.exercises[0].sets[0].isCompleted, isTrue);
        expect(loaded.exercises[0].sets[1].isCompleted, isFalse);
      },
    );
  });
}
