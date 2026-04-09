/// Widget tests for WeekBucketSection.
///
/// Covers: header text, completion counter, routine chip rendering,
/// empty state CTA, confirmation banner, and suggested-next card.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/routines/models/routine.dart';
import 'package:gymbuddy_app/features/routines/providers/notifiers/routine_list_notifier.dart';
import 'package:gymbuddy_app/features/weekly_plan/data/models/weekly_plan.dart';
import 'package:gymbuddy_app/features/weekly_plan/providers/weekly_plan_provider.dart';
import 'package:gymbuddy_app/features/weekly_plan/ui/widgets/week_bucket_section.dart';

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
// Helper widget builder (for non-loading scenarios)
// ---------------------------------------------------------------------------

Widget _build({
  WeeklyPlan? plan,
  List<Routine> routines = const [],
  bool needsConfirmation = false,
}) {
  return ProviderScope(
    overrides: [
      weeklyPlanProvider.overrideWith(() => _WeeklyPlanStub(plan)),
      routineListProvider.overrideWith(() => _RoutineListStub(routines)),
      weeklyPlanNeedsConfirmationProvider.overrideWith(
        (ref) => needsConfirmation,
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: const Scaffold(body: WeekBucketSection()),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('WeekBucketSection — empty state', () {
    testWidgets('renders nothing when routines list is empty', (tester) async {
      await tester.pumpWidget(_build(plan: _plan(), routines: const []));
      await tester.pump();
      await tester.pump();

      expect(find.text('THIS WEEK'), findsNothing);
      expect(find.text('Plan your week →'), findsNothing);
    });

    testWidgets(
      'shows "Plan your week" CTA when routines exist but no plan set',
      (tester) async {
        await tester.pumpWidget(
          _build(
            plan: null, // no plan for this week
            routines: [_routine()],
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.textContaining('Plan your week'), findsOneWidget);
      },
    );

    testWidgets('shows THIS WEEK header + Plan CTA when bucket is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(
          plan: _plan(routines: []), // plan exists but empty
          routines: [_routine()],
        ),
      );
      await tester.pump();
      await tester.pump();

      // Empty bucket shows "THIS WEEK" header + bordered "Plan your week" CTA.
      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.textContaining('Plan your week'), findsOneWidget);
    });

    testWidgets('renders nothing when plan is loading', (tester) async {
      final stub = _LoadingWeeklyPlanStub();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weeklyPlanProvider.overrideWith(() => stub),
            routineListProvider.overrideWith(
              () => _RoutineListStub([_routine()]),
            ),
            weeklyPlanNeedsConfirmationProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: WeekBucketSection()),
          ),
        ),
      );
      await tester.pump();

      // Loading state collapses to SizedBox.shrink.
      expect(find.text('THIS WEEK'), findsNothing);

      // Complete to release the pending future so the test can clean up.
      stub.complete();
      await tester.pumpAndSettle();
    });
  });

  group('WeekBucketSection — active week', () {
    testWidgets('shows "THIS WEEK" header', (tester) async {
      await tester.pumpWidget(
        _build(
          plan: _plan(routines: [_bucket(routineId: 'r-001', order: 1)]),
          routines: [_routine(id: 'r-001', name: 'Push Day')],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('THIS WEEK'), findsOneWidget);
    });

    testWidgets('shows edit icon button in section header (BUG-5)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _build(
          plan: _plan(routines: [_bucket(routineId: 'r-001', order: 1)]),
          routines: [_routine(id: 'r-001', name: 'Push Day')],
        ),
      );
      await tester.pump();
      await tester.pump();

      // The edit icon (edit_outlined) must be visible in the THIS WEEK header.
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('shows routine chips for each bucket entry', (tester) async {
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

      // Both routine names must appear somewhere in the chip row and/or card.
      expect(find.textContaining('Push Day'), findsWidgets);
      expect(find.textContaining('Pull Day'), findsOneWidget);
    });

    testWidgets('completion counter shows "0 of 2" when no routines done', (
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
              _bucket(routineId: 'r-001', order: 1),
              _bucket(routineId: 'r-002', order: 2),
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

      // The completion counter is rendered as Text.rich (RichText).
      // Verify the full combined text contains "0" and "of 2".
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final combined = richTexts.map((rt) => rt.text.toPlainText()).join(' ');

      expect(combined, contains('0'));
      expect(combined, contains('of 2'));
    });

    testWidgets('completion counter shows "1 of 2" when one routine is done', (
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
              _bucket(
                routineId: 'r-001',
                order: 1,
                completedWorkoutId: 'wk-done',
              ),
              _bucket(routineId: 'r-002', order: 2),
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

      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final combined = richTexts.map((rt) => rt.text.toPlainText()).join(' ');

      expect(combined, contains('1'));
      expect(combined, contains('of 2'));
    });

    testWidgets(
      'all routines done triggers week-complete transform (no THIS WEEK header)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _build(
            plan: _plan(
              routines: [
                _bucket(
                  routineId: 'r-001',
                  order: 1,
                  completedWorkoutId: 'wk-1',
                ),
                _bucket(
                  routineId: 'r-002',
                  order: 2,
                  completedWorkoutId: 'wk-2',
                ),
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

        // All complete → WeekReviewSection shows instead, section header gone.
        // This verifies the week-complete transform triggers correctly.
        expect(find.text('THIS WEEK'), findsNothing);
      },
    );
  });

  group('WeekBucketSection — suggested-next card', () {
    testWidgets('shows "Up next" card when there is an uncompleted routine', (
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

      // The card should show "Up next" label text.
      expect(find.text('Up next'), findsOneWidget);
    });

    testWidgets('suggested-next card shows the routine name', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _build(
          plan: _plan(routines: [_bucket(routineId: 'r-001', order: 1)]),
          routines: [_routine(id: 'r-001', name: 'Chest & Shoulders')],
        ),
      );
      await tester.pump();
      await tester.pump();

      // Card should display the routine name.
      expect(find.text('Chest & Shoulders'), findsWidgets);
      expect(find.text('Up next'), findsOneWidget);
    });

    testWidgets('suggested-next card has play_arrow icon', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _build(
          plan: _plan(routines: [_bucket(routineId: 'r-001', order: 1)]),
          routines: [_routine(id: 'r-001', name: 'Push Day')],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('suggested-next card is NOT shown when all routines are done', (
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
              _bucket(routineId: 'r-001', order: 1, completedWorkoutId: 'wk-1'),
            ],
          ),
          routines: [_routine(id: 'r-001', name: 'Push Day')],
        ),
      );
      await tester.pump();
      await tester.pump();

      // All routines complete → week review mode, no "Up next".
      expect(find.text('Up next'), findsNothing);
    });

    testWidgets('suggested-next card shows second routine when first is done', (
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
              _bucket(
                routineId: 'r-001',
                order: 1,
                completedWorkoutId: 'wk-done',
              ),
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

      // "Up next" should show Pull Day (second routine).
      expect(find.text('Up next'), findsOneWidget);
      // Pull Day should appear in both the card subtitle and in the chip row.
      expect(find.textContaining('Pull Day'), findsWidgets);
    });

    testWidgets('suggested-next card is tappable (InkWell wraps it)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _build(
          plan: _plan(routines: [_bucket(routineId: 'r-001', order: 1)]),
          routines: [_routine(id: 'r-001', name: 'Push Day')],
        ),
      );
      await tester.pump();
      await tester.pump();

      // Verify the card is tappable by finding an InkWell ancestor of "Up next".
      final upNextText = find.text('Up next');
      expect(upNextText, findsOneWidget);

      // Tapping the card should not throw (the actual navigation is handled
      // by GoRouter which is not available in this test context, so we just
      // verify no exception is thrown).
      final inkWells = find.ancestor(
        of: upNextText,
        matching: find.byType(InkWell),
      );
      expect(
        inkWells,
        findsWidgets,
        reason: 'The "Up next" card should be wrapped in an InkWell',
      );
    });

    testWidgets(
      'suggested-next card shows "Next workout" fallback when routine id is unknown',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // The bucket references 'r-unknown' but the routines list has no entry
        // for that id. The card should fall back to 'Next workout'.
        await tester.pumpWidget(
          _build(
            plan: _plan(routines: [_bucket(routineId: 'r-unknown', order: 1)]),
            // Provide a different routine id so nameMap misses 'r-unknown'.
            routines: [_routine(id: 'r-other', name: 'Pull Day')],
          ),
        );
        await tester.pump();
        await tester.pump();

        // "Up next" label should appear.
        expect(find.text('Up next'), findsOneWidget);
        // Routine name falls back to the default.
        expect(find.text('Next workout'), findsOneWidget);
      },
    );
  });

  group('WeekBucketSection — confirmation banner', () {
    testWidgets('shows confirmation banner when needsConfirmation is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(
          plan: _plan(routines: [_bucket(routineId: 'r-001', order: 1)]),
          routines: [_routine(id: 'r-001')],
          needsConfirmation: true,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Same plan this week?'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets(
      'does NOT show confirmation banner when needsConfirmation is false',
      (tester) async {
        await tester.pumpWidget(
          _build(
            plan: _plan(routines: [_bucket(routineId: 'r-001', order: 1)]),
            routines: [_routine(id: 'r-001')],
            needsConfirmation: false,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Same plan this week?'), findsNothing);
      },
    );

    testWidgets('tapping Confirm dismisses the banner', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weeklyPlanProvider.overrideWith(
              () => _WeeklyPlanStub(
                _plan(routines: [_bucket(routineId: 'r-001', order: 1)]),
              ),
            ),
            routineListProvider.overrideWith(
              () => _RoutineListStub([_routine(id: 'r-001')]),
            ),
            // Use a real StateProvider so the Confirm button can mutate it.
            weeklyPlanNeedsConfirmationProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: WeekBucketSection()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Same plan this week?'), findsOneWidget);

      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Same plan this week?'), findsNothing);
    });
  });
}
