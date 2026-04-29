import '../models/body_part.dart';
import '../models/title.dart';

/// Pure evaluator for the five cross-build distinction predicates (spec §10.3).
///
/// **Why a free-standing evaluator instead of a method on [Title]:** the JSON
/// catalog drives the slug+trigger metadata, but the predicate logic — AND/OR
/// across multiple body parts, ratio comparisons, "all six within 30%" — is
/// not expressible in JSON. Keeping the predicates here makes the v1 → v2
/// evolution path clean: cardio gets its own predicate alongside `iron_bound`
/// without touching the JSON envelope schema.
///
/// **Why pure / static:** identical to [`ClassResolver`](class_resolver.dart) —
/// the input is fully described by the rank map and the output is fully
/// determined by it. Pure functions are testable without a Riverpod
/// container, and the celebration-event builder can call this from any
/// snapshot pair without conditioning on the call site.
///
/// **Cardio in v1:** the `iron_bound` predicate per the spec is "Chest+Back+
/// Legs ≥ 60 AND cardio is low" — but in v1 cardio doesn't earn XP, so the
/// cardio condition is dropped. The trigger fires on the strength condition
/// alone. When v2 ships cardio XP, add the cardio condition here without
/// touching consumers.
class CrossBuildTitleEvaluator {
  const CrossBuildTitleEvaluator._();

  /// Floor every cross-build trigger requires before it can fire. Below this
  /// floor, the user is still consolidating and earning a structural title
  /// would feel unearned — every predicate gates on at least Rank 30 in some
  /// dimension.
  ///
  /// `iron_bound` and `saga_forged` use higher floors (60); `even_handed`
  /// uses 30. The min across all five is 30, so this is also the
  /// "any predicate could fire" lower bound.
  static const int evenHandedMinRank = 30;

  /// Spread fraction for `even_handed` — every body part must be within 30%
  /// of the max rank. Mirrors [`ClassResolver.ascendantSpreadFraction`] but
  /// at a higher minimum-rank floor (30 vs 5) so the title represents
  /// sustained balance rather than entry-level distribution.
  static const double evenHandedSpreadFraction = 0.30;

  /// Evaluate every cross-build trigger and return the slugs that fire for
  /// the given rank distribution.
  ///
  /// [ranks] is keyed by [BodyPart]; missing entries default to rank 1
  /// (matches the SQL default-row + [`RpgProgressSnapshot.progressFor`]
  /// contract). Cardio entries are ignored — v1 cardio is a v2 concern.
  ///
  /// Returns slugs in catalog order ([CrossBuildTriggerId.values] order):
  /// `pillar_walker, broad_shouldered, even_handed, iron_bound, saga_forged`.
  /// The detector's idempotency guard (`alreadyEarnedSlugs`) deduplicates
  /// against the persisted record set.
  static List<String> evaluate(Map<BodyPart, int> ranks) {
    // Project to active body parts only, defaulting missing entries to
    // rank 1 (matches the resolver convention).
    int rank(BodyPart bp) => ranks[bp] ?? 1;

    final chest = rank(BodyPart.chest);
    final back = rank(BodyPart.back);
    final legs = rank(BodyPart.legs);
    final shoulders = rank(BodyPart.shoulders);
    final arms = rank(BodyPart.arms);
    final core = rank(BodyPart.core);

    final fired = <String>[];

    if (_pillarWalker(legs: legs, arms: arms)) {
      fired.add(CrossBuildTriggerId.pillarWalker.dbValue);
    }
    if (_broadShouldered(
      chest: chest,
      back: back,
      shoulders: shoulders,
      legs: legs,
      core: core,
    )) {
      fired.add(CrossBuildTriggerId.broadShouldered.dbValue);
    }
    if (_evenHanded(chest, back, legs, shoulders, arms, core)) {
      fired.add(CrossBuildTriggerId.evenHanded.dbValue);
    }
    if (_ironBound(chest: chest, back: back, legs: legs)) {
      fired.add(CrossBuildTriggerId.ironBound.dbValue);
    }
    if (_sagaForged(chest, back, legs, shoulders, arms, core)) {
      fired.add(CrossBuildTriggerId.sagaForged.dbValue);
    }

    return fired;
  }

  /// `pillar_walker` — Legs ≥ 40 AND Legs ≥ 2 × Arms.
  ///
  /// "Walks on legs, not arms" — the lifter who chases lower-body strength.
  /// Both conditions matter: a lifter with legs 40 and arms 25 is
  /// chest-dominant by the spread, not pillar-walking.
  static bool _pillarWalker({required int legs, required int arms}) {
    if (legs < 40) return false;
    return legs >= 2 * arms;
  }

  /// `broad_shouldered` — Chest+Back+Shoulders ≥ 2 × (Legs+Core) AND every
  /// upper-body track ≥ 30.
  ///
  /// Classic upper-body specialist. The 2× ratio is intentionally aggressive
  /// — a 50/50 split routes to a different class; broad-shouldered is the
  /// genuinely upper-body-dominant build.
  static bool _broadShouldered({
    required int chest,
    required int back,
    required int shoulders,
    required int legs,
    required int core,
  }) {
    if (chest < 30) return false;
    if (back < 30) return false;
    if (shoulders < 30) return false;
    final upper = chest + back + shoulders;
    final lower = legs + core;
    return upper >= 2 * lower;
  }

  /// `even_handed` — Every active rank within 30% of max AND every rank ≥ 30.
  ///
  /// Mirrors [`ClassResolver`]'s Ascendant predicate at a higher rank floor
  /// — the title is the persistent-balance reward, where the class is the
  /// snapshot-balance reward. A lifter can be Ascendant from rank 5+ but
  /// only Even-Handed once every track reaches 30.
  static bool _evenHanded(int a, int b, int c, int d, int e, int f) {
    if (a < evenHandedMinRank) return false;
    if (b < evenHandedMinRank) return false;
    if (c < evenHandedMinRank) return false;
    if (d < evenHandedMinRank) return false;
    if (e < evenHandedMinRank) return false;
    if (f < evenHandedMinRank) return false;
    final values = [a, b, c, d, e, f];
    final maxRank = values.reduce((a, b) => a > b ? a : b);
    final minRank = values.reduce((a, b) => a < b ? a : b);
    final spread = (maxRank - minRank) / maxRank;
    return spread <= evenHandedSpreadFraction;
  }

  /// `iron_bound` — Chest+Back+Legs ≥ 60.
  ///
  /// "The big-three of strength training" — the powerlifter heuristic.
  /// Cardio condition (low cardio) is v2 — v1 ignores cardio entirely so
  /// the trigger fires on the strength sum alone.
  static bool _ironBound({
    required int chest,
    required int back,
    required int legs,
  }) {
    return chest >= 60 && back >= 60 && legs >= 60;
  }

  /// `saga_forged` — Every active rank ≥ 60.
  ///
  /// The end-game prestige title. By the time every track is at rank 60
  /// the user has been training consistently for many months — this title
  /// signals "I have done the work" rather than any specific build shape.
  static bool _sagaForged(int a, int b, int c, int d, int e, int f) {
    return a >= 60 && b >= 60 && c >= 60 && d >= 60 && e >= 60 && f >= 60;
  }
}
