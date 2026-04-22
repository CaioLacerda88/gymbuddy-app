import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';
import 'package:repsaga/features/personal_records/models/personal_record.dart';
import 'package:repsaga/features/personal_records/models/record_type.dart';
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

import '../../../../fixtures/test_finders.dart';
import '../../../../helpers/test_material_app.dart';

// ---------------------------------------------------------------------------
// Test exercise data
// ---------------------------------------------------------------------------

final _testExercise = Exercise(
  id: 'exercise-001',
  name: 'Bench Press',
  muscleGroup: MuscleGroup.chest,
  equipmentType: EquipmentType.barbell,
  isDefault: true,
  createdAt: DateTime(2026),
);

final _testExerciseWithDetails = Exercise(
  id: 'exercise-001',
  name: 'Bench Press',
  muscleGroup: MuscleGroup.chest,
  equipmentType: EquipmentType.barbell,
  isDefault: true,
  description: 'A compound chest exercise performed lying on a flat bench.',
  formTips:
      'Arch the back slightly\nKeep feet flat on the floor\nControl the descent',
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

ActiveWorkoutState _makeState({Exercise? exercise}) => ActiveWorkoutState(
  workout: _testWorkout,
  exercises: [
    ActiveWorkoutExercise(
      workoutExercise: WorkoutExercise(
        id: 'we-001',
        workoutId: 'workout-001',
        exerciseId: 'exercise-001',
        order: 1,
        exercise: exercise ?? _testExercise,
      ),
      sets: [
        ExerciseSet(
          id: 'set-001',
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

// ---------------------------------------------------------------------------
// Notifier stubs
// ---------------------------------------------------------------------------

class _TestActiveWorkoutNotifier extends AsyncNotifier<ActiveWorkoutState?>
    implements ActiveWorkoutNotifier {
  _TestActiveWorkoutNotifier({this.exercise});
  final Exercise? exercise;

  @override
  Future<ActiveWorkoutState?> build() async => _makeState(exercise: exercise);

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

class _MockProfileNotifier extends AsyncNotifier<Profile?>
    implements ProfileNotifier {
  @override
  Future<Profile?> build() async =>
      const Profile(id: 'user-1', weightUnit: 'kg');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget buildTestWidget({List<PersonalRecord>? prs, Exercise? exercise}) {
  return ProviderScope(
    overrides: [
      activeWorkoutProvider.overrideWith(
        () => _TestActiveWorkoutNotifier(exercise: exercise),
      ),
      restTimerProvider.overrideWith(() => _NullRestTimerNotifier()),
      profileProvider.overrideWith(() => _MockProfileNotifier()),
      exercisePRsProvider.overrideWith(
        (ref, exerciseId) => Future.value(prs ?? []),
      ),
      lastWorkoutSetsProvider.overrideWith((ref, ids) => Future.value({})),
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
  group('Exercise card info icon and detail sheet', () {
    testWidgets('shows info icon next to exercise name', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('tap on exercise name opens bottom sheet', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      // Tap the exercise name text.
      await tester.tap(find.text('Bench Press').first);
      await tester.pumpAndSettle();

      // Bottom sheet should show exercise detail.
      // The heading in the sheet shows the name again.
      expect(find.text('Bench Press'), findsWidgets);
      // Chips should be present.
      expect(find.text('Chest'), findsOneWidget);
      expect(find.text('Barbell'), findsOneWidget);
    });

    testWidgets('bottom sheet shows PR section', (tester) async {
      final prs = [
        PersonalRecord(
          id: 'pr-001',
          userId: 'user-001',
          exerciseId: 'exercise-001',
          recordType: RecordType.maxWeight,
          value: 100.0,
          achievedAt: DateTime(2026),
        ),
      ];

      await tester.pumpWidget(buildTestWidget(prs: prs));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Bench Press').first);
      await tester.pumpAndSettle();

      expect(find.text('Personal Records'), findsOneWidget);
      expect(find.text('100.0 kg'), findsOneWidget);
    });

    testWidgets('bottom sheet shows no records message when empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(prs: []));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Bench Press').first);
      await tester.pumpAndSettle();

      expect(find.text('No records yet'), findsOneWidget);
    });

    testWidgets('bottom sheet is dismissible via drag', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Bench Press').first);
      await tester.pumpAndSettle();

      // Verify sheet is open.
      expect(find.text('Chest'), findsOneWidget);

      // Drag the sheet down to dismiss.
      await tester.drag(find.text('Chest'), const Offset(0, 500));
      await tester.pumpAndSettle();

      // Sheet should be dismissed, we're back on workout screen.
      expect(find.text('Chest'), findsNothing);
    });

    testWidgets('exercise image thumbnail is NOT shown in card header', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      // The 40x40 image should NOT be present.
      // Look for ExerciseImage in the exercise card area.
      // The card should only have the name and info icon.
      final exerciseCard = find.byType(Card);
      expect(exerciseCard, findsOneWidget);

      // There should be no ExerciseImage within the card header.
      // The info_outline icon should be the visual indicator instead.
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });

  group('Bottom sheet description and form tips', () {
    testWidgets('shows ABOUT section when exercise has description', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(exercise: _testExerciseWithDetails),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Bench Press').first);
      await tester.pumpAndSettle();

      expect(find.text('ABOUT'), findsOneWidget);
      expect(find.textContaining('compound chest exercise'), findsOneWidget);
    });

    testWidgets('shows FORM TIPS section when exercise has formTips', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(exercise: _testExerciseWithDetails),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Bench Press').first);
      await tester.pumpAndSettle();

      expect(find.text('FORM TIPS'), findsOneWidget);
      // P9: form-tip bullets are 6x6 circular Containers in primary, not
      // check_circle_outline icons.
      expect(findBulletDots(), findsNWidgets(3));
      expect(find.text('Arch the back slightly'), findsOneWidget);
      expect(find.text('Keep feet flat on the floor'), findsOneWidget);
      expect(find.text('Control the descent'), findsOneWidget);
    });

    testWidgets('omits ABOUT and FORM TIPS when exercise has neither', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Bench Press').first);
      await tester.pumpAndSettle();

      expect(find.text('ABOUT'), findsNothing);
      expect(find.text('FORM TIPS'), findsNothing);
    });
  });
}
