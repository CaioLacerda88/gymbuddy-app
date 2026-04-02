// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workout.freezed.dart';
part 'workout.g.dart';

@freezed
class Workout with _$Workout {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Workout({
    required String id,
    required String userId,
    required String name,
    required DateTime startedAt,
    DateTime? finishedAt,
    int? durationSeconds,
    @JsonKey(defaultValue: false) required bool isActive,
    String? notes,
    required DateTime createdAt,
  }) = _Workout;

  factory Workout.fromJson(Map<String, dynamic> json) =>
      _$WorkoutFromJson(json);
}
