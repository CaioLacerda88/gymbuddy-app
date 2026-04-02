import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/workouts/models/active_workout_state.dart';
import 'package:gymbuddy_app/features/workouts/models/exercise_set.dart';
import 'package:gymbuddy_app/features/workouts/models/set_type.dart';
import 'package:gymbuddy_app/features/workouts/models/workout.dart';
import 'package:gymbuddy_app/features/workouts/models/workout_exercise.dart';

import '../../../../fixtures/test_factories.dart';

void main() {
  group('Workout', () {
    test('fromJson parses complete data', () {
      final json = TestWorkoutFactory.create();

      final workout = Workout.fromJson(json);

      expect(workout.id, 'workout-001');
      expect(workout.userId, 'user-001');
      expect(workout.name, 'Push Day');
      expect(workout.startedAt, DateTime.parse('2026-01-01T10:00:00Z'));
      expect(workout.finishedAt, DateTime.parse('2026-01-01T11:00:00Z'));
      expect(workout.durationSeconds, 3600);
      expect(workout.isActive, false);
      expect(workout.notes, isNull);
      expect(workout.createdAt, DateTime.parse('2026-01-01T10:00:00Z'));
    });

    test('fromJson handles null finishedAt', () {
      final json = TestWorkoutFactory.create(finishedAt: null);
      json['finished_at'] = null;

      final workout = Workout.fromJson(json);

      expect(workout.finishedAt, isNull);
    });

    test('fromJson handles null notes', () {
      final json = TestWorkoutFactory.create();

      final workout = Workout.fromJson(json);

      expect(workout.notes, isNull);
    });

    test('fromJson handles notes with value', () {
      final json = TestWorkoutFactory.create(notes: 'Great session');

      final workout = Workout.fromJson(json);

      expect(workout.notes, 'Great session');
    });

    test('fromJson handles null durationSeconds', () {
      final json = TestWorkoutFactory.create();
      json['duration_seconds'] = null;

      final workout = Workout.fromJson(json);

      expect(workout.durationSeconds, isNull);
    });

    test('isActive defaults to false when key is absent', () {
      final json = TestWorkoutFactory.create();
      json.remove('is_active');

      final workout = Workout.fromJson(json);

      expect(workout.isActive, false);
    });

    test('fromJson parses isActive true', () {
      final json = TestWorkoutFactory.create(isActive: true);

      final workout = Workout.fromJson(json);

      expect(workout.isActive, true);
    });

    test('toJson round-trip preserves all fields', () {
      final json = TestWorkoutFactory.create(notes: 'note');
      final workout = Workout.fromJson(json);
      final roundTripped = Workout.fromJson(workout.toJson());

      expect(roundTripped, workout);
    });

    test('toJson round-trip preserves null optional fields', () {
      final json = TestWorkoutFactory.create();
      json['finished_at'] = null;
      json['duration_seconds'] = null;

      final workout = Workout.fromJson(json);
      final roundTripped = Workout.fromJson(workout.toJson());

      expect(roundTripped.finishedAt, isNull);
      expect(roundTripped.durationSeconds, isNull);
      expect(roundTripped.notes, isNull);
    });

    test('equality works via Freezed == operator', () {
      final json = TestWorkoutFactory.create();
      final a = Workout.fromJson(json);
      final b = Workout.fromJson(json);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('equality detects differences', () {
      final a = Workout.fromJson(TestWorkoutFactory.create(name: 'Push Day'));
      final b = Workout.fromJson(TestWorkoutFactory.create(name: 'Pull Day'));

      expect(a, isNot(b));
    });

    test('copyWith creates modified copy', () {
      final workout = Workout.fromJson(TestWorkoutFactory.create());
      final modified = workout.copyWith(name: 'Leg Day');

      expect(modified.name, 'Leg Day');
      expect(modified.id, workout.id);
      expect(modified.userId, workout.userId);
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

    test('fromJson handles null restSeconds', () {
      final json = TestWorkoutExerciseFactory.create();

      final we = WorkoutExercise.fromJson(json);

      expect(we.restSeconds, isNull);
    });

    test('exercise field is excluded from toJson', () {
      final json = TestWorkoutExerciseFactory.create();
      final we = WorkoutExercise.fromJson(json);
      final serialized = we.toJson();

      expect(serialized.containsKey('exercise'), false);
    });

    test('toJson round-trip preserves scalar fields', () {
      final json = TestWorkoutExerciseFactory.create(restSeconds: 60, order: 2);
      final we = WorkoutExercise.fromJson(json);
      final roundTripped = WorkoutExercise.fromJson(we.toJson());

      expect(roundTripped.id, we.id);
      expect(roundTripped.workoutId, we.workoutId);
      expect(roundTripped.exerciseId, we.exerciseId);
      expect(roundTripped.order, we.order);
      expect(roundTripped.restSeconds, we.restSeconds);
    });

    test('equality works via Freezed == operator', () {
      final json = TestWorkoutExerciseFactory.create();
      final a = WorkoutExercise.fromJson(json);
      final b = WorkoutExercise.fromJson(json);

      expect(a, b);
    });
  });

  group('ExerciseSet', () {
    test('fromJson parses complete data', () {
      final json = TestSetFactory.create();

      final set = ExerciseSet.fromJson(json);

      expect(set.id, 'set-001');
      expect(set.workoutExerciseId, 'we-001');
      expect(set.setNumber, 1);
      expect(set.reps, 10);
      expect(set.weight, 60.0);
      expect(set.setType, SetType.working);
      expect(set.isCompleted, true);
      expect(set.createdAt, DateTime.parse('2026-01-01T10:05:00Z'));
    });

    test('setType defaults to working when key is absent', () {
      final json = TestSetFactory.create();
      json.remove('set_type');

      final set = ExerciseSet.fromJson(json);

      expect(set.setType, SetType.working);
    });

    test('setType defaults to working when value is null', () {
      final json = TestSetFactory.create();
      json['set_type'] = null;

      final set = ExerciseSet.fromJson(json);

      expect(set.setType, SetType.working);
    });

    test('fromJson parses all SetType values', () {
      for (final type in SetType.values) {
        final json = TestSetFactory.create(setType: type.name);
        final set = ExerciseSet.fromJson(json);
        expect(set.setType, type);
      }
    });

    test('weight is parsed as double', () {
      final json = TestSetFactory.create(weight: 100.5);

      final set = ExerciseSet.fromJson(json);

      expect(set.weight, isA<double>());
      expect(set.weight, 100.5);
    });

    test('fromJson handles null weight', () {
      final json = TestSetFactory.create();
      json['weight'] = null;

      final set = ExerciseSet.fromJson(json);

      expect(set.weight, isNull);
    });

    test('fromJson handles null reps', () {
      final json = TestSetFactory.create();
      json['reps'] = null;

      final set = ExerciseSet.fromJson(json);

      expect(set.reps, isNull);
    });

    test('fromJson handles null rpe', () {
      final json = TestSetFactory.create();

      final set = ExerciseSet.fromJson(json);

      expect(set.rpe, isNull);
    });

    test('fromJson handles null notes', () {
      final json = TestSetFactory.create();

      final set = ExerciseSet.fromJson(json);

      expect(set.notes, isNull);
    });

    test('isCompleted defaults to false when key is absent', () {
      final json = TestSetFactory.create();
      json.remove('is_completed');

      final set = ExerciseSet.fromJson(json);

      expect(set.isCompleted, false);
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
      final roundTripped = ExerciseSet.fromJson(set.toJson());

      expect(roundTripped, set);
    });

    test('toJson serializes setType as name string', () {
      final json = TestSetFactory.create(setType: 'dropset');
      final set = ExerciseSet.fromJson(json);
      final serialized = set.toJson();

      expect(serialized['set_type'], 'dropset');
    });

    test('equality works via Freezed == operator', () {
      final json = TestSetFactory.create();
      final a = ExerciseSet.fromJson(json);
      final b = ExerciseSet.fromJson(json);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('ActiveWorkoutExercise', () {
    test('fromJson parses workout exercise and sets', () {
      final weJson = TestWorkoutExerciseFactory.create(id: 'we-001');
      final setsJson = [
        TestSetFactory.create(id: 'set-001', workoutExerciseId: 'we-001'),
        TestSetFactory.create(
          id: 'set-002',
          workoutExerciseId: 'we-001',
          setNumber: 2,
        ),
      ];
      final json = {'workout_exercise': weJson, 'sets': setsJson};

      final awe = ActiveWorkoutExercise.fromJson(json);

      expect(awe.workoutExercise.id, 'we-001');
      expect(awe.sets, hasLength(2));
      expect(awe.sets[0].id, 'set-001');
      expect(awe.sets[1].id, 'set-002');
    });

    test('fromJson defaults sets to empty list when key is absent', () {
      final json = {'workout_exercise': TestWorkoutExerciseFactory.create()};

      final awe = ActiveWorkoutExercise.fromJson(json);

      expect(awe.sets, isEmpty);
    });

    test('toJson round-trip preserves workout exercise and sets', () {
      final json = {
        'workout_exercise': TestWorkoutExerciseFactory.create(),
        'sets': [TestSetFactory.create()],
      };

      final awe = ActiveWorkoutExercise.fromJson(json);
      // Round-trip through jsonEncode/jsonDecode to match production usage.
      final roundTripped = ActiveWorkoutExercise.fromJson(
        jsonDecode(jsonEncode(awe.toJson())) as Map<String, dynamic>,
      );

      expect(roundTripped.workoutExercise.id, awe.workoutExercise.id);
      expect(roundTripped.sets, hasLength(1));
    });

    test('equality works via Freezed == operator', () {
      final json = {
        'workout_exercise': TestWorkoutExerciseFactory.create(),
        'sets': <Map<String, dynamic>>[],
      };
      final a = ActiveWorkoutExercise.fromJson(json);
      final b = ActiveWorkoutExercise.fromJson(json);

      expect(a, b);
    });
  });

  group('ActiveWorkoutState', () {
    test('fromJson parses complete data', () {
      final json = TestActiveWorkoutStateFactory.create();

      final state = ActiveWorkoutState.fromJson(json);

      expect(state.workout.id, 'workout-001');
      expect(state.exercises, isEmpty);
      expect(state.schemaVersion, 1);
    });

    test('fromJson parses state with exercises', () {
      final json = TestActiveWorkoutStateFactory.createWithExercises(
        exerciseCount: 2,
        setsPerExercise: 3,
      );

      final state = ActiveWorkoutState.fromJson(json);

      expect(state.exercises, hasLength(2));
      expect(state.exercises[0].sets, hasLength(3));
      expect(state.exercises[1].sets, hasLength(3));
    });

    test('exercises defaults to empty list when key is absent', () {
      final json = TestActiveWorkoutStateFactory.create();
      json.remove('exercises');

      final state = ActiveWorkoutState.fromJson(json);

      expect(state.exercises, isEmpty);
    });

    test('schemaVersion defaults to 1 when key is absent', () {
      final json = TestActiveWorkoutStateFactory.create();
      json.remove('schema_version');

      final state = ActiveWorkoutState.fromJson(json);

      expect(state.schemaVersion, 1);
    });

    test('toJson round-trip preserves workout', () {
      final json = TestActiveWorkoutStateFactory.create();
      final state = ActiveWorkoutState.fromJson(json);
      // Round-trip through jsonEncode/jsonDecode to match production usage.
      final roundTripped = ActiveWorkoutState.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
      );

      expect(roundTripped.workout, state.workout);
      expect(roundTripped.schemaVersion, state.schemaVersion);
    });

    test('toJson round-trip preserves exercises and sets', () {
      final json = TestActiveWorkoutStateFactory.createWithExercises(
        exerciseCount: 1,
        setsPerExercise: 2,
      );
      final state = ActiveWorkoutState.fromJson(json);
      // Round-trip through jsonEncode/jsonDecode to match production usage.
      final roundTripped = ActiveWorkoutState.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
      );

      expect(roundTripped.exercises, hasLength(1));
      expect(roundTripped.exercises[0].sets, hasLength(2));
    });

    test('equality works via Freezed == operator', () {
      final json = TestActiveWorkoutStateFactory.create();
      final a = ActiveWorkoutState.fromJson(json);
      final b = ActiveWorkoutState.fromJson(json);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
