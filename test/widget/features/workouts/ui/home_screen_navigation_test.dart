/// Navigation tests for the W8 redesigned home screen.
///
/// - LastSessionLine navigates to /home/history via push.
/// - "Quick workout" (lapsed-state secondary CTA) goes to /workout/active via go.
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
import 'package:gymbuddy_app/features/workouts/ui/widgets/last_session_line.dart';

import '../../../../fixtures/test_factories.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _RoutineStub extends AsyncNotifier<List<Routine>>
    implements RoutineListNotifier {
  _RoutineStub(this.routines);
  final List<Routine> routines;

  @override
  Future<List<Routine>> build() async => routines;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HistoryStub extends AsyncNotifier<List<Workout>>
    implements WorkoutHistoryNotifier {
  _HistoryStub(this.workouts);
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
  Future<void> startWorkout([String? name]) async {}

  @override
  Future<void> discardWorkout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PlanStub extends AsyncNotifier<WeeklyPlan?>
    implements WeeklyPlanNotifier {
  _PlanStub(this.plan);
  final WeeklyPlan? plan;

  @override
  Future<WeeklyPlan?> build() async => plan;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileStub extends AsyncNotifier<Profile?> implements ProfileNotifier {
  _ProfileStub(this.profile);
  final Profile? profile;

  @override
  Future<Profile?> build() async => profile;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Workout _workout({required String finishedAt, String name = 'Push Day'}) =>
    Workout.fromJson(
      TestWorkoutFactory.create(name: name, finishedAt: finishedAt),
    );

Widget _buildTestApp({required List<Workout> workouts}) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, _) => const Scaffold(body: HomeScreen()),
        routes: [
          GoRoute(
            path: 'history',
            builder: (context, _) =>
                const Scaffold(body: Center(child: Text('History Screen'))),
          ),
        ],
      ),
      GoRoute(
        path: '/plan/week',
        builder: (context, _) =>
            const Scaffold(body: Center(child: Text('Plan Week Screen'))),
      ),
      GoRoute(
        path: '/workout/active',
        builder: (context, _) =>
            const Scaffold(body: Center(child: Text('Active Workout Screen'))),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      routineListProvider.overrideWith(() => _RoutineStub(const [])),
      workoutHistoryProvider.overrideWith(() => _HistoryStub(workouts)),
      activeWorkoutProvider.overrideWith(() => _NullActiveWorkoutNotifier()),
      weeklyPlanProvider.overrideWith(() => _PlanStub(null)),
      weeklyPlanNeedsConfirmationProvider.overrideWith((ref) => false),
      workoutCountProvider.overrideWith((ref) => Future.value(workouts.length)),
      profileProvider.overrideWith(
        () => _ProfileStub(
          const Profile(id: 'user-001', displayName: 'Alex', weightUnit: 'kg'),
        ),
      ),
    ],
    child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('HomeScreen - last session line navigation', () {
    testWidgets('tapping LastSessionLine navigates to /home/history via push', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await tester.pumpWidget(
        _buildTestApp(
          workouts: [_workout(finishedAt: yesterday.toIso8601String())],
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byType(LastSessionLine));
      await tester.pumpAndSettle();

      expect(find.text('History Screen'), findsOneWidget);

      final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
      expect(nav.canPop(), isTrue);
    });

    testWidgets('back from History returns to HomeScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await tester.pumpWidget(
        _buildTestApp(
          workouts: [_workout(finishedAt: yesterday.toIso8601String())],
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byType(LastSessionLine));
      await tester.pumpAndSettle();
      expect(find.text('History Screen'), findsOneWidget);

      final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
      nav.pop();
      await tester.pumpAndSettle();

      // Home is visible again - no History on stack.
      expect(find.text('History Screen'), findsNothing);
    });
  });

  group('HomeScreen - lapsed-state secondary CTA navigation', () {
    testWidgets(
      'tapping Quick workout (lapsed state) navigates to /workout/active',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        await tester.pumpWidget(
          _buildTestApp(
            workouts: [_workout(finishedAt: yesterday.toIso8601String())],
          ),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Quick workout'));
        // Allow the activeWorkoutProvider to resolve and the navigation to
        // settle. Multiple pumps model the async startWorkout flow.
        await tester.pumpAndSettle();

        expect(find.text('Active Workout Screen'), findsOneWidget);
      },
    );
  });
}
