// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pending_action.freezed.dart';
part 'pending_action.g.dart';

/// Discriminated union of actions that can be queued for offline sync.
///
/// Each variant carries raw JSON maps so we avoid serialisation issues
/// with typed models (e.g. `WorkoutExercise.exercise` is excluded from
/// `toJson`). The RPC and repository calls already accept these shapes.
@Freezed(unionKey: 'type')
sealed class PendingAction with _$PendingAction {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory PendingAction.saveWorkout({
    required String id,
    required Map<String, dynamic> workoutJson,
    required List<Map<String, dynamic>> exercisesJson,
    required List<Map<String, dynamic>> setsJson,
    required String userId,
    required DateTime queuedAt,
    @Default(0) int retryCount,
    String? lastError,
  }) = PendingSaveWorkout;

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory PendingAction.upsertRecords({
    required String id,
    required List<Map<String, dynamic>> recordsJson,
    required DateTime queuedAt,
    @Default(0) int retryCount,
    String? lastError,
  }) = PendingUpsertRecords;

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory PendingAction.markRoutineComplete({
    required String id,
    required String planId,
    required String routineId,
    required String workoutId,
    required DateTime queuedAt,
    @Default(0) int retryCount,
    String? lastError,
  }) = PendingMarkRoutineComplete;

  factory PendingAction.fromJson(Map<String, dynamic> json) =>
      _$PendingActionFromJson(json);
}
