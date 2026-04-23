/// Unit tests for GamificationSummary.fromTotal.
///
/// Covers:
///   - Normal level derivation from total XP
///   - xpIntoLevel and xpToNext are non-negative (clamped)
///   - Level 100 cap: xpToNext is 0 (no divide-by-zero for progress bars)
///   - Rank is derived correctly from the same total
///   - GamificationSummary.empty is a valid zero-state
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/gamification/domain/xp_calculator.dart';
import 'package:repsaga/features/gamification/models/xp_state.dart';

void main() {
  group('GamificationSummary.fromTotal', () {
    test('0 XP → level 1, rookie, xpToNext > 0', () {
      final s = GamificationSummary.fromTotal(0);
      expect(s.currentLevel, 1);
      expect(s.totalXp, 0);
      expect(s.rank, Rank.rookie);
      expect(s.xpToNext, greaterThan(0));
      expect(s.xpIntoLevel, 0);
    });

    test('totalXp at exactly LVL 2 threshold → level 2', () {
      final xp = xpForLevel(2);
      final s = GamificationSummary.fromTotal(xp);
      expect(s.currentLevel, 2);
      expect(s.xpIntoLevel, 0);
      expect(s.xpToNext, xpForLevel(3) - xp);
    });

    test('xpIntoLevel is always non-negative', () {
      // Regression guard: the formula `totalXp - currentThreshold` could
      // theoretically be negative if kXpCurve is not aligned with
      // levelFromTotalXp. Verify across representative levels.
      for (final xp in [0, 100, 500, 2500, 10000, 60000, 250000]) {
        final s = GamificationSummary.fromTotal(xp);
        expect(
          s.xpIntoLevel,
          greaterThanOrEqualTo(0),
          reason: 'xpIntoLevel must be >= 0 at totalXp=$xp',
        );
      }
    });

    test('xpToNext is always non-negative', () {
      for (final xp in [0, 100, 500, 2500, 10000, 60000, 250000]) {
        final s = GamificationSummary.fromTotal(xp);
        expect(
          s.xpToNext,
          greaterThanOrEqualTo(0),
          reason: 'xpToNext must be >= 0 at totalXp=$xp',
        );
      }
    });

    test('level 100 cap: xpToNext is 0, xpIntoLevel >= 0', () {
      // At level 100 there is no "next" level. xpToNext must be 0 so UI
      // progress bars don't show negative remaining XP.
      final maxXp = xpForLevel(100) + 50_000; // well past cap
      final s = GamificationSummary.fromTotal(maxXp);
      expect(s.currentLevel, 100);
      expect(s.xpToNext, 0);
      expect(s.xpIntoLevel, greaterThanOrEqualTo(0));
    });

    test('enormous XP stays at level 100 (no overflow)', () {
      final s = GamificationSummary.fromTotal(1 << 30);
      expect(s.currentLevel, 100);
      expect(s.rank, Rank.diamond);
    });

    test('rank transitions match kRankThresholds', () {
      expect(GamificationSummary.fromTotal(0).rank, Rank.rookie);
      expect(GamificationSummary.fromTotal(2500).rank, Rank.iron);
      expect(GamificationSummary.fromTotal(10000).rank, Rank.copper);
      expect(GamificationSummary.fromTotal(250000).rank, Rank.diamond);
    });
  });

  group('GamificationSummary.empty', () {
    test('is a valid zero-state with level 1 and rookie rank', () {
      const s = GamificationSummary.empty;
      expect(s.totalXp, 0);
      expect(s.currentLevel, 1);
      expect(s.xpIntoLevel, 0);
      expect(s.xpToNext, 0);
      expect(s.rank, Rank.rookie);
    });

    test('supports value equality', () {
      expect(GamificationSummary.empty, GamificationSummary.empty);
    });
  });

  group('GamificationSummary.fromJson / toJson round-trip', () {
    test('serializes and deserializes correctly', () {
      final original = GamificationSummary.fromTotal(5000);
      final json = original.toJson();
      final restored = GamificationSummary.fromJson(json);
      expect(restored, original);
    });

    test('snake_case json keys match expected DB column names', () {
      final s = GamificationSummary.fromTotal(0);
      final json = s.toJson();
      // Freezed FieldRename.snake maps currentLevel → current_level etc.
      expect(
        json.keys,
        containsAll([
          'total_xp',
          'current_level',
          'xp_into_level',
          'xp_to_next',
          'rank',
        ]),
      );
    });
  });
}
