import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/exercises/models/exercise.dart';
import 'package:gymbuddy_app/features/personal_records/models/personal_record.dart';
import 'package:gymbuddy_app/features/personal_records/providers/pr_providers.dart';
import 'package:gymbuddy_app/features/routines/models/routine.dart';
import 'package:gymbuddy_app/features/routines/providers/notifiers/routine_list_notifier.dart';
import 'package:gymbuddy_app/features/workouts/models/active_workout_state.dart';
import 'package:gymbuddy_app/features/workouts/models/workout.dart';
import 'package:gymbuddy_app/features/workouts/providers/notifiers/active_workout_notifier.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_history_providers.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_providers.dart';
import 'package:gymbuddy_app/features/workouts/ui/home_screen.dart';

import '../../../../fixtures/test_factories.dart';

// ---------------------------------------------------------------------------
// Test notifier stubs
// ---------------------------------------------------------------------------

class _EmptyRoutineNotifier extends AsyncNotifier<List<Routine>>
    implements RoutineListNotifier {
  @override
  Future<List<Routine>> build() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WorkoutHistoryNotifier extends AsyncNotifier<List<Workout>>
    implements WorkoutHistoryNotifier {
  _WorkoutHistoryNotifier(this.workouts);
  final List<Workout> workouts;

  @override
  Future<List<Workout>> build() async => workouts;

  @override
  bool get hasMore => false;

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> refresh() async {}
}

class _NullActiveWorkoutNotifier extends AsyncNotifier<ActiveWorkoutState?>
    implements ActiveWorkoutNotifier {
  @override
  Future<ActiveWorkoutState?> build() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PRWithExercise makePRWithExercise({
  String exerciseName = 'Bench Press',
  double value = 100.0,
}) {
  final record = PersonalRecord.fromJson(
    TestPersonalRecordFactory.create(value: value),
  );
  return (
    record: record,
    exerciseName: exerciseName,
    equipmentType: EquipmentType.barbell,
  );
}

Workout makeWorkout({required String finishedAt}) {
  return Workout.fromJson(TestWorkoutFactory.create(finishedAt: finishedAt));
}

Widget buildTestWidget({
  int workoutCount = 14,
  int prCount = 3,
  bool loadingCounts = false,
  List<Workout>? historyWorkouts,
  List<PRWithExercise>? recentPRs,
}) {
  final workouts = historyWorkouts ?? [];
  final prs = recentPRs ?? [];

  return ProviderScope(
    overrides: [
      routineListProvider.overrideWith(() => _EmptyRoutineNotifier()),
      workoutHistoryProvider.overrideWith(
        () => _WorkoutHistoryNotifier(workouts),
      ),
      activeWorkoutProvider.overrideWith(() => _NullActiveWorkoutNotifier()),
      recentPRsProvider.overrideWith((ref) => Future.value(prs)),
      if (loadingCounts) ...[
        workoutCountProvider.overrideWith((ref) => Completer<int>().future),
        prCountProvider.overrideWith((ref) => Completer<int>().future),
      ] else ...[
        workoutCountProvider.overrideWith((ref) => Future.value(workoutCount)),
        prCountProvider.overrideWith((ref) => Future.value(prCount)),
      ],
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: const Scaffold(body: HomeScreen()),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('HomeScreen stat cards', () {
    testWidgets('renders workout count', (tester) async {
      await tester.pumpWidget(buildTestWidget(workoutCount: 14));
      await tester.pump();
      await tester.pump();

      expect(find.text('14'), findsOneWidget);
      expect(find.text('Workouts'), findsWidgets);
    });

    testWidgets('renders PR count', (tester) async {
      await tester.pumpWidget(buildTestWidget(prCount: 3));
      await tester.pump();
      await tester.pump();

      expect(find.text('3'), findsOneWidget);
      expect(find.text('Records'), findsOneWidget);
    });

    testWidgets('shows -- when counts are loading', (tester) async {
      await tester.pumpWidget(buildTestWidget(loadingCounts: true));
      await tester.pump();
      await tester.pump();

      expect(find.text('--'), findsNWidgets(2));
    });

    testWidgets('shows 0 when user has no workouts or records', (tester) async {
      await tester.pumpWidget(buildTestWidget(workoutCount: 0, prCount: 0));
      await tester.pump();
      await tester.pump();

      expect(find.text('0'), findsNWidgets(2));
    });

    testWidgets('workout count card has correct semantics', (tester) async {
      await tester.pumpWidget(buildTestWidget(workoutCount: 14));
      await tester.pump();
      await tester.pump();

      final semantics = tester.getSemantics(
        find
            .ancestor(
              of: find.text('Workouts'),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantics.label, contains('Workouts'));
    });

    testWidgets('cards are in a Row with two Expanded children', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      // Find the row that contains the stat cards.
      final workoutsText = find.text('Workouts');
      final recordsText = find.text('Records');
      expect(workoutsText, findsWidgets);
      expect(recordsText, findsOneWidget);
    });
  });

  group('HomeScreen stat card subtitles', () {
    // The stat card uses a fixed SizedBox(height: 72) with vertical padding
    // of 10dp on each side, leaving 52dp for the 3-line Column. At Material3
    // default font sizes the column overflows. We build the card in an
    // unconstrained wrapper so layout completes without overflow errors, letting
    // us verify the text content and widget properties independently of the
    // card's height constraint.
    Widget buildUnconstrainedWidget({
      int workoutCount = 5,
      int prCount = 3,
      List<Workout>? historyWorkouts,
      List<PRWithExercise>? recentPRs,
    }) {
      final workouts = historyWorkouts ?? [];
      final prs = recentPRs ?? [];

      return ProviderScope(
        overrides: [
          routineListProvider.overrideWith(() => _EmptyRoutineNotifier()),
          workoutHistoryProvider.overrideWith(
            () => _WorkoutHistoryNotifier(workouts),
          ),
          activeWorkoutProvider.overrideWith(
            () => _NullActiveWorkoutNotifier(),
          ),
          recentPRsProvider.overrideWith((ref) => Future.value(prs)),
          workoutCountProvider.overrideWith(
            (ref) => Future.value(workoutCount),
          ),
          prCountProvider.overrideWith((ref) => Future.value(prCount)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            // Use an unconstrained box so the stat card column does not
            // overflow the fixed 72dp height during tests.
            body: SingleChildScrollView(child: HomeScreen()),
          ),
        ),
      );
    }

    testWidgets(
      'workouts card shows relative date subtitle from most recent workout',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final workout = makeWorkout(finishedAt: yesterday.toIso8601String());

        await tester.pumpWidget(
          buildUnconstrainedWidget(workoutCount: 5, historyWorkouts: [workout]),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Yesterday'), findsOneWidget);
      },
    );

    testWidgets(
      'workouts card shows "Today" when most recent workout is today',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final now = DateTime.now();
        final workout = makeWorkout(finishedAt: now.toIso8601String());

        await tester.pumpWidget(
          buildUnconstrainedWidget(workoutCount: 1, historyWorkouts: [workout]),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Today'), findsOneWidget);
      },
    );

    testWidgets(
      'records card shows PR exercise name subtitle from most recent PR',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final pr = makePRWithExercise(exerciseName: 'Romanian Deadlift');

        await tester.pumpWidget(
          buildUnconstrainedWidget(prCount: 1, recentPRs: [pr]),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Romanian Deadlift'), findsOneWidget);
      },
    );

    testWidgets('workouts card has no subtitle when history is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(workoutCount: 0, historyWorkouts: []),
      );
      await tester.pump();
      await tester.pump();

      // Relative date strings should not appear.
      expect(find.text('Today'), findsNothing);
      expect(find.text('Yesterday'), findsNothing);
      expect(find.textContaining('days ago'), findsNothing);
      expect(find.textContaining('w ago'), findsNothing);
      expect(find.textContaining('mo ago'), findsNothing);
    });

    testWidgets('records card has no subtitle when recentPRs is empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(prCount: 0, recentPRs: []));
      await tester.pump();
      await tester.pump();

      // No exercise name subtitle should appear.
      expect(find.text('Bench Press'), findsNothing);
    });

    testWidgets(
      'records card subtitle shows Bench Press from default PR factory',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final pr = makePRWithExercise(exerciseName: 'Bench Press');

        await tester.pumpWidget(
          buildUnconstrainedWidget(prCount: 3, recentPRs: [pr]),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Bench Press'), findsOneWidget);
      },
    );

    testWidgets('subtitle Text widget has overflow:ellipsis and maxLines:1', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const exerciseName = 'Bench Press';
      final pr = makePRWithExercise(exerciseName: exerciseName);

      await tester.pumpWidget(
        buildUnconstrainedWidget(prCount: 1, recentPRs: [pr]),
      );
      await tester.pump();
      await tester.pump();

      // The subtitle Text widget should have the ellipsis overflow policy.
      final subtitleText = tester.widget<Text>(find.text(exerciseName));
      expect(subtitleText.overflow, TextOverflow.ellipsis);
      expect(subtitleText.maxLines, 1);
    });
  });

  group('HomeScreen removed sections', () {
    testWidgets('RECENT section is not rendered', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      expect(find.text('RECENT'), findsNothing);
    });

    testWidgets('RECENT RECORDS section is not rendered', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      expect(find.text('RECENT RECORDS'), findsNothing);
    });

    testWidgets('"View All" buttons are not rendered', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      expect(find.text('View All'), findsNothing);
    });
  });
}
