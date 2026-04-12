// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workout.freezed.dart';
part 'workout.g.dart';

@freezed
abstract class Workout with _$Workout {
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

    /// Computed at query time — not a DB column.
    /// E.g. "Bench Press, Squat, Deadlift +2"
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? exerciseSummary,
  }) = _Workout;

  factory Workout.fromJson(Map<String, dynamic> json) =>
      _$WorkoutFromJson(json);
}
