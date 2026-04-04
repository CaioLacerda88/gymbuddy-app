import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/personal_records/providers/pr_providers.dart';
import 'package:gymbuddy_app/features/workouts/data/workout_repository.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_history_providers.dart';
import 'package:gymbuddy_app/features/workouts/ui/workout_detail_screen.dart';

import '../../../../fixtures/test_factories.dart';

void main() {
  WorkoutDetail makeDetail() {
    return WorkoutRepository.parseWorkoutDetail({
      ...TestWorkoutFactory.create(id: 'w-1'),
      'workout_exercises': [
        {
          ...TestWorkoutExerciseFactory.create(id: 'we-1', exerciseId: 'e-1'),
          'exercise': TestExerciseFactory.create(
            id: 'e-1',
            name: 'Bench Press',
          ),
          'sets': [
            TestSetFactory.create(
              id: 'set-1',
              workoutExerciseId: 'we-1',
              setNumber: 1,
            ),
            TestSetFactory.create(
              id: 'set-2',
              workoutExerciseId: 'we-1',
              setNumber: 2,
            ),
          ],
        },
      ],
    });
  }

  Widget buildTestWidget({required List<Override> overrides}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const WorkoutDetailScreen(workoutId: 'w-1'),
      ),
    );
  }

  group('WorkoutDetailScreen PR badges', () {
    testWidgets('shows trophy icon on PR sets', (tester) async {
      final detail = makeDetail();

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            workoutDetailProvider(
              'w-1',
            ).overrideWith((ref) => Future.value(detail)),
            workoutPRSetIdsProvider(
              'w-1',
            ).overrideWith((ref) => Future.value({'set-1'})),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      // set-1 is a PR: trophy icon should appear
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    });

    testWidgets('shows set number text on non-PR sets', (tester) async {
      final detail = makeDetail();

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            workoutDetailProvider(
              'w-1',
            ).overrideWith((ref) => Future.value(detail)),
            workoutPRSetIdsProvider(
              'w-1',
            ).overrideWith((ref) => Future.value({'set-1'})),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      // set-2 is not a PR: its set number '2.' should be visible
      expect(find.text('2.'), findsOneWidget);
      // set-1 is a PR so '1.' should not be shown
      expect(find.text('1.'), findsNothing);
    });

    testWidgets('shows no trophy icons when PR set is empty', (tester) async {
      final detail = makeDetail();

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            workoutDetailProvider(
              'w-1',
            ).overrideWith((ref) => Future.value(detail)),
            workoutPRSetIdsProvider(
              'w-1',
            ).overrideWith((ref) => Future.value(<String>{})),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      // No PR sets: no trophy icons at all
      expect(find.byIcon(Icons.emoji_events), findsNothing);
      // Both set numbers shown
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
    });

    testWidgets(
      'shows no trophy icons while workoutPRSetIdsProvider is loading',
      (tester) async {
        final detail = makeDetail();
        // Never completes during this test — simulates in-flight async fetch.
        final completer = Completer<Set<String>>();

        await tester.pumpWidget(
          buildTestWidget(
            overrides: [
              workoutDetailProvider(
                'w-1',
              ).overrideWith((ref) => Future.value(detail)),
              workoutPRSetIdsProvider(
                'w-1',
              ).overrideWith((ref) => completer.future),
            ],
          ),
        );
        // One pump: workout detail resolves, but PR provider is still loading.
        await tester.pump();
        await tester.pump();

        // Workout content is visible.
        expect(find.text('Bench Press'), findsOneWidget);
        // No trophy icons rendered during loading state.
        expect(find.byIcon(Icons.emoji_events), findsNothing);

        // Resolve the completer to avoid pending timer assertion.
        completer.complete({'set-1'});
        await tester.pump();
        await tester.pump();

        // After resolution, badge appears for set-1.
        expect(find.byIcon(Icons.emoji_events), findsOneWidget);
      },
    );

    testWidgets('trophy icon is rendered at 18dp', (tester) async {
      final detail = makeDetail();

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            workoutDetailProvider(
              'w-1',
            ).overrideWith((ref) => Future.value(detail)),
            workoutPRSetIdsProvider(
              'w-1',
            ).overrideWith((ref) => Future.value({'set-1'})),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.emoji_events));
      expect(iconWidget.size, 18.0);
    });
  });
}
