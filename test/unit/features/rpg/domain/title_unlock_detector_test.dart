/// Unit tests for [TitleUnlockDetector] (Phase 18c + 18e).
///
/// The detector is a pure function: given per-body-part rank deltas and the
/// set of already-earned title slugs, return the newly-unlocked titles in
/// canonical order.
///
/// v1 covers all three title kinds:
///   * `detect` — body-part ladder (78 titles). Pinned by the Phase 18c
///     suite below.
///   * `detectCharacterLevel` — character-level ladder (7 titles), Phase 18e.
///   * `detectCrossBuild` — distinction snapshot predicates (5 titles),
///     Phase 18e.
///
/// All three share the same idempotency rule (`alreadyEarnedSlugs`) and the
/// body-part + character-level detectors share the half-open `(old, new]`
/// boundary. The cross-build detector has no interval — it's a pure
/// snapshot evaluation against the post-save rank distribution. Each variant
/// gets its own group so a future refactor that changes one detector cannot
/// silently regress the others.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/domain/title_unlock_detector.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';
import 'package:repsaga/features/rpg/models/title.dart';

/// Minimal test catalog covering the boundary thresholds used in the suite.
/// We keep it explicit (rather than loading the full 90-entry asset) so a
/// catalog edit cannot silently change the unit semantics — if a future
/// editorial pass moves a slug, the test failure points at the right file.
const _catalog = <Title>[
  Title.bodyPart(slug: 'chest_r5', bodyPart: BodyPart.chest, rankThreshold: 5),
  Title.bodyPart(
    slug: 'chest_r10',
    bodyPart: BodyPart.chest,
    rankThreshold: 10,
  ),
  Title.bodyPart(
    slug: 'chest_r20',
    bodyPart: BodyPart.chest,
    rankThreshold: 20,
  ),
  Title.bodyPart(
    slug: 'chest_r99',
    bodyPart: BodyPart.chest,
    rankThreshold: 99,
  ),
  Title.bodyPart(slug: 'legs_r5', bodyPart: BodyPart.legs, rankThreshold: 5),
  Title.bodyPart(slug: 'legs_r10', bodyPart: BodyPart.legs, rankThreshold: 10),
  Title.bodyPart(slug: 'back_r5', bodyPart: BodyPart.back, rankThreshold: 5),
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
      // Detector returns Title (sealed); destructure to access body-part
      // ladder fields.
      final entry = result.single as BodyPartTitle;
      expect(entry.bodyPart, BodyPart.chest);
      expect(entry.rankThreshold, 5);
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
      expect(
        result.whereType<BodyPartTitle>().where(
          (t) => t.bodyPart == BodyPart.legs,
        ),
        isEmpty,
      );
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

    test('character-level + cross-build catalog entries are not body-part '
        'unlocks (filter)', () {
      // Defensive: when the catalog mixes the three kinds (real shipped
      // catalog), `detect` must filter to BodyPartTitle only — the
      // dedicated detectors handle character-level + cross-build. Otherwise
      // a level-up workout that also crosses a rank threshold would emit
      // duplicate or mislabelled titles.
      const mixedCatalog = <Title>[
        Title.bodyPart(
          slug: 'chest_r5',
          bodyPart: BodyPart.chest,
          rankThreshold: 5,
        ),
        Title.characterLevel(slug: 'apprentice', levelThreshold: 10),
        Title.crossBuild(
          slug: 'pillar_walker',
          triggerId: CrossBuildTriggerId.pillarWalker,
        ),
      ];

      final result = TitleUnlockDetector.detect(
        deltas: const [
          RankDelta(bodyPart: BodyPart.chest, oldRank: 4, newRank: 5),
        ],
        alreadyEarnedSlugs: const <String>{},
        catalog: mixedCatalog,
      );

      // Only the body-part entry survives; character-level + cross-build
      // entries are routed to their dedicated detectors.
      expect(result.map((t) => t.slug).toList(), ['chest_r5']);
    });
  });

  // ---------------------------------------------------------------------------
  // detectCharacterLevel — Phase 18e.
  // ---------------------------------------------------------------------------

  const characterLevelCatalog = <Title>[
    Title.characterLevel(slug: 'apprentice', levelThreshold: 10),
    Title.characterLevel(slug: 'journeyman', levelThreshold: 25),
    Title.characterLevel(slug: 'adept', levelThreshold: 50),
    Title.characterLevel(slug: 'master', levelThreshold: 75),
    Title.characterLevel(slug: 'grandmaster', levelThreshold: 100),
    // Body-part entry mixed in to verify the filter.
    Title.bodyPart(
      slug: 'chest_r5',
      bodyPart: BodyPart.chest,
      rankThreshold: 5,
    ),
  ];

  group('TitleUnlockDetector.detectCharacterLevel', () {
    test('crossing one threshold returns one title', () {
      final result = TitleUnlockDetector.detectCharacterLevel(
        oldLevel: 9,
        newLevel: 10,
        alreadyEarnedSlugs: const <String>{},
        catalog: characterLevelCatalog,
      );
      expect(result.single.slug, 'apprentice');
      // Variant accessor — the detector returns sealed Title; consumers
      // destructure to read levelThreshold.
      expect((result.single as CharacterLevelTitle).levelThreshold, 10);
    });

    test('crossing multiple thresholds in one transition returns them all', () {
      // Heroic backfill: the user finishes a workout that pushes them from
      // level 9 to level 27, sweeping both apprentice (10) and journeyman
      // (25). The detector must surface both.
      final result = TitleUnlockDetector.detectCharacterLevel(
        oldLevel: 9,
        newLevel: 27,
        alreadyEarnedSlugs: const <String>{},
        catalog: characterLevelCatalog,
      );
      expect(result.map((t) => t.slug).toList(), ['apprentice', 'journeyman']);
    });

    test('threshold equal to OLD level is not unlocked', () {
      // Boundary: oldLevel == 10 means the apprentice title was unlocked
      // before this workout. The half-open interval excludes oldLevel.
      final result = TitleUnlockDetector.detectCharacterLevel(
        oldLevel: 10,
        newLevel: 11,
        alreadyEarnedSlugs: const <String>{},
        catalog: characterLevelCatalog,
      );
      expect(result, isEmpty);
    });

    test('threshold equal to NEW level fires (boundary inclusive)', () {
      // Boundary: oldLevel == 24, newLevel == 25 → journeyman fires.
      final result = TitleUnlockDetector.detectCharacterLevel(
        oldLevel: 24,
        newLevel: 25,
        alreadyEarnedSlugs: const <String>{},
        catalog: characterLevelCatalog,
      );
      expect(result.single.slug, 'journeyman');
    });

    test('newLevel == oldLevel yields empty (no transition)', () {
      // The half-open interval reduces to the empty set; defensively the
      // detector also short-circuits at the top.
      final result = TitleUnlockDetector.detectCharacterLevel(
        oldLevel: 25,
        newLevel: 25,
        alreadyEarnedSlugs: const <String>{},
        catalog: characterLevelCatalog,
      );
      expect(result, isEmpty);
    });

    test('newLevel < oldLevel yields empty (defensive)', () {
      // record_level_xp never goes backwards — but if a future refactor
      // ever passes a reversed pair, the detector returns empty rather
      // than crashing or emitting reverse "unlocks".
      final result = TitleUnlockDetector.detectCharacterLevel(
        oldLevel: 50,
        newLevel: 25,
        alreadyEarnedSlugs: const <String>{},
        catalog: characterLevelCatalog,
      );
      expect(result, isEmpty);
    });

    test('already-earned titles are excluded', () {
      // Same idempotency rule as the body-part detector. A retried save
      // that re-emits the same level transition cannot re-fire the title.
      final result = TitleUnlockDetector.detectCharacterLevel(
        oldLevel: 9,
        newLevel: 27,
        alreadyEarnedSlugs: const {'apprentice'},
        catalog: characterLevelCatalog,
      );
      expect(result.map((t) => t.slug).toList(), ['journeyman']);
    });

    test('body-part + cross-build catalog entries are filtered out', () {
      // The detector reads only CharacterLevelTitle entries — every other
      // kind is silently ignored even if it exists in the input catalog.
      final result = TitleUnlockDetector.detectCharacterLevel(
        oldLevel: 4,
        newLevel: 11,
        alreadyEarnedSlugs: const <String>{},
        catalog: characterLevelCatalog,
      );
      // Only `apprentice` survives — the chest_r5 body-part entry is
      // filtered out even though the level transition encompasses rank 5.
      expect(result.map((t) => t.slug).toList(), ['apprentice']);
    });

    test('empty catalog yields empty', () {
      expect(
        TitleUnlockDetector.detectCharacterLevel(
          oldLevel: 1,
          newLevel: 100,
          alreadyEarnedSlugs: const <String>{},
          catalog: const <Title>[],
        ),
        isEmpty,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // detectCrossBuild — Phase 18e.
  // ---------------------------------------------------------------------------

  const crossBuildCatalog = <Title>[
    Title.crossBuild(
      slug: 'pillar_walker',
      triggerId: CrossBuildTriggerId.pillarWalker,
    ),
    Title.crossBuild(
      slug: 'broad_shouldered',
      triggerId: CrossBuildTriggerId.broadShouldered,
    ),
    Title.crossBuild(
      slug: 'even_handed',
      triggerId: CrossBuildTriggerId.evenHanded,
    ),
    Title.crossBuild(
      slug: 'iron_bound',
      triggerId: CrossBuildTriggerId.ironBound,
    ),
    Title.crossBuild(
      slug: 'saga_forged',
      triggerId: CrossBuildTriggerId.sagaForged,
    ),
    // Mixed in to verify the filter.
    Title.bodyPart(
      slug: 'chest_r5',
      bodyPart: BodyPart.chest,
      rankThreshold: 5,
    ),
    Title.characterLevel(slug: 'apprentice', levelThreshold: 10),
  ];

  Map<BodyPart, int> ranks({
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

  group('TitleUnlockDetector.detectCrossBuild', () {
    test('saturated rank distribution fires the structural predicates in '
        'catalog order', () {
      // Every track at rank 60 — even_handed, iron_bound, and saga_forged
      // all hold simultaneously. (pillar_walker requires legs >= 2 * arms,
      // broad_shouldered requires upper >> lower — mutually exclusive
      // with the saga_forged saturation. Those two have their own focused
      // tests below.)
      final result = TitleUnlockDetector.detectCrossBuild(
        rankMap: ranks(
          chest: 60,
          back: 60,
          legs: 60,
          shoulders: 60,
          arms: 60,
          core: 60,
        ),
        alreadyEarnedSlugs: const <String>{},
        catalog: crossBuildCatalog,
      );
      expect(result.map((t) => t.slug).toList(), [
        'even_handed',
        'iron_bound',
        'saga_forged',
      ]);
    });

    test('pillar_walker fires alone for a leg-dominant build', () {
      // legs 40, arms 1 — only the pillar_walker predicate is satisfied.
      final result = TitleUnlockDetector.detectCrossBuild(
        rankMap: ranks(legs: 40),
        alreadyEarnedSlugs: const <String>{},
        catalog: crossBuildCatalog,
      );
      expect(result.map((t) => t.slug).toList(), ['pillar_walker']);
    });

    test('broad_shouldered fires alone for an upper-body-dominant build', () {
      // chest+back+shoulders = 90 = 2 * (legs+core = 45). Upper floors all
      // at 30. Other predicates not satisfied (no track >= 40 → pillar_walker
      // off; spread (30-15)/30=0.50 → even_handed off; below rank 60 →
      // iron_bound and saga_forged off).
      final result = TitleUnlockDetector.detectCrossBuild(
        rankMap: ranks(chest: 30, back: 30, shoulders: 30, legs: 30, core: 15),
        alreadyEarnedSlugs: const <String>{},
        catalog: crossBuildCatalog,
      );
      expect(result.map((t) => t.slug).toList(), ['broad_shouldered']);
    });

    test('default-row (every track at 1) fires nothing', () {
      // Every predicate has at least a rank-30 floor — a brand-new user
      // cannot trip any of them.
      final result = TitleUnlockDetector.detectCrossBuild(
        rankMap: ranks(),
        alreadyEarnedSlugs: const <String>{},
        catalog: crossBuildCatalog,
      );
      expect(result, isEmpty);
    });

    test('already-earned slugs are filtered out', () {
      // Idempotency: the detector runs every workout-finish, so a user who
      // already earned `iron_bound` from a prior save must not see it again.
      final result = TitleUnlockDetector.detectCrossBuild(
        rankMap: ranks(chest: 60, back: 60, legs: 60),
        alreadyEarnedSlugs: const {'iron_bound', 'pillar_walker'},
        catalog: crossBuildCatalog,
      );
      expect(result, isEmpty);
    });

    test('body-part + character-level catalog entries are filtered out', () {
      // The detector reads only CrossBuildTitle entries. With chest at 60,
      // a body-part chest_r5 entry could be a tempting false positive —
      // verify it's not surfaced.
      final result = TitleUnlockDetector.detectCrossBuild(
        rankMap: ranks(chest: 60, back: 60, legs: 60),
        alreadyEarnedSlugs: const <String>{},
        catalog: crossBuildCatalog,
      );
      // chest+back+legs at 60 fires pillar_walker (legs 60 >= 2 * arms 1)
      // and iron_bound. body-part / character-level entries are filtered.
      expect(result.map((t) => t.slug).toList(), [
        'pillar_walker',
        'iron_bound',
      ]);
    });

    test('empty catalog yields empty', () {
      expect(
        TitleUnlockDetector.detectCrossBuild(
          rankMap: ranks(
            chest: 60,
            back: 60,
            legs: 60,
            shoulders: 60,
            arms: 60,
            core: 60,
          ),
          alreadyEarnedSlugs: const <String>{},
          catalog: const <Title>[],
        ),
        isEmpty,
      );
    });

    test(
      'partial catalog: only loaded slugs surface even if predicates fire',
      () {
        // Defensive: if a future catalog ships fewer than five cross-build
        // entries (e.g. an A/B-disabled slug), the detector returns only
        // the ones present in the input catalog. The evaluator will fire
        // them, but only the catalog-known slugs are joined back.
        const partial = <Title>[
          Title.crossBuild(
            slug: 'iron_bound',
            triggerId: CrossBuildTriggerId.ironBound,
          ),
        ];
        final result = TitleUnlockDetector.detectCrossBuild(
          rankMap: ranks(
            chest: 60,
            back: 60,
            legs: 60,
            shoulders: 60,
            arms: 60,
            core: 60,
          ),
          alreadyEarnedSlugs: const <String>{},
          catalog: partial,
        );
        expect(result.map((t) => t.slug).toList(), ['iron_bound']);
      },
    );
  });
}
