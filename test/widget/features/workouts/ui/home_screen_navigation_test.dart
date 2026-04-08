/// BUG-1: Stat card taps use context.push (not context.go) so Android back
/// returns to Home instead of exiting the app.
///
/// Strategy: wire the HomeScreen inside a real GoRouter with two routes —
/// `/home` (shell) and `/records` / `/home/history`. Record which navigation
/// method was called via a mock observer.  Because GoRouter.push adds a new
/// entry to the nav stack while GoRouter.go replaces it, we can distinguish
/// the two by checking whether the navigator stack grew (push) or was reset
/// (go).
///
/// Simpler equivalent: give each destination a distinct builder that records
/// a flag, then check that tapping the stat card lands on the target screen
/// AND that the previous screen (HomeScreen) remains reachable via the back
/// button — only possible if push was used.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/personal_records/providers/pr_providers.dart';
import 'package:gymbuddy_app/features/routines/models/routine.dart';
import 'package:gymbuddy_app/features/routines/providers/notifiers/routine_list_notifier.dart';
import 'package:gymbuddy_app/features/workouts/models/active_workout_state.dart';
import 'package:gymbuddy_app/features/workouts/models/workout.dart';
import 'package:gymbuddy_app/features/workouts/providers/notifiers/active_workout_notifier.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_history_providers.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_providers.dart';
import 'package:gymbuddy_app/features/workouts/ui/home_screen.dart';
import 'package:gymbuddy_app/features/weekly_plan/data/models/weekly_plan.dart';
import 'package:gymbuddy_app/features/weekly_plan/providers/weekly_plan_provider.dart';

// ---------------------------------------------------------------------------
// Stubs (minimal — we only care about navigation, not content)
// ---------------------------------------------------------------------------

class _EmptyRoutineNotifier extends AsyncNotifier<List<Routine>>
    implements RoutineListNotifier {
  @override
  Future<List<Routine>> build() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyHistoryNotifier extends AsyncNotifier<List<Workout>>
    implements WorkoutHistoryNotifier {
  @override
  Future<List<Workout>> build() async => [];

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

// ---------------------------------------------------------------------------
// Navigation observer — detects whether push or go was used.
//
// push adds an entry so _pushedRoutes grows.
// go replaces the stack so _pushedRoutes stays at 0 (route added via replace).
// ---------------------------------------------------------------------------

class _NavigationRecorder extends NavigatorObserver {
  final pushedRoutes = <String>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name ?? '';
    pushedRoutes.add(name);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a GoRouter that hosts HomeScreen at `/home` and stub screens at
/// `/records` and `/home/history`. Injects a [NavigatorObserver] so we can
/// detect whether `push` or `go` was called.
Widget _buildTestApp(_NavigationRecorder recorder) {
  final router = GoRouter(
    initialLocation: '/home',
    observers: [recorder],
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
      GoRoute(
        path: '/records',
        name: 'records',
        builder: (context, _) =>
            const Scaffold(body: Center(child: Text('Records Screen'))),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      routineListProvider.overrideWith(() => _EmptyRoutineNotifier()),
      workoutHistoryProvider.overrideWith(() => _EmptyHistoryNotifier()),
      activeWorkoutProvider.overrideWith(() => _NullActiveWorkoutNotifier()),
      weeklyPlanProvider.overrideWith(() => _NullWeeklyPlanNotifier()),
      weeklyPlanNeedsConfirmationProvider.overrideWith((ref) => false),
      recentPRsProvider.overrideWith((ref) => Future.value([])),
      workoutCountProvider.overrideWith((ref) => Future.value(0)),
      prCountProvider.overrideWith((ref) => Future.value(0)),
    ],
    child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('BUG-1: Home screen stat card navigation uses push not go', () {
    testWidgets(
      'tapping Records card navigates to /records via push (not go)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final recorder = _NavigationRecorder();
        await tester.pumpWidget(_buildTestApp(recorder));
        await tester.pump();
        await tester.pump();

        // Tap the Records stat card.
        await tester.tap(find.text('Records'));
        await tester.pumpAndSettle();

        // The Records screen should be visible.
        expect(find.text('Records Screen'), findsOneWidget);

        // push adds an entry to the navigator; go would replace the current
        // route, removing HomeScreen from the stack.
        // Verify HomeScreen is still reachable (pop back).
        final navigatorState = tester.state<NavigatorState>(
          find.byType(Navigator).last,
        );
        expect(
          navigatorState.canPop(),
          isTrue,
          reason:
              'Records was reached via push — HomeScreen is still below it.',
        );
      },
    );

    testWidgets(
      'tapping Workouts card navigates to /home/history via push (not go)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final recorder = _NavigationRecorder();
        await tester.pumpWidget(_buildTestApp(recorder));
        await tester.pump();
        await tester.pump();

        // Tap the Workouts stat card.
        await tester.tap(find.text('Workouts'));
        await tester.pumpAndSettle();

        // The History screen should be visible.
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

    testWidgets('back from Records screen returns to HomeScreen (not exit)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final recorder = _NavigationRecorder();
      await tester.pumpWidget(_buildTestApp(recorder));
      await tester.pump();
      await tester.pump();

      // Navigate to Records.
      await tester.tap(find.text('Records'));
      await tester.pumpAndSettle();
      expect(find.text('Records Screen'), findsOneWidget);

      // Pop back.
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      );
      navigator.pop();
      await tester.pumpAndSettle();

      // HomeScreen must be visible again.
      expect(find.text('GymBuddy'), findsOneWidget);
      expect(find.text('Records Screen'), findsNothing);
    });

    testWidgets('back from History screen returns to HomeScreen (not exit)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final recorder = _NavigationRecorder();
      await tester.pumpWidget(_buildTestApp(recorder));
      await tester.pump();
      await tester.pump();

      // Navigate to History.
      await tester.tap(find.text('Workouts'));
      await tester.pumpAndSettle();
      expect(find.text('History Screen'), findsOneWidget);

      // Pop back.
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      );
      navigator.pop();
      await tester.pumpAndSettle();

      // HomeScreen must be visible again.
      expect(find.text('GymBuddy'), findsOneWidget);
      expect(find.text('History Screen'), findsNothing);
    });
  });
}
