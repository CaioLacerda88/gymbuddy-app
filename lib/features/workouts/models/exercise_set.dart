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

/// Single source of truth for the snake_case set payload sent to the
/// `save_workout` RPC and queued as `setsJson` on offline `PendingSaveWorkout`.
///
/// Both call sites must serialize identically — drift between them caused
/// BUG-001, where the offline path omitted `created_at` and `ExerciseSet.fromJson`
/// then threw a null-cast on replay. Keep this map shape and key set in sync
/// with `_$ExerciseSetFromJson` in `exercise_set.g.dart`.
extension ExerciseSetRpcJson on ExerciseSet {
  Map<String, dynamic> toRpcJson() => <String, dynamic>{
    'id': id,
    'workout_exercise_id': workoutExerciseId,
    'set_number': setNumber,
    'reps': reps,
    'weight': weight,
    'rpe': rpe,
    'set_type': setType.name,
    'notes': notes,
    'is_completed': isCompleted,
    'created_at': createdAt.toIso8601String(),
  };
}
