import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/workouts/data/workout_local_storage.dart';
import 'package:gymbuddy_app/features/workouts/data/workout_repository.dart';
import 'package:gymbuddy_app/features/workouts/models/active_workout_state.dart';
import 'package:gymbuddy_app/features/workouts/models/set_type.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_providers.dart';
import 'package:gymbuddy_app/features/exercises/models/exercise.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../fixtures/test_factories.dart';

class MockWorkoutRepository extends Mock implements WorkoutRepository {}

class MockWorkoutLocalStorage extends Mock implements WorkoutLocalStorage {}

class FakeActiveWorkoutState extends Fake implements ActiveWorkoutState {}

/// Builds a typed [ActiveWorkoutState] from the test factories.
ActiveWorkoutState makeState({int exerciseCount = 0, int setsPerExercise = 0}) {
  final json = exerciseCount > 0
      ? TestActiveWorkoutStateFactory.createWithExercises(
          exerciseCount: exerciseCount,
          setsPerExercise: setsPerExercise,
        )
      : TestActiveWorkoutStateFactory.create();
  return ActiveWorkoutState.fromJson(json);
}

Exercise makeExercise({String id = 'exercise-new', String name = 'Squat'}) {
  return Exercise.fromJson(TestExerciseFactory.create(id: id, name: name));
}

/// Creates a container with mocked dependencies and a pre-seeded notifier state.
ProviderContainer makeContainer(ActiveWorkoutState? initialState) {
  final mockRepo = MockWorkoutRepository();
  final mockStorage = MockWorkoutLocalStorage();

  when(() => mockStorage.loadActiveWorkout()).thenReturn(initialState);
  when(() => mockStorage.saveActiveWorkout(any())).thenAnswer((_) async {});

  return ProviderContainer(
    overrides: [
      workoutRepositoryProvider.overrideWithValue(mockRepo),
      workoutLocalStorageProvider.overrideWithValue(mockStorage),
    ],
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeActiveWorkoutState());
  });

  group('ActiveWorkoutNotifier — local mutations', () {
    // ------------------------------------------------------------------ setup
    group('build', () {
      test('initialises to null when localStorage returns null', () async {
        final container = makeContainer(null);
        addTearDown(container.dispose);

        final state = await container.read(activeWorkoutProvider.future);

        expect(state, isNull);
      });

      test(
        'initialises from persisted state when localStorage has data',
        () async {
          final persisted = makeState(exerciseCount: 1, setsPerExercise: 2);
          final container = makeContainer(persisted);
          addTearDown(container.dispose);

          final state = await container.read(activeWorkoutProvider.future);

          expect(state, isNotNull);
          expect(state!.workout.id, persisted.workout.id);
          expect(state.exercises, hasLength(1));
        },
      );
    });

    // ---------------------------------------------------------------- addExercise
    group('addExercise', () {
      test('adds exercise to an empty workout', () async {
        final container = makeContainer(makeState());
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        container
            .read(activeWorkoutProvider.notifier)
            .addExercise(makeExercise());

        final result = container.read(activeWorkoutProvider).value!;
        expect(result.exercises, hasLength(1));
      });

      test('new exercise has order equal to its index position', () async {
        final container = makeContainer(makeState());
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        final notifier = container.read(activeWorkoutProvider.notifier);
        notifier.addExercise(makeExercise(id: 'ex-a', name: 'Squat'));
        notifier.addExercise(makeExercise(id: 'ex-b', name: 'Deadlift'));

        final result = container.read(activeWorkoutProvider).value!;
        expect(result.exercises[0].workoutExercise.order, 0);
        expect(result.exercises[1].workoutExercise.order, 1);
      });

      test('new exercise starts with no sets', () async {
        final container = makeContainer(makeState());
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        container
            .read(activeWorkoutProvider.notifier)
            .addExercise(makeExercise());

        final result = container.read(activeWorkoutProvider).value!;
        expect(result.exercises.first.sets, isEmpty);
      });

      test('new exercise workoutExercise links to correct workoutId', () async {
        final initial = makeState();
        final container = makeContainer(initial);
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        container
            .read(activeWorkoutProvider.notifier)
            .addExercise(makeExercise());

        final result = container.read(activeWorkoutProvider).value!;
        expect(
          result.exercises.first.workoutExercise.workoutId,
          initial.workout.id,
        );
      });

      test('does nothing when state is null', () {
        final container = makeContainer(null);
        addTearDown(container.dispose);

        // Should not throw.
        container
            .read(activeWorkoutProvider.notifier)
            .addExercise(makeExercise());

        expect(container.read(activeWorkoutProvider).value, isNull);
      });
    });

    // -------------------------------------------------------------- removeExercise
    group('removeExercise', () {
      test('removes the target exercise from the list', () async {
        final initial = makeState(exerciseCount: 2, setsPerExercise: 1);
        final container = makeContainer(initial);
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        final targetId = initial.exercises.first.workoutExercise.id;
        container.read(activeWorkoutProvider.notifier).removeExercise(targetId);

        final result = container.read(activeWorkoutProvider).value!;
        expect(result.exercises, hasLength(1));
        expect(
          result.exercises.any((e) => e.workoutExercise.id == targetId),
          isFalse,
        );
      });

      test('reorders remaining exercises starting from 0', () async {
        final initial = makeState(exerciseCount: 3, setsPerExercise: 0);
        final container = makeContainer(initial);
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        // Remove the first exercise.
        final firstId = initial.exercises.first.workoutExercise.id;
        container.read(activeWorkoutProvider.notifier).removeExercise(firstId);

        final result = container.read(activeWorkoutProvider).value!;
        expect(result.exercises[0].workoutExercise.order, 0);
        expect(result.exercises[1].workoutExercise.order, 1);
      });

      test('does nothing when workoutExerciseId does not exist', () async {
        final initial = makeState(exerciseCount: 1, setsPerExercise: 0);
        final container = makeContainer(initial);
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        container
            .read(activeWorkoutProvider.notifier)
            .removeExercise('nonexistent-id');

        final result = container.read(activeWorkoutProvider).value!;
        expect(result.exercises, hasLength(1));
      });
    });

    // ------------------------------------------------------------------ addSet
    group('addSet', () {
      test(
        'appends a set with setNumber 1 to an exercise that has no sets',
        () async {
          final initial = makeState(exerciseCount: 1, setsPerExercise: 0);
          final container = makeContainer(initial);
          addTearDown(container.dispose);
          await container.read(activeWorkoutProvider.future);

          final weId = initial.exercises.first.workoutExercise.id;
          container.read(activeWorkoutProvider.notifier).addSet(weId);

          final result = container.read(activeWorkoutProvider).value!;
          final sets = result.exercises.first.sets;
          expect(sets, hasLength(1));
          expect(sets.first.setNumber, 1);
        },
      );

      test('new set number equals existing set count plus one', () async {
        final initial = makeState(exerciseCount: 1, setsPerExercise: 2);
        final container = makeContainer(initial);
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        final weId = initial.exercises.first.workoutExercise.id;
        container.read(activeWorkoutProvider.notifier).addSet(weId);

        final result = container.read(activeWorkoutProvider).value!;
        expect(result.exercises.first.sets, hasLength(3));
        expect(result.exercises.first.sets.last.setNumber, 3);
      });

      test(
        'new set defaults to working type, not completed, zero weight/reps',
        () async {
          final initial = makeState(exerciseCount: 1, setsPerExercise: 0);
          final container = makeContainer(initial);
          addTearDown(container.dispose);
          await container.read(activeWorkoutProvider.future);

          final weId = initial.exercises.first.workoutExercise.id;
          container.read(activeWorkoutProvider.notifier).addSet(weId);

          final newSet = container
              .read(activeWorkoutProvider)
              .value!
              .exercises
              .first
              .sets
              .first;
          expect(newSet.setType, SetType.working);
          expect(newSet.isCompleted, isFalse);
          expect(newSet.weight, 0);
          expect(newSet.reps, 0);
        },
      );

      test('only affects the targeted exercise', () async {
        final initial = makeState(exerciseCount: 2, setsPerExercise: 1);
        final container = makeContainer(initial);
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        final firstWeId = initial.exercises.first.workoutExercise.id;
        container.read(activeWorkoutProvider.notifier).addSet(firstWeId);

        final result = container.read(activeWorkoutProvider).value!;
        expect(result.exercises.first.sets, hasLength(2));
        expect(result.exercises.last.sets, hasLength(1));
      });
    });

    // --------------------------------------------------------------- updateSet
    group('updateSet', () {
      test('updates weight on a specific set', () async {
        final initial = makeState(exerciseCount: 1, setsPerExercise: 1);
        final container = makeContainer(initial);
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        final weId = initial.exercises.first.workoutExercise.id;
        final setId = initial.exercises.first.sets.first.id;
        container
            .read(activeWorkoutProvider.notifier)
            .updateSet(weId, setId, weight: 100.0);

        final updatedSet = container
            .read(activeWorkoutProvider)
            .value!
            .exercises
            .first
            .sets
            .first;
        expect(updatedSet.weight, 100.0);
      });

      test('updates reps on a specific set', () async {
        final initial = makeState(exerciseCount: 1, setsPerExercise: 1);
        final container = makeContainer(initial);
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        final weId = initial.exercises.first.workoutExercise.id;
        final setId = initial.exercises.first.sets.first.id;
        container
            .read(activeWorkoutProvider.notifier)
            .updateSet(weId, setId, reps: 12);

        final updatedSet = container
            .read(activeWorkoutProvider)
            .value!
            .exercises
            .first
            .sets
            .first;
        expect(updatedSet.reps, 12);
      });

      test('updates setType on a specific set', () async {
        final initial = makeState(exerciseCount: 1, setsPerExercise: 1);
        final container = makeContainer(initial);
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        final weId = initial.exercises.first.workoutExercise.id;
        final setId = initial.exercises.first.sets.first.id;
        container
            .read(activeWorkoutProvider.notifier)
            .updateSet(weId, setId, setType: SetType.warmup);

        final updatedSet = container
            .read(activeWorkoutProvider)
            .value!
            .exercises
            .first
            .sets
            .first;
        expect(updatedSet.setType, SetType.warmup);
      });

      test(
        'preserves unspecified fields when doing a partial update',
        () async {
          final initial = makeState(exerciseCount: 1, setsPerExercise: 1);
          final container = makeContainer(initial);
          addTearDown(container.dispose);
          await container.read(activeWorkoutProvider.future);

          final weId = initial.exercises.first.workoutExercise.id;
          final originalSet = initial.exercises.first.sets.first;
          // Update only weight; reps should stay at their factory default.
          container
              .read(activeWorkoutProvider.notifier)
              .updateSet(weId, originalSet.id, weight: 80.0);

          final updatedSet = container
              .read(activeWorkoutProvider)
              .value!
              .exercises
              .first
              .sets
              .first;
          expect(updatedSet.weight, 80.0);
          expect(updatedSet.reps, originalSet.reps);
          expect(updatedSet.setType, originalSet.setType);
        },
      );

      test('does not affect other sets in the same exercise', () async {
        final initial = makeState(exerciseCount: 1, setsPerExercise: 3);
        final container = makeContainer(initial);
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        final weId = initial.exercises.first.workoutExercise.id;
        final secondSetId = initial.exercises.first.sets[1].id;
        container
            .read(activeWorkoutProvider.notifier)
            .updateSet(weId, secondSetId, weight: 999.0);

        final sets = container
            .read(activeWorkoutProvider)
            .value!
            .exercises
            .first
            .sets;
        expect(sets[0].weight, isNot(999.0));
        expect(sets[1].weight, 999.0);
        expect(sets[2].weight, isNot(999.0));
      });
    });

    // ------------------------------------------------------------- completeSet
    group('completeSet', () {
      test('toggles isCompleted from false to true', () async {
        // Factory default has isCompleted: true, so use addSet to get a fresh one.
        final initial = makeState(exerciseCount: 1, setsPerExercise: 0);
        final container = makeContainer(initial);
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        final weId = initial.exercises.first.workoutExercise.id;
        container.read(activeWorkoutProvider.notifier).addSet(weId);

        final addedSetId = container
            .read(activeWorkoutProvider)
            .value!
            .exercises
            .first
            .sets
            .first
            .id;
        expect(
          container
              .read(activeWorkoutProvider)
              .value!
              .exercises
              .first
              .sets
              .first
              .isCompleted,
          isFalse,
        );

        container
            .read(activeWorkoutProvider.notifier)
            .completeSet(weId, addedSetId);

        expect(
          container
              .read(activeWorkoutProvider)
              .value!
              .exercises
              .first
              .sets
              .first
              .isCompleted,
          isTrue,
        );
      });

      test('toggles isCompleted from true back to false', () async {
        final initial = makeState(exerciseCount: 1, setsPerExercise: 1);
        // Factory creates sets with isCompleted: true.
        final container = makeContainer(initial);
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        final weId = initial.exercises.first.workoutExercise.id;
        final setId = initial.exercises.first.sets.first.id;

        container.read(activeWorkoutProvider.notifier).completeSet(weId, setId);

        expect(
          container
              .read(activeWorkoutProvider)
              .value!
              .exercises
              .first
              .sets
              .first
              .isCompleted,
          isFalse,
        );
      });

      test('only toggles the targeted set', () async {
        final initial = makeState(exerciseCount: 1, setsPerExercise: 2);
        final container = makeContainer(initial);
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        final weId = initial.exercises.first.workoutExercise.id;
        final firstSetId = initial.exercises.first.sets.first.id;
        final secondSetInitialCompleted =
            initial.exercises.first.sets[1].isCompleted;

        container
            .read(activeWorkoutProvider.notifier)
            .completeSet(weId, firstSetId);

        final sets = container
            .read(activeWorkoutProvider)
            .value!
            .exercises
            .first
            .sets;
        expect(sets[1].isCompleted, secondSetInitialCompleted);
      });
    });

    // --------------------------------------------------------------- deleteSet
    group('deleteSet', () {
      test('removes the set from the exercise', () async {
        final initial = makeState(exerciseCount: 1, setsPerExercise: 3);
        final container = makeContainer(initial);
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        final weId = initial.exercises.first.workoutExercise.id;
        final middleSetId = initial.exercises.first.sets[1].id;
        container
            .read(activeWorkoutProvider.notifier)
            .deleteSet(weId, middleSetId);

        final result = container.read(activeWorkoutProvider).value!;
        expect(result.exercises.first.sets, hasLength(2));
        expect(
          result.exercises.first.sets.any((s) => s.id == middleSetId),
          isFalse,
        );
      });

      test('renumbers remaining sets consecutively from 1', () async {
        final initial = makeState(exerciseCount: 1, setsPerExercise: 3);
        final container = makeContainer(initial);
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        final weId = initial.exercises.first.workoutExercise.id;
        // Delete the first set; the remaining two should become 1 and 2.
        final firstSetId = initial.exercises.first.sets.first.id;
        container
            .read(activeWorkoutProvider.notifier)
            .deleteSet(weId, firstSetId);

        final remaining = container
            .read(activeWorkoutProvider)
            .value!
            .exercises
            .first
            .sets;
        expect(remaining[0].setNumber, 1);
        expect(remaining[1].setNumber, 2);
      });

      test('only affects the targeted exercise', () async {
        final initial = makeState(exerciseCount: 2, setsPerExercise: 2);
        final container = makeContainer(initial);
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        final firstWeId = initial.exercises.first.workoutExercise.id;
        final setId = initial.exercises.first.sets.first.id;
        container
            .read(activeWorkoutProvider.notifier)
            .deleteSet(firstWeId, setId);

        final result = container.read(activeWorkoutProvider).value!;
        expect(result.exercises.first.sets, hasLength(1));
        expect(result.exercises.last.sets, hasLength(2));
      });

      test('results in empty sets list when last set is deleted', () async {
        final initial = makeState(exerciseCount: 1, setsPerExercise: 1);
        final container = makeContainer(initial);
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        final weId = initial.exercises.first.workoutExercise.id;
        final setId = initial.exercises.first.sets.first.id;
        container.read(activeWorkoutProvider.notifier).deleteSet(weId, setId);

        expect(
          container.read(activeWorkoutProvider).value!.exercises.first.sets,
          isEmpty,
        );
      });
    });

    // ----------------------------------------------- Hive persistence (side effects)
    group('Hive persistence', () {
      test('saveActiveWorkout is called after addExercise', () async {
        final mockStorage = MockWorkoutLocalStorage();
        when(() => mockStorage.loadActiveWorkout()).thenReturn(makeState());
        when(
          () => mockStorage.saveActiveWorkout(any()),
        ).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            workoutRepositoryProvider.overrideWithValue(
              MockWorkoutRepository(),
            ),
            workoutLocalStorageProvider.overrideWithValue(mockStorage),
          ],
        );
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        container
            .read(activeWorkoutProvider.notifier)
            .addExercise(makeExercise());

        // Give the unawaited save a chance to run.
        await Future<void>.delayed(Duration.zero);
        verify(
          () => mockStorage.saveActiveWorkout(any()),
        ).called(greaterThan(0));
      });

      test('saveActiveWorkout is called after deleteSet', () async {
        final initial = makeState(exerciseCount: 1, setsPerExercise: 1);
        final mockStorage = MockWorkoutLocalStorage();
        when(() => mockStorage.loadActiveWorkout()).thenReturn(initial);
        when(
          () => mockStorage.saveActiveWorkout(any()),
        ).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            workoutRepositoryProvider.overrideWithValue(
              MockWorkoutRepository(),
            ),
            workoutLocalStorageProvider.overrideWithValue(mockStorage),
          ],
        );
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        final weId = initial.exercises.first.workoutExercise.id;
        final setId = initial.exercises.first.sets.first.id;
        container.read(activeWorkoutProvider.notifier).deleteSet(weId, setId);

        await Future<void>.delayed(Duration.zero);
        verify(
          () => mockStorage.saveActiveWorkout(any()),
        ).called(greaterThan(0));
      });
    });
  });
}
