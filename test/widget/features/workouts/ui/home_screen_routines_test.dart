import 'dart:async';

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

void main() {
  group('HomeScreen STARTER ROUTINES deduplication (PO-009)', () {
    testWidgets('does not render duplicate STARTER ROUTINES section', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineListProvider.overrideWith(() => _MixedRoutineNotifier()),
            workoutHistoryProvider.overrideWith(
              () => _EmptyWorkoutHistoryNotifier(),
            ),
            activeWorkoutProvider.overrideWith(
              () => _NullActiveWorkoutNotifier(),
            ),
            weeklyPlanProvider.overrideWith(() => _NullWeeklyPlanNotifier()),
            weeklyPlanNeedsConfirmationProvider.overrideWith((ref) => false),
            weekVolumeProvider.overrideWith((ref) => Future.value(0)),
            profileProvider.overrideWith(() => _ProfileNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: HomeScreen()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // STARTER ROUTINES should appear exactly once.
      expect(find.text('STARTER ROUTINES'), findsOneWidget);
      // MY ROUTINES should appear once.
      expect(find.text('MY ROUTINES'), findsOneWidget);
    });

    testWidgets(
      'section headers use 70%+ opacity for WCAG compliance (UX-V07)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              routineListProvider.overrideWith(
                () => _DefaultOnlyRoutineNotifier(),
              ),
              workoutHistoryProvider.overrideWith(
                () => _EmptyWorkoutHistoryNotifier(),
              ),
              activeWorkoutProvider.overrideWith(
                () => _NullActiveWorkoutNotifier(),
              ),
              weeklyPlanProvider.overrideWith(() => _NullWeeklyPlanNotifier()),
              weeklyPlanNeedsConfirmationProvider.overrideWith((ref) => false),
              weekVolumeProvider.overrideWith((ref) => Future.value(0)),
              profileProvider.overrideWith(() => _ProfileNotifier()),
            ],
            child: MaterialApp(
              theme: AppTheme.dark,
              home: const Scaffold(body: HomeScreen()),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        // Find section header text widget to inspect its style.
        final textWidgets = tester
            .widgetList<Text>(find.text('STARTER ROUTINES'))
            .toList();
        expect(textWidgets, isNotEmpty);

        final style = textWidgets.first.style;
        final alpha = style?.color?.a ?? 0;
        // Opacity should be 0.7 or higher.
        expect(alpha, greaterThanOrEqualTo(0.7));
      },
    );

    testWidgets(
      'does not show RECENT section (removed in home simplification)',
      (tester) async {
        // Use a never-completing notifier that stays in loading state.
        final notifier = _PendingWorkoutHistoryNotifier();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              routineListProvider.overrideWith(
                () => _DefaultOnlyRoutineNotifier(),
              ),
              workoutHistoryProvider.overrideWith(() => notifier),
              activeWorkoutProvider.overrideWith(
                () => _NullActiveWorkoutNotifier(),
              ),
              weeklyPlanProvider.overrideWith(() => _NullWeeklyPlanNotifier()),
              weeklyPlanNeedsConfirmationProvider.overrideWith((ref) => false),
              weekVolumeProvider.overrideWith((ref) => Future.value(0)),
              profileProvider.overrideWith(() => _ProfileNotifier()),
            ],
            child: MaterialApp(
              theme: AppTheme.dark,
              home: const Scaffold(body: HomeScreen()),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        // RECENT section was removed — skeleton should no longer appear.
        expect(find.text('RECENT'), findsNothing);

        // Complete the future so the test can clean up without pending timers.
        notifier.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('routines hidden when active plan exists', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineListProvider.overrideWith(() => _MixedRoutineNotifier()),
            workoutHistoryProvider.overrideWith(
              () => _EmptyWorkoutHistoryNotifier(),
            ),
            activeWorkoutProvider.overrideWith(
              () => _NullActiveWorkoutNotifier(),
            ),
            weeklyPlanProvider.overrideWith(() => _ActiveWeeklyPlanNotifier()),
            weeklyPlanNeedsConfirmationProvider.overrideWith((ref) => false),
            weekVolumeProvider.overrideWith((ref) => Future.value(0)),
            profileProvider.overrideWith(() => _ProfileNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: HomeScreen()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Routines list should be hidden when active plan exists.
      expect(find.text('MY ROUTINES'), findsNothing);
      expect(find.text('STARTER ROUTINES'), findsNothing);
    });
  });
}

/// Returns both user and default routines.
class _MixedRoutineNotifier extends AsyncNotifier<List<Routine>>
    implements RoutineListNotifier {
  @override
  Future<List<Routine>> build() async {
    return [
      Routine(
        id: 'user-1',
        name: 'My Push',
        userId: 'user-001',
        isDefault: false,
        exercises: const [],
        createdAt: DateTime(2026),
      ),
      Routine(
        id: 'default-1',
        name: 'Starter A',
        isDefault: true,
        exercises: const [],
        createdAt: DateTime(2026),
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Returns only default routines.
class _DefaultOnlyRoutineNotifier extends AsyncNotifier<List<Routine>>
    implements RoutineListNotifier {
  @override
  Future<List<Routine>> build() async {
    return [
      Routine(
        id: 'default-1',
        name: 'Starter A',
        isDefault: true,
        exercises: const [],
        createdAt: DateTime(2026),
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Returns empty workout history immediately.
class _EmptyWorkoutHistoryNotifier extends AsyncNotifier<List<Workout>>
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

/// Stays in loading state until [complete] is called.
class _PendingWorkoutHistoryNotifier extends AsyncNotifier<List<Workout>>
    implements WorkoutHistoryNotifier {
  final _completer = Completer<List<Workout>>();

  @override
  Future<List<Workout>> build() => _completer.future;

  void complete() {
    if (!_completer.isCompleted) _completer.complete([]);
  }

  @override
  bool get hasMore => false;

  @override
  bool get isLoadingMore => false;

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> refresh() async {}
}

/// Returns null active workout.
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

class _ActiveWeeklyPlanNotifier extends AsyncNotifier<WeeklyPlan?>
    implements WeeklyPlanNotifier {
  @override
  Future<WeeklyPlan?> build() async => WeeklyPlan(
    id: 'plan-1',
    userId: 'user-001',
    weekStart: DateTime(2026, 4, 6),
    routines: const [
      BucketRoutine(routineId: 'user-1', order: 1),
      BucketRoutine(routineId: 'default-1', order: 2),
    ],
    createdAt: DateTime(2026, 4, 6),
    updatedAt: DateTime(2026, 4, 6),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileNotifier extends AsyncNotifier<Profile?>
    implements ProfileNotifier {
  @override
  Future<Profile?> build() async =>
      const Profile(id: 'user-001', displayName: 'Test', weightUnit: 'kg');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
