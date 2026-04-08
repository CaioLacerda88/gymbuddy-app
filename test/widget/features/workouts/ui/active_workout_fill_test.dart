/// BUG-3: "Fill remaining" button visibility.
///
/// The button must be:
/// - HIDDEN when no fillable sets exist after the last completed set.
/// - VISIBLE when at least one incomplete set exists after the last completed.
/// - Labeled "Fill remaining" (not just "Fill").
///
/// The fix guards the button with `_hasFillableSets()` so it only renders
/// when there is actually something to fill.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/exercises/models/exercise.dart';
import 'package:gymbuddy_app/features/personal_records/providers/pr_providers.dart';
import 'package:gymbuddy_app/features/profile/models/profile.dart';
import 'package:gymbuddy_app/features/profile/providers/profile_providers.dart';
import 'package:gymbuddy_app/features/workouts/models/active_workout_state.dart';
import 'package:gymbuddy_app/features/workouts/models/exercise_set.dart';
import 'package:gymbuddy_app/features/workouts/models/set_type.dart';
import 'package:gymbuddy_app/features/workouts/models/workout.dart';
import 'package:gymbuddy_app/features/workouts/models/workout_exercise.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_providers.dart';
import 'package:gymbuddy_app/features/workouts/ui/active_workout_screen.dart';

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

ExerciseSet _makeSet({
  required int setNumber,
  required bool isCompleted,
  double weight = 60.0,
  int reps = 10,
}) {
  return ExerciseSet(
    id: 'set-$setNumber',
    workoutExerciseId: 'we-001',
    setNumber: setNumber,
    reps: reps,
    weight: weight,
    isCompleted: isCompleted,
    setType: SetType.working,
    createdAt: DateTime.now().toUtc(),
  );
}

ActiveWorkoutState _makeState(List<ExerciseSet> sets) {
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
        sets: sets,
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _FixedActiveWorkoutNotifier extends AsyncNotifier<ActiveWorkoutState?>
    implements ActiveWorkoutNotifier {
  _FixedActiveWorkoutNotifier(this.state_);
  final ActiveWorkoutState state_;

  @override
  Future<ActiveWorkoutState?> build() async => state_;

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
// Helper
// ---------------------------------------------------------------------------

Widget _buildWithSets(List<ExerciseSet> sets) {
  return ProviderScope(
    overrides: [
      activeWorkoutProvider.overrideWith(
        () => _FixedActiveWorkoutNotifier(_makeState(sets)),
      ),
      restTimerProvider.overrideWith(() => _NullRestTimerNotifier()),
      profileProvider.overrideWith(() => _KgProfileNotifier()),
      exercisePRsProvider.overrideWith((ref, _) => Future.value([])),
      lastWorkoutSetsProvider.overrideWith((ref, _) => Future.value({})),
      elapsedTimerProvider.overrideWith(
        (ref, startedAt) => Stream.value(const Duration(minutes: 5)),
      ),
    ],
    child: MaterialApp(theme: AppTheme.dark, home: const ActiveWorkoutScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('BUG-3: Fill remaining button visibility', () {
    testWidgets(
      'button is HIDDEN when no sets are completed (nothing to fill from)',
      (tester) async {
        final sets = [
          _makeSet(setNumber: 1, isCompleted: false),
          _makeSet(setNumber: 2, isCompleted: false),
          _makeSet(setNumber: 3, isCompleted: false),
        ];

        await tester.pumpWidget(_buildWithSets(sets));
        await tester.pump();
        await tester.pump();

        expect(find.text('Fill remaining'), findsNothing);
      },
    );

    testWidgets(
      'button is HIDDEN when all sets are completed (nothing left to fill)',
      (tester) async {
        final sets = [
          _makeSet(setNumber: 1, isCompleted: true),
          _makeSet(setNumber: 2, isCompleted: true),
          _makeSet(setNumber: 3, isCompleted: true),
        ];

        await tester.pumpWidget(_buildWithSets(sets));
        await tester.pump();
        await tester.pump();

        expect(find.text('Fill remaining'), findsNothing);
      },
    );

    testWidgets(
      'button is HIDDEN when sets are completed in sequence (last = completed)',
      (tester) async {
        // User completed sets 1 and 2; set 3 is the last and it is the last
        // completed — no incomplete sets exist after it.
        final sets = [
          _makeSet(setNumber: 1, isCompleted: true),
          _makeSet(setNumber: 2, isCompleted: true),
        ];

        await tester.pumpWidget(_buildWithSets(sets));
        await tester.pump();
        await tester.pump();

        expect(find.text('Fill remaining'), findsNothing);
      },
    );

    testWidgets(
      'button is VISIBLE when incomplete sets exist after the last completed set',
      (tester) async {
        // Set 1 is completed; sets 2 and 3 are not — fillable.
        final sets = [
          _makeSet(setNumber: 1, isCompleted: true),
          _makeSet(setNumber: 2, isCompleted: false),
          _makeSet(setNumber: 3, isCompleted: false),
        ];

        await tester.pumpWidget(_buildWithSets(sets));
        await tester.pump();
        await tester.pump();

        expect(find.text('Fill remaining'), findsOneWidget);
      },
    );

    testWidgets(
      'button is VISIBLE when one completed set precedes one incomplete set',
      (tester) async {
        final sets = [
          _makeSet(setNumber: 1, isCompleted: true),
          _makeSet(setNumber: 2, isCompleted: false),
        ];

        await tester.pumpWidget(_buildWithSets(sets));
        await tester.pump();
        await tester.pump();

        expect(find.text('Fill remaining'), findsOneWidget);
      },
    );

    testWidgets('button label is "Fill remaining" (not "Fill")', (
      tester,
    ) async {
      final sets = [
        _makeSet(setNumber: 1, isCompleted: true),
        _makeSet(setNumber: 2, isCompleted: false),
      ];

      await tester.pumpWidget(_buildWithSets(sets));
      await tester.pump();
      await tester.pump();

      // Exact label text matches the BUG-3 fix (renamed from "Fill").
      expect(find.text('Fill remaining'), findsOneWidget);
      // Old label must not be present.
      expect(find.text('Fill'), findsNothing);
    });

    testWidgets(
      'button is HIDDEN when only one completed set exists and no incomplete follow it',
      (tester) async {
        // A single completed set — nothing after it to fill.
        final sets = [_makeSet(setNumber: 1, isCompleted: true)];

        await tester.pumpWidget(_buildWithSets(sets));
        await tester.pump();
        await tester.pump();

        expect(find.text('Fill remaining'), findsNothing);
      },
    );

    testWidgets(
      'button is VISIBLE when middle set is completed and later sets are not',
      (tester) async {
        // Sets: 1=incomplete, 2=completed, 3=incomplete
        // lastCompletedSetNumber = 2; set 3 is after it and incomplete → fillable
        final sets = [
          _makeSet(setNumber: 1, isCompleted: false),
          _makeSet(setNumber: 2, isCompleted: true),
          _makeSet(setNumber: 3, isCompleted: false),
        ];

        await tester.pumpWidget(_buildWithSets(sets));
        await tester.pump();
        await tester.pump();

        expect(find.text('Fill remaining'), findsOneWidget);
      },
    );
  });
}
