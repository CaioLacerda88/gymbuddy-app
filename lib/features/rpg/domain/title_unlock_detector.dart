import '../models/body_part.dart';
import '../models/title.dart';

/// A single body-part rank transition produced by `record_set_xp`.
///
/// `oldRank` is the rank value BEFORE the workout's XP applied; `newRank` is
/// the rank value AFTER. The detector treats a title as "newly unlocked" when
/// its threshold is in the half-open interval `(oldRank, newRank]` — equality
/// to `newRank` fires (boundary case) but equality to `oldRank` does not (the
/// title was unlocked in a prior workout).
class RankDelta {
  const RankDelta({
    required this.bodyPart,
    required this.oldRank,
    required this.newRank,
  });

  final BodyPart bodyPart;
  final int oldRank;
  final int newRank;
}

/// Pure-function detector for the per-body-part title ladder (Phase 18c v1).
///
/// **Why this is a pure static function instead of a method on the repo or a
/// notifier:** the input is fully described by `(deltas, alreadyEarnedSlugs,
/// catalog)` and the output is fully determined by it. Keeping it pure means
/// it's unit-testable without a Supabase mock, and the orchestrator
/// (`ActiveWorkoutNotifier._finishOnline`) can run it on either the live
/// `record_set_xp` payload or a backfill replay without conditioning on the
/// caller.
///
/// **Boundary semantics (locked):**
///   * threshold == newRank → unlocked this workout
///   * threshold == oldRank → not unlocked (already-earned in a prior workout)
///   * threshold < oldRank → already earned, ignored
///   * threshold > newRank → not yet earned, ignored
///   * threshold ∈ (oldRank, newRank] AND slug ∈ alreadyEarnedSlugs → skipped
///     (idempotency guard against retried saves)
///
/// **Output ordering:** the catalog is iterated in its on-disk order, so
/// titles surface body-part-grouped, ascending threshold. The
/// [CelebrationQueue] re-orders them per the playback rules; the detector
/// itself is stable but not opinionated about presentation order.
///
/// Character-level + cross-build title detection arrives in Phase 18e — v1
/// covers the per-body-part ladder only (78 titles).
class TitleUnlockDetector {
  const TitleUnlockDetector._();

  /// Returns the titles unlocked by [deltas], filtered through
  /// [alreadyEarnedSlugs]. The order matches the catalog iteration order.
  static List<Title> detect({
    required List<RankDelta> deltas,
    required Set<String> alreadyEarnedSlugs,
    required List<Title> catalog,
  }) {
    if (deltas.isEmpty || catalog.isEmpty) {
      return const <Title>[];
    }

    // Index deltas by body part so the catalog walk is O(catalog) rather
    // than O(catalog × deltas). Multiple deltas for the same body part in
    // one workout would be a `record_set_xp` bug — defensively last-wins
    // on (oldRank, newRank), but in practice we expect one entry per body
    // part per finish.
    final deltaByBodyPart = <BodyPart, RankDelta>{};
    for (final d in deltas) {
      if (d.oldRank == d.newRank) continue;
      deltaByBodyPart[d.bodyPart] = d;
    }
    if (deltaByBodyPart.isEmpty) {
      return const <Title>[];
    }

    final unlocked = <Title>[];
    for (final entry in catalog) {
      final delta = deltaByBodyPart[entry.bodyPart];
      if (delta == null) continue;
      // Half-open interval: threshold > oldRank AND threshold <= newRank.
      if (entry.rankThreshold <= delta.oldRank) continue;
      if (entry.rankThreshold > delta.newRank) continue;
      if (alreadyEarnedSlugs.contains(entry.slug)) continue;
      unlocked.add(entry);
    }
    return unlocked;
  }
}
