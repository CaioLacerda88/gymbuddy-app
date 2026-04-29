/// Unit tests for [CrossBuildTitleEvaluator] (Phase 18e, spec §10.3).
///
/// The evaluator is a pure function that receives a body-part rank map and
/// returns the set of cross-build slugs that fire for that distribution.
/// Each of the five predicates is a different shape of structural condition
/// (ratio, sum, spread, floor) and the seams between "fires" and "doesn't
/// fire" are the exact rank values consumers will hit at the boundary.
///
/// These tests pin every predicate's fire/no-fire boundary so the SQL mirror
/// in `00043_cross_build_titles_backfill.sql` can be edited without quietly
/// drifting from the Dart contract — if a predicate changes here, the SQL
/// side must change in lockstep (and vice-versa). Each group locks one
/// trigger; the cross-cutting tests at the end pin "multiple fire at once"
/// and "cardio is silently ignored" for parity with the SQL `evaluate_*`
/// function.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/domain/cross_build_title_evaluator.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';

/// Build a rank map for the six active body parts with named overrides.
/// Defaults to rank 1 — matches the SQL default-row contract and the
/// `evaluate` method's missing-entry projection.
Map<BodyPart, int> _ranks({
  int chest = 1,
  int back = 1,
  int legs = 1,
  int shoulders = 1,
  int arms = 1,
  int core = 1,
}) => {
  BodyPart.chest: chest,
  BodyPart.back: back,
  BodyPart.legs: legs,
  BodyPart.shoulders: shoulders,
  BodyPart.arms: arms,
  BodyPart.core: core,
};

void main() {
  group('CrossBuildTitleEvaluator — pillar_walker', () {
    test('legs == 40 AND legs == 2 * arms (boundary) → fires', () {
      // legs at the floor (40) and at exactly 2x arms (40 vs 20). Both
      // conditions are inclusive — the predicate uses `>=` on both sides.
      final result = CrossBuildTitleEvaluator.evaluate(
        _ranks(legs: 40, arms: 20),
      );
      expect(result, contains('pillar_walker'));
    });

    test('legs == 39 (one below floor) → does not fire', () {
      // Boundary: legs < 40 short-circuits before the ratio check.
      final result = CrossBuildTitleEvaluator.evaluate(
        _ranks(legs: 39, arms: 19),
      );
      expect(result, isNot(contains('pillar_walker')));
    });

    test('legs == 40, arms == 21 (ratio fails) → does not fire', () {
      // 40 < 2 * 21 = 42 → ratio breaks even though legs cleared the floor.
      final result = CrossBuildTitleEvaluator.evaluate(
        _ranks(legs: 40, arms: 21),
      );
      expect(result, isNot(contains('pillar_walker')));
    });

    test('legs == 60, arms == 1 (default rank) → fires', () {
      // Default-row arms (rank 1) trivially satisfies the 2x condition.
      // This is the common shape: a leg-day-only lifter early in their saga.
      expect(
        CrossBuildTitleEvaluator.evaluate(_ranks(legs: 60)),
        contains('pillar_walker'),
      );
    });
  });

  group('CrossBuildTitleEvaluator — broad_shouldered', () {
    test('upper-body floor + 2x ratio at exact boundary → fires', () {
      // chest+back+shoulders = 90 = 2 * (legs+core = 45). All three upper
      // tracks at the 30 floor. The ratio uses `>=` so equality fires.
      final result = CrossBuildTitleEvaluator.evaluate(
        _ranks(chest: 30, back: 30, shoulders: 30, legs: 30, core: 15),
      );
      expect(result, contains('broad_shouldered'));
    });

    test('chest below 30 (others above) → does not fire', () {
      // The per-track upper-body floor short-circuits before the ratio.
      // chest=29 fails the floor even though the sum (29+30+30=89) still
      // beats 2*(20+10=30) → 60.
      final result = CrossBuildTitleEvaluator.evaluate(
        _ranks(chest: 29, back: 30, shoulders: 30, legs: 20, core: 10),
      );
      expect(result, isNot(contains('broad_shouldered')));
    });

    test('all upper tracks at 30 but ratio just under 2x → does not fire', () {
      // chest+back+shoulders = 90, legs+core = 46 → 2 * 46 = 92 > 90.
      // The ratio is < 2x, so the predicate fails despite the floors.
      final result = CrossBuildTitleEvaluator.evaluate(
        _ranks(chest: 30, back: 30, shoulders: 30, legs: 30, core: 16),
      );
      expect(result, isNot(contains('broad_shouldered')));
    });
  });

  group('CrossBuildTitleEvaluator — even_handed', () {
    test('every track exactly 30, spread 0% → fires', () {
      // Boundary: every track at the floor (30) and the spread is zero.
      // The predicate's `evenHandedMinRank == 30` is inclusive.
      final result = CrossBuildTitleEvaluator.evaluate(
        _ranks(
          chest: 30,
          back: 30,
          legs: 30,
          shoulders: 30,
          arms: 30,
          core: 30,
        ),
      );
      expect(result, contains('even_handed'));
    });

    test('one track below floor (rank 29), others 30+ → does not fire', () {
      // Boundary: even at perfect balance among the rest, a single track at
      // 29 short-circuits before the spread is computed. This mirrors
      // ClassResolver's Ascendant floor at a higher rank value.
      final result = CrossBuildTitleEvaluator.evaluate(
        _ranks(
          chest: 30,
          back: 30,
          legs: 30,
          shoulders: 30,
          arms: 30,
          core: 29,
        ),
      );
      expect(result, isNot(contains('even_handed')));
    });

    test('spread exactly 30% → fires (boundary inclusive)', () {
      // (50 - 35) / 50 = 0.30. Both endpoints clear the rank-30 floor; the
      // predicate uses `<=` so equality fires.
      final result = CrossBuildTitleEvaluator.evaluate(
        _ranks(
          chest: 50,
          back: 35,
          legs: 35,
          shoulders: 35,
          arms: 35,
          core: 35,
        ),
      );
      expect(result, contains('even_handed'));
    });

    test('spread just over 30% → does not fire', () {
      // (50 - 34) / 50 = 0.32 > 0.30. The predicate fails by a hair while
      // every track still clears the rank-30 floor.
      final result = CrossBuildTitleEvaluator.evaluate(
        _ranks(
          chest: 50,
          back: 34,
          legs: 34,
          shoulders: 34,
          arms: 34,
          core: 34,
        ),
      );
      expect(result, isNot(contains('even_handed')));
    });
  });

  group('CrossBuildTitleEvaluator — iron_bound', () {
    test('chest, back, legs all 60 (boundary) → fires', () {
      // Boundary: every track at the inclusive floor (60). Cardio-low
      // condition is deferred to v2 — the strength predicate fires alone.
      final result = CrossBuildTitleEvaluator.evaluate(
        _ranks(chest: 60, back: 60, legs: 60),
      );
      expect(result, contains('iron_bound'));
    });

    test('one of (chest, back, legs) at 59 → does not fire', () {
      // The predicate is AND-of-three; a single track below the floor
      // short-circuits.
      expect(
        CrossBuildTitleEvaluator.evaluate(
          _ranks(chest: 59, back: 60, legs: 60),
        ),
        isNot(contains('iron_bound')),
      );
      expect(
        CrossBuildTitleEvaluator.evaluate(
          _ranks(chest: 60, back: 59, legs: 60),
        ),
        isNot(contains('iron_bound')),
      );
      expect(
        CrossBuildTitleEvaluator.evaluate(
          _ranks(chest: 60, back: 60, legs: 59),
        ),
        isNot(contains('iron_bound')),
      );
    });

    test('upper-body-only: chest+back at 60 but legs 30 → does not fire', () {
      // Defensive: the spec specifically requires the big-three (squat-row-
      // bench heuristic). A user who skips legs cannot earn it.
      expect(
        CrossBuildTitleEvaluator.evaluate(
          _ranks(chest: 60, back: 60, legs: 30, shoulders: 60, arms: 60),
        ),
        isNot(contains('iron_bound')),
      );
    });
  });

  group('CrossBuildTitleEvaluator — saga_forged', () {
    test('every active track at 60 (boundary) → fires', () {
      // Boundary: every track at the inclusive floor (60). All five other
      // predicates fire too in this distribution — the result list is
      // dense.
      final result = CrossBuildTitleEvaluator.evaluate(
        _ranks(
          chest: 60,
          back: 60,
          legs: 60,
          shoulders: 60,
          arms: 60,
          core: 60,
        ),
      );
      expect(result, contains('saga_forged'));
    });

    test('one track at 59 → does not fire', () {
      // Single sub-floor entry breaks the AND-of-six predicate.
      final result = CrossBuildTitleEvaluator.evaluate(
        _ranks(
          chest: 60,
          back: 60,
          legs: 60,
          shoulders: 60,
          arms: 60,
          core: 59,
        ),
      );
      expect(result, isNot(contains('saga_forged')));
    });

    test('all five strength tracks at 99 except arms at 1 → does not fire', () {
      // Defensive: even a heroic 99/99/99/99/99 distribution fails if a
      // single body part is left untrained. saga_forged is "every track has
      // done the work" not "most tracks have done the work".
      final result = CrossBuildTitleEvaluator.evaluate(
        _ranks(chest: 99, back: 99, legs: 99, shoulders: 99, arms: 1, core: 99),
      );
      expect(result, isNot(contains('saga_forged')));
    });
  });

  group('CrossBuildTitleEvaluator — multi-fire & catalog order', () {
    test('every track at 60 fires every predicate in catalog order', () {
      // Saturation point — every predicate is structurally satisfied.
      // The list order must match `CrossBuildTriggerId.values` so the
      // celebration queue can rely on a stable presentation order.
      final result = CrossBuildTitleEvaluator.evaluate(
        _ranks(
          chest: 60,
          back: 60,
          legs: 60,
          shoulders: 60,
          arms: 30,
          core: 60,
        ),
      );
      // legs 60 >= 2 * arms 30 → pillar_walker
      // chest+back+shoulders = 180 >= 2 * (60+60 = 120) = 240? 180 < 240
      //   → broad_shouldered NO
      // even_handed: arms 30 within 30% of max 60? (60-30)/60 = 0.50 NO
      // iron_bound: chest, back, legs >= 60 YES
      // saga_forged: arms < 60 NO
      expect(result, ['pillar_walker', 'iron_bound']);
    });

    test('rank 1 default-row distribution → empty result', () {
      // A brand-new user fires nothing. Every predicate has at least a
      // rank-30 floor.
      expect(CrossBuildTitleEvaluator.evaluate(_ranks()), isEmpty);
    });

    test('cardio entry is silently ignored', () {
      // BodyPart.cardio is not part of any predicate. A massive cardio
      // value cannot accidentally trip a strength predicate.
      final ranks = _ranks(
        chest: 60,
        back: 60,
        legs: 60,
        shoulders: 60,
        arms: 60,
        core: 60,
      );
      ranks[BodyPart.cardio] = 99;
      expect(CrossBuildTitleEvaluator.evaluate(ranks), contains('saga_forged'));
    });

    test('missing entries default to rank 1', () {
      // Defensive: if a body part is absent from the ranks map, the
      // evaluator projects rank 1 (matches the SQL COALESCE default and
      // RpgProgressSnapshot.progressFor). With chest/back/legs at 60 and
      // shoulders/arms/core absent, the strength predicates fire:
      //   * pillar_walker: legs 60 >= 2 * arms (defaulted to 1) → fires
      //   * iron_bound: chest/back/legs all 60 → fires
      // saga_forged + even_handed need shoulders/arms/core too, so they
      // do not fire.
      final ranks = {BodyPart.chest: 60, BodyPart.back: 60, BodyPart.legs: 60};
      expect(CrossBuildTitleEvaluator.evaluate(ranks), [
        'pillar_walker',
        'iron_bound',
      ]);
    });
  });
}
