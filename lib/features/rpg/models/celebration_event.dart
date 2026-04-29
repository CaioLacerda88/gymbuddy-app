// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

import 'body_part.dart';

part 'celebration_event.freezed.dart';

/// Discriminated union of post-workout celebration events.
///
/// The workout-finish flow (`ActiveWorkoutNotifier._finishOnline`) builds an
/// ordered list of these events from the `record_set_xp` deltas and feeds
/// them into [CelebrationQueue], which applies the cap-at-3 rule and returns
/// the playback order plus an optional overflow payload.
///
/// **Why a sealed class instead of polymorphism via subclassing**: Freezed's
/// `@Freezed` union gives us exhaustive `switch`/`when` ergonomics in the
/// orchestrator and the overlay router — adding a new event type forces a
/// compile error in every consumer until they handle it. That structural
/// guarantee is the point: we do not want a future contributor to add
/// `WeeklyStreakEvent` and silently drop it on the floor at the queue.
@freezed
sealed class CelebrationEvent with _$CelebrationEvent {
  /// A body-part rank threshold was crossed in this workout.
  ///
  /// `newRank` is the post-workout rank value (1–99). `bodyPart` drives both
  /// the rune sigil chosen for the overlay and the tiebreaker in the
  /// celebration queue (highest rank first).
  const factory CelebrationEvent.rankUp({
    required BodyPart bodyPart,
    required int newRank,
  }) = RankUpEvent;

  /// The derived character level rolled over.
  ///
  /// One per workout finish at most — character level is a pure function of
  /// the per-body-part ranks, so the queue collapses multiple body-part rank
  /// crosses into a single character-level event.
  const factory CelebrationEvent.levelUp({required int newLevel}) =
      LevelUpEvent;

  /// A title slug was newly unlocked.
  ///
  /// `slug` is the asset-catalog join key. The half-sheet resolves the
  /// localized name + flavor + sub-label at render time by looking the slug
  /// up against the catalog ([Title]) and pattern-matching on the variant
  /// (body-part / character-level / cross-build).
  ///
  /// **Why slug-only (Phase 18e):** the body-part rank-threshold sub-label
  /// is one of three possible sub-labels — character-level and cross-build
  /// titles use different copy entirely. Carrying only the slug forces the
  /// resolver to consult the catalog, which is the only surface that knows
  /// what shape the metadata has. The pre-18e shape (`slug + bodyPart +
  /// rankThreshold`) silently encoded the body-part assumption.
  const factory CelebrationEvent.titleUnlock({required String slug}) =
      TitleUnlockEvent;

  /// A body part transitioned from "never trained" to "trained" — fires the
  /// 800ms first-awakening compressed overlay.
  ///
  /// Throttled by `ActiveWorkoutNotifier._firstAwakeningFiredThisSession`:
  /// only one fires per workout session even if the user awakens multiple
  /// body parts in one finish. Subsequent body-part awakenings render
  /// silently as a rune-state change on the next character-sheet read.
  const factory CelebrationEvent.firstAwakening({required BodyPart bodyPart}) =
      FirstAwakeningEvent;
}
