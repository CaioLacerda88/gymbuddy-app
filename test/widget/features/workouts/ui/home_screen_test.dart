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
import 'package:intl/intl.dart';

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

class _RoutineNotifierWithData extends AsyncNotifier<List<Routine>>
    implements RoutineListNotifier {
  _RoutineNotifierWithData(this._routines);
  final List<Routine> _routines;

  @override
  Future<List<Routine>> build() async => _routines;

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

class _ActiveWeeklyPlanNotifier extends AsyncNotifier<WeeklyPlan?>
    implements WeeklyPlanNotifier {
  static final _plan = WeeklyPlan(
    id: 'plan-1',
    userId: 'user-001',
    weekStart: DateTime(2026, 4, 6),
    routines: const [
      BucketRoutine(routineId: 'routine-1', order: 1),
      BucketRoutine(routineId: 'routine-2', order: 2),
    ],
    createdAt: DateTime(2026, 4, 6),
    updatedAt: DateTime(2026, 4, 6),
  );

  @override
  Future<WeeklyPlan?> build() async => _plan;

  /// Transitions the state to AsyncLoading while retaining previous data.
  void simulateReload() {
    state = const AsyncLoading<WeeklyPlan?>().copyWithPrevious(
      AsyncData(_plan),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileNotifier extends AsyncNotifier<Profile?>
    implements ProfileNotifier {
  @override
  Future<Profile?> build() async =>
      const Profile(id: 'user-001', displayName: 'Alex', weightUnit: 'kg');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NullProfileNotifier extends AsyncNotifier<Profile?>
    implements ProfileNotifier {
  @override
  Future<Profile?> build() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileNotifierWithUnit extends AsyncNotifier<Profile?>
    implements ProfileNotifier {
  _ProfileNotifierWithUnit(this._weightUnit);
  final String _weightUnit;

  @override
  Future<Profile?> build() async =>
      Profile(id: 'user-001', displayName: 'Alex', weightUnit: _weightUnit);

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
  bool hasActivePlan = false,
  bool hasProfile = true,
  List<Routine>? routines,
}) {
  final workouts = historyWorkouts.isEmpty && !hasActivePlan
      ? <Workout>[]
      : historyWorkouts;

  return ProviderScope(
    overrides: [
      routineListProvider.overrideWith(
        () => routines != null
            ? _RoutineNotifierWithData(routines)
            : _EmptyRoutineNotifier(),
      ),
      workoutHistoryProvider.overrideWith(
        () => _WorkoutHistoryNotifier(workouts),
      ),
      activeWorkoutProvider.overrideWith(() => _NullActiveWorkoutNotifier()),
      weeklyPlanProvider.overrideWith(
        () => hasActivePlan
            ? _ActiveWeeklyPlanNotifier()
            : _NullWeeklyPlanNotifier(),
      ),
      weeklyPlanNeedsConfirmationProvider.overrideWith((ref) => false),
      weekVolumeProvider.overrideWith((ref) => Future.value(weekVolume)),
      profileProvider.overrideWith(
        () => hasProfile ? _ProfileNotifier() : _NullProfileNotifier(),
      ),
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
  group('HomeScreen layout redesign', () {
    testWidgets('shows formatted date in header', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      final expected = DateFormat(
        'EEE, MMM d',
      ).format(DateTime.now()).toUpperCase();
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('shows user display name when profile has one', (tester) async {
      await tester.pumpWidget(buildTestWidget(hasProfile: true));
      await tester.pump();
      await tester.pump();

      expect(find.text('Alex'), findsOneWidget);
    });

    testWidgets('does NOT show large GymBuddy title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      expect(find.text('GymBuddy'), findsNothing);
    });

    testWidgets('shows contextual stat cells (Last session + Week volume)', (
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
              name: 'Push Day',
            ),
          ],
          weekVolume: 12400,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Last session'), findsOneWidget);
      expect(find.text("Week's volume"), findsOneWidget);
      expect(find.byType(ContextualStatCell), findsNWidgets(2));
    });

    testWidgets('does NOT show old lifetime stat cards (Workouts/Records)', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      // Old stat card labels should be gone.
      expect(find.text('Workouts'), findsNothing);
      expect(find.text('Records'), findsNothing);
    });

    testWidgets('Start Empty Workout is a FilledButton', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      expect(find.text('Start Empty Workout'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      // Verify it's not OutlinedButton.
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('routines list hidden when active plan exists', (tester) async {
      final routines = [
        Routine(
          id: 'routine-1',
          name: 'My Push',
          userId: 'user-001',
          isDefault: false,
          exercises: const [],
          createdAt: DateTime(2026),
        ),
        Routine(
          id: 'routine-2',
          name: 'My Pull',
          userId: 'user-001',
          isDefault: false,
          exercises: const [],
          createdAt: DateTime(2026),
        ),
      ];

      await tester.pumpWidget(
        buildTestWidget(hasActivePlan: true, routines: routines),
      );
      await tester.pump();
      await tester.pump();

      // Routines list should be hidden.
      expect(find.text('MY ROUTINES'), findsNothing);
      expect(find.text('STARTER ROUTINES'), findsNothing);
    });

    testWidgets('routines list visible when no active plan', (tester) async {
      final routines = [
        Routine(
          id: 'routine-1',
          name: 'My Push',
          userId: 'user-001',
          isDefault: false,
          exercises: const [],
          createdAt: DateTime(2026),
        ),
      ];

      await tester.pumpWidget(
        buildTestWidget(hasActivePlan: false, routines: routines),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('MY ROUTINES'), findsOneWidget);
    });

    testWidgets('last session shows relative date and workout name', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      await tester.pumpWidget(
        buildTestWidget(
          historyWorkouts: [
            makeWorkout(
              finishedAt: threeDaysAgo.toIso8601String(),
              name: 'Leg Day',
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      // Should show relative date + workout name.
      expect(find.textContaining('3 days ago'), findsOneWidget);
      expect(find.textContaining('Leg Day'), findsOneWidget);
    });

    testWidgets('week volume shows formatted value', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget(weekVolume: 12400));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('12,400'), findsOneWidget);
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

    testWidgets('shows "No volume yet" when week volume is 0', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget(weekVolume: 0));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('No volume yet'), findsOneWidget);
    });

    testWidgets('onboarding CTA shown when no routines at all', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(hasActivePlan: false, routines: []),
      );
      await tester.pump();
      await tester.pump();

      // When no routines exist and no active plan, the home screen shows
      // the _CreateRoutineCta widget with "Create Your First Routine".
      expect(find.text('Create Your First Routine'), findsOneWidget);
    });
  });

  group('HomeScreen — plan reload stability', () {
    testWidgets('routines list stays hidden during plan provider reload', (
      tester,
    ) async {
      final planNotifier = _ActiveWeeklyPlanNotifier();
      final routines = [
        Routine(
          id: 'routine-1',
          name: 'My Push',
          userId: 'user-001',
          isDefault: false,
          exercises: const [],
          createdAt: DateTime(2026),
        ),
        Routine(
          id: 'routine-2',
          name: 'My Pull',
          userId: 'user-001',
          isDefault: false,
          exercises: const [],
          createdAt: DateTime(2026),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineListProvider.overrideWith(
              () => _RoutineNotifierWithData(routines),
            ),
            workoutHistoryProvider.overrideWith(
              () => _WorkoutHistoryNotifier([]),
            ),
            activeWorkoutProvider.overrideWith(
              () => _NullActiveWorkoutNotifier(),
            ),
            weeklyPlanProvider.overrideWith(() => planNotifier),
            weeklyPlanNeedsConfirmationProvider.overrideWith((ref) => false),
            weekVolumeProvider.overrideWith((ref) => Future.value(0.0)),
            profileProvider.overrideWith(() => _ProfileNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: HomeScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Active plan exists — routines list should be hidden.
      expect(find.text('MY ROUTINES'), findsNothing);

      // Simulate provider reload (e.g., navigating back to home).
      planNotifier.simulateReload();
      await tester.pump();

      // During reload, hasActivePlan should remain true — routines list
      // should still be hidden (not flash momentarily).
      expect(find.text('MY ROUTINES'), findsNothing);
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

  group('HomeScreen week volume unit threading', () {
    Widget buildWithUnit(String unit) {
      return ProviderScope(
        overrides: [
          routineListProvider.overrideWith(() => _EmptyRoutineNotifier()),
          workoutHistoryProvider.overrideWith(
            () => _WorkoutHistoryNotifier(const []),
          ),
          activeWorkoutProvider.overrideWith(
            () => _NullActiveWorkoutNotifier(),
          ),
          weeklyPlanProvider.overrideWith(() => _NullWeeklyPlanNotifier()),
          weeklyPlanNeedsConfirmationProvider.overrideWith((ref) => false),
          weekVolumeProvider.overrideWith((ref) => Future.value(12400.0)),
          profileProvider.overrideWith(() => _ProfileNotifierWithUnit(unit)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: HomeScreen()),
        ),
      );
    }

    testWidgets("Week's volume stat card shows the user's weight unit", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildWithUnit('kg'));
      await tester.pump();
      await tester.pump();

      // The volume cell text is "<number> <unit> this week".
      expect(find.textContaining('12,400 kg this week'), findsOneWidget);
      // Make sure the other unit is nowhere on the week volume cell.
      expect(find.textContaining('lbs'), findsNothing);
    });

    testWidgets(
      "Week's volume stat card flips to lbs when profile weightUnit is lbs",
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildWithUnit('lbs'));
        await tester.pump();
        await tester.pump();

        // Same stored volume, just a different suffix — no conversion.
        expect(find.textContaining('12,400 lbs this week'), findsOneWidget);
        // And the kg suffix must not appear in the volume cell.
        expect(find.textContaining('12,400 kg'), findsNothing);
      },
    );
  });
}
