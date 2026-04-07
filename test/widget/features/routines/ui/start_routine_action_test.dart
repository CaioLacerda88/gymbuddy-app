// Widget tests for startRoutineWorkout — covering the error path that
// BUG-003 exposed: when all exercises in a routine fail to resolve (exercise
// field is null), the function silently returned without feedback.
//
// Systematic gap: there were no widget tests that exercised the `exercises.isEmpty`
// branch. The model-level tests in routine_repository_start_bug_test.dart
// verified the filtering logic in isolation, but not the actual snackbar
// displayed to the user.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:go_router/go_router.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/routines/models/routine.dart';
import 'package:gymbuddy_app/features/routines/ui/start_routine_action.dart';
import 'package:gymbuddy_app/features/workouts/data/workout_local_storage.dart';
import 'package:gymbuddy_app/features/workouts/data/workout_repository.dart';
import 'package:gymbuddy_app/features/workouts/models/active_workout_state.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../fixtures/test_factories.dart';

// ---------------------------------------------------------------------------
// Mocks & fakes
// ---------------------------------------------------------------------------

class MockWorkoutRepository extends Mock implements WorkoutRepository {}

class MockWorkoutLocalStorage extends Mock implements WorkoutLocalStorage {}

class FakeActiveWorkoutState extends Fake implements ActiveWorkoutState {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a Routine where all exercises have no resolved Exercise object.
/// This simulates the BUG-005 scenario where _resolveExercises early-exits.
Routine _makeRoutineWithUnresolvedExercises() {
  return Routine.fromJson(
    TestRoutineFactory.create(
      id: 'r-unresolved',
      name: 'Push Day',
      exercises: [
        TestRoutineExerciseFactory.create(exerciseId: 'ex-001'),
        TestRoutineExerciseFactory.create(exerciseId: 'ex-002'),
        // No 'exercise' key → exercise field will be null
      ],
    ),
  );
}

/// Builds a Routine with all exercises soft-deleted.
Routine _makeRoutineWithDeletedExercises() {
  final deletedExercise = TestExerciseFactory.create(
    id: 'ex-deleted',
    name: 'Deleted Move',
    deletedAt: '2026-01-15T00:00:00Z',
  );
  return Routine.fromJson(
    TestRoutineFactory.create(
      id: 'r-deleted',
      name: 'Old Routine',
      exercises: [
        TestRoutineExerciseFactory.create(
          exerciseId: 'ex-deleted',
          exercise: deletedExercise,
        ),
      ],
    ),
  );
}

/// Builds a Routine with at least one valid, non-deleted exercise.
Routine _makeRoutineWithValidExercises() {
  final exercise = TestExerciseFactory.create(
    id: 'ex-bench',
    name: 'Bench Press',
    equipmentType: 'barbell',
  );
  return Routine.fromJson(
    TestRoutineFactory.create(
      id: 'r-valid',
      name: 'Push Day',
      exercises: [
        TestRoutineExerciseFactory.create(
          exerciseId: 'ex-bench',
          exercise: exercise,
        ),
      ],
    ),
  );
}

/// Pumps a minimal [Scaffold] with a button that calls [startRoutineWorkout].
Future<void> _pumpRoutineStarter(
  WidgetTester tester,
  Routine routine, {
  required MockWorkoutRepository mockRepo,
  required MockWorkoutLocalStorage mockStorage,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutRepositoryProvider.overrideWithValue(mockRepo),
        workoutLocalStorageProvider.overrideWithValue(mockStorage),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Consumer(
          builder: (context, ref, _) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => startRoutineWorkout(context, ref, routine),
                child: const Text('Start'),
              ),
            );
          },
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(FakeActiveWorkoutState());
  });

  group('startRoutineWorkout — empty exercises error path (BUG-003)', () {
    late MockWorkoutRepository mockRepo;
    late MockWorkoutLocalStorage mockStorage;

    setUp(() {
      mockRepo = MockWorkoutRepository();
      mockStorage = MockWorkoutLocalStorage();

      when(() => mockStorage.loadActiveWorkout()).thenReturn(null);
      when(() => mockStorage.saveActiveWorkout(any())).thenAnswer((_) async {});
      when(() => mockStorage.hasActiveWorkout).thenReturn(false);
    });

    testWidgets(
      'shows snackbar when all exercises have null exercise reference (BUG-003)',
      (tester) async {
        final routine = _makeRoutineWithUnresolvedExercises();

        await _pumpRoutineStarter(
          tester,
          routine,
          mockRepo: mockRepo,
          mockStorage: mockStorage,
        );

        // Act: press the start button.
        await tester.tap(find.text('Start'));
        await tester.pump(); // trigger setState
        await tester.pump(const Duration(milliseconds: 100)); // snackbar anim

        // Assert: snackbar with the expected error message appears.
        expect(
          find.text('Could not load exercises. Please try again.'),
          findsOneWidget,
          reason:
              'BUG-003: when all routine exercises are unresolved (exercise == null), '
              'a snackbar must be shown. Previously the function silently returned.',
        );

        // Also verify: no attempt was made to create a workout on the server.
        verifyNever(
          () => mockRepo.createActiveWorkout(
            userId: any(named: 'userId'),
            name: any(named: 'name'),
          ),
        );
      },
    );

    testWidgets('shows snackbar when all exercises are soft-deleted', (
      tester,
    ) async {
      final routine = _makeRoutineWithDeletedExercises();

      await _pumpRoutineStarter(
        tester,
        routine,
        mockRepo: mockRepo,
        mockStorage: mockStorage,
      );

      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Could not load exercises. Please try again.'),
        findsOneWidget,
        reason:
            'Soft-deleted exercises are filtered out; if no exercises remain, '
            'the same error snackbar must appear',
      );
    });

    testWidgets('shows snackbar when routine has no exercises at all', (
      tester,
    ) async {
      final emptyRoutine = Routine.fromJson(
        TestRoutineFactory.create(
          id: 'r-empty',
          name: 'Empty Routine',
          exercises: [],
        ),
      );

      await _pumpRoutineStarter(
        tester,
        emptyRoutine,
        mockRepo: mockRepo,
        mockStorage: mockStorage,
      );

      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Could not load exercises. Please try again.'),
        findsOneWidget,
      );
    });
  });

  group('startRoutineWorkout — happy path smoke test', () {
    testWidgets(
      'does NOT show error snackbar when routine has valid exercises',
      (tester) async {
        final mockRepo = MockWorkoutRepository();
        final mockStorage = MockWorkoutLocalStorage();

        when(() => mockStorage.loadActiveWorkout()).thenReturn(null);
        when(
          () => mockStorage.saveActiveWorkout(any()),
        ).thenAnswer((_) async {});
        when(() => mockStorage.hasActiveWorkout).thenReturn(false);

        // createActiveWorkout must succeed for the happy path to proceed.
        final createdWorkout = ActiveWorkoutState.fromJson(
          TestActiveWorkoutStateFactory.create(
            workout: TestWorkoutFactory.create(
              id: 'w-happy',
              name: 'Push Day',
              isActive: true,
            ),
          ),
        ).workout;
        when(
          () => mockRepo.createActiveWorkout(
            userId: any(named: 'userId'),
            name: any(named: 'name'),
          ),
        ).thenAnswer((_) async => createdWorkout);
        when(
          () => mockRepo.getLastWorkoutSets(any()),
        ).thenAnswer((_) async => {});

        final routine = _makeRoutineWithValidExercises();

        // GoRouter is required because startRoutineWorkout calls context.go()
        // on the happy path. Without it the test throws "No GoRouter found".
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Consumer(
                builder: (context, ref, _) {
                  return Scaffold(
                    body: ElevatedButton(
                      onPressed: () =>
                          startRoutineWorkout(context, ref, routine),
                      child: const Text('Start'),
                    ),
                  );
                },
              ),
            ),
            GoRoute(
              path: '/workout/active',
              builder: (context, state) =>
                  const Scaffold(body: Text('Active Workout')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              workoutRepositoryProvider.overrideWithValue(mockRepo),
              workoutLocalStorageProvider.overrideWithValue(mockStorage),
            ],
            child: MaterialApp.router(
              theme: AppTheme.dark,
              routerConfig: router,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Start'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // The error snackbar must NOT appear for a valid routine.
        // (startFromRoutine may fail with AuthException because no auth is
        // wired up in this test, but that is not the empty-exercises path.)
        expect(
          find.text('Could not load exercises. Please try again.'),
          findsNothing,
          reason:
              'A routine with valid exercises must not show the empty-exercises '
              'error snackbar',
        );
      },
    );
  });
}
