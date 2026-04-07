// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../exercises/models/exercise.dart';

part 'workout_exercise.freezed.dart';
part 'workout_exercise.g.dart';

@freezed
class WorkoutExercise with _$WorkoutExercise {
  @JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
  const factory WorkoutExercise({
    required String id,
    required String workoutId,
    required String exerciseId,
    required int order,
    int? restSeconds,
    Exercise? exercise,
  }) = _WorkoutExercise;

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) =>
      _$WorkoutExerciseFromJson(json);
}
