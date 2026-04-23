// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/xp_calculator.dart';

part 'xp_state.freezed.dart';
part 'xp_state.g.dart';

/// High-level projection of a user's XP state used by UI consumers.
///
/// This is the exact shape 17d (character sheet), 17e (home LVL line),
/// and 16b (paywall personalization) read. See PLAN.md §17b "Providers".
///
/// Derived fields:
///   * [xpIntoLevel] — XP accumulated within the current level (0..xpToNext-1)
///   * [xpToNext]    — XP remaining to advance to the next level
///
/// Both are exposed explicitly so the LVL bar can be rendered without UI
/// code having to know about kXpCurve indices. The XP-into-level /
/// XP-remaining maths happens in [GamificationSummary.fromTotal] and is
/// covered by unit tests.
@freezed
abstract class GamificationSummary with _$GamificationSummary {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory GamificationSummary({
    required int totalXp,
    required int currentLevel,
    required int xpIntoLevel,
    required int xpToNext,
    required Rank rank,
  }) = _GamificationSummary;

  factory GamificationSummary.fromJson(Map<String, dynamic> json) =>
      _$GamificationSummaryFromJson(json);

  /// Build a [GamificationSummary] from a raw total XP value by consulting
  /// the shared level curve and rank thresholds.
  factory GamificationSummary.fromTotal(int totalXp) {
    final level = levelFromTotalXp(totalXp);
    final currentThreshold = xpForLevel(level);
    // At level 100 the "next level" doesn't exist; keep xpToNext at 0 to
    // avoid divide-by-zero in UI progress bars.
    final nextThreshold = level >= 100
        ? currentThreshold
        : xpForLevel(level + 1);
    // `levelFromTotalXp` returns LVL 1 even when totalXp < xpForLevel(1)
    // (fresh users start at LVL 1 with 0 XP). Clamp the base to the current
    // threshold so xpIntoLevel stays non-negative and xpToNext remains a
    // stable denominator for the progress bar — otherwise the gap would
    // shrink as the user earns XP inside the [0, xpForLevel(1)) band.
    final xpBase = totalXp < currentThreshold ? currentThreshold : totalXp;
    return GamificationSummary(
      totalXp: totalXp,
      currentLevel: level,
      xpIntoLevel: xpBase - currentThreshold,
      xpToNext: level >= 100 ? 0 : nextThreshold - xpBase,
      rank: rankFromTotalXp(totalXp),
    );
  }

  /// Zero-state used before any XP event has been recorded or read.
  static const GamificationSummary empty = GamificationSummary(
    totalXp: 0,
    currentLevel: 1,
    xpIntoLevel: 0,
    xpToNext: 0,
    rank: Rank.rookie,
  );
}
