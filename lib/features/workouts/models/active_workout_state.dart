// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

import 'exercise_set.dart';
import 'workout.dart';
import 'workout_exercise.dart';

part 'active_workout_state.freezed.dart';
part 'active_workout_state.g.dart';

@freezed
class ActiveWorkoutExercise with _$ActiveWorkoutExercise {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ActiveWorkoutExercise({
    required WorkoutExercise workoutExercise,
    @JsonKey(defaultValue: <ExerciseSet>[]) required List<ExerciseSet> sets,
  }) = _ActiveWorkoutExercise;

  factory ActiveWorkoutExercise.fromJson(Map<String, dynamic> json) =>
      _$ActiveWorkoutExerciseFromJson(json);
}

@freezed
class ActiveWorkoutState with _$ActiveWorkoutState {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ActiveWorkoutState({
    required Workout workout,
    @JsonKey(defaultValue: <ActiveWorkoutExercise>[])
    required List<ActiveWorkoutExercise> exercises,

    /// The source routine's ID when this workout was started from a routine.
    /// Used for matching bucket completion in the weekly plan.
    String? routineId,
  }) = _ActiveWorkoutState;

  factory ActiveWorkoutState.fromJson(Map<String, dynamic> json) =>
      _$ActiveWorkoutStateFromJson(json);
}
