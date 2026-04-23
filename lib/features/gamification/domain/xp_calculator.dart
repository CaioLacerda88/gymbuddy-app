import 'dart:math' as math;

import '../../personal_records/models/record_type.dart';
import '../../workouts/models/exercise_set.dart';
import '../../workouts/models/set_type.dart';
import '../models/xp_breakdown.dart';

/// Per-PR payload passed into [XpCalculator.compute].
///
/// The calculator only needs the record type (weight vs rep) to decide
/// between the +100 heavy and +50 rep PR contribution. Carrying the full
/// [PersonalRecord] would force every unit test to build a Freezed model
/// for something the calculator never reads. A thin value object keeps
/// the calculator independent from the PR domain beyond [RecordType].
class XpPrAward {
  const XpPrAward({required this.recordType});

  final RecordType recordType;
}

/// Stateless XP calculator.
///
/// Pure function surface: every call with the same inputs must return the
/// same breakdown. No clock reads, no provider access, no IO. The repository
/// wraps this and persists via the `award_xp` RPC; the calculator itself is
/// trivially unit-testable with no mocks.
///
/// Formula (PLAN.md §17b):
///
///   base      = 50 per workout (flat floor)
///   volume    = floor(totalKg / 500)
///               where totalKg = sum(weight * reps) over
///               completed *working* sets (warm-ups / drop sets excluded)
///   intensity = sum((rpe - 5) * 10) for rpe > 5
///               over completed working sets
///   pr        = 100 per max-weight PR, 50 per max-reps/max-volume PR
///   quest     = 75 when hasCompletedQuest = true (17e / 18a)
///   comeback  = ×2 multiplier applied to (base + volume + intensity + pr + quest)
///               when isComeback = true; stored as the *delta* from the
///               single-pass sum so [XpBreakdown] keeps the invariant
///               `total == sum(all components)`.
///
/// The comeback path in 17b always passes `isComeback = false`; 17c flips
/// it on for the first workout after a skipped-week. The multiplier path is
/// exercised here so 17c is a one-line flag flip, not a refactor.
class XpCalculator {
  const XpCalculator._();

  /// Flat base XP awarded per workout.
  static const int kBase = 50;

  /// kg-per-volume-point — 500 kg of total volume awards 1 XP.
  static const int kKgPerVolumePoint = 500;

  /// Bonus per RPE-point above 5.
  static const int kIntensityPointsPerRpe = 10;

  /// Heavy PR (max-weight) contribution.
  static const int kHeavyPrXp = 100;

  /// Rep / volume PR contribution.
  static const int kRepPrXp = 50;

  /// Flat bonus for a completed weekly quest.
  static const int kQuestXp = 75;

  /// Compute the per-workout XP breakdown from the workout's completed sets,
  /// the PRs detected by [PRDetectionService], and two orchestration flags.
  ///
  /// [sets] may include non-completed sets and non-working types — they are
  /// filtered here so callers don't have to duplicate the filter logic that
  /// already exists on [completedWorkingSets].
  static XpBreakdown compute({
    required List<ExerciseSet> sets,
    required List<XpPrAward> prs,
    bool isComeback = false,
    bool hasCompletedQuest = false,
  }) {
    final workingSets = sets
        .where((s) => s.isCompleted && s.setType == SetType.working)
        .toList(growable: false);

    // Volume — floor(totalKg / 500). totalKg is the sum of weight * reps
    // across completed working sets. Missing weight or reps contribute 0
    // (the set is effectively a marker, not a lift).
    num totalKg = 0;
    for (final s in workingSets) {
      final w = s.weight ?? 0;
      final r = s.reps ?? 0;
      totalKg += w * r;
    }
    final volume = (totalKg / kKgPerVolumePoint).floor();

    // Intensity — sum((rpe - 5) * 10) for rpe > 5.
    var intensity = 0;
    for (final s in workingSets) {
      final rpe = s.rpe;
      if (rpe != null && rpe > 5) {
        intensity += (rpe - 5) * kIntensityPointsPerRpe;
      }
    }

    // PR points — weight PRs worth 100, rep/volume PRs worth 50 each.
    var prXp = 0;
    for (final p in prs) {
      prXp += switch (p.recordType) {
        RecordType.maxWeight => kHeavyPrXp,
        RecordType.maxReps => kRepPrXp,
        RecordType.maxVolume => kRepPrXp,
      };
    }

    final quest = hasCompletedQuest ? kQuestXp : 0;

    // Comeback is a multiplier on the sum of the four single-pass components
    // above (PLAN: "comeback x2, applied last"). We store the multiplier as
    // a separate component so the UI can label the bonus line distinctly
    // and so total == sum(all components) always holds.
    final singlePass = kBase + volume + intensity + prXp + quest;
    final comeback = isComeback ? singlePass : 0;
    final total = singlePass + comeback;

    return XpBreakdown(
      base: kBase,
      volume: volume,
      intensity: intensity,
      pr: prXp,
      quest: quest,
      comeback: comeback,
      total: total,
    );
  }
}

// ---------------------------------------------------------------------------
// Level curve
// ---------------------------------------------------------------------------

/// Number of supported levels. Matches [kXpCurve].length.
const int kMaxLevel = 100;

int _computeThreshold(int level) => (300 * math.pow(level, 1.3)).floor();

/// Total XP required to reach the given [level].
///
/// Formula: `floor(300 * pow(level, 1.3))`.
/// Accepts integer levels in `[1, kMaxLevel]`; throws [ArgumentError]
/// otherwise. The curve is retention-tuned so a first-week user hits
/// LVL 8 within 2–3 sessions with one PR (see PLAN.md §17 "Retention
/// Dependency").
int xpForLevel(int level) {
  if (level < 1 || level > kMaxLevel) {
    throw ArgumentError.value(level, 'level', 'must be in [1, $kMaxLevel]');
  }
  return kXpCurve[level - 1];
}

/// Precomputed `xpForLevel(n)` for `n` in 1..100.
///
/// Precomputation is more about call-site clarity than speed — an immutable
/// list populated once at startup lets callers iterate thresholds without
/// re-running `pow` on every frame. The curve itself never changes at runtime.
final List<int> kXpCurve = List<int>.unmodifiable(
  List<int>.generate(kMaxLevel, (i) => _computeThreshold(i + 1)),
);

/// Given a total XP value, return the highest level whose threshold the
/// value meets or exceeds.
///
/// Binary-searches [kXpCurve]. Returns 1 for `totalXp < xpForLevel(1)` —
/// there is no LVL 0. Caps at [kMaxLevel].
int levelFromTotalXp(int totalXp) {
  if (totalXp < kXpCurve[0]) return 1;
  // Binary search: find the largest i such that kXpCurve[i] <= totalXp.
  var lo = 0;
  var hi = kXpCurve.length - 1;
  var answer = 0;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (kXpCurve[mid] <= totalXp) {
      answer = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return answer + 1;
}

// ---------------------------------------------------------------------------
// Ranks
// ---------------------------------------------------------------------------

/// Bronze/iron → diamond rank ladder.
///
/// Rank is a *coarse* progression signal separate from level: a fresh user
/// is rookie regardless of LVL. The threshold table below encodes the
/// PLAN-locked values; keeping them here instead of SQL lets 17d retune
/// without a migration.
enum Rank {
  rookie,
  iron,
  copper,
  silver,
  gold,
  platinum,
  diamond;

  /// Token used in the DB (`user_xp.rank CHECK` + `award_xp` breakdown).
  String get dbValue => name;

  /// Parse the stored token back into a [Rank]. Unknown tokens degrade
  /// gracefully to [Rank.rookie] so a future server-side rank enum
  /// extension never breaks existing clients.
  static Rank fromDbValue(String value) {
    for (final r in Rank.values) {
      if (r.dbValue == value) return r;
    }
    return Rank.rookie;
  }
}

/// Total-XP threshold each rank unlocks at.
///
/// Per PLAN.md §17b: Rookie(0) → Iron(2_500) → Copper(10_000) →
/// Silver(25_000) → Gold(60_000) → Platinum(125_000) → Diamond(250_000).
const Map<Rank, int> kRankThresholds = {
  Rank.rookie: 0,
  Rank.iron: 2500,
  Rank.copper: 10000,
  Rank.silver: 25000,
  Rank.gold: 60000,
  Rank.platinum: 125000,
  Rank.diamond: 250000,
};

/// Return the highest rank whose threshold [totalXp] has reached.
Rank rankFromTotalXp(int totalXp) {
  // Walk the enum in reverse (highest threshold first) and return the
  // first match. `values` is guaranteed to be in declaration order.
  for (final r in Rank.values.reversed) {
    final t = kRankThresholds[r];
    if (t != null && totalXp >= t) return r;
  }
  return Rank.rookie;
}
