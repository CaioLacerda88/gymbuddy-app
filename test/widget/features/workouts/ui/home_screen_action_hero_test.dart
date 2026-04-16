/// Widget tests for the home Action Hero banner CTA.
///
/// Covers the four state modes per PLAN W8:
///   1. Active plan + incomplete week -> "Start {suggestedNext routineName}"
///   2. Brand new (no plan, no history) -> beginner CTA (Full Body)
///   3. Lapsed (no plan, has history) -> "Plan your week" primary + "Quick
///      workout" secondary TextButton below
///   4. Week complete -> "Start new week" (navigates to /plan/week)
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
import 'package:gymbuddy_app/features/workouts/models/workout.dart';
import 'package:gymbuddy_app/features/workouts/providers/notifiers/active_workout_notifier.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_history_providers.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_providers.dart';
import 'package:gymbuddy_app/features/workouts/ui/widgets/action_hero.dart';

import '../../../../fixtures/test_factories.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _PlanStub extends AsyncNotifier<WeeklyPlan?>
    implements WeeklyPlanNotifier {
  _PlanStub(this.plan);
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

Workout _workout() => Workout.fromJson(
  TestWorkoutFactory.create(finishedAt: '2026-04-10T10:00:00Z'),
);

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Widget _buildWithRouter({
  WeeklyPlan? plan,
  List<Routine> routines = const [],
  List<Workout> workouts = const [],
  int workoutCount = 0,
  void Function(String)? onPushed,
}) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (ctx, _) => const Scaffold(body: ActionHero()),
      ),
      GoRoute(
        path: '/plan/week',
        builder: (ctx, _) =>
            const Scaffold(body: Center(child: Text('Plan Week Screen'))),
      ),
      GoRoute(
        path: '/workout/active',
        builder: (ctx, _) =>
            const Scaffold(body: Center(child: Text('Active Workout Screen'))),
      ),
    ],
    observers: [
      _RouterObserver((loc) {
        onPushed?.call(loc);
      }),
    ],
  );

  return ProviderScope(
    overrides: [
      weeklyPlanProvider.overrideWith(() => _PlanStub(plan)),
      routineListProvider.overrideWith(() => _RoutineListStub(routines)),
      workoutHistoryProvider.overrideWith(() => _HistoryStub(workouts)),
      workoutCountProvider.overrideWith((ref) => Future.value(workoutCount)),
      activeWorkoutProvider.overrideWith(() => _NullActiveWorkoutNotifier()),
    ],
    child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
  );
}

class _RouterObserver extends NavigatorObserver {
  _RouterObserver(this.onPushed);
  final void Function(String location) onPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final name = route.settings.name;
    if (name != null) onPushed(name);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ActionHero - active plan, incomplete', () {
    testWidgets('renders banner with UP NEXT label and routine name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWithRouter(
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
          workoutCount: 5,
        ),
      );
      await tester.pump();
      await tester.pump();

      // New banner pattern (matches _BeginnerCta vocabulary): UP NEXT label
      // above the routine name; no stock "Start X" button text.
      expect(find.text('UP NEXT'), findsOneWidget);
      expect(find.text('Push Day'), findsOneWidget);
      expect(find.text('Start Push Day'), findsNothing);
    });

    testWidgets('renders metadata line with exercise count and duration', (
      tester,
    ) async {
      // 6 exercises x 3 sets at 120s rest each — matches the duration
      // estimator's 45-min output (mirrors the beginner CTA test pattern).
      final routine = Routine(
        id: 'r-1',
        name: 'Push Day',
        userId: 'user-001',
        isDefault: false,
        exercises: List.generate(
          6,
          (i) => RoutineExercise(
            exerciseId: 'ex-$i',
            setConfigs: List.generate(
              3,
              (_) => const RoutineSetConfig(targetReps: 5, restSeconds: 120),
            ),
          ),
        ),
        createdAt: DateTime(2026),
      );

      await tester.pumpWidget(
        _buildWithRouter(
          plan: _plan(routines: [_bucket(routineId: 'r-1', order: 1)]),
          routines: [routine],
          workoutCount: 5,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('6 exercises'), findsOneWidget);
      expect(find.textContaining('~45 min'), findsOneWidget);
    });

    testWidgets('renders play_arrow as a glyph (not a Button component)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWithRouter(
          plan: _plan(routines: [_bucket(routineId: 'r-1', order: 1)]),
          routines: [_routine(id: 'r-1', name: 'Push Day', userId: 'user-001')],
          workoutCount: 5,
        ),
      );
      await tester.pump();
      await tester.pump();

      // Play glyph is present, but the banner must NOT be a FilledButton —
      // the active-plan hero is a tappable Material+InkWell card, not a
      // stock Material button.
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('routine name is rendered with titleLarge typography', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWithRouter(
          plan: _plan(routines: [_bucket(routineId: 'r-1', order: 1)]),
          routines: [_routine(id: 'r-1', name: 'Push Day', userId: 'user-001')],
          workoutCount: 5,
        ),
      );
      await tester.pump();
      await tester.pump();

      final ctx = tester.element(find.text('Push Day'));
      final expected = Theme.of(
        ctx,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);
      final actual = tester.widget<Text>(find.text('Push Day')).style;
      expect(actual?.fontSize, expected?.fontSize);
      expect(actual?.fontWeight, FontWeight.w700);
    });

    testWidgets('banner is tappable (InkWell with non-null onTap)', (
      tester,
    ) async {
      // We don't assert the destination here — startRoutineWorkout is covered
      // by its own widget tests and needs a routine with resolved exercises
      // to reach the navigation call. The contract this test owns is that
      // the banner surface is wired up as a tappable InkWell.
      await tester.pumpWidget(
        _buildWithRouter(
          plan: _plan(routines: [_bucket(routineId: 'r-1', order: 1)]),
          routines: [_routine(id: 'r-1', name: 'Push Day', userId: 'user-001')],
          workoutCount: 5,
        ),
      );
      await tester.pump();
      await tester.pump();

      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.onTap, isNotNull);
    });

    testWidgets('suggested-next advances to the next uncompleted routine', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWithRouter(
          plan: _plan(
            routines: [
              _bucket(routineId: 'r-1', order: 1, completedWorkoutId: 'wk-1'),
              _bucket(routineId: 'r-2', order: 2),
            ],
          ),
          routines: [
            _routine(id: 'r-1', name: 'Push Day', userId: 'user-001'),
            _routine(id: 'r-2', name: 'Pull Day', userId: 'user-001'),
          ],
          workoutCount: 5,
        ),
      );
      await tester.pump();
      await tester.pump();

      // With the first routine complete, the hero CTA advances to Pull Day.
      expect(find.text('Pull Day'), findsOneWidget);
      expect(find.text('Push Day'), findsNothing);
    });
  });

  group('ActionHero - brand new (no plan, no history)', () {
    testWidgets('renders beginner CTA (Full Body)', (tester) async {
      await tester.pumpWidget(
        _buildWithRouter(
          plan: null,
          routines: [
            _routine(id: 'r-fb', name: 'Full Body', isDefault: true),
            _routine(id: 'r-u', name: 'Upper Body', isDefault: true),
          ],
          workouts: const [],
          workoutCount: 0,
        ),
      );
      await tester.pump();
      await tester.pump();

      // Beginner CTA label is "YOUR FIRST WORKOUT" and shows the routine name.
      expect(find.text('YOUR FIRST WORKOUT'), findsOneWidget);
      expect(find.text('Full Body'), findsOneWidget);
      // Not lapsed-state copy.
      expect(find.text('Plan your week'), findsNothing);
      expect(find.text('Quick workout'), findsNothing);
    });

    testWidgets('renders nothing when no defaults and no history and no plan', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWithRouter(
          plan: null,
          routines: [
            _routine(id: 'r-u', name: 'My Routine', userId: 'user-001'),
          ],
          workouts: const [],
          workoutCount: 0,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('YOUR FIRST WORKOUT'), findsNothing);
      expect(find.text('Plan your week'), findsNothing);
      expect(find.text('Quick workout'), findsNothing);
    });
  });

  group('ActionHero - lapsed (no plan, has history)', () {
    testWidgets(
      'shows "Plan your week" primary FilledButton + "Quick workout" secondary OutlinedButton',
      (tester) async {
        await tester.pumpWidget(
          _buildWithRouter(
            plan: null,
            routines: [_routine(id: 'r-1', name: 'X', userId: 'user-001')],
            workouts: [_workout()],
            workoutCount: 3,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Plan your week'), findsOneWidget);
        expect(find.text('Quick workout'), findsOneWidget);

        // Primary must be FilledButton, secondary must be OutlinedButton
        // (visibility upgrade from the original ghost TextButton).
        expect(find.byType(FilledButton), findsOneWidget);
        expect(find.byType(OutlinedButton), findsOneWidget);
        expect(find.byType(TextButton), findsNothing);
      },
    );

    testWidgets('secondary OutlinedButton has minimum height of 48dp', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWithRouter(
          plan: null,
          routines: [_routine(id: 'r-1', name: 'X', userId: 'user-001')],
          workouts: [_workout()],
          workoutCount: 3,
        ),
      );
      await tester.pump();
      await tester.pump();

      final outlined = tester.widget<OutlinedButton>(
        find.byType(OutlinedButton),
      );
      final min = outlined.style?.minimumSize?.resolve({});
      expect(min, isNotNull);
      expect(min!.height, greaterThanOrEqualTo(48));
    });

    testWidgets('"Plan your week" navigates to /plan/week', (tester) async {
      await tester.pumpWidget(
        _buildWithRouter(
          plan: null,
          routines: [_routine(id: 'r-1', name: 'X', userId: 'user-001')],
          workouts: [_workout()],
          workoutCount: 3,
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Plan your week'));
      await tester.pumpAndSettle();

      expect(find.text('Plan Week Screen'), findsOneWidget);
    });
  });

  group('ActionHero - week complete', () {
    testWidgets(
      'renders banner with NEW WEEK label and "Start new week" headline',
      (tester) async {
        await tester.pumpWidget(
          _buildWithRouter(
            plan: _plan(
              routines: [
                _bucket(routineId: 'r-1', order: 1, completedWorkoutId: 'wk-1'),
                _bucket(routineId: 'r-2', order: 2, completedWorkoutId: 'wk-2'),
              ],
            ),
            routines: [
              _routine(id: 'r-1', name: 'Push', userId: 'user-001'),
              _routine(id: 'r-2', name: 'Pull', userId: 'user-001'),
            ],
            workoutCount: 6,
          ),
        );
        await tester.pump();
        await tester.pump();

        // New banner pattern: NEW WEEK label + "Start new week" headline +
        // "Y of Y done" sub-line, NOT a FilledButton with stock chrome.
        expect(find.text('NEW WEEK'), findsOneWidget);
        expect(find.text('Start new week'), findsOneWidget);
        expect(find.textContaining('2 of 2 done'), findsOneWidget);
        expect(find.byType(FilledButton), findsNothing);
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      },
    );

    testWidgets('tapping the week-complete banner navigates to /plan/week', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWithRouter(
          plan: _plan(
            routines: [
              _bucket(routineId: 'r-1', order: 1, completedWorkoutId: 'wk-1'),
            ],
          ),
          routines: [_routine(id: 'r-1', name: 'Push', userId: 'user-001')],
          workoutCount: 2,
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Start new week'));
      await tester.pumpAndSettle();

      expect(find.text('Plan Week Screen'), findsOneWidget);
    });
  });

  group('ActionHero - tap targets', () {
    testWidgets('lapsed primary FilledButton is at least 48dp tall', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWithRouter(
          plan: null,
          routines: [_routine(id: 'r-1', name: 'X', userId: 'user-001')],
          workouts: [_workout()],
          workoutCount: 3,
        ),
      );
      await tester.pump();
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final min = button.style?.minimumSize?.resolve({});
      expect(min, isNotNull);
      expect(min!.height, greaterThanOrEqualTo(48));
    });

    testWidgets('active-plan banner has at least 80dp height', (tester) async {
      await tester.pumpWidget(
        _buildWithRouter(
          plan: _plan(routines: [_bucket(routineId: 'r-1', order: 1)]),
          routines: [_routine(id: 'r-1', name: 'Push', userId: 'user-001')],
          workoutCount: 2,
        ),
      );
      await tester.pump();
      await tester.pump();

      // The banner wraps "Push" — find its enclosing InkWell and assert the
      // rendered height is >= 80dp.
      final inkWell = find
          .ancestor(of: find.text('Push'), matching: find.byType(InkWell))
          .first;
      final size = tester.getSize(inkWell);
      expect(size.height, greaterThanOrEqualTo(80));
    });
  });
}
