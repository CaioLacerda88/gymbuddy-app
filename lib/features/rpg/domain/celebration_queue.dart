import '../models/celebration_event.dart';

/// Result of [CelebrationQueue.build] — the ordered playback list plus an
/// optional overflow card payload when the cap-at-3 rule trims rank-ups.
class CelebrationQueueResult {
  const CelebrationQueueResult({required this.queue, this.overflow});

  /// Ordered events to render. Length is at most 3 + (number of
  /// first-awakening events). First-awakening events bypass the cap because
  /// they are themselves session-throttled upstream (see
  /// `ActiveWorkoutNotifier._firstAwakeningFiredThisSession`) — at most one
  /// per workout.
  final List<CelebrationEvent> queue;

  /// Non-null when the cap-at-3 rule dropped one or more rank-ups. The UI
  /// renders a non-modal "{N} more rank-ups — open Saga" card after the
  /// last queue overlay (3s auto-dismiss, tappable).
  final OverflowPayload? overflow;
}

/// Payload for the condensed overflow card shown when more than 3 events
/// would otherwise queue. Currently only rank-ups can overflow — level-ups
/// and titles always survive the cap (see [CelebrationQueue.build]).
class OverflowPayload {
  const OverflowPayload({required this.remainingRankUps});

  final int remainingRankUps;
}

/// Pure transform that takes the unordered events from a workout finish and
/// produces the playback queue.
///
/// **Ordering rules (locked, spec §13.2):**
///   1. First-awakening events lead — they narratively precede the body part
///      ranking up at all. Throttled to one per workout upstream.
///   2. Rank-up events follow, sorted by `newRank` descending (biggest jump
///      first as tiebreaker — the lifter's biggest win leads the narrative).
///   3. The character level-up event (at most one per workout — character
///      level is a pure function of body-part ranks).
///   4. Title-unlock events close — they are the crown on the workout. Both
///      titles in a multi-unlock workout survive (no cap on titles).
///
/// **Cap-at-3 rule (locked, PO):**
///   * Total visible queue capped at 3 to keep the celebration under ~3.5s.
///   * First-awakening overlays bypass the cap (they're an onboarding moment,
///     800ms compressed, not part of the rank-celebration churn).
///   * When the cap bites, the *closing* events (level-up + titles) survive
///     and rank-ups are trimmed from the lowest-rank end. The narrative
///     "you ranked up the biggest body part, leveled up, earned a title"
///     reads better than "three rank-ups, no payoff."
///   * Trimmed rank-ups are summarized in [OverflowPayload.remainingRankUps]
///     so the overflow card can render "{N} more rank-ups — open Saga."
///
/// **Idempotency:** same input → same output. The dismiss-skip-end semantic
/// is owned by the runtime scheduler (`ActiveWorkoutNotifier`), not the
/// queue. A user dismissing mid-queue does not change what `build` returns.
class CelebrationQueue {
  const CelebrationQueue._();

  static const int _capExcludingAwakening = 3;

  /// Build the playback queue from [events].
  static CelebrationQueueResult build({
    required List<CelebrationEvent> events,
  }) {
    if (events.isEmpty) {
      return const CelebrationQueueResult(queue: <CelebrationEvent>[]);
    }

    // Bucket by event kind. Order within each bucket is canonicalized
    // before we apply the cap.
    final firstAwakenings = <FirstAwakeningEvent>[];
    final rankUps = <RankUpEvent>[];
    final levelUps = <LevelUpEvent>[];
    final titles = <TitleUnlockEvent>[];

    for (final e in events) {
      switch (e) {
        case FirstAwakeningEvent():
          firstAwakenings.add(e);
        case RankUpEvent():
          rankUps.add(e);
        case LevelUpEvent():
          levelUps.add(e);
        case TitleUnlockEvent():
          titles.add(e);
      }
    }

    // Highest body-part rank first so the biggest jump leads. Stable
    // secondary sort by body-part dbValue keeps output deterministic when
    // two body parts hit the same threshold in the same workout.
    rankUps.sort((a, b) {
      final cmp = b.newRank.compareTo(a.newRank);
      if (cmp != 0) return cmp;
      return a.bodyPart.dbValue.compareTo(b.bodyPart.dbValue);
    });

    // Compute how many rank-ups can fit alongside the closers. Cap excludes
    // first-awakenings (separate onboarding overlay).
    //
    // capacity = capExcludingAwakening - (level-ups kept) - (titles kept)
    final closersCount = levelUps.length + titles.length;
    final rankUpCapacity = (_capExcludingAwakening - closersCount).clamp(
      0,
      rankUps.length,
    );

    final keptRankUps = rankUps.take(rankUpCapacity).toList(growable: false);
    final overflowCount = rankUps.length - keptRankUps.length;

    final queue = <CelebrationEvent>[
      ...firstAwakenings,
      ...keptRankUps,
      ...levelUps,
      ...titles,
    ];

    final overflow = overflowCount > 0
        ? OverflowPayload(remainingRankUps: overflowCount)
        : null;

    return CelebrationQueueResult(queue: queue, overflow: overflow);
  }
}
