import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';
import 'package:repsaga/features/workouts/data/workout_repository.dart';
import 'package:repsaga/features/workouts/models/set_type.dart';

import '../../../../fixtures/test_factories.dart';

/// Merges a factory map with additional keys, returning `Map&lt;String, dynamic&gt;`.
Map<String, dynamic> _merge(
  Map<String, dynamic> base,
  Map<String, dynamic> extra,
) {
  return {...base, ...extra};
}

/// Builds a workout_exercise entry with sets attached.
///
/// Phase 15f Stage 6: joined exercise data is no longer embedded in the
/// query result — the parser resolves it from a separate `exerciseMap`
/// produced by `ExerciseRepository.getExercisesByIds`. Tests that assert
/// on `WorkoutExercise.exercise` build the row with `we['exercise_id']`
/// and pass a matching map as the second arg to `parseWorkoutDetail`.
Map<String, dynamic> _weEntry({
  required Map<String, dynamic> we,
  List<Map<String, dynamic>> sets = const [],
}) {
  return _merge(we, {'sets': sets});
}

void main() {
  group('WorkoutRepository.parseWorkoutDetail', () {
    group('basic parsing', () {
      test('parses workout with no exercises', () {
        final data = _merge(TestWorkoutFactory.create(), {
          'workout_exercises': <dynamic>[],
        });

        final result = WorkoutRepository.parseWorkoutDetail(data);

        expect(result.workout.id, 'workout-001');
        expect(result.exercises, isEmpty);
        expect(result.setsByExercise, isEmpty);
      });

      test('handles absent workout_exercises key', () {
        final data = Map<String, dynamic>.from(TestWorkoutFactory.create());

        final result = WorkoutRepository.parseWorkoutDetail(data);

        expect(result.exercises, isEmpty);
        expect(result.setsByExercise, isEmpty);
      });

      test('parses workout fields correctly', () {
        final data = _merge(
          TestWorkoutFactory.create(
            name: 'Morning Session',
            userId: 'user-abc',
          ),
          {'workout_exercises': <dynamic>[]},
        );

        final result = WorkoutRepository.parseWorkoutDetail(data);

        expect(result.workout.name, 'Morning Session');
        expect(result.workout.userId, 'user-abc');
      });
    });

    group('exercise parsing', () {
      test('parses a single exercise with sets', () {
        const weId = 'we-001';
        final data = _merge(TestWorkoutFactory.create(), {
          'workout_exercises': [
            _weEntry(
              we: TestWorkoutExerciseFactory.create(id: weId),
              sets: [
                TestSetFactory.create(
                  id: 'set-001',
                  workoutExerciseId: weId,
                  setNumber: 1,
                ),
              ],
            ),
          ],
        });

        final result = WorkoutRepository.parseWorkoutDetail(data);

        expect(result.exercises, hasLength(1));
        expect(result.exercises[0].id, weId);
        expect(result.setsByExercise[weId], hasLength(1));
        expect(result.setsByExercise[weId]![0].id, 'set-001');
      });

      test('parses exercise with no sets', () {
        const weId = 'we-001';
        final data = _merge(TestWorkoutFactory.create(), {
          'workout_exercises': [
            _weEntry(we: TestWorkoutExerciseFactory.create(id: weId)),
          ],
        });

        final result = WorkoutRepository.parseWorkoutDetail(data);

        expect(result.exercises, hasLength(1));
        expect(result.setsByExercise[weId], isEmpty);
      });

      test('parses multiple exercises', () {
        final data = _merge(TestWorkoutFactory.create(), {
          'workout_exercises': [
            _weEntry(
              we: TestWorkoutExerciseFactory.create(id: 'we-001', order: 1),
            ),
            _weEntry(
              we: TestWorkoutExerciseFactory.create(id: 'we-002', order: 2),
            ),
          ],
        });

        final result = WorkoutRepository.parseWorkoutDetail(data);

        expect(result.exercises, hasLength(2));
        expect(result.setsByExercise.keys, containsAll(['we-001', 'we-002']));
      });
    });

    group('sorting', () {
      test('sorts exercises by order ascending', () {
        final data = _merge(TestWorkoutFactory.create(), {
          'workout_exercises': [
            _weEntry(
              we: TestWorkoutExerciseFactory.create(id: 'we-003', order: 3),
            ),
            _weEntry(
              we: TestWorkoutExerciseFactory.create(id: 'we-001', order: 1),
            ),
            _weEntry(
              we: TestWorkoutExerciseFactory.create(id: 'we-002', order: 2),
            ),
          ],
        });

        final result = WorkoutRepository.parseWorkoutDetail(data);

        expect(result.exercises[0].id, 'we-001');
        expect(result.exercises[1].id, 'we-002');
        expect(result.exercises[2].id, 'we-003');
      });

      test('sorts sets by set_number ascending', () {
        const weId = 'we-001';
        final data = _merge(TestWorkoutFactory.create(), {
          'workout_exercises': [
            _weEntry(
              we: TestWorkoutExerciseFactory.create(id: weId),
              sets: [
                TestSetFactory.create(
                  id: 'set-003',
                  workoutExerciseId: weId,
                  setNumber: 3,
                ),
                TestSetFactory.create(
                  id: 'set-001',
                  workoutExerciseId: weId,
                  setNumber: 1,
                ),
                TestSetFactory.create(
                  id: 'set-002',
                  workoutExerciseId: weId,
                  setNumber: 2,
                ),
              ],
            ),
          ],
        });

        final result = WorkoutRepository.parseWorkoutDetail(data);

        final sets = result.setsByExercise[weId]!;
        expect(sets[0].setNumber, 1);
        expect(sets[1].setNumber, 2);
        expect(sets[2].setNumber, 3);
        expect(sets[0].id, 'set-001');
        expect(sets[2].id, 'set-003');
      });
    });

    group('joined exercise data', () {
      // Phase 15f Stage 6: rows carry `exercise_id` only; the parser resolves
      // [WorkoutExercise.exercise] from the optional `exerciseMap` argument
      // populated by [ExerciseRepository.getExercisesByIds] in the active locale.

      test('resolves exercise from exerciseMap by exercise_id', () {
        const weId = 'we-001';
        final exercise = Exercise.fromJson(
          TestExerciseFactory.create(
            id: 'exercise-001',
            name: 'Bench Press',
            muscleGroup: 'chest',
            equipmentType: 'barbell',
          ),
        );
        final data = _merge(TestWorkoutFactory.create(), {
          'workout_exercises': [
            _weEntry(
              we: TestWorkoutExerciseFactory.create(
                id: weId,
                exerciseId: 'exercise-001',
              ),
            ),
          ],
        });

        final result = WorkoutRepository.parseWorkoutDetail(data, {
          'exercise-001': exercise,
        });

        expect(result.exercises[0].exercise, isNotNull);
        expect(result.exercises[0].exercise!.id, 'exercise-001');
        expect(result.exercises[0].exercise!.name, 'Bench Press');
        expect(result.exercises[0].exercise!.muscleGroup, MuscleGroup.chest);
      });

      test('exercise is null when exerciseMap is empty (default)', () {
        const weId = 'we-001';
        final data = _merge(TestWorkoutFactory.create(), {
          'workout_exercises': [
            _weEntry(we: TestWorkoutExerciseFactory.create(id: weId)),
          ],
        });

        final result = WorkoutRepository.parseWorkoutDetail(data);

        expect(result.exercises[0].exercise, isNull);
      });

      test('exercise is null when exercise_id is missing from exerciseMap '
          '(soft-deleted / foreign-owned)', () {
        const weId = 'we-001';
        final data = _merge(TestWorkoutFactory.create(), {
          'workout_exercises': [
            _weEntry(
              we: TestWorkoutExerciseFactory.create(
                id: weId,
                exerciseId: 'exercise-missing',
              ),
            ),
          ],
        });

        // exerciseMap doesn't contain 'exercise-missing'.
        final result = WorkoutRepository.parseWorkoutDetail(data, const {});

        expect(result.exercises[0].exercise, isNull);
      });
    });

    group('set data integrity', () {
      test('preserves set fields including setType and weight', () {
        const weId = 'we-001';
        final data = _merge(TestWorkoutFactory.create(), {
          'workout_exercises': [
            _weEntry(
              we: TestWorkoutExerciseFactory.create(id: weId),
              sets: [
                TestSetFactory.create(
                  id: 'set-001',
                  workoutExerciseId: weId,
                  setNumber: 1,
                  setType: 'warmup',
                  weight: 40.0,
                  reps: 15,
                  rpe: 5,
                  isCompleted: true,
                ),
              ],
            ),
          ],
        });

        final result = WorkoutRepository.parseWorkoutDetail(data);

        final set = result.setsByExercise[weId]![0];
        expect(set.setType, SetType.warmup);
        expect(set.weight, 40.0);
        expect(set.reps, 15);
        expect(set.rpe, 5);
        expect(set.isCompleted, true);
      });

      test('sets map keyed by workout_exercise id', () {
        final data = _merge(TestWorkoutFactory.create(), {
          'workout_exercises': [
            _weEntry(
              we: TestWorkoutExerciseFactory.create(id: 'we-A', order: 1),
              sets: [
                TestSetFactory.create(
                  id: 'set-A1',
                  workoutExerciseId: 'we-A',
                  setNumber: 1,
                ),
              ],
            ),
            _weEntry(
              we: TestWorkoutExerciseFactory.create(id: 'we-B', order: 2),
              sets: [
                TestSetFactory.create(
                  id: 'set-B1',
                  workoutExerciseId: 'we-B',
                  setNumber: 1,
                ),
                TestSetFactory.create(
                  id: 'set-B2',
                  workoutExerciseId: 'we-B',
                  setNumber: 2,
                ),
              ],
            ),
          ],
        });

        final result = WorkoutRepository.parseWorkoutDetail(data);

        expect(result.setsByExercise['we-A'], hasLength(1));
        expect(result.setsByExercise['we-B'], hasLength(2));
        expect(result.setsByExercise['we-A']![0].id, 'set-A1');
        expect(result.setsByExercise['we-B']![0].id, 'set-B1');
        expect(result.setsByExercise['we-B']![1].id, 'set-B2');
      });
    });
  });

  group('WorkoutRepository.buildExerciseSummary', () {
    /// Phase 15f Stage 6: rows now carry `exercise_id` (not an embedded
    /// `exercise` join object) and names are resolved via a separate
    /// `namesById` map produced by [ExerciseRepository.getExercisesByIds].

    /// Builds N rows with sequential exercise_ids ('ex-1', 'ex-2', ...) and
    /// returns the matching id→name map for [buildExerciseSummary].
    ({List<Map<String, dynamic>> rows, Map<String, String> namesById})
    makeEntries(List<String> names) {
      final rows = <Map<String, dynamic>>[];
      final namesById = <String, String>{};
      for (var i = 0; i < names.length; i++) {
        final id = 'ex-${i + 1}';
        rows.add({'order': i + 1, 'exercise_id': id});
        namesById[id] = names[i];
      }
      return (rows: rows, namesById: namesById);
    }

    test('returns empty string for empty list', () {
      expect(WorkoutRepository.buildExerciseSummary([], const {}), '');
    });

    test('returns single name when only one exercise', () {
      final entries = makeEntries(['Bench Press']);
      expect(
        WorkoutRepository.buildExerciseSummary(entries.rows, entries.namesById),
        'Bench Press',
      );
    });

    test('returns comma-separated names for up to 3 exercises', () {
      final entries = makeEntries(['Bench Press', 'Squat', 'Deadlift']);
      expect(
        WorkoutRepository.buildExerciseSummary(entries.rows, entries.namesById),
        'Bench Press, Squat, Deadlift',
      );
    });

    test('truncates at 3 and appends +N for more than 3 exercises', () {
      final entries = makeEntries([
        'Bench Press',
        'Squat',
        'Deadlift',
        'OHP',
        'Row',
      ]);
      expect(
        WorkoutRepository.buildExerciseSummary(entries.rows, entries.namesById),
        'Bench Press, Squat, Deadlift +2',
      );
    });

    test('sorts exercises by order field before naming', () {
      final entries = [
        {'order': 3, 'exercise_id': 'ex-3'},
        {'order': 1, 'exercise_id': 'ex-1'},
        {'order': 2, 'exercise_id': 'ex-2'},
      ];
      const namesById = {'ex-1': 'First', 'ex-2': 'Second', 'ex-3': 'Third'};
      expect(
        WorkoutRepository.buildExerciseSummary(entries, namesById),
        'First, Second, Third',
      );
    });

    test('skips entries where exercise_id is missing from the names map '
        '(soft-deleted / foreign-owned)', () {
      final entries = [
        {'order': 1, 'exercise_id': 'ex-missing'},
        {'order': 2, 'exercise_id': 'ex-known'},
      ];
      const namesById = {'ex-known': 'Squat'};
      expect(
        WorkoutRepository.buildExerciseSummary(entries, namesById),
        'Squat',
      );
    });

    test('skips entries where exercise_id is null', () {
      final entries = [
        {'order': 1, 'exercise_id': null},
        {'order': 2, 'exercise_id': 'ex-1'},
      ];
      const namesById = {'ex-1': 'Squat'};
      expect(
        WorkoutRepository.buildExerciseSummary(entries, namesById),
        'Squat',
      );
    });

    test('returns empty string when names map is empty', () {
      final entries = [
        {'order': 1, 'exercise_id': 'ex-1'},
        {'order': 2, 'exercise_id': 'ex-2'},
      ];
      expect(WorkoutRepository.buildExerciseSummary(entries, const {}), '');
    });
  });
}
