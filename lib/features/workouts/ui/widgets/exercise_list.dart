import 'package:flutter/material.dart';

import '../../models/active_workout_state.dart';
import 'exercise_card.dart';

/// Vertical list of [ExerciseCard]s for the active workout body.
///
/// Pure layout wrapper — defers all per-exercise behavior to [ExerciseCard].
/// Bottom padding accounts for the FAB so the last card can scroll above it.
class ExerciseList extends StatelessWidget {
  const ExerciseList({
    required this.exercises,
    required this.reorderMode,
    super.key,
  });

  final List<ActiveWorkoutExercise> exercises;
  final bool reorderMode;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88, top: 8),
      itemCount: exercises.length,
      itemBuilder: (context, index) => ExerciseCard(
        activeExercise: exercises[index],
        reorderMode: reorderMode,
        isFirst: index == 0,
        isLast: index == exercises.length - 1,
      ),
    );
  }
}
