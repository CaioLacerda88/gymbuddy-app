import 'dart:math' as math;

/// Rank curve (spec §6).
///
/// ```
/// xp_to_next(n)            = 60 × 1.10^(n - 1)
/// xp_cumulative_for_rank(n) = 60 × (1.10^(n - 1) - 1) / 0.10
/// ```
///
/// The cumulative curve is precomputed for ranks 1..99 — the lookup table
/// is loaded once at startup and never recomputed. The function form is
/// kept for tests + sanity checks.
class RankCurve {
  const RankCurve._();

  /// Visible rank cap. The underlying XP formula keeps growing past this;
  /// the UI clamps at 99.
  static const int maxRank = 99;

  /// Base — XP needed for rank 2 (the first rank-up).
  static const double xpBase = 60.0;

  /// Geometric growth factor between successive `xp_to_next` levels.
  static const double xpGrowth = 1.10;

  /// XP delta `xp_to_next(n)` — XP to advance from rank `n` to rank `n + 1`.
  ///
  /// Rank 1 → 2 needs `xpBase` (60 XP). The geometric factor compounds
  /// thereafter. Asserts `n >= 1`.
  static double xpToNext(int rank) {
    assert(rank >= 1, 'rank must be >= 1');
    return xpBase * math.pow(xpGrowth, rank - 1).toDouble();
  }

  /// Cumulative XP at the start of rank `n`.
  ///
  /// `cumulativeXpForRank(1) == 0` — every user starts at rank 1 with 0 XP.
  /// `cumulativeXpForRank(2) == 60`, `cumulativeXpForRank(99)` ≈ 6.83M
  /// per spec §6 table.
  static double cumulativeXpForRank(int rank) {
    assert(rank >= 1, 'rank must be >= 1');
    if (rank == 1) return 0.0;
    final geom = math.pow(xpGrowth, rank - 1).toDouble();
    return xpBase * (geom - 1) / (xpGrowth - 1);
  }

  /// Highest rank whose cumulative XP threshold `totalXp` has reached.
  ///
  /// Caps at [maxRank]. Total XP ≥ `cumulativeXpForRank(99)` returns 99.
  /// Negative or zero XP returns 1.
  ///
  /// Implementation uses the lookup table — O(log n) binary search. The
  /// closed-form inverse (`log(1 + totalXp × 0.10 / 60) / log(1.10) + 1`)
  /// is mathematically correct but produces float drift at high ranks
  /// (rank 99 has cumulative XP ≈ 6.8M; subtracting 60/0.10 then dividing by
  /// log(1.10) loses ~6 digits of precision). Lookup-table is cheap (99
  /// entries), exact, and keeps Dart parity with the SQL implementation
  /// (which also uses a precomputed table for the same reason).
  static int rankForXp(num totalXp) {
    if (totalXp <= 0) return 1;
    if (totalXp >= _cumulativeTable[maxRank - 1]) return maxRank;
    // Binary search for the largest rank n where cumulativeXpForRank(n) <= totalXp.
    var lo = 0;
    var hi = _cumulativeTable.length - 1;
    var answer = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_cumulativeTable[mid] <= totalXp) {
        answer = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    // _cumulativeTable[i] = cumulativeXpForRank(i + 1) → answer index 0 == rank 1.
    return answer + 1;
  }

  /// XP earned within the user's current rank — `totalXp - cumulativeXpForRank(rank)`.
  /// Returns 0 if `totalXp` is below the rank's threshold (defensive — this
  /// shouldn't happen with a consistent rank value but UI code shouldn't
  /// crash on stale state).
  static double xpInRank(num totalXp, int rank) {
    final base = cumulativeXpForRank(rank);
    final delta = totalXp - base;
    return delta < 0 ? 0 : delta.toDouble();
  }

  /// XP remaining to reach the next rank — `xpToNext(rank) - xpInRank(...)`.
  /// At [maxRank] this returns 0 (no further progression on the visible bar).
  static double xpToNextRank(num totalXp, int rank) {
    if (rank >= maxRank) return 0;
    final inRank = xpInRank(totalXp, rank);
    final to = xpToNext(rank);
    final remaining = to - inRank;
    return remaining < 0 ? 0 : remaining;
  }

  /// Progress fraction within the current rank — `xpInRank / xpToNext(rank)`,
  /// clamped to [0, 1]. At maxRank returns 1.0 (filled bar).
  static double progressFraction(num totalXp, int rank) {
    if (rank >= maxRank) return 1.0;
    final inRank = xpInRank(totalXp, rank);
    final to = xpToNext(rank);
    if (to <= 0) return 0;
    final p = inRank / to;
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p;
  }

  // ---- precomputed cumulative table ----------------------------------------

  /// `_cumulativeTable[i]` = `cumulativeXpForRank(i + 1)`. Length 99.
  static final List<double> _cumulativeTable = List<double>.unmodifiable(
    List<double>.generate(maxRank, (i) => cumulativeXpForRank(i + 1)),
  );

  /// Read-only view of the precomputed cumulative table — exposed for tests
  /// and any consumer that needs a rank-by-rank list (e.g. progress bars
  /// rendering threshold ticks).
  static List<double> get cumulativeTable => _cumulativeTable;
}

/// Character Level (spec §7).
///
/// ```
/// character_level = max(1, floor((Σ active_ranks - N_active) / 4) + 1)
/// ```
///
/// v1: `N_active = 6` (chest, back, legs, shoulders, arms, core).
/// When cardio ships in v2 the constant flips to 7 and the formula is
/// unchanged.
int characterLevel(
  Map<String, int> ranks, {
  List<String> activeKeys = _activeKeys,
}) {
  var total = 0;
  var n = 0;
  for (final key in activeKeys) {
    final r = ranks[key];
    if (r == null) continue;
    total += r;
    n += 1;
  }
  if (n == 0) return 1;
  final lvl = ((total - n) ~/ 4) + 1;
  return lvl < 1 ? 1 : lvl;
}

/// v1 active-rank keys. Matches `BodyPart.dbValue` for the six strength
/// tracks. Kept as `String` instead of `BodyPart` so the helper is
/// model-import-free and trivially testable.
const List<String> _activeKeys = [
  'chest',
  'back',
  'legs',
  'shoulders',
  'arms',
  'core',
];
