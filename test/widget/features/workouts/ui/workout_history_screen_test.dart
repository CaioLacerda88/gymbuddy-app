import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/workouts/models/workout.dart';
import 'package:repsaga/features/workouts/providers/workout_history_providers.dart';
import 'package:repsaga/features/workouts/ui/workout_history_screen.dart';

import '../../../../fixtures/test_factories.dart';
import '../../../../helpers/test_material_app.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _WorkoutHistoryStub extends AsyncNotifier<List<Workout>>
    implements WorkoutHistoryNotifier {
  _WorkoutHistoryStub({
    required this.workouts,
    this.isLoadingMoreValue = false,
    this.hasMoreValue = false,
  });

  final List<Workout> workouts;
  final bool isLoadingMoreValue;
  final bool hasMoreValue;

  @override
  Future<List<Workout>> build() async => workouts;

  @override
  bool get hasMore => hasMoreValue;

  @override
  bool get isLoadingMore => isLoadingMoreValue;

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> refresh() async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

List<Workout> makeWorkouts(int count) {
  return List.generate(count, (i) {
    return Workout.fromJson(
      TestWorkoutFactory.create(
        id: 'workout-$i',
        name: 'Workout $i',
        finishedAt: DateTime.now()
            .subtract(Duration(days: i))
            .toIso8601String(),
      ),
    );
  });
}

Widget buildTestWidget({
  required List<Workout> workouts,
  bool isLoadingMore = false,
  bool hasMore = false,
}) {
  return ProviderScope(
    overrides: [
      workoutHistoryProvider.overrideWith(
        () => _WorkoutHistoryStub(
          workouts: workouts,
          isLoadingMoreValue: isLoadingMore,
          hasMoreValue: hasMore,
        ),
      ),
    ],
    child: TestMaterialApp(
      theme: AppTheme.dark,
      home: const WorkoutHistoryScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests — PO-028: loading indicator during load-more
// ---------------------------------------------------------------------------

void main() {
  group('WorkoutHistoryScreen', () {
    testWidgets('shows empty state when no workouts', (tester) async {
      await tester.pumpWidget(buildTestWidget(workouts: []));
      await tester.pump();
      await tester.pump();

      expect(find.text('No workouts yet'), findsOneWidget);
      expect(
        find.text('Your completed workouts will appear here'),
        findsOneWidget,
      );
    });

    testWidgets('shows workout cards when workouts are present', (
      tester,
    ) async {
      final workouts = makeWorkouts(3);
      await tester.pumpWidget(buildTestWidget(workouts: workouts));
      await tester.pump();
      await tester.pump();

      expect(find.text('Workout 0'), findsOneWidget);
      expect(find.text('Workout 1'), findsOneWidget);
      expect(find.text('Workout 2'), findsOneWidget);
    });

    testWidgets(
      'PO-028: shows CircularProgressIndicator in list when isLoadingMore is true',
      (tester) async {
        final workouts = makeWorkouts(5);
        await tester.pumpWidget(
          buildTestWidget(workouts: workouts, isLoadingMore: true),
        );
        await tester.pump();
        await tester.pump();

        // The load-more spinner appears as an extra item at the bottom of the list.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'PO-028: shows CircularProgressIndicator in list when hasMore is true',
      (tester) async {
        final workouts = makeWorkouts(5);
        await tester.pumpWidget(
          buildTestWidget(workouts: workouts, hasMore: true),
        );
        await tester.pump();
        await tester.pump();

        // hasMore also causes the loading item to render (next page anticipated).
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'does NOT show load-more indicator when isLoadingMore is false and hasMore is false',
      (tester) async {
        final workouts = makeWorkouts(5);
        await tester.pumpWidget(
          buildTestWidget(
            workouts: workouts,
            isLoadingMore: false,
            hasMore: false,
          ),
        );
        await tester.pump();
        await tester.pump();

        // No loading indicator should appear.
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets('shows RefreshIndicator wrapping the list', (tester) async {
      final workouts = makeWorkouts(3);
      await tester.pumpWidget(buildTestWidget(workouts: workouts));
      await tester.pump();
      await tester.pump();

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('history AppBar title reads "History"', (tester) async {
      await tester.pumpWidget(buildTestWidget(workouts: []));
      await tester.pump();

      expect(find.text('History'), findsOneWidget);
    });
  });
}
