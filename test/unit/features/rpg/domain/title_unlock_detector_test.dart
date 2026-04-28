/// Unit tests for [TitleUnlockDetector] (Phase 18c).
///
/// The detector is a pure function: given per-body-part rank deltas and the
/// set of already-earned title slugs, return the newly-unlocked titles in
/// canonical order. v1 covers the per-body-part ladder only (78 titles).
/// Character-level + cross-build detection arrives in Phase 18e.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/domain/title_unlock_detector.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';
import 'package:repsaga/features/rpg/models/title.dart';

/// Minimal test catalog covering the boundary thresholds used in the suite.
/// We keep it explicit (rather than loading the full 78-entry asset) so a
/// catalog edit cannot silently change the unit semantics — if a future
/// editorial pass moves a slug, the test failure points at the right file.
const _catalog = <Title>[
  Title(slug: 'chest_r5', bodyPart: BodyPart.chest, rankThreshold: 5),
  Title(slug: 'chest_r10', bodyPart: BodyPart.chest, rankThreshold: 10),
  Title(slug: 'chest_r20', bodyPart: BodyPart.chest, rankThreshold: 20),
  Title(slug: 'chest_r99', bodyPart: BodyPart.chest, rankThreshold: 99),
  Title(slug: 'legs_r5', bodyPart: BodyPart.legs, rankThreshold: 5),
  Title(slug: 'legs_r10', bodyPart: BodyPart.legs, rankThreshold: 10),
  Title(slug: 'back_r5', bodyPart: BodyPart.back, rankThreshold: 5),
];

void main() {
  group('TitleUnlockDetector', () {
    test('crossing a single threshold returns one title', () {
      final result = TitleUnlockDetector.detect(
        deltas: const [
          RankDelta(bodyPart: BodyPart.chest, oldRank: 4, newRank: 5),
        ],
        alreadyEarnedSlugs: const <String>{},
        catalog: _catalog,
      );
      expect(result, hasLength(1));
      expect(result.single.slug, 'chest_r5');
      expect(result.single.bodyPart, BodyPart.chest);
      expect(result.single.rankThreshold, 5);
    });

    test('crossing multiple thresholds in one delta returns them all', () {
      // Backfill scenario or a heroic single workout — chest jumped from
      // rank 4 to 11. The detector must surface BOTH the rank-5 and rank-10
      // unlocks; Stage 7's celebration queue then caps at 3 overlays.
      final result = TitleUnlockDetector.detect(
        deltas: const [
          RankDelta(bodyPart: BodyPart.chest, oldRank: 4, newRank: 11),
        ],
        alreadyEarnedSlugs: const <String>{},
        catalog: _catalog,
      );
      expect(result.map((t) => t.slug).toList(), ['chest_r5', 'chest_r10']);
    });

    test('threshold equal to the OLD rank is not unlocked', () {
      // The user was already at rank 5 before this workout — their rank-5
      // title was unlocked in a prior workout. Idempotency guard.
      final result = TitleUnlockDetector.detect(
        deltas: const [
          RankDelta(bodyPart: BodyPart.chest, oldRank: 5, newRank: 6),
        ],
        alreadyEarnedSlugs: const <String>{},
        catalog: _catalog,
      );
      expect(result, isEmpty);
    });

    test('threshold equal to the NEW rank is unlocked', () {
      // Boundary: oldRank=4, newRank=5 — the rank-5 title fires.
      final result = TitleUnlockDetector.detect(
        deltas: const [
          RankDelta(bodyPart: BodyPart.chest, oldRank: 4, newRank: 5),
        ],
        alreadyEarnedSlugs: const <String>{},
        catalog: _catalog,
      );
      expect(result.single.slug, 'chest_r5');
    });

    test('already-earned titles are excluded', () {
      // Defensive: the set membership check guards against the same title
      // firing twice if record_set_xp deltas are replayed (e.g. retry of a
      // failed save).
      final result = TitleUnlockDetector.detect(
        deltas: const [
          RankDelta(bodyPart: BodyPart.chest, oldRank: 4, newRank: 11),
        ],
        alreadyEarnedSlugs: const {'chest_r5'},
        catalog: _catalog,
      );
      expect(result.map((t) => t.slug).toList(), ['chest_r10']);
    });

    test('cross-body-part deltas return distinct entries', () {
      final result = TitleUnlockDetector.detect(
        deltas: const [
          RankDelta(bodyPart: BodyPart.chest, oldRank: 4, newRank: 5),
          RankDelta(bodyPart: BodyPart.legs, oldRank: 9, newRank: 10),
          RankDelta(bodyPart: BodyPart.back, oldRank: 4, newRank: 5),
        ],
        alreadyEarnedSlugs: const <String>{},
        catalog: _catalog,
      );
      expect(result.map((t) => t.slug).toList()..sort(), [
        'back_r5',
        'chest_r5',
        'legs_r10',
      ]);
    });

    test('zero-delta entries (oldRank == newRank) yield nothing', () {
      final result = TitleUnlockDetector.detect(
        deltas: const [
          RankDelta(bodyPart: BodyPart.chest, oldRank: 5, newRank: 5),
        ],
        alreadyEarnedSlugs: const <String>{},
        catalog: _catalog,
      );
      expect(result, isEmpty);
    });

    test('empty deltas list yields empty result', () {
      final result = TitleUnlockDetector.detect(
        deltas: const [],
        alreadyEarnedSlugs: const <String>{},
        catalog: _catalog,
      );
      expect(result, isEmpty);
    });

    test('catalog entry for a body part with no delta is not unlocked', () {
      // Defensive: legs has no delta in this workout — even though the user
      // hasn't earned legs_r5 yet, it must not surface.
      final result = TitleUnlockDetector.detect(
        deltas: const [
          RankDelta(bodyPart: BodyPart.chest, oldRank: 4, newRank: 5),
        ],
        alreadyEarnedSlugs: const <String>{},
        catalog: _catalog,
      );
      expect(result.where((t) => t.bodyPart == BodyPart.legs), isEmpty);
    });

    test('terminal Rank 99 unlock fires when crossed from 98', () {
      final result = TitleUnlockDetector.detect(
        deltas: const [
          RankDelta(bodyPart: BodyPart.chest, oldRank: 98, newRank: 99),
        ],
        alreadyEarnedSlugs: const <String>{},
        catalog: _catalog,
      );
      expect(result.single.slug, 'chest_r99');
    });
  });
}
