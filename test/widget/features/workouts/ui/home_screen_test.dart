/// Top-level HomeScreen smoke tests for the W8 Home refresh.
///
/// The deep contracts (status line, action hero, last session) live in
/// dedicated test files. This file only verifies that:
///   - the skeleton composes the right blocks per state
///   - removed legacy elements (date header, stat grid, Start Empty Workout
///     label, _SuggestedNextCard, THIS WEEK label, counter) are gone
///   - the confirmation banner still renders when needsConfirmation is true
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
import 'package:gymbuddy_app/core/offline/pending_sync_provider.dart';
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
  _ProfileStub(this.profile);
  final Profile? profile;

  @override
  Future<Profile?> build() async => profile;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ZeroPendingSyncNotifier extends PendingSyncNotifier {
  @override
  int build() => 0;
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

Workout _workout({
  String id = 'w-001',
  String name = 'Push Day',
  required String finishedAt,
}) => Workout.fromJson(
  TestWorkoutFactory.create(id: id, name: name, finishedAt: finishedAt),
);

BucketRoutine _bucket({
  required String routineId,
  required int order,
  String? completedWorkoutId,
}) => BucketRoutine(
  routineId: routineId,
  order: order,
  completedWorkoutId: completedWorkoutId,
);

WeeklyPlan _plan({required List<BucketRoutine> routines}) => WeeklyPlan(
  id: 'plan-001',
  userId: 'user-001',
  weekStart: DateTime(2026, 4, 13),
  routines: routines,
  createdAt: DateTime(2026, 4, 13),
  updatedAt: DateTime(2026, 4, 13),
);

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Widget _build({
  WeeklyPlan? plan,
  List<Routine> routines = const [],
  List<Workout> workouts = const [],
  Profile? profile = const Profile(
    id: 'user-001',
    displayName: 'Alex',
    weightUnit: 'kg',
  ),
  int workoutCount = 0,
  bool needsConfirmation = false,
}) {
  return ProviderScope(
    overrides: [
      weeklyPlanProvider.overrideWith(() => _PlanStub(plan)),
      weeklyPlanNeedsConfirmationProvider.overrideWith(
        (ref) => needsConfirmation,
      ),
      routineListProvider.overrideWith(() => _RoutineStub(routines)),
      workoutHistoryProvider.overrideWith(() => _HistoryStub(workouts)),
      workoutCountProvider.overrideWith((ref) => Future.value(workoutCount)),
      activeWorkoutProvider.overrideWith(() => _NullActiveWorkoutNotifier()),
      profileProvider.overrideWith(() => _ProfileStub(profile)),
      pendingSyncProvider.overrideWith(() => _ZeroPendingSyncNotifier()),
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
  group('HomeScreen - W8 skeleton', () {
    testWidgets('active plan: renders status line + action hero + chips', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _build(
          plan: _plan(
            routines: [
              _bucket(routineId: 'r-1', order: 1),
              _bucket(routineId: 'r-2', order: 2),
            ],
          ),
          routines: [
            _routine(id: 'r-1', name: 'Push Day', userId: 'user-001'),
            _routine(id: 'r-2', name: 'Pull Day', userId: 'user-001'),
          ],
          workoutCount: 3,
        ),
      );
      await tester.pump();
      await tester.pump();

      // Status line is present with count text.
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final combined = richTexts.map((rt) => rt.text.toPlainText()).join('|');
      expect(combined, contains('of 2 this week'));

      // Action hero shows the suggested next routine (new UP NEXT banner
      // uses just the routine name, not the legacy "Start X" prefix). The
      // routine name also appears in the bucket chip row below, so we
      // assert one-or-more rather than a strict single match.
      expect(find.text('UP NEXT'), findsOneWidget);
      expect(find.text('Push Day'), findsWidgets);
    });

    testWidgets('active plan + week complete: shows "Start new week" hero', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _build(
          plan: _plan(
            routines: [
              _bucket(routineId: 'r-1', order: 1, completedWorkoutId: 'wk-1'),
            ],
          ),
          routines: [_routine(id: 'r-1', name: 'Push Day', userId: 'user-001')],
          workoutCount: 1,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Start new week'), findsOneWidget);
      expect(find.textContaining('Week complete'), findsOneWidget);
    });

    testWidgets(
      'lapsed (no plan + history): shows Plan your week + Quick workout',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        await tester.pumpWidget(
          _build(
            plan: null,
            routines: [_routine(id: 'r-1', name: 'X', userId: 'user-001')],
            workouts: [_workout(finishedAt: yesterday.toIso8601String())],
            workoutCount: 3,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Plan your week'), findsOneWidget);
        expect(find.text('Quick workout'), findsOneWidget);
        expect(find.text('No plan this week'), findsOneWidget);
      },
    );

    testWidgets(
      'brand new (no plan, no history, Full Body default): shows beginner CTA',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _build(
            plan: null,
            routines: [
              _routine(id: 'r-fb', name: 'Full Body', isDefault: true),
            ],
            workoutCount: 0,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('YOUR FIRST WORKOUT'), findsOneWidget);
        expect(find.text('Full Body'), findsOneWidget);
        // No lapsed-state buttons.
        expect(find.text('Plan your week'), findsNothing);
        expect(find.text('Quick workout'), findsNothing);
      },
    );

    testWidgets(
      'no plan + user routines: shows My Routines list (truncated to 3 + See all)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        await tester.pumpWidget(
          _build(
            plan: null,
            routines: [
              _routine(id: 'u-1', name: 'My Push', userId: 'user-001'),
              _routine(id: 'u-2', name: 'My Pull', userId: 'user-001'),
              _routine(id: 'u-3', name: 'My Legs', userId: 'user-001'),
              _routine(id: 'u-4', name: 'My Arms', userId: 'user-001'),
              _routine(id: 'u-5', name: 'My Shoulders', userId: 'user-001'),
            ],
            workouts: [_workout(finishedAt: yesterday.toIso8601String())],
            workoutCount: 1,
          ),
        );
        await tester.pump();
        await tester.pump();

        // Top 3 visible.
        expect(find.text('My Push'), findsOneWidget);
        expect(find.text('My Pull'), findsOneWidget);
        expect(find.text('My Legs'), findsOneWidget);
        // 4th and 5th hidden behind See all.
        expect(find.text('My Arms'), findsNothing);
        expect(find.text('My Shoulders'), findsNothing);
        // See all pill is visible.
        expect(find.text('See all'), findsOneWidget);
      },
    );

    testWidgets('active plan: routines list is hidden', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _build(
          plan: _plan(routines: [_bucket(routineId: 'r-1', order: 1)]),
          routines: [
            _routine(id: 'r-1', name: 'Push', userId: 'user-001'),
            _routine(id: 'u-1', name: 'Private', userId: 'user-001'),
          ],
          workoutCount: 1,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('MY ROUTINES'), findsNothing);
      expect(find.text('See all'), findsNothing);
    });
  });

  group('HomeScreen - removed legacy elements', () {
    testWidgets('does NOT render date header (EEE, MMM d)', (tester) async {
      await tester.pumpWidget(_build(workoutCount: 1));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('MON,'), findsNothing);
      expect(find.textContaining('TUE,'), findsNothing);
      expect(find.textContaining('WED,'), findsNothing);
      expect(find.textContaining('THU,'), findsNothing);
      expect(find.textContaining('FRI,'), findsNothing);
      expect(find.textContaining('SAT,'), findsNothing);
      expect(find.textContaining('SUN,'), findsNothing);
    });

    testWidgets('does NOT render the old stat grid', (tester) async {
      await tester.pumpWidget(_build(workoutCount: 1));
      await tester.pump();
      await tester.pump();

      expect(find.text('Last session'), findsNothing);
      expect(find.text("Week's volume"), findsNothing);
    });

    testWidgets('does NOT render "Start Empty Workout" label', (tester) async {
      await tester.pumpWidget(_build(workoutCount: 1));
      await tester.pump();
      await tester.pump();

      expect(find.text('Start Empty Workout'), findsNothing);
    });

    testWidgets(
      'does NOT render the "Up next" suggested-next card (folded into hero)',
      (tester) async {
        await tester.pumpWidget(
          _build(
            plan: _plan(routines: [_bucket(routineId: 'r-1', order: 1)]),
            routines: [_routine(id: 'r-1', name: 'Push', userId: 'user-001')],
            workoutCount: 1,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Up next'), findsNothing);
      },
    );

    testWidgets(
      'does NOT render THIS WEEK label or counter (absorbed by status line)',
      (tester) async {
        await tester.pumpWidget(
          _build(
            plan: _plan(routines: [_bucket(routineId: 'r-1', order: 1)]),
            routines: [_routine(id: 'r-1', name: 'Push', userId: 'user-001')],
            workoutCount: 1,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('THIS WEEK'), findsNothing);
      },
    );
  });

  group('HomeScreen - confirmation banner', () {
    testWidgets(
      'renders confirmation banner when weeklyPlanNeedsConfirmation is true',
      (tester) async {
        await tester.pumpWidget(
          _build(
            plan: _plan(routines: [_bucket(routineId: 'r-1', order: 1)]),
            routines: [_routine(id: 'r-1', name: 'Push', userId: 'user-001')],
            workoutCount: 1,
            needsConfirmation: true,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Same plan this week?'), findsOneWidget);
      },
    );
  });
}
