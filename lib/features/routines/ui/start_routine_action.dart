import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../workouts/models/routine_start_config.dart';
import '../../workouts/providers/workout_providers.dart';
import '../models/routine.dart';

/// Builds a [RoutineStartConfig] from a routine and starts an active workout.
///
/// Filters out exercises that are missing or soft-deleted.
Future<void> startRoutineWorkout(
  BuildContext context,
  WidgetRef ref,
  Routine routine,
) async {
  final exercises = routine.exercises
      .where((re) => re.exercise != null && re.exercise!.deletedAt == null)
      .map(
        (re) => RoutineStartExercise(
          exerciseId: re.exerciseId,
          exercise: re.exercise!,
          setCount: re.setConfigs.isNotEmpty ? re.setConfigs.length : 3,
          targetReps: re.setConfigs.isNotEmpty
              ? re.setConfigs.first.targetReps
              : null,
          restSeconds: re.setConfigs.isNotEmpty
              ? re.setConfigs.first.restSeconds
              : null,
        ),
      )
      .toList();

  if (exercises.isEmpty) return;

  final config = RoutineStartConfig(
    routineName: routine.name,
    exercises: exercises,
  );

  await ref.read(activeWorkoutProvider.notifier).startFromRoutine(config);
  if (!context.mounted) return;
  context.go('/workout/active');
}
