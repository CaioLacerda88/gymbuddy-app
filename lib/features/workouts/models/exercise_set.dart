// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

import 'set_type.dart';

part 'exercise_set.freezed.dart';
part 'exercise_set.g.dart';

SetType _setTypeFromJson(dynamic value) =>
    SetType.fromString(value as String? ?? 'working');

String _setTypeToJson(SetType type) => type.name;

@freezed
abstract class ExerciseSet with _$ExerciseSet {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ExerciseSet({
    required String id,
    required String workoutExerciseId,
    required int setNumber,
    int? reps,
    double? weight,
    int? rpe,
    @JsonKey(
      defaultValue: SetType.working,
      fromJson: _setTypeFromJson,
      toJson: _setTypeToJson,
    )
    required SetType setType,
    String? notes,
    @JsonKey(defaultValue: false) required bool isCompleted,
    required DateTime createdAt,
  }) = _ExerciseSet;

  factory ExerciseSet.fromJson(Map<String, dynamic> json) =>
      _$ExerciseSetFromJson(json);
}
