import '../models/body_part.dart';
import '../models/title.dart';
import 'cross_build_title_evaluator.dart';

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

/// Pure-function detectors for the three v1 title kinds (Phase 18c + 18e).
///
/// **Why three static methods on one class instead of three classes:** the
/// methods share the boundary semantics (half-open `(old, new]` interval +
/// `alreadyEarnedSlugs` idempotency guard) and the orchestrator
/// (`CelebrationEventBuilder.build`) calls all three on the same snapshot
/// pair. Keeping them co-located makes the contract visible: every detector
/// returns slugs (not Title objects, not TitleUnlockEvents) and the builder
/// resolves the catalog once for downstream rendering.
///
/// **Why pure static functions instead of methods on the repo or a notifier:**
/// the input is fully described by `(deltas, alreadyEarnedSlugs, catalog)`
/// and the output is fully determined by it. Keeping them pure means they're
/// unit-testable without a Supabase mock, and the orchestrator can run them
/// on either the live `record_set_xp` payload or a backfill replay without
/// conditioning on the caller.
///
/// **Boundary semantics (locked, applies to body-part + character-level):**
///   * threshold == newRank → unlocked this workout
///   * threshold == oldRank → not unlocked (already-earned in a prior workout)
///   * threshold < oldRank → already earned, ignored
///   * threshold > newRank → not yet earned, ignored
///   * threshold ∈ (oldRank, newRank] AND slug ∈ alreadyEarnedSlugs → skipped
///     (idempotency guard against retried saves)
///
/// Cross-build detection has no rank-delta interval — it's a snapshot
/// predicate evaluated against the post-save rank distribution. Idempotency
/// is the same: any slug in `alreadyEarnedSlugs` is filtered out.
class TitleUnlockDetector {
  const TitleUnlockDetector._();

  /// Returns the body-part titles unlocked by [deltas], filtered through
  /// [alreadyEarnedSlugs]. The order matches the catalog iteration order.
  ///
  /// Filters [catalog] to [BodyPartTitle] entries — character-level and
  /// cross-build entries are evaluated by the dedicated detectors.
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
      if (entry is! BodyPartTitle) continue;
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

  /// Returns the character-level titles unlocked by the [oldLevel] →
  /// [newLevel] transition, filtered through [alreadyEarnedSlugs].
  ///
  /// Boundary semantics mirror [detect]: a threshold equal to [newLevel]
  /// fires, equal to [oldLevel] does not. Same idempotency rule via
  /// [alreadyEarnedSlugs].
  ///
  /// Filters [catalog] to [CharacterLevelTitle] entries. Returns the empty
  /// list when [newLevel] <= [oldLevel] (no transition).
  static List<Title> detectCharacterLevel({
    required int oldLevel,
    required int newLevel,
    required Set<String> alreadyEarnedSlugs,
    required List<Title> catalog,
  }) {
    if (newLevel <= oldLevel || catalog.isEmpty) {
      return const <Title>[];
    }
    final unlocked = <Title>[];
    for (final entry in catalog) {
      if (entry is! CharacterLevelTitle) continue;
      // Half-open interval: threshold > oldLevel AND threshold <= newLevel.
      if (entry.levelThreshold <= oldLevel) continue;
      if (entry.levelThreshold > newLevel) continue;
      if (alreadyEarnedSlugs.contains(entry.slug)) continue;
      unlocked.add(entry);
    }
    return unlocked;
  }

  /// Returns the cross-build titles that fire for the post-save rank
  /// distribution, filtered through [alreadyEarnedSlugs].
  ///
  /// Cross-build detection has no rank-delta interval — it's a snapshot
  /// predicate evaluated against [rankMap]. The detector runs every
  /// workout-finish (cheap: 5 predicates, all O(1)) and the
  /// [alreadyEarnedSlugs] guard handles idempotency exactly as the other
  /// detectors do.
  ///
  /// Filters [catalog] to [CrossBuildTitle] entries; the trigger predicates
  /// live in [`CrossBuildTitleEvaluator`].
  static List<Title> detectCrossBuild({
    required Map<BodyPart, int> rankMap,
    required Set<String> alreadyEarnedSlugs,
    required List<Title> catalog,
  }) {
    if (catalog.isEmpty) {
      return const <Title>[];
    }
    final firedSlugs = CrossBuildTitleEvaluator.evaluate(rankMap).toSet();
    if (firedSlugs.isEmpty) {
      return const <Title>[];
    }
    final unlocked = <Title>[];
    for (final entry in catalog) {
      if (entry is! CrossBuildTitle) continue;
      if (!firedSlugs.contains(entry.slug)) continue;
      if (alreadyEarnedSlugs.contains(entry.slug)) continue;
      unlocked.add(entry);
    }
    return unlocked;
  }
}
