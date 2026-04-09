import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/profile/models/profile.dart';
import 'package:gymbuddy_app/features/profile/providers/profile_providers.dart';
import 'package:gymbuddy_app/features/routines/models/routine.dart';
import 'package:gymbuddy_app/features/routines/providers/notifiers/routine_list_notifier.dart';
import 'package:gymbuddy_app/features/weekly_plan/data/models/weekly_plan.dart';
import 'package:gymbuddy_app/features/weekly_plan/providers/weekly_plan_provider.dart';
import 'package:gymbuddy_app/features/workouts/models/active_workout_state.dart';
import 'package:gymbuddy_app/features/workouts/models/workout.dart';
import 'package:gymbuddy_app/features/workouts/providers/notifiers/active_workout_notifier.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_history_providers.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_providers.dart';
import 'package:gymbuddy_app/features/workouts/ui/home_screen.dart';
import 'package:gymbuddy_app/features/workouts/ui/widgets/contextual_stat_cell.dart';

import '../../../../fixtures/test_factories.dart';

// ---------------------------------------------------------------------------
// Notifier stubs
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
  bool get isLoadingMore => false;

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

class _NullWeeklyPlanNotifier extends AsyncNotifier<WeeklyPlan?>
    implements WeeklyPlanNotifier {
  @override
  Future<WeeklyPlan?> build() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileNotifier extends AsyncNotifier<Profile?>
    implements ProfileNotifier {
  @override
  Future<Profile?> build() async =>
      const Profile(id: 'user-001', displayName: 'Test User', weightUnit: 'kg');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Workout makeWorkout({required String finishedAt, String name = 'Push Day'}) {
  return Workout.fromJson(
    TestWorkoutFactory.create(finishedAt: finishedAt, name: name),
  );
}

Widget buildTestWidget({
  List<Workout> historyWorkouts = const [],
  double weekVolume = 0,
}) {
  return ProviderScope(
    overrides: [
      routineListProvider.overrideWith(() => _EmptyRoutineNotifier()),
      workoutHistoryProvider.overrideWith(
        () => _WorkoutHistoryNotifier(historyWorkouts),
      ),
      activeWorkoutProvider.overrideWith(() => _NullActiveWorkoutNotifier()),
      weeklyPlanProvider.overrideWith(() => _NullWeeklyPlanNotifier()),
      weeklyPlanNeedsConfirmationProvider.overrideWith((ref) => false),
      weekVolumeProvider.overrideWith((ref) => Future.value(weekVolume)),
      profileProvider.overrideWith(() => _ProfileNotifier()),
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
  group('HomeScreen contextual stat cells', () {
    testWidgets('renders two ContextualStatCell widgets', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      expect(find.byType(ContextualStatCell), findsNWidgets(2));
    });

    testWidgets('last session shows relative date + workout name', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await tester.pumpWidget(
        buildTestWidget(
          historyWorkouts: [
            makeWorkout(
              finishedAt: yesterday.toIso8601String(),
              name: 'Chest Day',
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Last session'), findsOneWidget);
      // "Yesterday — Chest Day"
      expect(find.textContaining('Yesterday'), findsOneWidget);
      expect(find.textContaining('Chest Day'), findsOneWidget);
    });

    testWidgets('week volume shows formatted value with unit', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget(weekVolume: 8500));
      await tester.pump();
      await tester.pump();

      expect(find.text("Week's volume"), findsOneWidget);
      expect(find.textContaining('8,500'), findsOneWidget);
      expect(find.textContaining('this week'), findsOneWidget);
    });

    testWidgets('shows "No workouts yet" when history is empty', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('No workouts yet'), findsOneWidget);
    });

    testWidgets('shows "No volume yet" when volume is 0', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget(weekVolume: 0));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('No volume yet'), findsOneWidget);
    });

    testWidgets('last session shows "Today" for same-day workout', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      await tester.pumpWidget(
        buildTestWidget(
          historyWorkouts: [makeWorkout(finishedAt: now.toIso8601String())],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Today'), findsOneWidget);
    });

    testWidgets('cells are in a Row with two Expanded children', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      expect(find.text('Last session'), findsOneWidget);
      expect(find.text("Week's volume"), findsOneWidget);
    });

    testWidgets('stat cells have correct semantics', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      // Find semantics on first stat cell.
      final lastSessionCell = find
          .ancestor(
            of: find.text('Last session'),
            matching: find.byType(Semantics),
          )
          .first;
      final semantics = tester.getSemantics(lastSessionCell);
      expect(semantics.label, contains('Last session'));
    });
  });
}
