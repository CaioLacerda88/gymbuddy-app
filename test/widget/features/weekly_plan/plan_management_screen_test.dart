/// Widget tests for PlanManagementScreen.
///
/// Covers:
/// - Soft-cap inline text with X/Y counter (Change 2)
/// - Auto-fill button in empty state (Change 1)
/// - "routines planned" counter when below soft cap (Change 2)
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
  Future<void> upsertPlan(List<BucketRoutine> routines) async {}

  @override
  Future<void> clearPlan() async {}

  @override
  // ignore: must_call_super
  dynamic noSuchMethod(Invocation invocation) {}
}

class _RoutineListStub extends AsyncNotifier<List<Routine>>
    implements RoutineListNotifier {
  _RoutineListStub(this.routines);
  final List<Routine> routines;

  @override
  Future<List<Routine>> build() async => routines;

  @override
  // ignore: must_call_super
  dynamic noSuchMethod(Invocation invocation) {}
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
  // ignore: must_call_super
  dynamic noSuchMethod(Invocation invocation) {}
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
      // Wrap in Consumer to eagerly initialise workoutHistoryProvider so
      // the auto-fill loading guard doesn't block on first access.
      home: Consumer(
        builder: (context, ref, _) {
          ref.watch(workoutHistoryProvider);
          return const PlanManagementScreen();
        },
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PlanManagementScreen soft-cap inline text', () {
    testWidgets(
      'shows "X/Y goal reached" text when bucket count >= training frequency',
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
        await tester.pumpAndSettle();

        expect(
          find.textContaining('2/2 goal reached'),
          findsOneWidget,
          reason: 'Soft-cap hint should show "2/2 goal reached" at cap',
        );
      },
    );

    testWidgets(
      'shows "X/Y routines planned" when bucket count < training frequency',
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
          find.textContaining('goal reached'),
          findsNothing,
          reason: 'Soft-cap hint should NOT appear when bucket < frequency',
        );
        expect(
          find.textContaining('1/3 routines planned'),
          findsOneWidget,
          reason: 'Counter should show "1/3 routines planned" below cap',
        );
      },
    );

    testWidgets(
      'shows "X/Y goal reached" text when bucket count exceeds frequency',
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
          find.textContaining('3/2 goal reached'),
          findsOneWidget,
          reason: 'Soft-cap hint should show "3/2 goal reached" when over',
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
      expect(find.textContaining('goal reached'), findsOneWidget);
    });
  });

  group('PlanManagementScreen empty state', () {
    testWidgets('shows Auto-fill button in empty state', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // No plan => empty state.
      final routines = [_routine(id: 'r-001', name: 'Push Day')];

      await tester.pumpWidget(
        _build(plan: null, routines: routines, trainingFrequency: 3),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Auto-fill'),
        findsOneWidget,
        reason: 'Empty state should show the auto-fill button',
      );
      expect(find.byIcon(Icons.repeat), findsOneWidget);
    });

    testWidgets(
      'shows both Add Routines and Auto-fill buttons in empty state',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final routines = [_routine(id: 'r-001', name: 'Push Day')];

        await tester.pumpWidget(
          _build(plan: null, routines: routines, trainingFrequency: 3),
        );
        await tester.pumpAndSettle();

        expect(find.text('Add Routines'), findsOneWidget);
        expect(find.text('Auto-fill'), findsOneWidget);
      },
    );

    testWidgets('Auto-fill button is an OutlinedButton', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final routines = [_routine(id: 'r-001', name: 'Push Day')];

      await tester.pumpWidget(
        _build(plan: null, routines: routines, trainingFrequency: 3),
      );
      await tester.pumpAndSettle();

      // The auto-fill button should be an OutlinedButton (not FilledButton).
      final outlinedButtons = find.byType(OutlinedButton);
      expect(outlinedButtons, findsOneWidget);
    });

    testWidgets('tapping Auto-fill button triggers the auto-fill action', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final routines = [_routine(id: 'r-001', name: 'Push Day')];

      await tester.pumpWidget(
        _build(plan: null, routines: routines, trainingFrequency: 3),
      );
      await tester.pumpAndSettle();

      // Tapping should not throw; the auto-fill method handles the logic.
      await tester.tap(find.text('Auto-fill'));
      await tester.pumpAndSettle();

      // After auto-fill with 1 routine and freq=3, we expect 1 routine in the
      // bucket — the empty state should be gone and the routine should appear.
      expect(find.text('Push Day'), findsOneWidget);
      expect(find.text('No routines planned this week'), findsNothing);
    });
  });

  group('PlanManagementScreen edge cases', () {
    testWidgets(
      'trainingFrequency=0 shows "0/0 goal reached" without crashing',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Profile with trainingFrequencyPerWeek = 0 is a degenerate edge case.
        // The _AddRoutineRow counter must not crash (no division by zero).
        final routines = [_routine(id: 'r-001', name: 'Push Day')];
        final plan = _plan(routines: [_bucket(routineId: 'r-001', order: 1)]);

        await tester.pumpWidget(
          _build(plan: plan, routines: routines, trainingFrequency: 0),
        );
        await tester.pumpAndSettle();

        // With frequency=0 and 1 routine in bucket, atSoftCap is true (1 >= 0).
        // Counter shows "1/0 goal reached" — no crash.
        expect(
          find.textContaining('goal reached'),
          findsOneWidget,
          reason:
              'With frequency=0, atSoftCap is always true; no crash expected',
        );
      },
    );

    testWidgets(
      'auto-fill with trainingFrequency=0 produces empty plan without crashing',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // With frequency=0, _autoFill takes 0 routines => empty plan.
        final routines = [_routine(id: 'r-001', name: 'Push Day')];

        await tester.pumpWidget(
          _build(plan: null, routines: routines, trainingFrequency: 0),
        );
        await tester.pumpAndSettle();

        // Tap Auto-fill — should not throw even though count=0.
        await tester.tap(find.text('Auto-fill'));
        await tester.pumpAndSettle();

        // Empty plan result: empty state stays since no routines were added.
        // Auto-fill with freq=0 selects 0 routines, leaving the bucket empty.
        expect(find.text('No routines planned this week'), findsOneWidget);
      },
    );
  });
}
