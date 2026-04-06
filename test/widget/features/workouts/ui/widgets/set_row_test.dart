import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/workouts/data/workout_local_storage.dart';
import 'package:gymbuddy_app/features/workouts/data/workout_repository.dart';
import 'package:gymbuddy_app/features/workouts/models/active_workout_state.dart';
import 'package:gymbuddy_app/features/workouts/models/exercise_set.dart';
import 'package:gymbuddy_app/features/workouts/models/set_type.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_providers.dart';
import 'package:gymbuddy_app/features/workouts/ui/widgets/set_row.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../fixtures/test_factories.dart';

class MockWorkoutRepository extends Mock implements WorkoutRepository {}

class MockWorkoutLocalStorage extends Mock implements WorkoutLocalStorage {}

class FakeActiveWorkoutState extends Fake implements ActiveWorkoutState {}

/// Creates a minimal [ExerciseSet] using the test factory.
ExerciseSet makeSet({
  String id = 'set-001',
  String workoutExerciseId = 'we-001',
  int setNumber = 1,
  double weight = 60.0,
  int reps = 10,
  SetType setType = SetType.working,
  bool isCompleted = false,
}) {
  return ExerciseSet.fromJson(
    TestSetFactory.create(
      id: id,
      workoutExerciseId: workoutExerciseId,
      setNumber: setNumber,
      weight: weight,
      reps: reps,
      setType: setType.name,
      isCompleted: isCompleted,
    ),
  );
}

/// Creates a [ProviderContainer] with mocked storage returning [initialState].
ProviderContainer makeContainer(ActiveWorkoutState? initialState) {
  final mockStorage = MockWorkoutLocalStorage();
  when(() => mockStorage.loadActiveWorkout()).thenReturn(initialState);
  when(() => mockStorage.saveActiveWorkout(any())).thenAnswer((_) async {});

  final container = ProviderContainer(
    overrides: [
      workoutRepositoryProvider.overrideWithValue(MockWorkoutRepository()),
      workoutLocalStorageProvider.overrideWithValue(mockStorage),
    ],
  );
  return container;
}

Widget buildTestWidget(Widget child, {ProviderContainer? container}) {
  return UncontrolledProviderScope(
    container: container ?? makeContainer(null),
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: SizedBox(
          // SetRow has a WeightStepper + RepsStepper side by side inside an
          // Expanded column. 800px gives each stepper enough room to render
          // without overflow warnings in the test harness.
          width: 800,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeActiveWorkoutState());
  });

  group('SetRow', () {
    group('rendering', () {
      testWidgets('displays the set number', (tester) async {
        final set = makeSet(setNumber: 3);
        await tester.pumpWidget(
          buildTestWidget(SetRow(set: set, workoutExerciseId: 'we-001')),
        );

        expect(find.text('3'), findsOneWidget);
      });

      testWidgets('displays working-set badge label "W"', (tester) async {
        final set = makeSet(setType: SetType.working);
        await tester.pumpWidget(
          buildTestWidget(SetRow(set: set, workoutExerciseId: 'we-001')),
        );

        expect(find.text('W'), findsOneWidget);
      });

      testWidgets('displays warmup-set badge label "WU"', (tester) async {
        final set = makeSet(setType: SetType.warmup);
        await tester.pumpWidget(
          buildTestWidget(SetRow(set: set, workoutExerciseId: 'we-001')),
        );

        expect(find.text('WU'), findsOneWidget);
      });

      testWidgets('displays dropset badge label "D"', (tester) async {
        final set = makeSet(setType: SetType.dropset);
        await tester.pumpWidget(
          buildTestWidget(SetRow(set: set, workoutExerciseId: 'we-001')),
        );

        expect(find.text('D'), findsOneWidget);
      });

      testWidgets('displays to-failure badge label "F"', (tester) async {
        final set = makeSet(setType: SetType.failure);
        await tester.pumpWidget(
          buildTestWidget(SetRow(set: set, workoutExerciseId: 'we-001')),
        );

        expect(find.text('F'), findsOneWidget);
      });

      testWidgets('displays "kg" label next to weight', (tester) async {
        final set = makeSet();
        await tester.pumpWidget(
          buildTestWidget(SetRow(set: set, workoutExerciseId: 'we-001')),
        );

        expect(find.text('kg'), findsOneWidget);
      });

      testWidgets('renders checkbox unchecked when isCompleted is false', (
        tester,
      ) async {
        final set = makeSet(isCompleted: false);
        await tester.pumpWidget(
          buildTestWidget(SetRow(set: set, workoutExerciseId: 'we-001')),
        );

        final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
        expect(checkbox.value, isFalse);
      });

      testWidgets('renders checkbox checked when isCompleted is true', (
        tester,
      ) async {
        final set = makeSet(isCompleted: true);
        await tester.pumpWidget(
          buildTestWidget(SetRow(set: set, workoutExerciseId: 'we-001')),
        );

        final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
        expect(checkbox.value, isTrue);
      });
    });

    group('interactions', () {
      testWidgets(
        'tapping checkbox toggles isCompleted on the notifier state',
        (tester) async {
          final stateJson = TestActiveWorkoutStateFactory.createWithExercises(
            exerciseCount: 1,
            setsPerExercise: 1,
          );
          final workoutState = ActiveWorkoutState.fromJson(stateJson);
          final weId = workoutState.exercises.first.workoutExercise.id;
          final set = workoutState.exercises.first.sets.first;
          final initialCompleted = set.isCompleted;

          final container = makeContainer(workoutState);
          addTearDown(container.dispose);
          // Prime the notifier so it has loaded state.
          await container.read(activeWorkoutProvider.future);

          await tester.pumpWidget(
            buildTestWidget(
              SetRow(set: set, workoutExerciseId: weId),
              container: container,
            ),
          );

          await tester.tap(find.byType(Checkbox));
          await tester.pump();

          final updatedState = container.read(activeWorkoutProvider).value;
          expect(
            updatedState?.exercises.first.sets.first.isCompleted,
            isNot(initialCompleted),
          );
        },
      );

      testWidgets(
        'long-pressing set number cycles set type from working to warmup',
        (tester) async {
          final stateJson = TestActiveWorkoutStateFactory.createWithExercises(
            exerciseCount: 1,
            setsPerExercise: 1,
          );
          final workoutState = ActiveWorkoutState.fromJson(stateJson);
          final weId = workoutState.exercises.first.workoutExercise.id;
          // The factory creates sets with type 'working'.
          final set = workoutState.exercises.first.sets.first;
          expect(set.setType, SetType.working);

          final container = makeContainer(workoutState);
          addTearDown(container.dispose);
          await container.read(activeWorkoutProvider.future);

          await tester.pumpWidget(
            buildTestWidget(
              SetRow(set: set, workoutExerciseId: weId),
              container: container,
            ),
          );

          // Long-press the set number area to cycle set type.
          await tester.longPress(find.text('${set.setNumber}'));
          await tester.pump();

          final updatedState = container.read(activeWorkoutProvider).value;
          expect(
            updatedState?.exercises.first.sets.first.setType,
            SetType.warmup,
          );
        },
      );
    });

    group('ghost text (previous session hint)', () {
      testWidgets(
        'shows ghost text when lastSet is provided and set is not completed',
        (tester) async {
          final set = makeSet(isCompleted: false);
          final lastSet = makeSet(id: 'last-set', weight: 80.0, reps: 8);

          await tester.pumpWidget(
            buildTestWidget(
              SetRow(set: set, workoutExerciseId: 'we-001', lastSet: lastSet),
            ),
          );

          expect(find.text('Last: 80kg × 8'), findsOneWidget);
        },
      );

      testWidgets('hides ghost text when set is already completed', (
        tester,
      ) async {
        final set = makeSet(isCompleted: true);
        final lastSet = makeSet(id: 'last-set', weight: 80.0, reps: 8);

        await tester.pumpWidget(
          buildTestWidget(
            SetRow(set: set, workoutExerciseId: 'we-001', lastSet: lastSet),
          ),
        );

        expect(find.text('Last: 80kg × 8'), findsNothing);
      });

      testWidgets('hides ghost text when lastSet is null', (tester) async {
        final set = makeSet(isCompleted: false);

        await tester.pumpWidget(
          buildTestWidget(SetRow(set: set, workoutExerciseId: 'we-001')),
        );

        // No "Last:" prefix should appear anywhere.
        expect(find.textContaining('Last:'), findsNothing);
      });

      testWidgets(
        'ghost text shows integer weight without decimal when weight is whole number',
        (tester) async {
          final set = makeSet(isCompleted: false);
          final lastSet = makeSet(id: 'last-set', weight: 100.0, reps: 5);

          await tester.pumpWidget(
            buildTestWidget(
              SetRow(set: set, workoutExerciseId: 'we-001', lastSet: lastSet),
            ),
          );

          // Whole-number weights should display without a decimal suffix.
          expect(find.text('Last: 100kg × 5'), findsOneWidget);
        },
      );
    });

    group('isNew checkbox lock', () {
      testWidgets(
        'checkbox is non-interactive within 600ms when isNew is true',
        (tester) async {
          final stateJson = TestActiveWorkoutStateFactory.createWithExercises(
            exerciseCount: 1,
            setsPerExercise: 1,
          );
          final workoutState = ActiveWorkoutState.fromJson(stateJson);
          final weId = workoutState.exercises.first.workoutExercise.id;
          final set = workoutState.exercises.first.sets.first;

          final container = makeContainer(workoutState);
          addTearDown(container.dispose);
          await container.read(activeWorkoutProvider.future);

          await tester.pumpWidget(
            buildTestWidget(
              SetRow(set: set, workoutExerciseId: weId, isNew: true),
              container: container,
            ),
          );

          // Tap the checkbox immediately — still within the 600ms lock window.
          await tester.tap(find.byType(Checkbox));
          await tester.pump();

          // isCompleted should NOT have changed because the lock is active.
          final state = container.read(activeWorkoutProvider).value;
          expect(
            state?.exercises.first.sets.first.isCompleted,
            set.isCompleted,
          );
        },
      );

      testWidgets('checkbox becomes interactive after 600ms lock expires', (
        tester,
      ) async {
        final stateJson = TestActiveWorkoutStateFactory.createWithExercises(
          exerciseCount: 1,
          setsPerExercise: 1,
        );
        final workoutState = ActiveWorkoutState.fromJson(stateJson);
        final weId = workoutState.exercises.first.workoutExercise.id;
        final set = workoutState.exercises.first.sets.first;
        final initialCompleted = set.isCompleted;

        final container = makeContainer(workoutState);
        addTearDown(container.dispose);
        await container.read(activeWorkoutProvider.future);

        await tester.pumpWidget(
          buildTestWidget(
            SetRow(set: set, workoutExerciseId: weId, isNew: true),
            container: container,
          ),
        );

        // Advance time past the 600ms lock duration.
        await tester.pump(const Duration(milliseconds: 601));

        // Now tap the checkbox — the lock should have expired.
        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        final state = container.read(activeWorkoutProvider).value;
        expect(
          state?.exercises.first.sets.first.isCompleted,
          isNot(initialCompleted),
        );
      });

      testWidgets(
        'checkbox is immediately interactive when isNew is false (default)',
        (tester) async {
          final stateJson = TestActiveWorkoutStateFactory.createWithExercises(
            exerciseCount: 1,
            setsPerExercise: 1,
          );
          final workoutState = ActiveWorkoutState.fromJson(stateJson);
          final weId = workoutState.exercises.first.workoutExercise.id;
          final set = workoutState.exercises.first.sets.first;
          final initialCompleted = set.isCompleted;

          final container = makeContainer(workoutState);
          addTearDown(container.dispose);
          await container.read(activeWorkoutProvider.future);

          await tester.pumpWidget(
            buildTestWidget(
              // isNew defaults to false — no lock should apply.
              SetRow(set: set, workoutExerciseId: weId),
              container: container,
            ),
          );

          await tester.tap(find.byType(Checkbox));
          await tester.pump();

          final state = container.read(activeWorkoutProvider).value;
          expect(
            state?.exercises.first.sets.first.isCompleted,
            isNot(initialCompleted),
          );
        },
      );
    });

    group('hint line suppression', () {
      testWidgets('hint line is hidden when set values match lastSet exactly', (
        tester,
      ) async {
        // Current set has the same weight/reps as lastSet — hint is redundant.
        final set = makeSet(weight: 80.0, reps: 8, isCompleted: false);
        final lastSet = makeSet(id: 'last-set', weight: 80.0, reps: 8);

        await tester.pumpWidget(
          buildTestWidget(
            SetRow(set: set, workoutExerciseId: 'we-001', lastSet: lastSet),
          ),
        );

        expect(find.textContaining('Last:'), findsNothing);
      });

      testWidgets(
        'hint line is shown when current weight differs from lastSet',
        (tester) async {
          final set = makeSet(weight: 60.0, reps: 8, isCompleted: false);
          final lastSet = makeSet(id: 'last-set', weight: 80.0, reps: 8);

          await tester.pumpWidget(
            buildTestWidget(
              SetRow(set: set, workoutExerciseId: 'we-001', lastSet: lastSet),
            ),
          );

          expect(find.text('Last: 80kg × 8'), findsOneWidget);
        },
      );

      testWidgets('hint line is shown when current reps differ from lastSet', (
        tester,
      ) async {
        final set = makeSet(weight: 80.0, reps: 10, isCompleted: false);
        final lastSet = makeSet(id: 'last-set', weight: 80.0, reps: 8);

        await tester.pumpWidget(
          buildTestWidget(
            SetRow(set: set, workoutExerciseId: 'we-001', lastSet: lastSet),
          ),
        );

        expect(find.text('Last: 80kg × 8'), findsOneWidget);
      });

      testWidgets(
        'hint line is shown when both weight and reps differ from lastSet',
        (tester) async {
          final set = makeSet(weight: 60.0, reps: 10, isCompleted: false);
          final lastSet = makeSet(id: 'last-set', weight: 80.0, reps: 8);

          await tester.pumpWidget(
            buildTestWidget(
              SetRow(set: set, workoutExerciseId: 'we-001', lastSet: lastSet),
            ),
          );

          expect(find.text('Last: 80kg × 8'), findsOneWidget);
        },
      );
    });

    group('accessibility semantics', () {
      testWidgets('set number has correct semantics label with type info', (
        tester,
      ) async {
        final set = makeSet(setType: SetType.working);
        await tester.pumpWidget(
          buildTestWidget(SetRow(set: set, workoutExerciseId: 'we-001')),
        );

        expect(
          find.bySemanticsLabel(
            RegExp(r'Set 1.*Long press to change type: Working'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('uncompleted checkbox has "Mark set as done" semantics', (
        tester,
      ) async {
        final set = makeSet(isCompleted: false);
        await tester.pumpWidget(
          buildTestWidget(SetRow(set: set, workoutExerciseId: 'we-001')),
        );

        expect(find.bySemanticsLabel('Mark set as done'), findsOneWidget);
      });

      testWidgets('completed checkbox has "Set completed" semantics', (
        tester,
      ) async {
        final set = makeSet(isCompleted: true);
        await tester.pumpWidget(
          buildTestWidget(SetRow(set: set, workoutExerciseId: 'we-001')),
        );

        expect(find.bySemanticsLabel('Set completed'), findsOneWidget);
      });
    });
  });
}
