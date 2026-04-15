/// Tests for the routines surface on HomeScreen after the W8 refresh.
///
/// Starter routines moved to /routines (see routine_list_screen_test.dart).
/// Home only shows MY ROUTINES - truncated to 3 + "See all" pill - and only
/// when the user does NOT have an active weekly plan.
library;

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
  @override
  Future<Profile?> build() async =>
      const Profile(id: 'user-001', displayName: 'Alex', weightUnit: 'kg');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Factories
// ---------------------------------------------------------------------------

Routine _routine({
  required String id,
  required String name,
  bool isDefault = false,
  String? userId,
}) => Routine(
  id: id,
  name: name,
  userId: userId,
  isDefault: isDefault,
  exercises: const [],
  createdAt: DateTime(2026),
);

BucketRoutine _bucket({required String routineId, required int order}) =>
    BucketRoutine(routineId: routineId, order: order);

WeeklyPlan _plan({required List<BucketRoutine> routines}) => WeeklyPlan(
  id: 'plan-001',
  userId: 'user-001',
  weekStart: DateTime(2026, 4, 13),
  routines: routines,
  createdAt: DateTime(2026, 4, 13),
  updatedAt: DateTime(2026, 4, 13),
);

Workout _workout() => Workout.fromJson(
  TestWorkoutFactory.create(finishedAt: '2026-04-10T10:00:00Z'),
);

Widget _build({
  required List<Routine> routines,
  WeeklyPlan? plan,
  List<Workout> workouts = const [],
  int workoutCount = 0,
}) {
  return ProviderScope(
    overrides: [
      routineListProvider.overrideWith(() => _RoutineStub(routines)),
      workoutHistoryProvider.overrideWith(() => _HistoryStub(workouts)),
      activeWorkoutProvider.overrideWith(() => _NullActiveWorkoutNotifier()),
      weeklyPlanProvider.overrideWith(() => _PlanStub(plan)),
      weeklyPlanNeedsConfirmationProvider.overrideWith((ref) => false),
      workoutCountProvider.overrideWith((ref) => Future.value(workoutCount)),
      profileProvider.overrideWith(() => _ProfileStub()),
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
  group('HomeScreen - starter routines moved off home', () {
    testWidgets(
      'does NOT render STARTER ROUTINES on home when defaults exist',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _build(
            routines: [
              _routine(id: 'u-1', name: 'My Push', userId: 'user-001'),
              _routine(id: 'd-1', name: 'Full Body', isDefault: true),
            ],
            workouts: [_workout()],
            workoutCount: 1,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('STARTER ROUTINES'), findsNothing);
        // Full Body must not appear as a starter card on home.
        expect(find.text('Full Body'), findsNothing);
      },
    );
  });

  group('HomeScreen - MY ROUTINES (truncated top 3)', () {
    testWidgets('shows MY ROUTINES when user has routines and no active plan', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _build(
          routines: [_routine(id: 'u-1', name: 'My Push', userId: 'user-001')],
          workouts: [_workout()],
          workoutCount: 1,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('MY ROUTINES'), findsOneWidget);
      expect(find.text('My Push'), findsOneWidget);
    });

    testWidgets('truncates user routines to the top 3', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _build(
          routines: [
            _routine(id: 'u-1', name: 'My Push', userId: 'user-001'),
            _routine(id: 'u-2', name: 'My Pull', userId: 'user-001'),
            _routine(id: 'u-3', name: 'My Legs', userId: 'user-001'),
            _routine(id: 'u-4', name: 'My Arms', userId: 'user-001'),
            _routine(id: 'u-5', name: 'My Shoulders', userId: 'user-001'),
          ],
          workouts: [_workout()],
          workoutCount: 1,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('My Push'), findsOneWidget);
      expect(find.text('My Pull'), findsOneWidget);
      expect(find.text('My Legs'), findsOneWidget);
      expect(find.text('My Arms'), findsNothing);
      expect(find.text('My Shoulders'), findsNothing);
      expect(find.text('See all'), findsOneWidget);
    });

    testWidgets('no See all pill when 3 or fewer user routines', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _build(
          routines: [
            _routine(id: 'u-1', name: 'My Push', userId: 'user-001'),
            _routine(id: 'u-2', name: 'My Pull', userId: 'user-001'),
          ],
          workouts: [_workout()],
          workoutCount: 1,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('See all'), findsNothing);
    });

    testWidgets('MY ROUTINES hidden when active plan exists', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _build(
          routines: [_routine(id: 'r-1', name: 'Push', userId: 'user-001')],
          plan: _plan(routines: [_bucket(routineId: 'r-1', order: 1)]),
          workoutCount: 1,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('MY ROUTINES'), findsNothing);
      expect(find.text('STARTER ROUTINES'), findsNothing);
    });
  });
}
