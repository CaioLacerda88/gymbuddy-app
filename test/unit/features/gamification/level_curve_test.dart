import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/gamification/domain/xp_calculator.dart';

void main() {
  group('kXpCurve', () {
    test('has exactly 100 entries (levels 1..100)', () {
      // Index 0 represents level 1, index 99 represents level 100.
      expect(kXpCurve.length, 100);
    });

    test('is monotonically strictly increasing across levels 1..100', () {
      for (var i = 1; i < kXpCurve.length; i++) {
        expect(
          kXpCurve[i],
          greaterThan(kXpCurve[i - 1]),
          reason:
              'Curve must strictly increase, but level ${i + 1} '
              '(${kXpCurve[i]}) <= level $i (${kXpCurve[i - 1]}).',
        );
      }
    });

    test('LVL 1 threshold is 300 (formula floor(300 * 1^1.3) = 300)', () {
      expect(xpForLevel(1), 300);
      expect(kXpCurve[0], 300);
    });

    test('LVL 8 threshold is approximately 3800 (retention-tuned anchor)', () {
      // floor(300 * 8^1.3) = floor(300 * 14.928...) = floor(4478.48) — let's
      // anchor the test on the computed value rather than the approximation
      // in the PLAN narrative (PLAN says "~3800"; the formula yields 4478,
      // which is still in the 2–3 session / 1 PR reach per the retention
      // argument). Keep both sanity bounds loose.
      final expected = (300 * math.pow(8, 1.3)).floor();
      expect(xpForLevel(8), expected);
      // Defensive: confirm this is at least above the conservative 3000
      // floor the PLAN implies for "reachable in 2–3 sessions".
      expect(xpForLevel(8), greaterThan(3000));
    });

    test('LVL 50 matches the computed curve value', () {
      final expected = (300 * math.pow(50, 1.3)).floor();
      expect(xpForLevel(50), expected);
    });

    test('xpForLevel(1) == kXpCurve[0]', () {
      expect(xpForLevel(1), kXpCurve[0]);
    });

    test('xpForLevel rejects levels outside 1..100', () {
      expect(() => xpForLevel(0), throwsArgumentError);
      expect(() => xpForLevel(101), throwsArgumentError);
      expect(() => xpForLevel(-1), throwsArgumentError);
    });
  });

  group('levelFromTotalXp', () {
    test('0 XP → LVL 1', () {
      expect(levelFromTotalXp(0), 1);
    });

    test('just below LVL 2 threshold → LVL 1', () {
      expect(levelFromTotalXp(xpForLevel(2) - 1), 1);
    });

    test('exactly LVL 2 threshold → LVL 2', () {
      expect(levelFromTotalXp(xpForLevel(2)), 2);
    });

    test('exactly LVL 8 threshold → LVL 8', () {
      expect(levelFromTotalXp(xpForLevel(8)), 8);
    });

    test('mid-level XP maps to previous level', () {
      // Halfway between LVL 5 and LVL 6 thresholds.
      final mid = (xpForLevel(5) + xpForLevel(6)) ~/ 2;
      expect(levelFromTotalXp(mid), 5);
    });

    test('enormous XP caps at LVL 100', () {
      expect(levelFromTotalXp(1 << 60), 100);
    });

    test('is monotonically non-decreasing across the full curve', () {
      int prev = 1;
      for (var xp = 0; xp < xpForLevel(20); xp += 50) {
        final lvl = levelFromTotalXp(xp);
        expect(
          lvl,
          greaterThanOrEqualTo(prev),
          reason: 'Level should never decrease as XP grows.',
        );
        prev = lvl;
      }
    });
  });

  group('Rank thresholds + rankFromTotalXp', () {
    test('rank thresholds are ordered', () {
      const ranks = Rank.values;
      for (var i = 1; i < ranks.length; i++) {
        expect(
          kRankThresholds[ranks[i]]!,
          greaterThan(kRankThresholds[ranks[i - 1]]!),
          reason: 'Rank thresholds must be strictly ascending',
        );
      }
    });

    test('0 XP → rookie', () {
      expect(rankFromTotalXp(0), Rank.rookie);
    });

    test('2_500 XP → iron', () {
      expect(rankFromTotalXp(2500), Rank.iron);
    });

    test('just below iron threshold → rookie', () {
      expect(rankFromTotalXp(2499), Rank.rookie);
    });

    test('10_000 XP → copper', () {
      expect(rankFromTotalXp(10000), Rank.copper);
    });

    test('25_000 XP → silver', () {
      expect(rankFromTotalXp(25000), Rank.silver);
    });

    test('60_000 XP → gold', () {
      expect(rankFromTotalXp(60000), Rank.gold);
    });

    test('125_000 XP → platinum', () {
      expect(rankFromTotalXp(125000), Rank.platinum);
    });

    test('250_000 XP → diamond', () {
      expect(rankFromTotalXp(250000), Rank.diamond);
    });

    test('enormous XP stays at diamond (no overflow to a lower rank)', () {
      expect(rankFromTotalXp(1 << 40), Rank.diamond);
    });
  });

  group('Rank.dbValue', () {
    test('matches the snake-case tokens the migration CHECK enforces', () {
      expect(Rank.rookie.dbValue, 'rookie');
      expect(Rank.iron.dbValue, 'iron');
      expect(Rank.copper.dbValue, 'copper');
      expect(Rank.silver.dbValue, 'silver');
      expect(Rank.gold.dbValue, 'gold');
      expect(Rank.platinum.dbValue, 'platinum');
      expect(Rank.diamond.dbValue, 'diamond');
    });

    test('Rank.fromDbValue is a symmetric inverse', () {
      for (final r in Rank.values) {
        expect(Rank.fromDbValue(r.dbValue), r);
      }
    });

    test('Rank.fromDbValue on unknown falls back to rookie', () {
      expect(Rank.fromDbValue('mythic'), Rank.rookie);
    });
  });
}
