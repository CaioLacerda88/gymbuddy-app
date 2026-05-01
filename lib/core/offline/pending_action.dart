// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pending_action.freezed.dart';
part 'pending_action.g.dart';

/// Discriminated union of actions that can be queued for offline sync.
///
/// Each variant carries raw JSON maps so we avoid serialisation issues
/// with typed models (e.g. `WorkoutExercise.exercise` is excluded from
/// `toJson`). The RPC and repository calls already accept these shapes.
///
/// **Dependency ordering (BUG-002):** every variant carries an optional
/// [dependsOn] list of parent action IDs. The drain holds an action back
/// until every ID in [dependsOn] has either been dequeued (parent committed)
/// or no longer exists in the queue (parent dismissed). Children of the
/// same parent batch (e.g. a `PendingUpsertRecords` whose `set_id` references
/// rows that the parent `PendingSaveWorkout` is about to insert) MUST be
/// enqueued with the parent's `id` in [dependsOn] — otherwise replay can
/// race the FK and we get `personal_records_set_id_fkey` violations.
///
/// **`lastError` is dev-facing only (BUG-042):** the field stores a raw
/// `.toString()` of the most recent failure for log inspection and Sentry
/// breadcrumbs. It MUST NOT be rendered in any UI. UI surfaces consume
/// errors via [SyncErrorMapper.toUserMessage] which produces a localized,
/// schema-free message keyed by exception class.
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
    @Default(<String>[]) List<String> dependsOn,
  }) = PendingSaveWorkout;

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory PendingAction.upsertRecords({
    required String id,
    required List<Map<String, dynamic>> recordsJson,
    @Default('') String userId,
    required DateTime queuedAt,
    @Default(0) int retryCount,
    String? lastError,
    @Default(<String>[]) List<String> dependsOn,
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
    @Default(<String>[]) List<String> dependsOn,
  }) = PendingMarkRoutineComplete;

  factory PendingAction.fromJson(Map<String, dynamic> json) =>
      _$PendingActionFromJson(json);
}
