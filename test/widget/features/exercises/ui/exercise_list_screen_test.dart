import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';
import 'package:repsaga/features/exercises/providers/exercise_providers.dart';
import 'package:repsaga/features/exercises/ui/exercise_list_screen.dart';

import '../../../../fixtures/test_factories.dart';
import '../../../../helpers/test_material_app.dart';

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
      child: TestMaterialApp(
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
          child: TestMaterialApp(
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

  group('ExerciseListScreen P9 custom-exercise accent', () {
    BoxDecoration? cardDecoration(WidgetTester tester, String exerciseName) {
      // Walk up from the exercise name Text to find the card's outer
      // Container (the one carrying the Border decoration).
      final textFinder = find.text(exerciseName);
      expect(textFinder, findsOneWidget);
      final containers = tester
          .widgetList<Container>(
            find.ancestor(of: textFinder, matching: find.byType(Container)),
          )
          .toList();
      for (final c in containers) {
        final d = c.decoration;
        if (d is BoxDecoration && d.border != null) {
          return d;
        }
      }
      return null;
    }

    testWidgets('custom exercise card has a primary left-border accent', (
      tester,
    ) async {
      final customExercises = [
        Exercise.fromJson(
          TestExerciseFactory.create(
            id: 'exercise-custom-001',
            name: 'My Home Press',
            isDefault: false,
            userId: 'user-001',
          ),
        ),
      ];

      await tester.pumpWidget(
        buildTestWidget(exerciseValue: AsyncData(customExercises)),
      );
      await tester.pumpAndSettle();

      final deco = cardDecoration(tester, 'My Home Press');
      expect(deco, isNotNull);
      final border = deco!.border! as Border;
      expect(
        border.left.width,
        3,
        reason: 'custom cards should have a 3dp left accent',
      );
      expect(border.left.style, isNot(equals(BorderStyle.none)));
    });

    testWidgets('default exercise card has no left-border accent', (
      tester,
    ) async {
      final defaultExercises = [
        Exercise.fromJson(TestExerciseFactory.create(name: 'Bench Press')),
      ];

      await tester.pumpWidget(
        buildTestWidget(exerciseValue: AsyncData(defaultExercises)),
      );
      await tester.pumpAndSettle();

      final deco = cardDecoration(tester, 'Bench Press');
      expect(deco, isNotNull);
      final border = deco!.border! as Border;
      expect(
        border.left.style,
        BorderStyle.none,
        reason: 'default cards should have no left accent',
      );
    });
  });
}
