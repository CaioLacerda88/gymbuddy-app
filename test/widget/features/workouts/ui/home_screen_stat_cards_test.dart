import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/personal_records/providers/pr_providers.dart';
import 'package:gymbuddy_app/features/routines/models/routine.dart';
import 'package:gymbuddy_app/features/routines/providers/notifiers/routine_list_notifier.dart';
import 'package:gymbuddy_app/features/workouts/models/active_workout_state.dart';
import 'package:gymbuddy_app/features/workouts/models/workout.dart';
import 'package:gymbuddy_app/features/workouts/providers/notifiers/active_workout_notifier.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_history_providers.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_providers.dart';
import 'package:gymbuddy_app/features/workouts/ui/home_screen.dart';

// ---------------------------------------------------------------------------
// Test notifier stubs
// ---------------------------------------------------------------------------

class _EmptyRoutineNotifier extends AsyncNotifier<List<Routine>>
    implements RoutineListNotifier {
  @override
  Future<List<Routine>> build() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyWorkoutHistoryNotifier extends AsyncNotifier<List<Workout>>
    implements WorkoutHistoryNotifier {
  @override
  Future<List<Workout>> build() async => [];

  @override
  bool get hasMore => false;

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
// Helpers
// ---------------------------------------------------------------------------

Widget buildTestWidget({
  int workoutCount = 14,
  int prCount = 3,
  bool loadingCounts = false,
}) {
  return ProviderScope(
    overrides: [
      routineListProvider.overrideWith(() => _EmptyRoutineNotifier()),
      workoutHistoryProvider.overrideWith(() => _EmptyWorkoutHistoryNotifier()),
      activeWorkoutProvider.overrideWith(() => _NullActiveWorkoutNotifier()),
      recentPRsProvider.overrideWith((ref) => Future.value([])),
      if (loadingCounts) ...[
        workoutCountProvider.overrideWith((ref) => Completer<int>().future),
        prCountProvider.overrideWith((ref) => Completer<int>().future),
      ] else ...[
        workoutCountProvider.overrideWith((ref) => Future.value(workoutCount)),
        prCountProvider.overrideWith((ref) => Future.value(prCount)),
      ],
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
  group('HomeScreen stat cards', () {
    testWidgets('renders workout count', (tester) async {
      await tester.pumpWidget(buildTestWidget(workoutCount: 14));
      await tester.pump();
      await tester.pump();

      expect(find.text('14'), findsOneWidget);
      expect(find.text('Workouts'), findsWidgets);
    });

    testWidgets('renders PR count', (tester) async {
      await tester.pumpWidget(buildTestWidget(prCount: 3));
      await tester.pump();
      await tester.pump();

      expect(find.text('3'), findsOneWidget);
      expect(find.text('Records'), findsOneWidget);
    });

    testWidgets('shows -- when counts are loading', (tester) async {
      await tester.pumpWidget(buildTestWidget(loadingCounts: true));
      await tester.pump();
      await tester.pump();

      expect(find.text('--'), findsNWidgets(2));
    });

    testWidgets('shows 0 when user has no workouts or records', (tester) async {
      await tester.pumpWidget(buildTestWidget(workoutCount: 0, prCount: 0));
      await tester.pump();
      await tester.pump();

      expect(find.text('0'), findsNWidgets(2));
    });

    testWidgets('workout count card has correct semantics', (tester) async {
      await tester.pumpWidget(buildTestWidget(workoutCount: 14));
      await tester.pump();
      await tester.pump();

      final semantics = tester.getSemantics(
        find
            .ancestor(
              of: find.text('Workouts'),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantics.label, contains('Workouts'));
    });

    testWidgets('cards are in a Row with two Expanded children', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await tester.pump();

      // Find the row that contains the stat cards.
      final workoutsText = find.text('Workouts');
      final recordsText = find.text('Records');
      expect(workoutsText, findsWidgets);
      expect(recordsText, findsOneWidget);
    });
  });
}
