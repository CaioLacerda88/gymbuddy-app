import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/workouts/models/exercise_set.dart';
import 'package:repsaga/features/workouts/models/set_type.dart';
import 'package:repsaga/features/workouts/utils/set_filters.dart';

ExerciseSet _makeSet({
  String id = 'set-001',
  int? reps = 10,
  double? weight = 100,
  SetType setType = SetType.working,
  bool isCompleted = true,
}) {
  return ExerciseSet(
    id: id,
    workoutExerciseId: 'we-001',
    setNumber: 1,
    reps: reps,
    weight: weight,
    setType: setType,
    isCompleted: isCompleted,
    createdAt: DateTime(2026),
  );
}

void main() {
  group('isCompletedWorkingSet', () {
    test('true for completed working set with positive reps', () {
      expect(isCompletedWorkingSet(_makeSet()), isTrue);
    });

    test('false for warmup set', () {
      expect(isCompletedWorkingSet(_makeSet(setType: SetType.warmup)), isFalse);
    });

    test('false for dropset', () {
      expect(
        isCompletedWorkingSet(_makeSet(setType: SetType.dropset)),
        isFalse,
      );
    });

    test('false for failure set', () {
      expect(
        isCompletedWorkingSet(_makeSet(setType: SetType.failure)),
        isFalse,
      );
    });

    test('false for incomplete set', () {
      expect(isCompletedWorkingSet(_makeSet(isCompleted: false)), isFalse);
    });

    test('false for zero reps', () {
      expect(isCompletedWorkingSet(_makeSet(reps: 0)), isFalse);
    });

    test('false for null reps', () {
      expect(isCompletedWorkingSet(_makeSet(reps: null)), isFalse);
    });
  });

  group('completedWorkingSets', () {
    test('returns only sets matching the predicate', () {
      final sets = [
        _makeSet(id: 'a'),
        _makeSet(id: 'b', setType: SetType.warmup),
        _makeSet(id: 'c', isCompleted: false),
        _makeSet(id: 'd', reps: 0),
        _makeSet(id: 'e'),
      ];

      final result = completedWorkingSets(sets);

      expect(result.map((s) => s.id).toList(), ['a', 'e']);
    });

    test('empty input returns empty list', () {
      expect(completedWorkingSets(const []), isEmpty);
    });
  });
}
