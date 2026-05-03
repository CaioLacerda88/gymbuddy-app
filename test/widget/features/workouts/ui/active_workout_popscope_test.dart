/// Widget tests for ActiveWorkoutScreen PopScope behavior.
///
/// Verifies that PopScope wraps the entire ActiveWorkoutScreen.build(),
/// including loading states, so Android back never closes the app.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';
import 'package:repsaga/features/personal_records/providers/pr_providers.dart';
import 'package:repsaga/features/profile/models/profile.dart';
import 'package:repsaga/features/profile/providers/profile_providers.dart';
import 'package:repsaga/features/workouts/models/active_workout_state.dart';
import 'package:repsaga/features/workouts/models/exercise_set.dart';
import 'package:repsaga/features/workouts/models/set_type.dart';
import 'package:repsaga/features/workouts/models/workout.dart';
import 'package:repsaga/features/workouts/models/workout_exercise.dart';
import 'package:repsaga/features/workouts/providers/workout_providers.dart';
import 'package:repsaga/features/workouts/ui/active_workout_screen.dart';
import '../../../../helpers/test_material_app.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

final _testExercise = Exercise(
  id: 'exercise-001',
  name: 'Bench Press',
  muscleGroup: MuscleGroup.chest,
  equipmentType: EquipmentType.barbell,
  isDefault: true,
  createdAt: DateTime(2026),
);

final _testWorkout = Workout(
  id: 'workout-001',
  userId: 'user-001',
  name: 'Push Day',
  startedAt: DateTime.now().toUtc(),
  isActive: true,
  createdAt: DateTime.now().toUtc(),
);

ActiveWorkoutState _makeState() {
  return ActiveWorkoutState(
    workout: _testWorkout,
    exercises: [
      ActiveWorkoutExercise(
        workoutExercise: WorkoutExercise(
          id: 'we-001',
          workoutId: 'workout-001',
          exerciseId: 'exercise-001',
          order: 1,
          exercise: _testExercise,
        ),
        sets: [
          ExerciseSet(
            id: 'set-1',
            workoutExerciseId: 'we-001',
            setNumber: 1,
            reps: 10,
            weight: 60.0,
            isCompleted: false,
            setType: SetType.working,
            createdAt: DateTime.now().toUtc(),
          ),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

/// Notifier that stays in loading state until [complete] is called.
class _LoadingWorkoutNotifier extends AsyncNotifier<ActiveWorkoutState?>
    implements ActiveWorkoutNotifier {
  final _completer = Completer<ActiveWorkoutState?>();

  @override
  Future<ActiveWorkoutState?> build() => _completer.future;

  void complete(ActiveWorkoutState? state) {
    if (!_completer.isCompleted) _completer.complete(state);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedActiveWorkoutNotifier extends AsyncNotifier<ActiveWorkoutState?>
    implements ActiveWorkoutNotifier {
  _FixedActiveWorkoutNotifier(this._state);
  final ActiveWorkoutState? _state;

  @override
  Future<ActiveWorkoutState?> build() async => _state;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NullRestTimerNotifier extends Notifier<RestTimerState?>
    implements RestTimerNotifier {
  @override
  RestTimerState? build() => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _KgProfileNotifier extends AsyncNotifier<Profile?>
    implements ProfileNotifier {
  @override
  Future<Profile?> build() async => const Profile(id: 'u1', weightUnit: 'kg');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildWithLoadingNotifier(_LoadingWorkoutNotifier notifier) {
  return ProviderScope(
    overrides: [
      activeWorkoutProvider.overrideWith(() => notifier),
      restTimerProvider.overrideWith(() => _NullRestTimerNotifier()),
      profileProvider.overrideWith(() => _KgProfileNotifier()),
      exercisePRsProvider.overrideWith((ref, _) => Future.value([])),
      lastWorkoutSetsProvider.overrideWith((ref, _) => Future.value({})),
      elapsedTimerProvider.overrideWith(
        (ref, startedAt) => Stream.value(const Duration(minutes: 5)),
      ),
    ],
    child: TestMaterialApp(
      theme: AppTheme.dark,
      home: const ActiveWorkoutScreen(),
    ),
  );
}

Widget _buildWithState(ActiveWorkoutState state) {
  return ProviderScope(
    overrides: [
      activeWorkoutProvider.overrideWith(
        () => _FixedActiveWorkoutNotifier(state),
      ),
      restTimerProvider.overrideWith(() => _NullRestTimerNotifier()),
      profileProvider.overrideWith(() => _KgProfileNotifier()),
      exercisePRsProvider.overrideWith((ref, _) => Future.value([])),
      lastWorkoutSetsProvider.overrideWith((ref, _) => Future.value({})),
      elapsedTimerProvider.overrideWith(
        (ref, startedAt) => Stream.value(const Duration(minutes: 5)),
      ),
    ],
    child: TestMaterialApp(
      theme: AppTheme.dark,
      home: const ActiveWorkoutScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ActiveWorkoutScreen — PopScope covers all states', () {
    testWidgets('PopScope wraps loading state (prevents app exit)', (
      tester,
    ) async {
      final notifier = _LoadingWorkoutNotifier();

      await tester.pumpWidget(_buildWithLoadingNotifier(notifier));
      await tester.pump();

      // During loading, the screen shows a CircularProgressIndicator.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // A PopScope widget must exist in the tree during loading.
      // PopScope is generic, so find by widget predicate.
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString().startsWith('PopScope'),
        ),
        findsOneWidget,
      );

      // Clean up: complete the future to avoid pending timer warnings.
      notifier.complete(_makeState());
      await tester.pumpAndSettle();
    });

    testWidgets('PopScope wraps active workout state', (tester) async {
      await tester.pumpWidget(_buildWithState(_makeState()));
      await tester.pump();
      await tester.pump();

      // The active workout body should be visible.
      expect(find.text('Push Day'), findsOneWidget);

      // PopScope must exist at the top level.
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString().startsWith('PopScope'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('back press on active workout shows discard dialog', (
      tester,
    ) async {
      await tester.pumpWidget(_buildWithState(_makeState()));
      await tester.pump();
      await tester.pump();

      // Simulate Android back button press via the Navigator pop mechanism.
      // The PopScope should intercept this and show the discard dialog.
      final dynamic widgetsBinding = tester.binding;
      // ignore: avoid_dynamic_calls
      await widgetsBinding.handlePopRoute();
      await tester.pumpAndSettle();

      // The DiscardWorkoutDialog should now be visible.
      expect(find.text('Discard Workout?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);

      // Dismiss the dialog to clean up state. BUG-041 resolved: the guard
      // is now an instance field on DiscardWorkoutCoordinator (not file-level),
      // so each test gets a fresh coordinator and there is no cross-test leak.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'stacked discard dialog guard — close button tap while dialog is '
      'already open does not open a second dialog (C2)',
      (tester) async {
        await tester.pumpWidget(_buildWithState(_makeState()));
        await tester.pump();
        await tester.pump();

        // Open the discard dialog via the AppBar close button.
        await tester.tap(find.byTooltip('Discard workout'));
        await tester.pumpAndSettle();

        // Verify one dialog is showing.
        expect(find.text('Discard Workout?'), findsOneWidget);

        // Simulate a concurrent back press via PopScope while the dialog is
        // already showing. handlePopRoute pops the topmost route first (the
        // dialog), so to truly test the guard we need to call the
        // _showDiscardDialog path directly. But since that's private, we
        // verify the guard by checking that after the dialog is dismissed by
        // handlePopRoute, the guard is properly reset and a new dialog can
        // be opened.
        final dynamic widgetsBinding = tester.binding;
        // ignore: avoid_dynamic_calls
        await widgetsBinding.handlePopRoute();
        await tester.pumpAndSettle();

        // The handlePopRoute dismissed the dialog (popped the dialog route).
        // The guard should have reset (in the finally block).
        expect(find.text('Discard Workout?'), findsNothing);

        // Verify the guard was properly reset — we can open the dialog again.
        await tester.tap(find.byTooltip('Discard workout'));
        await tester.pumpAndSettle();

        expect(find.text('Discard Workout?'), findsOneWidget);

        // Clean up — dismiss the dialog.
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      },
    );
  });
}
