/// Widget tests for [WeekBucketSection] after the W8 Home refresh.
///
/// The widget is now chip-row-only — the `THIS WEEK` label, progress
/// counter, edit icon, "Up next" card, beginner CTA, empty state, and
/// confirmation banner all moved to sibling widgets on the Home screen
/// (`HomeStatusLine`, `ActionHero`, `_ConfirmBanner`, `_WeekReviewCard`).
///
/// Covers:
///  - Renders the chip row when an active plan has routines
///  - Hides when plan is null, plan is empty, or routines list is empty
///  - Hides on week-complete (HomeScreen owns the review card)
///  - Hides during initial load or on error with no cached data
///  - Retains stale content during provider reload (no flicker)
library;

// ignore_for_file: invalid_use_of_internal_member — copyWithPrevious is @internal in Riverpod 3; needed to simulate reload state in tests
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/routines/models/routine.dart';
import 'package:gymbuddy_app/features/routines/providers/notifiers/routine_list_notifier.dart';
import 'package:gymbuddy_app/features/weekly_plan/data/models/weekly_plan.dart';
import 'package:gymbuddy_app/features/weekly_plan/providers/weekly_plan_provider.dart';
import 'package:gymbuddy_app/features/weekly_plan/ui/widgets/routine_chip.dart';
import 'package:gymbuddy_app/features/weekly_plan/ui/widgets/week_bucket_section.dart';
import '../../../helpers/test_material_app.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

/// Stub that returns a fixed [WeeklyPlan?] synchronously.
class _WeeklyPlanStub extends AsyncNotifier<WeeklyPlan?>
    implements WeeklyPlanNotifier {
  _WeeklyPlanStub(this.plan);
  final WeeklyPlan? plan;

  @override
  Future<WeeklyPlan?> build() async => plan;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stub that stays in loading state until [complete] is called.
class _LoadingWeeklyPlanStub extends AsyncNotifier<WeeklyPlan?>
    implements WeeklyPlanNotifier {
  final _completer = Completer<WeeklyPlan?>();

  @override
  Future<WeeklyPlan?> build() => _completer.future;

  void complete() {
    if (!_completer.isCompleted) _completer.complete(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stub that resolves with data first, then can be transitioned to a
/// loading-with-previous-data state to simulate provider reload.
class _ReloadableWeeklyPlanStub extends AsyncNotifier<WeeklyPlan?>
    implements WeeklyPlanNotifier {
  _ReloadableWeeklyPlanStub(this._plan);
  final WeeklyPlan? _plan;

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

/// Stub that provides a fixed list of [Routine]s synchronously.
class _RoutineListStub extends AsyncNotifier<List<Routine>>
    implements RoutineListNotifier {
  _RoutineListStub(this.routines);
  final List<Routine> routines;

  @override
  Future<List<Routine>> build() async => routines;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

BucketRoutine _bucket({
  String routineId = 'r-001',
  int order = 1,
  String? completedWorkoutId,
}) {
  return BucketRoutine(
    routineId: routineId,
    order: order,
    completedWorkoutId: completedWorkoutId,
  );
}

WeeklyPlan _plan({List<BucketRoutine> routines = const []}) {
  return WeeklyPlan(
    id: 'plan-001',
    userId: 'user-001',
    weekStart: DateTime(2026, 4, 7),
    routines: routines,
    createdAt: DateTime(2026, 4, 7),
    updatedAt: DateTime(2026, 4, 7),
  );
}

// ---------------------------------------------------------------------------
// Helper widget builder
// ---------------------------------------------------------------------------

Widget _build({WeeklyPlan? plan, List<Routine> routines = const []}) {
  return ProviderScope(
    overrides: [
      weeklyPlanProvider.overrideWith(() => _WeeklyPlanStub(plan)),
      routineListProvider.overrideWith(() => _RoutineListStub(routines)),
    ],
    child: TestMaterialApp(
      theme: AppTheme.dark,
      home: const Scaffold(body: WeekBucketSection()),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('WeekBucketSection — hidden states', () {
    testWidgets('renders nothing when routines list is empty', (tester) async {
      await tester.pumpWidget(
        _build(
          plan: _plan(routines: [_bucket(routineId: 'r-001')]),
          routines: const [],
        ),
      );
      await tester.pump();
      await tester.pump();

      // No chips, no THIS WEEK label, no counter — fully collapsed.
      expect(find.byType(RoutineChip), findsNothing);
      expect(find.text('THIS WEEK'), findsNothing);
    });

    testWidgets('renders nothing when plan is null', (tester) async {
      await tester.pumpWidget(_build(plan: null, routines: [_routine()]));
      await tester.pump();
      await tester.pump();

      expect(find.byType(RoutineChip), findsNothing);
    });

    testWidgets('renders nothing when plan has no bucket routines', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(
          plan: _plan(routines: const []),
          routines: [_routine()],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(RoutineChip), findsNothing);
    });

    testWidgets('renders nothing when plan is loading with no cached data', (
      tester,
    ) async {
      final stub = _LoadingWeeklyPlanStub();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weeklyPlanProvider.overrideWith(() => stub),
            routineListProvider.overrideWith(
              () => _RoutineListStub([_routine()]),
            ),
          ],
          child: TestMaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: WeekBucketSection()),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(RoutineChip), findsNothing);

      // Complete to release the pending future so the test can clean up.
      stub.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('renders nothing in week-complete state', (tester) async {
      // All routines complete → HomeScreen's _WeekReviewCard owns the review;
      // WeekBucketSection collapses to SizedBox.shrink().
      await tester.pumpWidget(
        _build(
          plan: _plan(
            routines: [
              _bucket(routineId: 'r-001', order: 1, completedWorkoutId: 'wk-1'),
              _bucket(routineId: 'r-002', order: 2, completedWorkoutId: 'wk-2'),
            ],
          ),
          routines: [
            _routine(id: 'r-001'),
            _routine(id: 'r-002'),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(RoutineChip), findsNothing);
    });
  });

  group('WeekBucketSection — active chip row', () {
    testWidgets('renders one RoutineChip per bucket entry', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _build(
          plan: _plan(
            routines: [
              _bucket(routineId: 'r-001', order: 1),
              _bucket(routineId: 'r-002', order: 2),
              _bucket(routineId: 'r-003', order: 3),
            ],
          ),
          routines: [
            _routine(id: 'r-001', name: 'Push Day'),
            _routine(id: 'r-002', name: 'Pull Day'),
            _routine(id: 'r-003', name: 'Leg Day'),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(RoutineChip), findsNWidgets(3));
    });

    testWidgets('chip row shows routine names', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _build(
          plan: _plan(
            routines: [
              _bucket(routineId: 'r-001', order: 1),
              _bucket(routineId: 'r-002', order: 2),
            ],
          ),
          routines: [
            _routine(id: 'r-001', name: 'Push Day'),
            _routine(id: 'r-002', name: 'Pull Day'),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Push Day'), findsWidgets);
      expect(find.textContaining('Pull Day'), findsWidgets);
    });

    testWidgets('chip row ordering matches bucket order', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Bucket entries are intentionally out of insertion order — the widget
      // must sort them ascending by `order` before building chips.
      await tester.pumpWidget(
        _build(
          plan: _plan(
            routines: [
              _bucket(routineId: 'r-002', order: 2),
              _bucket(routineId: 'r-001', order: 1),
            ],
          ),
          routines: [
            _routine(id: 'r-001', name: 'Push Day'),
            _routine(id: 'r-002', name: 'Pull Day'),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      final chips = tester
          .widgetList<RoutineChip>(find.byType(RoutineChip))
          .toList();
      expect(chips.length, 2);
      expect(chips.first.sequenceNumber, 1);
      expect(chips.last.sequenceNumber, 2);
    });

    testWidgets(
      'does not render removed UI (THIS WEEK header, counter, Up next card)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _build(
            plan: _plan(
              routines: [
                _bucket(routineId: 'r-001', order: 1),
                _bucket(routineId: 'r-002', order: 2),
              ],
            ),
            routines: [
              _routine(id: 'r-001', name: 'Push Day'),
              _routine(id: 'r-002', name: 'Pull Day'),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        // These moved out of WeekBucketSection in W8.
        expect(find.text('THIS WEEK'), findsNothing);
        expect(find.text('Up next'), findsNothing);
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        // Confirm banner moved to HomeScreen.
        expect(find.text('Same plan this week?'), findsNothing);
      },
    );
  });

  group('WeekBucketSection — reload stale data', () {
    testWidgets('retains chip row during provider reload', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final stub = _ReloadableWeeklyPlanStub(
        _plan(routines: [_bucket(routineId: 'r-001', order: 1)]),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weeklyPlanProvider.overrideWith(() => stub),
            routineListProvider.overrideWith(
              () => _RoutineListStub([_routine(id: 'r-001', name: 'Push Day')]),
            ),
          ],
          child: TestMaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: WeekBucketSection()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(RoutineChip), findsOneWidget);

      // Simulate provider reload (e.g., returning to home screen).
      stub.simulateReload();
      await tester.pump();

      // Chip row should still be visible — stale data shown during reload.
      expect(find.byType(RoutineChip), findsOneWidget);
    });
  });
}
