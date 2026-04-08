import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/exercises/models/exercise.dart';
import 'package:gymbuddy_app/features/exercises/providers/exercise_providers.dart';
import 'package:gymbuddy_app/features/exercises/ui/exercise_list_screen.dart';

import '../../../../fixtures/test_factories.dart';

void main() {
  final testExercises = [
    Exercise.fromJson(TestExerciseFactory.create()),
    Exercise.fromJson(
      TestExerciseFactory.create(
        id: 'exercise-002',
        name: 'Squat',
        muscleGroup: 'legs',
        equipmentType: 'barbell',
      ),
    ),
    Exercise.fromJson(
      TestExerciseFactory.create(
        id: 'exercise-003',
        name: 'Pull Up',
        muscleGroup: 'back',
        equipmentType: 'bodyweight',
      ),
    ),
  ];

  Widget buildTestWidget({
    AsyncValue<List<Exercise>> exerciseValue = const AsyncLoading(),
  }) {
    return ProviderScope(
      overrides: [
        filteredExerciseListProvider.overrideWith((ref) => exerciseValue),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const ExerciseListScreen(),
      ),
    );
  }

  group('ExerciseListScreen', () {
    testWidgets('renders exercise list with names visible', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(exerciseValue: AsyncData(testExercises)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('Squat'), findsOneWidget);
      expect(find.text('Pull Up'), findsOneWidget);
    });

    testWidgets('renders muscle group filter buttons (All + 6 groups)', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(exerciseValue: AsyncData(testExercises)),
      );
      await tester.pumpAndSettle();

      // All button + 6 muscle groups
      expect(find.text('All'), findsOneWidget);
      for (final group in MuscleGroup.values) {
        expect(find.text(group.displayName), findsWidgets);
      }
    });

    testWidgets('renders equipment filter chips', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(exerciseValue: AsyncData(testExercises)),
      );
      await tester.pumpAndSettle();

      for (final type in EquipmentType.values) {
        expect(find.text(type.displayName), findsWidgets);
      }
    });

    testWidgets('renders search field', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(exerciseValue: AsyncData(testExercises)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Search exercises...'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });

    testWidgets('renders FAB for creating exercises', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(exerciseValue: AsyncData(testExercises)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('shows empty state without filters', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(exerciseValue: const AsyncData([])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your exercises will appear here'), findsOneWidget);
      expect(find.text('Create Exercise'), findsOneWidget);
    });

    testWidgets('shows filtered empty state with Clear Filters button', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filteredExerciseListProvider.overrideWith(
              (ref) => const AsyncData(<Exercise>[]),
            ),
            selectedMuscleGroupProvider.overrideWith(
              (ref) => MuscleGroup.chest,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const ExerciseListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No exercises match your filters'), findsOneWidget);
      expect(find.text('Clear Filters'), findsOneWidget);
    });

    // PO-016: exercise list must be wrapped in a RefreshIndicator so users can
    // pull-to-refresh to reload the exercise catalogue.
    testWidgets('PO-016: exercise list is wrapped in a RefreshIndicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(exerciseValue: AsyncData(testExercises)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });
}
