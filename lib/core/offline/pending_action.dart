// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pending_action.freezed.dart';
part 'pending_action.g.dart';

/// Coarse classification of why a queued action last failed.
///
/// This is computed by [SyncErrorMapper.classifyCategory] at the moment a
/// drain attempt fails and stored on the action so the [PendingSyncSheet]
/// can pick the right CTA without re-classifying:
///
/// - [SyncErrorCategory.none] / [SyncErrorCategory.network] /
///   [SyncErrorCategory.transient] / [SyncErrorCategory.unknown] → retry is
///   meaningful; show "Tentar novamente". `unknown` is intentionally NOT
///   terminal — a genuinely unknown error class might be a one-off plugin
///   crash that retry resolves, and forcing "Dispensar" removes the user's
///   only recovery path. If the underlying issue is structural, the next
///   attempt will surface a more specific exception class that the mapper
///   routes to [structural].
/// - [SyncErrorCategory.structural] / [SyncErrorCategory.session] → retry
///   will not resolve it (FK violation, type-cast crash, expired session);
///   show "Dispensar" + branded copy directing the user to support
///   (BUG-008).
enum SyncErrorCategory {
  /// Default for items that have not failed yet.
  none,

  /// SocketException / TimeoutException / HttpException / NetworkException.
  network,

  /// Server-side issue likely to clear up (5xx, generic flake).
  transient,

  /// Client-side data shape problem — FK violation, type cast, RLS denial.
  /// Retrying without code changes won't help.
  structural,

  /// Authentication / token problem.
  session,

  /// Catch-all: an unexpected exception class. Treated as non-terminal —
  /// the user keeps a retry CTA. See doc comment above for rationale.
  unknown,
}

/// Discriminated union of actions that can be queued for offline sync.
///
/// Each variant carries raw JSON maps so we avoid serialisation issues
/// with typed models (e.g. `WorkoutExercise.exercise` is excluded from
/// `toJson`). The RPC and repository calls already accept these shapes.
///
/// **Dependency ordering (BUG-002, BUG-003):** every variant carries an
/// optional [dependsOn] list of parent action IDs. The drain holds an action
/// back until every ID in [dependsOn] has either been dequeued (parent
/// committed) or no longer exists in the queue (parent dismissed). Children
/// of the same parent batch (e.g. a `PendingUpsertRecords` whose `set_id`
/// references rows that the parent `PendingSaveWorkout` is about to insert,
/// or a `PendingSaveWorkout` whose `exercise_id` references an exercise the
/// `PendingCreateExercise` will insert first) MUST be enqueued with the
/// parent's `id` in [dependsOn] — otherwise replay can race the FK and we
/// get `*_fkey` constraint violations.
///
/// **`lastError` is dev-facing only (BUG-042):** the field stores a raw
/// `.toString()` of the most recent failure for log inspection and Sentry
/// breadcrumbs. It MUST NOT be rendered in any UI. UI surfaces consume
/// errors via [SyncErrorMapper.toUserMessage] which produces a localized,
/// schema-free message keyed by exception class.
///
/// **`errorCategory` drives UI CTA selection (BUG-008):** populated by the
/// drain code via [SyncErrorMapper.classifyCategory] when an attempt fails.
/// The pending-sync sheet reads it to decide between retry and dismiss.
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
    @Default(SyncErrorCategory.none) SyncErrorCategory errorCategory,
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
    @Default(SyncErrorCategory.none) SyncErrorCategory errorCategory,
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
    @Default(SyncErrorCategory.none) SyncErrorCategory errorCategory,
  }) = PendingMarkRoutineComplete;

  /// Custom exercise the user created while offline.
  ///
  /// The exercise is materialized client-side first (a UUID is generated and
  /// stamped onto the row in the local cache so workouts logged in the same
  /// offline session can attach to it). On replay the [exerciseId] is passed
  /// to the server insert so the row's primary key matches what the local
  /// session already wrote — every downstream `PendingSaveWorkout` that
  /// references this exercise carries `dependsOn: [thisAction.id]` so the
  /// drain commits the exercise before the workout (BUG-003).
  ///
  /// [locale] is the locale the user typed the name in; the server insert
  /// writes a single `exercise_translations` row keyed by `(exerciseId,
  /// locale)` and returns the row keyed back as the cascade default.
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory PendingAction.createExercise({
    required String id,
    required String exerciseId,
    required String userId,
    required String locale,
    required String name,
    required String muscleGroup,
    required String equipmentType,
    String? description,
    String? formTips,
    required DateTime queuedAt,
    @Default(0) int retryCount,
    String? lastError,
    @Default(<String>[]) List<String> dependsOn,
    @Default(SyncErrorCategory.none) SyncErrorCategory errorCategory,
  }) = PendingCreateExercise;

  factory PendingAction.fromJson(Map<String, dynamic> json) =>
      _$PendingActionFromJson(json);
}
