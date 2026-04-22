import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/workouts/models/active_workout_state.dart';
import 'package:repsaga/features/workouts/models/exercise_set.dart';
import 'package:repsaga/features/workouts/models/set_type.dart';
import 'package:repsaga/features/workouts/models/workout.dart';
import 'package:repsaga/features/workouts/models/workout_exercise.dart';

import '../../../../fixtures/test_factories.dart';

void main() {
  group('Workout', () {
    test('fromJson parses complete data', () {
      final json = TestWorkoutFactory.create(notes: 'Great session');

      final workout = Workout.fromJson(json);

      expect(workout.id, 'workout-001');
      expect(workout.userId, 'user-001');
      expect(workout.name, 'Push Day');
      expect(workout.startedAt, DateTime.parse('2026-01-01T10:00:00Z'));
      expect(workout.finishedAt, DateTime.parse('2026-01-01T11:00:00Z'));
      expect(workout.durationSeconds, 3600);
      expect(workout.isActive, false);
      expect(workout.notes, 'Great session');
    });

    test('fromJson handles null optional fields', () {
      final json = TestWorkoutFactory.create();
      json['finished_at'] = null;
      json['duration_seconds'] = null;

      final workout = Workout.fromJson(json);

      expect(workout.finishedAt, isNull);
      expect(workout.durationSeconds, isNull);
      expect(workout.notes, isNull);
    });

    test('isActive defaults to false when key is absent', () {
      final json = TestWorkoutFactory.create();
      json.remove('is_active');

      expect(Workout.fromJson(json).isActive, false);
    });

    test('toJson round-trip preserves all fields', () {
      final json = TestWorkoutFactory.create(notes: 'note');
      final workout = Workout.fromJson(json);
      final roundTripped = Workout.fromJson(workout.toJson());

      expect(roundTripped, workout);
    });
  });

  group('WorkoutExercise', () {
    test('fromJson parses complete data', () {
      final json = TestWorkoutExerciseFactory.create(restSeconds: 90);

      final we = WorkoutExercise.fromJson(json);

      expect(we.id, 'we-001');
      expect(we.workoutId, 'workout-001');
      expect(we.exerciseId, 'exercise-001');
      expect(we.order, 1);
      expect(we.restSeconds, 90);
      expect(we.exercise, isNull);
    });

    test('exercise field is included in toJson for Hive persistence', () {
      final we = WorkoutExercise.fromJson(TestWorkoutExerciseFactory.create());
      expect(we.toJson().containsKey('exercise'), true);
    });

    test('toJson round-trip preserves scalar fields', () {
      final json = TestWorkoutExerciseFactory.create(restSeconds: 60, order: 2);
      final we = WorkoutExercise.fromJson(json);
      final roundTripped = WorkoutExercise.fromJson(we.toJson());

      expect(roundTripped.id, we.id);
      expect(roundTripped.order, we.order);
      expect(roundTripped.restSeconds, we.restSeconds);
    });
  });

  group('ExerciseSet', () {
    test('fromJson parses complete data', () {
      final json = TestSetFactory.create(
        setType: 'warmup',
        weight: 40.0,
        reps: 15,
        rpe: 6,
        notes: 'light set',
      );

      final set = ExerciseSet.fromJson(json);

      expect(set.id, 'set-001');
      expect(set.setType, SetType.warmup);
      expect(set.weight, 40.0);
      expect(set.reps, 15);
      expect(set.rpe, 6);
      expect(set.notes, 'light set');
      expect(set.isCompleted, true);
    });

    test('setType defaults to working when absent or null', () {
      final absent = TestSetFactory.create()..remove('set_type');
      final nullVal = TestSetFactory.create()..['set_type'] = null;

      expect(ExerciseSet.fromJson(absent).setType, SetType.working);
      expect(ExerciseSet.fromJson(nullVal).setType, SetType.working);
    });

    test('fromJson parses all SetType values', () {
      for (final type in SetType.values) {
        final json = TestSetFactory.create(setType: type.name);
        expect(ExerciseSet.fromJson(json).setType, type);
      }
    });

    test('isCompleted defaults to false when key is absent', () {
      final json = TestSetFactory.create()..remove('is_completed');
      expect(ExerciseSet.fromJson(json).isCompleted, false);
    });

    test('toJson round-trip preserves all fields', () {
      final json = TestSetFactory.create(
        setType: 'warmup',
        weight: 40.0,
        reps: 15,
        rpe: 6,
        notes: 'warm-up set',
      );
      final set = ExerciseSet.fromJson(json);
      expect(ExerciseSet.fromJson(set.toJson()), set);
    });

    test('toJson serializes setType as name string', () {
      final set = ExerciseSet.fromJson(
        TestSetFactory.create(setType: 'dropset'),
      );
      expect(set.toJson()['set_type'], 'dropset');
    });
  });

  group('ActiveWorkoutExercise', () {
    test('fromJson parses workout exercise and sets', () {
      final json = {
        'workout_exercise': TestWorkoutExerciseFactory.create(id: 'we-001'),
        'sets': [
          TestSetFactory.create(id: 'set-001', workoutExerciseId: 'we-001'),
          TestSetFactory.create(
            id: 'set-002',
            workoutExerciseId: 'we-001',
            setNumber: 2,
          ),
        ],
      };

      final awe = ActiveWorkoutExercise.fromJson(json);

      expect(awe.workoutExercise.id, 'we-001');
      expect(awe.sets, hasLength(2));
    });

    test('fromJson defaults sets to empty list when key is absent', () {
      final json = {'workout_exercise': TestWorkoutExerciseFactory.create()};

      expect(ActiveWorkoutExercise.fromJson(json).sets, isEmpty);
    });
  });

  group('ActiveWorkoutState', () {
    test('fromJson parses complete data with exercises', () {
      final json = TestActiveWorkoutStateFactory.createWithExercises(
        exerciseCount: 2,
        setsPerExercise: 3,
      );

      final state = ActiveWorkoutState.fromJson(json);

      expect(state.workout.id, 'workout-001');
      expect(state.exercises, hasLength(2));
      expect(state.exercises[0].sets, hasLength(3));
    });

    test('defaults exercises to empty when absent', () {
      final json = TestActiveWorkoutStateFactory.create()..remove('exercises');

      final state = ActiveWorkoutState.fromJson(json);

      expect(state.exercises, isEmpty);
    });

    test('toJson round-trip preserves full nested state', () {
      final json = TestActiveWorkoutStateFactory.createWithExercises(
        exerciseCount: 1,
        setsPerExercise: 2,
      );
      final state = ActiveWorkoutState.fromJson(json);
      // Round-trip through jsonEncode/jsonDecode to match production usage
      final roundTripped = ActiveWorkoutState.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
      );

      expect(roundTripped.workout, state.workout);
      expect(roundTripped.exercises, hasLength(1));
      expect(roundTripped.exercises[0].sets, hasLength(2));
    });
  });
}
