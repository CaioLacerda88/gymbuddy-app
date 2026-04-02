import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/auth/data/auth_repository.dart';
import 'package:gymbuddy_app/features/auth/providers/auth_providers.dart';
import 'package:gymbuddy_app/features/workouts/data/workout_local_storage.dart';
import 'package:gymbuddy_app/features/workouts/data/workout_repository.dart';
import 'package:gymbuddy_app/features/workouts/models/active_workout_state.dart';
import 'package:gymbuddy_app/features/workouts/models/set_type.dart';
import 'package:gymbuddy_app/features/workouts/models/workout.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_providers.dart';
import 'package:gymbuddy_app/features/exercises/models/exercise.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../../../fixtures/test_factories.dart';

class MockWorkoutRepository extends Mock implements WorkoutRepository {}

class MockWorkoutLocalStorage extends Mock implements WorkoutLocalStorage {}

class MockAuthRepository extends Mock implements AuthRepository {}

class FakeActiveWorkoutState extends Fake implements ActiveWorkoutState {}

class FakeWorkout extends Fake implements Workout {}

/// Creates a minimal [User] that satisfies the `_userId` getter in the notifier.
User fakeUser({String id = 'user-test-001'}) {
  return User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
    isAnonymous: false,
  );
}

/// Builds a [Workout] model from the test factory JSON.
Workout makeWorkout({String? id, bool isActive = true}) {
  return Workout.fromJson(
    TestWorkoutFactory.create(id: id, isActive: isActive),
  );
}

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

/// Creates a container suitable for testing async methods (startWorkout,
/// finishWorkout, discardWorkout) — includes [MockAuthRepository] so the
/// `_userId` getter can be controlled without touching the Supabase singleton.
({
  ProviderContainer container,
  MockWorkoutRepository mockRepo,
  MockWorkoutLocalStorage mockStorage,
  MockAuthRepository mockAuth,
})
makeAsyncContainer(ActiveWorkoutState? initialState) {
  final mockRepo = MockWorkoutRepository();
  final mockStorage = MockWorkoutLocalStorage();
  final mockAuth = MockAuthRepository();

  when(() => mockStorage.loadActiveWorkout()).thenReturn(initialState);
  when(() => mockStorage.saveActiveWorkout(any())).thenAnswer((_) async {});

  final container = ProviderContainer(
    overrides: [
      workoutRepositoryProvider.overrideWithValue(mockRepo),
      workoutLocalStorageProvider.overrideWithValue(mockStorage),
      authRepositoryProvider.overrideWithValue(mockAuth),
    ],
  );
  return (
    container: container,
    mockRepo: mockRepo,
    mockStorage: mockStorage,
    mockAuth: mockAuth,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeActiveWorkoutState());
    registerFallbackValue(FakeWorkout());
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

  // ================================================================
  // Async network methods — startWorkout / finishWorkout / discardWorkout
  // ================================================================
  //
  // The `_userId` getter previously called Supabase.instance directly, making
  // it impossible to test without a real Supabase singleton. It has been
  // refactored to use `ref.read(authRepositoryProvider)`, which is overridable
  // in tests via ProviderContainer. All tests in this group use
  // `makeAsyncContainer`, which injects MockAuthRepository.

  group('ActiveWorkoutNotifier — startWorkout', () {
    test(
      'success: calls createActiveWorkout, saves to Hive, state is AsyncData',
      () async {
        final (:container, :mockRepo, :mockStorage, :mockAuth) =
            makeAsyncContainer(null);
        addTearDown(container.dispose);

        final createdWorkout = makeWorkout(id: 'workout-new');
        when(() => mockAuth.currentUser).thenReturn(fakeUser());
        when(
          () => mockRepo.createActiveWorkout(
            userId: any(named: 'userId'),
            name: any(named: 'name'),
          ),
        ).thenAnswer((_) async => createdWorkout);

        await container.read(activeWorkoutProvider.future);
        await container
            .read(activeWorkoutProvider.notifier)
            .startWorkout('Leg Day');

        final result = container.read(activeWorkoutProvider);
        expect(result, isA<AsyncData<ActiveWorkoutState?>>());
        expect(result.value, isNotNull);
        expect(result.value!.workout.id, 'workout-new');
        expect(result.value!.exercises, isEmpty);

        verify(
          () => mockRepo.createActiveWorkout(
            userId: 'user-test-001',
            name: 'Leg Day',
          ),
        ).called(1);

        // Give the unawaited Hive save a chance to run.
        await Future<void>.delayed(Duration.zero);
        verify(
          () => mockStorage.saveActiveWorkout(any()),
        ).called(greaterThan(0));
      },
    );

    test(
      'unauthenticated: state becomes AsyncError with AuthException',
      () async {
        final (:container, :mockRepo, :mockStorage, :mockAuth) =
            makeAsyncContainer(null);
        addTearDown(container.dispose);

        when(() => mockAuth.currentUser).thenReturn(null);

        await container.read(activeWorkoutProvider.future);
        await container
            .read(activeWorkoutProvider.notifier)
            .startWorkout('Push Day');

        final result = container.read(activeWorkoutProvider);
        expect(result, isA<AsyncError<ActiveWorkoutState?>>());
        verifyNever(
          () => mockRepo.createActiveWorkout(
            userId: any(named: 'userId'),
            name: any(named: 'name'),
          ),
        );
      },
    );

    test('repo error: state becomes AsyncError', () async {
      final (:container, :mockRepo, :mockStorage, :mockAuth) =
          makeAsyncContainer(null);
      addTearDown(container.dispose);

      when(() => mockAuth.currentUser).thenReturn(fakeUser());
      when(
        () => mockRepo.createActiveWorkout(
          userId: any(named: 'userId'),
          name: any(named: 'name'),
        ),
      ).thenThrow(Exception('Network failure'));

      await container.read(activeWorkoutProvider.future);
      await container
          .read(activeWorkoutProvider.notifier)
          .startWorkout('Push Day');

      expect(
        container.read(activeWorkoutProvider),
        isA<AsyncError<ActiveWorkoutState?>>(),
      );
    });
  });

  group('ActiveWorkoutNotifier — finishWorkout', () {
    test('success: calls saveWorkout with correct data, clears Hive, '
        'state is AsyncData(null)', () async {
      final initial = makeState(exerciseCount: 1, setsPerExercise: 2);
      final (:container, :mockRepo, :mockStorage, :mockAuth) =
          makeAsyncContainer(initial);
      addTearDown(container.dispose);

      final savedWorkout = makeWorkout(isActive: false);
      when(() => mockAuth.currentUser).thenReturn(fakeUser());
      when(
        () => mockRepo.saveWorkout(
          workout: any(named: 'workout'),
          exercises: any(named: 'exercises'),
          sets: any(named: 'sets'),
        ),
      ).thenAnswer((_) async => savedWorkout);
      when(() => mockStorage.clearActiveWorkout()).thenAnswer((_) async {});

      await container.read(activeWorkoutProvider.future);
      await container
          .read(activeWorkoutProvider.notifier)
          .finishWorkout(notes: 'Great session');

      final result = container.read(activeWorkoutProvider);
      expect(result, isA<AsyncData<ActiveWorkoutState?>>());
      expect(result.value, isNull);

      // Verify saveWorkout received the right shapes.
      final captured = verify(
        () => mockRepo.saveWorkout(
          workout: captureAny(named: 'workout'),
          exercises: captureAny(named: 'exercises'),
          sets: captureAny(named: 'sets'),
        ),
      ).captured;
      final capturedWorkout = captured[0] as Workout;
      expect(capturedWorkout.isActive, isFalse);
      expect(capturedWorkout.finishedAt, isNotNull);
      expect(capturedWorkout.notes, 'Great session');
      expect(capturedWorkout.durationSeconds, isNotNull);

      final capturedExercises = captured[1] as List;
      expect(capturedExercises, hasLength(1));

      final capturedSets = captured[2] as List;
      expect(capturedSets, hasLength(2));

      verify(() => mockStorage.clearActiveWorkout()).called(1);
    });

    test('does nothing when state is null', () async {
      final (:container, :mockRepo, :mockStorage, :mockAuth) =
          makeAsyncContainer(null);
      addTearDown(container.dispose);

      when(() => mockAuth.currentUser).thenReturn(fakeUser());

      await container.read(activeWorkoutProvider.future);
      await container.read(activeWorkoutProvider.notifier).finishWorkout();

      // State remains null — no network call, no Hive clear.
      expect(container.read(activeWorkoutProvider).value, isNull);
      verifyNever(
        () => mockRepo.saveWorkout(
          workout: any(named: 'workout'),
          exercises: any(named: 'exercises'),
          sets: any(named: 'sets'),
        ),
      );
      verifyNever(() => mockStorage.clearActiveWorkout());
    });

    test('repo error: state becomes AsyncError, Hive is NOT cleared', () async {
      final initial = makeState(exerciseCount: 1, setsPerExercise: 1);
      final (:container, :mockRepo, :mockStorage, :mockAuth) =
          makeAsyncContainer(initial);
      addTearDown(container.dispose);

      when(() => mockAuth.currentUser).thenReturn(fakeUser());
      when(
        () => mockRepo.saveWorkout(
          workout: any(named: 'workout'),
          exercises: any(named: 'exercises'),
          sets: any(named: 'sets'),
        ),
      ).thenThrow(Exception('Save failed'));

      await container.read(activeWorkoutProvider.future);
      await container.read(activeWorkoutProvider.notifier).finishWorkout();

      expect(
        container.read(activeWorkoutProvider),
        isA<AsyncError<ActiveWorkoutState?>>(),
      );
      // Hive must NOT be cleared when save fails — user can retry or discard.
      verifyNever(() => mockStorage.clearActiveWorkout());
    });
  });

  group('ActiveWorkoutNotifier — discardWorkout', () {
    test(
      'success: calls discardWorkout, clears Hive, state is AsyncData(null)',
      () async {
        final initial = makeState(exerciseCount: 1, setsPerExercise: 1);
        final (:container, :mockRepo, :mockStorage, :mockAuth) =
            makeAsyncContainer(initial);
        addTearDown(container.dispose);

        when(() => mockAuth.currentUser).thenReturn(fakeUser());
        when(
          () => mockRepo.discardWorkout(any(), userId: any(named: 'userId')),
        ).thenAnswer((_) async {});
        when(() => mockStorage.clearActiveWorkout()).thenAnswer((_) async {});

        await container.read(activeWorkoutProvider.future);
        await container.read(activeWorkoutProvider.notifier).discardWorkout();

        final result = container.read(activeWorkoutProvider);
        expect(result, isA<AsyncData<ActiveWorkoutState?>>());
        expect(result.value, isNull);

        verify(
          () => mockRepo.discardWorkout(
            initial.workout.id,
            userId: 'user-test-001',
          ),
        ).called(1);
        verify(() => mockStorage.clearActiveWorkout()).called(1);
      },
    );

    test('does nothing when state is null', () async {
      final (:container, :mockRepo, :mockStorage, :mockAuth) =
          makeAsyncContainer(null);
      addTearDown(container.dispose);

      when(() => mockAuth.currentUser).thenReturn(fakeUser());

      await container.read(activeWorkoutProvider.future);
      await container.read(activeWorkoutProvider.notifier).discardWorkout();

      // State remains null — no network call, no Hive clear.
      expect(container.read(activeWorkoutProvider).value, isNull);
      verifyNever(
        () => mockRepo.discardWorkout(any(), userId: any(named: 'userId')),
      );
      verifyNever(() => mockStorage.clearActiveWorkout());
    });

    test('repo error: state becomes AsyncError', () async {
      final initial = makeState(exerciseCount: 0, setsPerExercise: 0);
      final (:container, :mockRepo, :mockStorage, :mockAuth) =
          makeAsyncContainer(initial);
      addTearDown(container.dispose);

      when(() => mockAuth.currentUser).thenReturn(fakeUser());
      when(
        () => mockRepo.discardWorkout(any(), userId: any(named: 'userId')),
      ).thenThrow(Exception('Delete failed'));

      await container.read(activeWorkoutProvider.future);
      await container.read(activeWorkoutProvider.notifier).discardWorkout();

      expect(
        container.read(activeWorkoutProvider),
        isA<AsyncError<ActiveWorkoutState?>>(),
      );
      // Hive must NOT be cleared when the network call fails.
      verifyNever(() => mockStorage.clearActiveWorkout());
    });
  });
}
