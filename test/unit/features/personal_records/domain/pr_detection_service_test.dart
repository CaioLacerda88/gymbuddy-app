import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';
import 'package:repsaga/features/personal_records/domain/pr_detection_service.dart';
import 'package:repsaga/features/personal_records/models/personal_record.dart';
import 'package:repsaga/features/personal_records/models/record_type.dart';
import 'package:repsaga/features/workouts/models/active_workout_state.dart';
import 'package:repsaga/features/workouts/models/exercise_set.dart';
import 'package:repsaga/features/workouts/models/set_type.dart';
import 'package:repsaga/features/workouts/models/workout_exercise.dart';

ActiveWorkoutExercise makeExercise({
  String exerciseId = 'exercise-001',
  EquipmentType equipmentType = EquipmentType.barbell,
  List<ExerciseSet>? sets,
}) {
  final exercise = Exercise(
    id: exerciseId,
    name: 'Test Exercise',
    muscleGroup: MuscleGroup.chest,
    equipmentType: equipmentType,
    isDefault: true,
    createdAt: DateTime(2026),
  );
  final we = WorkoutExercise(
    id: 'we-$exerciseId',
    workoutId: 'workout-001',
    exerciseId: exerciseId,
    order: 0,
    exercise: exercise,
  );
  return ActiveWorkoutExercise(workoutExercise: we, sets: sets ?? []);
}

ExerciseSet makeSet({
  String id = 'set-001',
  double weight = 100,
  int reps = 10,
  SetType setType = SetType.working,
  bool isCompleted = true,
}) {
  return ExerciseSet(
    id: id,
    workoutExerciseId: 'we-exercise-001',
    setNumber: 1,
    weight: weight,
    reps: reps,
    setType: setType,
    isCompleted: isCompleted,
    createdAt: DateTime(2026),
  );
}

void main() {
  late PRDetectionService service;

  setUp(() {
    service = PRDetectionService();
  });

  group('PRDetectionService', () {
    test('detects max weight PR from working sets', () {
      final exercises = [
        makeExercise(
          sets: [
            makeSet(id: 's1', weight: 80, reps: 10),
            makeSet(id: 's2', weight: 100, reps: 10),
            makeSet(id: 's3', weight: 90, reps: 10),
          ],
        ),
      ];

      final result = service.detectPRs(
        userId: 'user-001',
        exercises: exercises,
        existingRecords: {},
      );

      expect(result.isFirstWorkout, isTrue);
      final maxWeight = result.newRecords
          .where((r) => r.recordType == RecordType.maxWeight)
          .first;
      expect(maxWeight.value, 100);
      // Should also have maxReps and maxVolume
      expect(
        result.newRecords.map((r) => r.recordType).toSet(),
        containsAll([
          RecordType.maxWeight,
          RecordType.maxReps,
          RecordType.maxVolume,
        ]),
      );
    });

    test('detects max reps PR', () {
      final exercises = [
        makeExercise(
          sets: [
            makeSet(id: 's1', weight: 80, reps: 10),
            makeSet(id: 's2', weight: 80, reps: 12),
            makeSet(id: 's3', weight: 80, reps: 8),
          ],
        ),
      ];

      final result = service.detectPRs(
        userId: 'user-001',
        exercises: exercises,
        existingRecords: {},
      );

      final maxReps = result.newRecords
          .where((r) => r.recordType == RecordType.maxReps)
          .first;
      expect(maxReps.value, 12);
    });

    test('detects max volume PR (weight x reps)', () {
      final exercises = [
        makeExercise(
          sets: [
            makeSet(id: 's1', weight: 100, reps: 5), // 500
            makeSet(id: 's2', weight: 80, reps: 8), // 640
            makeSet(id: 's3', weight: 60, reps: 10), // 600
          ],
        ),
      ];

      final result = service.detectPRs(
        userId: 'user-001',
        exercises: exercises,
        existingRecords: {},
      );

      final maxVolume = result.newRecords
          .where((r) => r.recordType == RecordType.maxVolume)
          .first;
      expect(maxVolume.value, 640);
    });

    test('excludes warmup sets', () {
      final exercises = [
        makeExercise(
          sets: [
            makeSet(id: 's1', weight: 200, reps: 5, setType: SetType.warmup),
            makeSet(id: 's2', weight: 100, reps: 10),
          ],
        ),
      ];

      final result = service.detectPRs(
        userId: 'user-001',
        exercises: exercises,
        existingRecords: {},
      );

      final maxWeight = result.newRecords
          .where((r) => r.recordType == RecordType.maxWeight)
          .first;
      expect(maxWeight.value, 100);
    });

    test('excludes dropset and failure sets', () {
      final exercises = [
        makeExercise(
          sets: [
            makeSet(id: 's1', weight: 100, reps: 10),
            makeSet(id: 's2', weight: 150, reps: 8, setType: SetType.dropset),
            makeSet(id: 's3', weight: 120, reps: 6, setType: SetType.failure),
          ],
        ),
      ];

      final result = service.detectPRs(
        userId: 'user-001',
        exercises: exercises,
        existingRecords: {},
      );

      final maxWeight = result.newRecords
          .where((r) => r.recordType == RecordType.maxWeight)
          .first;
      expect(maxWeight.value, 100);
    });

    test('excludes incomplete sets', () {
      final exercises = [
        makeExercise(
          sets: [
            makeSet(id: 's1', weight: 80, reps: 10, isCompleted: true),
            makeSet(id: 's2', weight: 100, reps: 10, isCompleted: false),
          ],
        ),
      ];

      final result = service.detectPRs(
        userId: 'user-001',
        exercises: exercises,
        existingRecords: {},
      );

      final maxWeight = result.newRecords
          .where((r) => r.recordType == RecordType.maxWeight)
          .first;
      expect(maxWeight.value, 80);
    });

    test('bodyweight exercise with zero weight tracks only maxReps', () {
      final exercises = [
        makeExercise(
          equipmentType: EquipmentType.bodyweight,
          sets: [makeSet(id: 's1', weight: 0, reps: 15)],
        ),
      ];

      final result = service.detectPRs(
        userId: 'user-001',
        exercises: exercises,
        existingRecords: {},
      );

      expect(result.newRecords.length, 1);
      expect(result.newRecords.first.recordType, RecordType.maxReps);
      expect(result.newRecords.first.value, 15);
    });

    test('bodyweight exercise with added weight tracks all three', () {
      final exercises = [
        makeExercise(
          equipmentType: EquipmentType.bodyweight,
          sets: [makeSet(id: 's1', weight: 10, reps: 12)],
        ),
      ];

      final result = service.detectPRs(
        userId: 'user-001',
        exercises: exercises,
        existingRecords: {},
      );

      expect(result.newRecords.length, 3);
      final types = result.newRecords.map((r) => r.recordType).toSet();
      expect(types, {
        RecordType.maxWeight,
        RecordType.maxReps,
        RecordType.maxVolume,
      });
    });

    test('ties are NOT new PRs (strictly greater required)', () {
      final existingRecord = PersonalRecord(
        id: 'pr-existing',
        userId: 'user-001',
        exerciseId: 'exercise-001',
        recordType: RecordType.maxWeight,
        value: 100,
        achievedAt: DateTime(2026),
      );

      final exercises = [
        makeExercise(sets: [makeSet(id: 's1', weight: 100, reps: 10)]),
      ];

      final result = service.detectPRs(
        userId: 'user-001',
        exercises: exercises,
        existingRecords: {
          'exercise-001': [existingRecord],
        },
      );

      final maxWeightRecords = result.newRecords.where(
        (r) => r.recordType == RecordType.maxWeight,
      );
      expect(maxWeightRecords, isEmpty);
    });

    test('first workout detection', () {
      final exercises = [
        makeExercise(sets: [makeSet(id: 's1', weight: 100, reps: 10)]),
      ];

      final result = service.detectPRs(
        userId: 'user-001',
        exercises: exercises,
        existingRecords: {},
      );

      expect(result.isFirstWorkout, isTrue);
    });

    test('not first workout when existing records present', () {
      final existingRecord = PersonalRecord(
        id: 'pr-existing',
        userId: 'user-001',
        exerciseId: 'exercise-001',
        recordType: RecordType.maxWeight,
        value: 80,
        achievedAt: DateTime(2026),
      );

      final exercises = [
        makeExercise(sets: [makeSet(id: 's1', weight: 100, reps: 10)]),
      ];

      final result = service.detectPRs(
        userId: 'user-001',
        exercises: exercises,
        existingRecords: {
          'exercise-001': [existingRecord],
        },
      );

      expect(result.isFirstWorkout, isFalse);
    });

    test('skips exercise with null exercise model', () {
      const we = WorkoutExercise(
        id: 'we-null',
        workoutId: 'workout-001',
        exerciseId: 'exercise-null',
        order: 0,
        exercise: null,
      );
      final exercises = [
        ActiveWorkoutExercise(
          workoutExercise: we,
          sets: [makeSet(id: 's1', weight: 100, reps: 10)],
        ),
      ];

      final result = service.detectPRs(
        userId: 'user-001',
        exercises: exercises,
        existingRecords: {},
      );

      expect(result.newRecords, isEmpty);
    });

    test('skips sets with 0 reps', () {
      final exercises = [
        makeExercise(sets: [makeSet(id: 's1', weight: 100, reps: 0)]),
      ];

      final result = service.detectPRs(
        userId: 'user-001',
        exercises: exercises,
        existingRecords: {},
      );

      expect(result.newRecords, isEmpty);
    });

    test('skips sets with null reps', () {
      final exercises = [
        makeExercise(
          sets: [
            ExerciseSet(
              id: 's1',
              workoutExerciseId: 'we-exercise-001',
              setNumber: 1,
              weight: 100,
              reps: null,
              setType: SetType.working,
              isCompleted: true,
              createdAt: DateTime(2026),
            ),
          ],
        ),
      ];

      final result = service.detectPRs(
        userId: 'user-001',
        exercises: exercises,
        existingRecords: {},
      );

      expect(result.newRecords, isEmpty);
    });

    test('handles multiple exercises in one workout', () {
      final exercises = [
        makeExercise(
          exerciseId: 'exercise-A',
          sets: [makeSet(id: 'sA1', weight: 100, reps: 10)],
        ),
        makeExercise(
          exerciseId: 'exercise-B',
          sets: [makeSet(id: 'sB1', weight: 60, reps: 15)],
        ),
      ];

      final result = service.detectPRs(
        userId: 'user-001',
        exercises: exercises,
        existingRecords: {},
      );

      final exerciseIds = result.newRecords.map((r) => r.exerciseId).toSet();
      expect(exerciseIds, contains('exercise-A'));
      expect(exerciseIds, contains('exercise-B'));
    });

    test('PR with 999kg extreme value works', () {
      final exercises = [
        makeExercise(sets: [makeSet(id: 's1', weight: 999, reps: 1)]),
      ];

      final result = service.detectPRs(
        userId: 'user-001',
        exercises: exercises,
        existingRecords: {},
      );

      final maxWeight = result.newRecords
          .where((r) => r.recordType == RecordType.maxWeight)
          .first;
      expect(maxWeight.value, 999);
    });
  });
}
