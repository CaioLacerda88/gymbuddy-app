// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../exercises/models/exercise.dart';

part 'routine.freezed.dart';
part 'routine.g.dart';

@freezed
class RoutineSetConfig with _$RoutineSetConfig {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory RoutineSetConfig({
    int? targetReps,
    double? targetWeight,
    int? restSeconds,
  }) = _RoutineSetConfig;

  factory RoutineSetConfig.fromJson(Map<String, dynamic> json) =>
      _$RoutineSetConfigFromJson(json);
}

@freezed
class RoutineExercise with _$RoutineExercise {
  @JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
  const factory RoutineExercise({
    required String exerciseId,
    @JsonKey(defaultValue: <RoutineSetConfig>[])
    required List<RoutineSetConfig> setConfigs,
    @JsonKey(includeToJson: false) Exercise? exercise,
  }) = _RoutineExercise;

  factory RoutineExercise.fromJson(Map<String, dynamic> json) =>
      _$RoutineExerciseFromJson(json);
}

@freezed
class Routine with _$Routine {
  @JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
  const factory Routine({
    required String id,
    String? userId,
    required String name,
    @JsonKey(defaultValue: false) required bool isDefault,
    @JsonKey(defaultValue: <RoutineExercise>[])
    required List<RoutineExercise> exercises,
    required DateTime createdAt,
  }) = _Routine;

  factory Routine.fromJson(Map<String, dynamic> json) =>
      _$RoutineFromJson(json);
}
