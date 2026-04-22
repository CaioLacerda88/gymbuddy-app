import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';
import 'package:repsaga/features/workouts/models/routine_start_config.dart';

import '../../../../fixtures/test_factories.dart';

Exercise _makeExercise({
  String id = 'exercise-001',
  String name = 'Bench Press',
}) {
  return Exercise.fromJson(TestExerciseFactory.create(id: id, name: name));
}

void main() {
  group('RoutineStartExercise', () {
    test('stores all fields correctly', () {
      final exercise = _makeExercise();
      final rse = RoutineStartExercise(
        exerciseId: exercise.id,
        exercise: exercise,
        setCount: 4,
        targetReps: 10,
        restSeconds: 90,
      );

      expect(rse.exerciseId, exercise.id);
      expect(rse.exercise.name, 'Bench Press');
      expect(rse.setCount, 4);
      expect(rse.targetReps, 10);
      expect(rse.restSeconds, 90);
    });

    test('allows null targetReps and restSeconds', () {
      final exercise = _makeExercise();
      final rse = RoutineStartExercise(
        exerciseId: exercise.id,
        exercise: exercise,
        setCount: 3,
      );

      expect(rse.targetReps, isNull);
      expect(rse.restSeconds, isNull);
    });
  });

  group('RoutineStartConfig', () {
    test('creates from routine data with multiple exercises', () {
      final benchPress = _makeExercise();
      final squat = _makeExercise(id: 'exercise-002', name: 'Squat');

      final config = RoutineStartConfig(
        routineName: 'Push Day',
        exercises: [
          RoutineStartExercise(
            exerciseId: benchPress.id,
            exercise: benchPress,
            setCount: 4,
            targetReps: 10,
            restSeconds: 90,
          ),
          RoutineStartExercise(
            exerciseId: squat.id,
            exercise: squat,
            setCount: 3,
            targetReps: 8,
            restSeconds: 120,
          ),
        ],
      );

      expect(config.routineName, 'Push Day');
      expect(config.exercises, hasLength(2));
      expect(config.exercises[0].exerciseId, 'exercise-001');
      expect(config.exercises[0].setCount, 4);
      expect(config.exercises[1].exerciseId, 'exercise-002');
      expect(config.exercises[1].setCount, 3);
    });

    test('supports empty exercises list', () {
      const config = RoutineStartConfig(
        routineName: 'Empty Routine',
        exercises: [],
      );

      expect(config.routineName, 'Empty Routine');
      expect(config.exercises, isEmpty);
    });
  });
}
