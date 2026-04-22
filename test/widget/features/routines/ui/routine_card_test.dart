import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';
import 'package:repsaga/features/routines/models/routine.dart';
import 'package:repsaga/features/routines/ui/widgets/routine_card.dart';

import '../../../../fixtures/test_factories.dart';
import '../../../../helpers/test_material_app.dart';

Exercise _makeExercise({
  String id = 'exercise-001',
  String name = 'Bench Press',
  String muscleGroup = 'chest',
}) {
  return Exercise.fromJson(
    TestExerciseFactory.create(id: id, name: name, muscleGroup: muscleGroup),
  );
}

Routine _makeRoutine({
  String name = 'Push Day',
  List<RoutineExercise>? exercises,
}) {
  return Routine(
    id: 'routine-001',
    name: name,
    isDefault: false,
    exercises: exercises ?? [],
    createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
  );
}

Widget _buildCard({
  required Routine routine,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
}) {
  return TestMaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: RoutineCard(
        routine: routine,
        onTap: onTap ?? () {},
        onLongPress: onLongPress,
      ),
    ),
  );
}

void main() {
  group('RoutineCard', () {
    testWidgets('renders routine name', (tester) async {
      final routine = _makeRoutine(name: 'Leg Day');
      await tester.pumpWidget(_buildCard(routine: routine));

      expect(find.text('Leg Day'), findsOneWidget);
    });

    testWidgets(
      'renders muscle group subtitle when exercises have resolved exercise',
      (tester) async {
        final routine = _makeRoutine(
          name: 'Push Day',
          exercises: [
            RoutineExercise(
              exerciseId: 'ex-1',
              setConfigs: const [],
              exercise: _makeExercise(muscleGroup: 'chest'),
            ),
            RoutineExercise(
              exerciseId: 'ex-2',
              setConfigs: const [],
              exercise: _makeExercise(
                id: 'exercise-002',
                name: 'OHP',
                muscleGroup: 'shoulders',
              ),
            ),
          ],
        );
        await tester.pumpWidget(_buildCard(routine: routine));

        // Muscle groups joined with middle dot
        expect(find.textContaining('Chest'), findsOneWidget);
        expect(find.textContaining('Shoulders'), findsOneWidget);
      },
    );

    testWidgets('shows play icon as launch affordance', (tester) async {
      final routine = _makeRoutine(
        exercises: [
          RoutineExercise(
            exerciseId: 'ex-1',
            setConfigs: const [],
            exercise: _makeExercise(),
          ),
          RoutineExercise(
            exerciseId: 'ex-2',
            setConfigs: const [],
            exercise: _makeExercise(id: 'exercise-002', name: 'Squat'),
          ),
          RoutineExercise(
            exerciseId: 'ex-3',
            setConfigs: const [],
            exercise: _makeExercise(id: 'exercise-003', name: 'OHP'),
          ),
        ],
      );
      await tester.pumpWidget(_buildCard(routine: routine));

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      final routine = _makeRoutine();
      await tester.pumpWidget(
        _buildCard(routine: routine, onTap: () => tapped = true),
      );

      await tester.tap(find.byType(RoutineCard));
      expect(tapped, isTrue);
    });

    testWidgets('calls onLongPress when long-pressed', (tester) async {
      var longPressed = false;
      final routine = _makeRoutine();
      await tester.pumpWidget(
        _buildCard(routine: routine, onLongPress: () => longPressed = true),
      );

      await tester.longPress(find.byType(RoutineCard));
      expect(longPressed, isTrue);
    });

    testWidgets('shows exercise count as subtitle when no resolved exercises', (
      tester,
    ) async {
      final routine = _makeRoutine(
        exercises: [
          const RoutineExercise(exerciseId: 'ex-1', setConfigs: []),
          const RoutineExercise(exerciseId: 'ex-2', setConfigs: []),
        ],
      );
      await tester.pumpWidget(_buildCard(routine: routine));

      // Falls back to "2 exercises"
      expect(find.text('2 exercises'), findsOneWidget);
    });

    testWidgets(
      'shows singular "exercise" for one exercise with no resolved data',
      (tester) async {
        final routine = _makeRoutine(
          exercises: [
            const RoutineExercise(exerciseId: 'ex-1', setConfigs: []),
          ],
        );
        await tester.pumpWidget(_buildCard(routine: routine));

        expect(find.text('1 exercise'), findsOneWidget);
      },
    );
  });
}
