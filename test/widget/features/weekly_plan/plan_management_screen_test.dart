/// Widget tests for PlanManagementScreen — BUG-7 soft-cap inline text.
///
/// Verifies that "Goal reached -- add anyway" text appears when the number
/// of bucket routines meets or exceeds the training frequency (atSoftCap),
/// and is absent when below the soft cap.
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
import 'package:gymbuddy_app/features/weekly_plan/ui/plan_management_screen.dart';
import 'package:gymbuddy_app/features/workouts/models/workout.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_history_providers.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _WeeklyPlanStub extends AsyncNotifier<WeeklyPlan?>
    implements WeeklyPlanNotifier {
  _WeeklyPlanStub(this.plan);
  final WeeklyPlan? plan;

  @override
  Future<WeeklyPlan?> build() async => plan;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RoutineListStub extends AsyncNotifier<List<Routine>>
    implements RoutineListNotifier {
  _RoutineListStub(this.routines);
  final List<Routine> routines;

  @override
  Future<List<Routine>> build() async => routines;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileStub extends AsyncNotifier<Profile?> implements ProfileNotifier {
  _ProfileStub(this.frequency);
  final int frequency;

  @override
  Future<Profile?> build() async => Profile(
    id: 'user-001',
    displayName: 'Test',
    weightUnit: 'kg',
    trainingFrequencyPerWeek: frequency,
  );

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

// ---------------------------------------------------------------------------
// Factories
// ---------------------------------------------------------------------------

Routine _routine({String id = 'r-001', String name = 'Push Day'}) {
  return Routine(
    id: id,
    name: name,
    isDefault: false,
    exercises: const [],
    createdAt: DateTime(2026),
  );
}

BucketRoutine _bucket({required String routineId, required int order}) {
  return BucketRoutine(routineId: routineId, order: order);
}

WeeklyPlan _plan({List<BucketRoutine> routines = const []}) {
  return WeeklyPlan(
    id: 'plan-001',
    userId: 'user-001',
    weekStart: DateTime(2026, 4, 6),
    routines: routines,
    createdAt: DateTime(2026, 4, 6),
    updatedAt: DateTime(2026, 4, 6),
  );
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _build({
  required WeeklyPlan? plan,
  required List<Routine> routines,
  int trainingFrequency = 3,
}) {
  return ProviderScope(
    overrides: [
      weeklyPlanProvider.overrideWith(() => _WeeklyPlanStub(plan)),
      routineListProvider.overrideWith(() => _RoutineListStub(routines)),
      profileProvider.overrideWith(() => _ProfileStub(trainingFrequency)),
      workoutHistoryProvider.overrideWith(() => _EmptyHistoryNotifier()),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: const PlanManagementScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('BUG-7: PlanManagementScreen soft-cap inline text', () {
    testWidgets(
      'shows "Goal reached" text when bucket count >= training frequency',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Training frequency = 2, bucket has 2 routines => at soft cap.
        final routines = [
          _routine(id: 'r-001', name: 'Push Day'),
          _routine(id: 'r-002', name: 'Pull Day'),
        ];
        final plan = _plan(
          routines: [
            _bucket(routineId: 'r-001', order: 1),
            _bucket(routineId: 'r-002', order: 2),
          ],
        );

        await tester.pumpWidget(
          _build(plan: plan, routines: routines, trainingFrequency: 2),
        );
        // Allow the plan provider to resolve and seed the stateful widget.
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Goal reached'),
          findsOneWidget,
          reason: 'Soft-cap hint should appear when bucket >= frequency',
        );
      },
    );

    testWidgets(
      'does NOT show "Goal reached" text when bucket count < training frequency',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Training frequency = 3, bucket has 1 routine => below soft cap.
        final routines = [
          _routine(id: 'r-001', name: 'Push Day'),
          _routine(id: 'r-002', name: 'Pull Day'),
        ];
        final plan = _plan(routines: [_bucket(routineId: 'r-001', order: 1)]);

        await tester.pumpWidget(
          _build(plan: plan, routines: routines, trainingFrequency: 3),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Goal reached'),
          findsNothing,
          reason: 'Soft-cap hint should NOT appear when bucket < frequency',
        );
      },
    );

    testWidgets(
      'shows "Goal reached" text when bucket count exceeds frequency',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Training frequency = 2, bucket has 3 routines => exceeds soft cap.
        final routines = [
          _routine(id: 'r-001', name: 'Push Day'),
          _routine(id: 'r-002', name: 'Pull Day'),
          _routine(id: 'r-003', name: 'Leg Day'),
        ];
        final plan = _plan(
          routines: [
            _bucket(routineId: 'r-001', order: 1),
            _bucket(routineId: 'r-002', order: 2),
            _bucket(routineId: 'r-003', order: 3),
          ],
        );

        await tester.pumpWidget(
          _build(plan: plan, routines: routines, trainingFrequency: 2),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Goal reached'),
          findsOneWidget,
          reason: 'Soft-cap hint should appear when bucket > frequency',
        );
      },
    );

    testWidgets('"Add Routine" button is present alongside soft-cap text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final routines = [
        _routine(id: 'r-001', name: 'Push Day'),
        _routine(id: 'r-002', name: 'Pull Day'),
      ];
      final plan = _plan(
        routines: [
          _bucket(routineId: 'r-001', order: 1),
          _bucket(routineId: 'r-002', order: 2),
        ],
      );

      await tester.pumpWidget(
        _build(plan: plan, routines: routines, trainingFrequency: 2),
      );
      await tester.pumpAndSettle();

      // Both "Add Routine" and soft-cap text should be present.
      expect(find.text('Add Routine'), findsOneWidget);
      expect(find.textContaining('Goal reached'), findsOneWidget);
    });
  });
}
