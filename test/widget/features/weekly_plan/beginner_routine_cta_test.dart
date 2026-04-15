/// Widget tests for the first-run beginner routine CTA (`_BeginnerCta`) which
/// now lives inside [ActionHero] (see `lib/features/workouts/ui/widgets/
/// action_hero.dart`). After the W8 Home refresh, Home composes its blocks
/// from ActionHero (owns the beginner CTA), HomeStatusLine, LastSessionLine,
/// etc. — WeekBucketSection is chip-row-only.
///
/// Since `_BeginnerCta` is private, tests drive it through the public
/// [ActionHero] widget with provider overrides:
/// - `weeklyPlanProvider` returns null (no active plan)
/// - `workoutCountProvider` returns 0 (brand-new user)
/// - `routineListProvider` holds at least one default routine
///
/// Covers:
///  - Renders the YOUR FIRST WORKOUT label, routine name, and stats line
///  - Renders a play_arrow icon
///  - Whole card is tappable (InkWell wraps the content)
///  - Does NOT render when the user has finished at least one workout (then
///    ActionHero renders the lapsed "Plan your week" CTA instead)
///  - Does NOT render when no default routines exist
///  - Prefers "Full Body" over other defaults; falls back to first default
///    alphabetically when Full Body is missing
///  - Long routine names do not overflow (ellipsis)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/routines/models/routine.dart';
import 'package:gymbuddy_app/features/routines/providers/notifiers/routine_list_notifier.dart';
import 'package:gymbuddy_app/features/weekly_plan/data/models/weekly_plan.dart';
import 'package:gymbuddy_app/features/weekly_plan/providers/weekly_plan_provider.dart';
import 'package:gymbuddy_app/features/workouts/models/active_workout_state.dart';
import 'package:gymbuddy_app/features/workouts/providers/notifiers/active_workout_notifier.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_history_providers.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_providers.dart';
import 'package:gymbuddy_app/features/workouts/ui/widgets/action_hero.dart';

// ---------------------------------------------------------------------------
// Notifier stubs
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

class _NullActiveWorkoutNotifier extends AsyncNotifier<ActiveWorkoutState?>
    implements ActiveWorkoutNotifier {
  @override
  Future<ActiveWorkoutState?> build() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Factories
// ---------------------------------------------------------------------------

/// Builds a default routine with realistic set_configs.
///
/// Each exercise gets 3 sets at the given rest (default 120s) so the duration
/// estimator renders a meaningful "~N min" instead of collapsing to the
/// fallback branch.
Routine _defaultRoutine({
  required String id,
  required String name,
  int exerciseCount = 6,
  int restSeconds = 120,
  int setsPerExercise = 3,
}) {
  return Routine(
    id: id,
    name: name,
    isDefault: true,
    exercises: List.generate(
      exerciseCount,
      (i) => RoutineExercise(
        exerciseId: 'ex-$id-$i',
        setConfigs: List.generate(
          setsPerExercise,
          (_) => RoutineSetConfig(targetReps: 5, restSeconds: restSeconds),
        ),
      ),
    ),
    createdAt: DateTime(2026),
  );
}

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _build({
  required List<Routine> routines,
  int workoutCount = 0,
  WeeklyPlan? plan,
}) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: ActionHero()),
      ),
      GoRoute(
        path: '/plan/week',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Plan week'))),
      ),
      GoRoute(
        path: '/workout/active',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Active workout'))),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      weeklyPlanProvider.overrideWith(() => _WeeklyPlanStub(plan)),
      routineListProvider.overrideWith(() => _RoutineListStub(routines)),
      weeklyPlanNeedsConfirmationProvider.overrideWith((ref) => false),
      workoutCountProvider.overrideWith((ref) => Future.value(workoutCount)),
      activeWorkoutProvider.overrideWith(() => _NullActiveWorkoutNotifier()),
    ],
    child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('BeginnerRoutineCta — visibility', () {
    testWidgets('renders YOUR FIRST WORKOUT label when conditions match', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(
          routines: [_defaultRoutine(id: 'r-full-body', name: 'Full Body')],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('YOUR FIRST WORKOUT'), findsOneWidget);
    });

    testWidgets('renders routine name as headline', (tester) async {
      await tester.pumpWidget(
        _build(
          routines: [_defaultRoutine(id: 'r-full-body', name: 'Full Body')],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Full Body'), findsOneWidget);
    });

    testWidgets('renders stats line with exercise count and duration', (
      tester,
    ) async {
      // 6 exercises × 3 sets × (120s rest + 30s work) = 2700s = 45 min.
      await tester.pumpWidget(
        _build(
          routines: [
            _defaultRoutine(
              id: 'r-full-body',
              name: 'Full Body',
              exerciseCount: 6,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('6 exercises'), findsOneWidget);
      expect(find.textContaining('~45 min'), findsOneWidget);
    });

    testWidgets('renders a play_arrow icon', (tester) async {
      await tester.pumpWidget(
        _build(
          routines: [_defaultRoutine(id: 'r-full-body', name: 'Full Body')],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('does NOT render when workoutCount > 0', (tester) async {
      await tester.pumpWidget(
        _build(
          routines: [_defaultRoutine(id: 'r-full-body', name: 'Full Body')],
          workoutCount: 1,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('YOUR FIRST WORKOUT'), findsNothing);
      // ActionHero switches to the lapsed state: "Plan your week" primary
      // button + "Quick workout" secondary button.
      expect(find.text('Plan your week'), findsOneWidget);
    });

    testWidgets('does NOT render when no default routines exist', (
      tester,
    ) async {
      // Only a user-created routine, no defaults to recommend.
      final userRoutine = Routine(
        id: 'r-user',
        userId: 'user-001',
        name: 'My Custom',
        isDefault: false,
        exercises: const [],
        createdAt: DateTime(2026),
      );
      await tester.pumpWidget(_build(routines: [userRoutine]));
      await tester.pump();
      await tester.pump();

      // CTA not shown.
      expect(find.text('YOUR FIRST WORKOUT'), findsNothing);
      // Lapsed CTA also not shown — workoutCount is 0 so ActionHero takes
      // the brand-new branch, but `_pickBeginnerRoutine` returns null, so the
      // widget collapses to SizedBox.shrink().
      expect(find.text('Plan your week'), findsNothing);
    });

    testWidgets('does NOT render when routines list is entirely empty', (
      tester,
    ) async {
      await tester.pumpWidget(_build(routines: const []));
      await tester.pump();
      await tester.pump();

      expect(find.text('YOUR FIRST WORKOUT'), findsNothing);
    });
  });

  group('BeginnerRoutineCta — routine selection', () {
    testWidgets(
      'prefers the "Full Body" default when multiple defaults exist',
      (tester) async {
        await tester.pumpWidget(
          _build(
            routines: [
              _defaultRoutine(id: 'r-push', name: 'Push Day'),
              _defaultRoutine(id: 'r-pull', name: 'Pull Day'),
              _defaultRoutine(id: 'r-legs', name: 'Leg Day'),
              _defaultRoutine(id: 'r-full', name: 'Full Body'),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        // Headline must be Full Body, not Push/Pull/Leg Day.
        expect(find.text('Full Body'), findsOneWidget);
        expect(find.text('Push Day'), findsNothing);
      },
    );

    testWidgets(
      'falls back to first default (alphabetical) when Full Body is missing',
      (tester) async {
        await tester.pumpWidget(
          _build(
            routines: [
              _defaultRoutine(id: 'r-push', name: 'Push Day'),
              _defaultRoutine(id: 'r-pull', name: 'Pull Day'),
              _defaultRoutine(id: 'r-legs', name: 'Leg Day'),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        // Alphabetical fallback: Leg Day < Pull Day < Push Day.
        expect(find.text('Leg Day'), findsOneWidget);
      },
    );

    testWidgets('ignores user-created routines when picking the default', (
      tester,
    ) async {
      final userRoutine = Routine(
        id: 'r-user',
        userId: 'user-001',
        name: 'AAA Custom',
        isDefault: false,
        exercises: const [],
        createdAt: DateTime(2026),
      );
      await tester.pumpWidget(
        _build(
          routines: [
            userRoutine,
            _defaultRoutine(id: 'r-full', name: 'Full Body'),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      // Even though "AAA Custom" sorts first, the user routine must be ignored
      // and Full Body selected.
      expect(find.text('Full Body'), findsOneWidget);
      expect(find.text('AAA Custom'), findsNothing);
    });
  });

  group('BeginnerRoutineCta — interaction', () {
    testWidgets('entire card is wrapped in an InkWell (tap target)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(
          routines: [_defaultRoutine(id: 'r-full', name: 'Full Body')],
        ),
      );
      await tester.pump();
      await tester.pump();

      final label = find.text('YOUR FIRST WORKOUT');
      expect(label, findsOneWidget);
      final inkWell = find.ancestor(of: label, matching: find.byType(InkWell));
      expect(
        inkWell,
        findsWidgets,
        reason: 'YOUR FIRST WORKOUT label should sit inside an InkWell',
      );
    });

    testWidgets('tap does not throw during build or layout', (tester) async {
      await tester.pumpWidget(
        _build(
          routines: [_defaultRoutine(id: 'r-full', name: 'Full Body')],
        ),
      );
      await tester.pump();
      await tester.pump();

      // The card must be laid out and visible so tapping is safe.
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('BeginnerRoutineCta — layout', () {
    testWidgets('long routine names do not cause overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _build(
          routines: [
            _defaultRoutine(
              id: 'r-long',
              name:
                  'Full Body Foundations For The Very Committed Beginner Program',
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      // No RenderFlex overflow during layout.
      expect(tester.takeException(), isNull);
    });
  });
}
