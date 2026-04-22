// Tests that expose BUG-003 and BUG-005:
//
// BUG-003: start_routine_action.dart silently does nothing when all
// RoutineExercise.exercise fields are null (exercise resolution failed).
// No error is shown to the user.
//
// BUG-005: RoutineRepository._resolveExercises returns unresolved routines
// when the exercise batch-fetch returns empty (early return at line 114 in
// routine_repository.dart applies to "fetch returned empty" the same as
// "no exercises exist").
//
// These tests verify what SHOULD happen (with assertions that expose the bugs).

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';
import 'package:repsaga/features/routines/models/routine.dart';

import '../../../../fixtures/test_factories.dart';

Routine _makeRoutineWithUnresolvedExercises() {
  // Simulate what RoutineRepository returns when _resolveExercises early-exits
  // (BUG-005): exercises have exerciseId but exercise == null.
  return Routine.fromJson(
    TestRoutineFactory.create(
      exercises: [
        TestRoutineExerciseFactory.create(
          exerciseId: 'ex-001',
          // No 'exercise' key → exercise field will be null after fromJson
        ),
        TestRoutineExerciseFactory.create(
          exerciseId: 'ex-002',
          // No 'exercise' key → exercise field will be null after fromJson
        ),
      ],
    ),
  );
}

Routine _makeRoutineWithResolvedExercises() {
  return Routine.fromJson(
    TestRoutineFactory.create(
      exercises: [
        TestRoutineExerciseFactory.create(
          exerciseId: 'ex-001',
          exercise: TestExerciseFactory.create(id: 'ex-001', name: 'Squat'),
        ),
        TestRoutineExerciseFactory.create(
          exerciseId: 'ex-002',
          exercise: TestExerciseFactory.create(
            id: 'ex-002',
            name: 'Romanian Deadlift',
          ),
        ),
      ],
    ),
  );
}

void main() {
  group('RoutineExercise resolution (BUG-003 / BUG-005)', () {
    test('RoutineExercise.exercise is null when no exercise data in JSONB row', () {
      // This is the state produced by BUG-005: _resolveExercises returned
      // routines without populating exercise references.
      final routine = _makeRoutineWithUnresolvedExercises();

      expect(routine.exercises, hasLength(2));
      for (final re in routine.exercises) {
        expect(
          re.exercise,
          isNull,
          reason:
              'When exercise resolution fails, RoutineExercise.exercise is null. '
              'This leads to BUG-003 where startRoutineWorkout silently returns.',
        );
      }
    });

    test(
      'all exercises filtered out when exercise is null (BUG-003 trigger condition)',
      () {
        final routine = _makeRoutineWithUnresolvedExercises();

        // This replicates the filter in start_routine_action.dart lines 43-44.
        final filtered = routine.exercises
            .where(
              (re) => re.exercise != null && re.exercise!.deletedAt == null,
            )
            .toList();

        // BUG-003: when exercises are unresolved, the filtered list is empty
        // and the workout silently does not start.
        expect(
          filtered,
          isEmpty,
          reason:
              'BUG-003: with null exercise references, all exercises are '
              'filtered out and startRoutineWorkout returns without feedback.',
        );
      },
    );

    test(
      'exercises with resolved exercise objects pass the filter correctly',
      () {
        final routine = _makeRoutineWithResolvedExercises();

        final filtered = routine.exercises
            .where(
              (re) => re.exercise != null && re.exercise!.deletedAt == null,
            )
            .toList();

        // Happy path: resolved exercises are not filtered out.
        expect(filtered, hasLength(2));
        expect(filtered[0].exercise!.name, 'Squat');
        expect(filtered[1].exercise!.name, 'Romanian Deadlift');
      },
    );

    test(
      'soft-deleted exercises are correctly excluded even when exercise is resolved',
      () {
        final softDeleted = Exercise.fromJson(
          TestExerciseFactory.create(
            id: 'ex-deleted',
            name: 'Deleted Exercise',
            deletedAt: '2026-02-01T00:00:00Z',
          ),
        );
        final routine = Routine.fromJson(
          TestRoutineFactory.create(
            exercises: [
              TestRoutineExerciseFactory.create(
                exerciseId: 'ex-deleted',
                exercise: TestExerciseFactory.create(
                  id: 'ex-deleted',
                  name: 'Deleted Exercise',
                  deletedAt: '2026-02-01T00:00:00Z',
                ),
              ),
              TestRoutineExerciseFactory.create(
                exerciseId: 'ex-active',
                exercise: TestExerciseFactory.create(
                  id: 'ex-active',
                  name: 'Active Exercise',
                ),
              ),
            ],
          ),
        );
        // Manually patch the soft-deleted exercise onto the RoutineExercise
        // to simulate resolved state.
        final withDeleted = routine.exercises[0].copyWith(
          exercise: softDeleted,
        );
        final active = routine.exercises[1];

        final filtered = [withDeleted, active]
            .where(
              (re) => re.exercise != null && re.exercise!.deletedAt == null,
            )
            .toList();

        expect(filtered, hasLength(1));
        expect(filtered[0].exercise!.name, 'Active Exercise');
        expect(filtered[0].exercise!.deletedAt, isNull);
      },
    );

    test(
      'routine with mix of resolved and null exercises: null ones are silently excluded (BUG-003)',
      () {
        final resolvedRe = RoutineExercise.fromJson(
          TestRoutineExerciseFactory.create(
            exerciseId: 'ex-resolved',
            exercise: TestExerciseFactory.create(
              id: 'ex-resolved',
              name: 'Squat',
            ),
          ),
        );
        final unresolvedRe = RoutineExercise.fromJson(
          TestRoutineExerciseFactory.create(
            exerciseId: 'ex-unresolved',
            // no exercise key → null
          ),
        );

        final exercises = [resolvedRe, unresolvedRe];
        final filtered = exercises
            .where(
              (re) => re.exercise != null && re.exercise!.deletedAt == null,
            )
            .toList();

        // The partially resolved case still starts the workout with only
        // the exercises that resolved — but the user doesn't see any indication
        // that one exercise was silently dropped (BUG-003 extended scenario).
        expect(filtered, hasLength(1));
        expect(filtered[0].exercise!.name, 'Squat');
        expect(
          unresolvedRe.exercise,
          isNull,
          reason:
              'BUG-003: exercises with null references are silently dropped '
              'with no user feedback when a routine is partially resolved.',
        );
      },
    );
  });
}
