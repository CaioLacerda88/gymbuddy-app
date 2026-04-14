/// Navigation tests for the redesigned home screen.
///
/// Stat cells both navigate to /home/history via push.
/// "Start Empty Workout" navigates to /workout/active via go.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

import '../../../../fixtures/test_factories.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _EmptyRoutineNotifier extends AsyncNotifier<List<Routine>>
    implements RoutineListNotifier {
  @override
  Future<List<Routine>> build() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// History notifier that returns a single completed workout so the
/// contextual stat cells render (the P8 hide-when-empty guard collapses the
/// row when lastSession == null AND weekVolume == 0).
class _SingleWorkoutHistoryNotifier extends AsyncNotifier<List<Workout>>
    implements WorkoutHistoryNotifier {
  @override
  Future<List<Workout>> build() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return [
      Workout.fromJson(
        TestWorkoutFactory.create(
          id: 'wk-001',
          name: 'Push Day',
          finishedAt: yesterday.toIso8601String(),
        ),
      ),
    ];
  }

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
      const Profile(id: 'user-001', displayName: 'Alex', weightUnit: 'kg');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildTestApp() {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, _) => const Scaffold(body: HomeScreen()),
        routes: [
          GoRoute(
            path: 'history',
            name: 'history',
            builder: (context, _) =>
                const Scaffold(body: Center(child: Text('History Screen'))),
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      routineListProvider.overrideWith(() => _EmptyRoutineNotifier()),
      workoutHistoryProvider.overrideWith(
        () => _SingleWorkoutHistoryNotifier(),
      ),
      activeWorkoutProvider.overrideWith(() => _NullActiveWorkoutNotifier()),
      weeklyPlanProvider.overrideWith(() => _NullWeeklyPlanNotifier()),
      weeklyPlanNeedsConfirmationProvider.overrideWith((ref) => false),
      weekVolumeProvider.overrideWith((ref) => Future.value(0)),
      workoutCountProvider.overrideWith((ref) => Future.value(1)),
      profileProvider.overrideWith(() => _ProfileNotifier()),
    ],
    child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Home screen contextual stat cell navigation', () {
    testWidgets(
      'tapping Last session cell navigates to /home/history via push',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_buildTestApp());
        await tester.pump();
        await tester.pump();

        // Tap the "Last session" stat cell.
        await tester.tap(find.text('Last session'));
        await tester.pumpAndSettle();

        // History screen should be visible.
        expect(find.text('History Screen'), findsOneWidget);

        // Verify push semantics — HomeScreen is still on the stack.
        final navigatorState = tester.state<NavigatorState>(
          find.byType(Navigator).last,
        );
        expect(
          navigatorState.canPop(),
          isTrue,
          reason:
              'History was reached via push — HomeScreen is still below it.',
        );
      },
    );

    testWidgets(
      'tapping Week volume cell navigates to /home/history via push',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_buildTestApp());
        await tester.pump();
        await tester.pump();

        // Tap the "Week's volume" stat cell.
        await tester.tap(find.text("Week's volume"));
        await tester.pumpAndSettle();

        // History screen should be visible.
        expect(find.text('History Screen'), findsOneWidget);

        // Verify push semantics.
        final navigatorState = tester.state<NavigatorState>(
          find.byType(Navigator).last,
        );
        expect(
          navigatorState.canPop(),
          isTrue,
          reason:
              'History was reached via push — HomeScreen is still below it.',
        );
      },
    );

    testWidgets('back from History returns to HomeScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump();

      // Navigate to History.
      await tester.tap(find.text('Last session'));
      await tester.pumpAndSettle();
      expect(find.text('History Screen'), findsOneWidget);

      // Pop back.
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      );
      navigator.pop();
      await tester.pumpAndSettle();

      // HomeScreen must be visible again (no "GymBuddy" title — check stat cells).
      expect(find.text('Last session'), findsOneWidget);
      expect(find.text('History Screen'), findsNothing);
    });
  });
}
