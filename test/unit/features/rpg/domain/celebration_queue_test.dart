/// Unit tests for [CelebrationQueue] (Phase 18c).
///
/// The queue is a pure function: given an unordered list of celebration
/// events from a workout finish, return the playback order plus an optional
/// overflow payload (cap-at-3 rule). The dismiss-skip-end semantic is owned
/// by the runtime scheduler in `ActiveWorkoutNotifier`; the queue itself is
/// stateless and idempotent so the same input always yields the same output.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/domain/celebration_queue.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';
import 'package:repsaga/features/rpg/models/celebration_event.dart';
import 'package:repsaga/features/rpg/models/character_class.dart';

void main() {
  group('CelebrationQueue.build', () {
    test('preserves causal order: rank-ups → level-up → title unlock', () {
      // Spec §13.2: rank-up overlays narrate the body-part progression, the
      // character-level overlay caps that off, then the title half-sheet
      // crowns the workout. The queue must enforce this regardless of the
      // input order produced by `record_set_xp`.
      final result = CelebrationQueue.build(
        events: const [
          CelebrationEvent.titleUnlock(slug: 'chest_r5_initiate_of_the_forge'),
          CelebrationEvent.levelUp(newLevel: 3),
          CelebrationEvent.rankUp(bodyPart: BodyPart.chest, newRank: 5),
        ],
      );

      expect(result.queue, hasLength(3));
      expect(result.queue[0], isA<RankUpEvent>());
      expect(result.queue[1], isA<LevelUpEvent>());
      expect(result.queue[2], isA<TitleUnlockEvent>());
      expect(result.overflow, isNull);
    });

    test(
      'rank-ups are sorted by highest body-part rank first (tiebreaker)',
      () {
        // PO decision: when multiple body parts hit a rank threshold in the
        // same workout, surface the BIGGEST jump first — the lifter's biggest
        // win leads, the smaller wins build on it.
        final result = CelebrationQueue.build(
          events: const [
            CelebrationEvent.rankUp(bodyPart: BodyPart.chest, newRank: 5),
            CelebrationEvent.rankUp(bodyPart: BodyPart.legs, newRank: 20),
            CelebrationEvent.rankUp(bodyPart: BodyPart.back, newRank: 10),
          ],
        );

        expect(result.queue.whereType<RankUpEvent>().map((e) => e.newRank), [
          20,
          10,
          5,
        ]);
        expect(result.overflow, isNull);
      },
    );

    test(
      'cap-at-3: 4 rank-ups produces 3 overlays + overflow card with count 1',
      () {
        // PO decision: 6 body-part rank-ups + level-up + title = 10s of
        // overlays = churn. Cap at 3, condense the rest.
        final result = CelebrationQueue.build(
          events: const [
            CelebrationEvent.rankUp(bodyPart: BodyPart.chest, newRank: 10),
            CelebrationEvent.rankUp(bodyPart: BodyPart.back, newRank: 10),
            CelebrationEvent.rankUp(bodyPart: BodyPart.legs, newRank: 10),
            CelebrationEvent.rankUp(bodyPart: BodyPart.shoulders, newRank: 10),
          ],
        );

        expect(result.queue, hasLength(3));
        expect(result.queue.every((e) => e is RankUpEvent), isTrue);
        expect(result.overflow, isNotNull);
        expect(result.overflow!.remainingRankUps, 1);
      },
    );

    test('cap-at-3: rank + level + title fits exactly without overflow', () {
      // Boundary: 1 rank + 1 level + 1 title = 3 overlays. No overflow.
      // The half-sheet itself counts as an overlay slot in the visible queue.
      final result = CelebrationQueue.build(
        events: const [
          CelebrationEvent.rankUp(bodyPart: BodyPart.chest, newRank: 5),
          CelebrationEvent.levelUp(newLevel: 2),
          CelebrationEvent.titleUnlock(slug: 'chest_r5_initiate_of_the_forge'),
        ],
      );

      expect(result.queue, hasLength(3));
      expect(result.overflow, isNull);
    });

    test('cap-at-3 reservation: 4 rank-ups + 1 level + 1 title → top rank-up '
        'reserved, then more rank-ups, closers trimmed (BUG-013)', () {
      // BUG-013 inversion (Cluster 3): rank-ups never lose to closers.
      // 4 rank-ups + 1 level-up + 1 title = 6 events, cap at 3.
      // Reservation policy: slot 1 (class — none here) → slot 2 (top
      // rank-up = 30) → remaining 2 slots fill with the next two
      // highest rank-ups (20, 10). Level-up + title get dropped silently
      // — they're still server-side and surface on the saga screen.
      final result = CelebrationQueue.build(
        events: const [
          CelebrationEvent.rankUp(bodyPart: BodyPart.chest, newRank: 30),
          CelebrationEvent.rankUp(bodyPart: BodyPart.back, newRank: 20),
          CelebrationEvent.rankUp(bodyPart: BodyPart.legs, newRank: 10),
          CelebrationEvent.rankUp(bodyPart: BodyPart.arms, newRank: 5),
          CelebrationEvent.levelUp(newLevel: 4),
          CelebrationEvent.titleUnlock(slug: 'chest_r30_forge_born'),
        ],
      );

      expect(result.queue, hasLength(3));
      expect(result.queue.every((e) => e is RankUpEvent), isTrue);
      expect(
        result.queue.whereType<RankUpEvent>().map((e) => e.newRank).toList(),
        [30, 20, 10],
      );
      // 1 rank-up dropped (rank 5); the level-up + title are silently
      // absorbed by the cap.
      expect(result.overflow, isNotNull);
      expect(result.overflow!.remainingRankUps, 1);
    });

    test(
      'first-awakening events bypass the cap and sit at the head of the queue',
      () {
        // Spec §13.4: first-awakening is an onboarding moment. It precedes the
        // body-part's first rank-up narratively (the body part wakes up before
        // it ranks up). The session-throttle in ActiveWorkoutNotifier caps it
        // to one fire per workout, so we never see more than one here.
        final result = CelebrationQueue.build(
          events: const [
            CelebrationEvent.rankUp(bodyPart: BodyPart.chest, newRank: 5),
            CelebrationEvent.firstAwakening(bodyPart: BodyPart.chest),
          ],
        );

        expect(result.queue, hasLength(2));
        expect(result.queue.first, isA<FirstAwakeningEvent>());
        expect(result.queue[1], isA<RankUpEvent>());
      },
    );

    test('empty event list yields empty queue and no overflow', () {
      final result = CelebrationQueue.build(events: const []);
      expect(result.queue, isEmpty);
      expect(result.overflow, isNull);
    });

    test('single rank-up yields single-slot queue, no overflow', () {
      final result = CelebrationQueue.build(
        events: const [
          CelebrationEvent.rankUp(bodyPart: BodyPart.chest, newRank: 5),
        ],
      );
      expect(result.queue, hasLength(1));
      expect(result.overflow, isNull);
    });

    test('multiple title unlocks are all kept after the cap-priority pass', () {
      // Edge case: a high backfill or first-time finish can mint two titles
      // in the same workout (e.g. chest crosses both Rank 5 and Rank 10).
      // Both must survive — the half-sheet renders them sequentially.
      final result = CelebrationQueue.build(
        events: const [
          CelebrationEvent.titleUnlock(slug: 'chest_r5_initiate_of_the_forge'),
          CelebrationEvent.titleUnlock(slug: 'chest_r10_plate_bearer'),
          CelebrationEvent.rankUp(bodyPart: BodyPart.chest, newRank: 11),
        ],
      );

      // 1 rank + 2 titles = 3 slots, no overflow.
      expect(result.queue, hasLength(3));
      expect(result.queue.whereType<TitleUnlockEvent>(), hasLength(2));
      expect(result.overflow, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // BUG-011 + BUG-013 — Class change + reservation policy boundary tests
  // -------------------------------------------------------------------------
  group('CelebrationQueue.build — class change + reservation policy', () {
    test('class change is placed at the head of the queue (BUG-011)', () {
      // Slot 1 is reserved for ClassChangeEvent. Even when the input order
      // has rank-ups first, the queue surfaces the class change first.
      final result = CelebrationQueue.build(
        events: const [
          CelebrationEvent.rankUp(bodyPart: BodyPart.chest, newRank: 5),
          CelebrationEvent.classChange(
            fromClass: CharacterClass.initiate,
            toClass: CharacterClass.bulwark,
          ),
        ],
      );
      expect(result.queue, hasLength(2));
      expect(result.queue.first, isA<ClassChangeEvent>());
      expect(result.queue[1], isA<RankUpEvent>());
    });

    test('boundary: 1 closer (level-up only) → kept, no overflow', () {
      // Trivial baseline. No class, no rank-up, single level-up.
      final result = CelebrationQueue.build(
        events: const [CelebrationEvent.levelUp(newLevel: 3)],
      );
      expect(result.queue, hasLength(1));
      expect(result.queue.first, isA<LevelUpEvent>());
      expect(result.overflow, isNull);
    });

    test('boundary: 3 closers (level + 2 titles) → all kept, no overflow', () {
      // Cap exactly absorbs 3 closers. Order: level-up before titles.
      final result = CelebrationQueue.build(
        events: const [
          CelebrationEvent.titleUnlock(slug: 'chest_r5_initiate_of_the_forge'),
          CelebrationEvent.titleUnlock(slug: 'chest_r10_plate_bearer'),
          CelebrationEvent.levelUp(newLevel: 5),
        ],
      );
      expect(result.queue, hasLength(3));
      expect(result.queue[0], isA<LevelUpEvent>());
      expect(result.queue.whereType<TitleUnlockEvent>(), hasLength(2));
      expect(result.overflow, isNull);
    });

    test(
      'boundary: 1 class change + 3 closers → class wins, only 2 closers fit (BUG-011 + BUG-013)',
      () {
        // Cap=3 with a class change means slot 1 is reserved for the class
        // and only 2 closer slots remain. Level-up takes priority over
        // titles in the closers ordering.
        final result = CelebrationQueue.build(
          events: const [
            CelebrationEvent.classChange(
              fromClass: CharacterClass.initiate,
              toClass: CharacterClass.bulwark,
            ),
            CelebrationEvent.titleUnlock(
              slug: 'chest_r5_initiate_of_the_forge',
            ),
            CelebrationEvent.titleUnlock(slug: 'chest_r10_plate_bearer'),
            CelebrationEvent.levelUp(newLevel: 5),
          ],
        );
        expect(result.queue, hasLength(3));
        expect(result.queue[0], isA<ClassChangeEvent>());
        expect(result.queue[1], isA<LevelUpEvent>());
        expect(result.queue[2], isA<TitleUnlockEvent>());
        // Closers don't overflow the rank-up overflow card — they're
        // absorbed silently.
        expect(result.overflow, isNull);
      },
    );

    test(
      'boundary: 1 class change + 1 rank-up + 3 closers → class + rank-up + level (BUG-013)',
      () {
        // Cap=3. Slot 1 = class, slot 2 = top rank-up, slot 3 = level-up.
        // Both titles drop silently. Critical: rank-up survives even
        // though closers fill the queue (BUG-013 invariant).
        final result = CelebrationQueue.build(
          events: const [
            CelebrationEvent.classChange(
              fromClass: CharacterClass.initiate,
              toClass: CharacterClass.bulwark,
            ),
            CelebrationEvent.rankUp(bodyPart: BodyPart.chest, newRank: 5),
            CelebrationEvent.levelUp(newLevel: 5),
            CelebrationEvent.titleUnlock(
              slug: 'chest_r5_initiate_of_the_forge',
            ),
            CelebrationEvent.titleUnlock(slug: 'chest_r10_plate_bearer'),
          ],
        );
        expect(result.queue, hasLength(3));
        expect(result.queue[0], isA<ClassChangeEvent>());
        expect(result.queue[1], isA<RankUpEvent>());
        expect(result.queue[2], isA<LevelUpEvent>());
        // No rank-up overflow (only one rank-up, it survived).
        expect(result.overflow, isNull);
      },
    );

    test('BUG-013 invariant: 3 closers + 1 rank-up → top rank-up survives, '
        'closers trimmed to 2', () {
      // Pre-Cluster-3 behaviour: closers (level + 2 titles) would fill
      // all 3 slots and the rank-up would overflow. New behaviour:
      // slot 2 reserved for rank-up, only 2 closer slots remain.
      final result = CelebrationQueue.build(
        events: const [
          CelebrationEvent.rankUp(bodyPart: BodyPart.chest, newRank: 10),
          CelebrationEvent.titleUnlock(slug: 'chest_r5_initiate_of_the_forge'),
          CelebrationEvent.titleUnlock(slug: 'chest_r10_plate_bearer'),
          CelebrationEvent.levelUp(newLevel: 5),
        ],
      );
      expect(result.queue, hasLength(3));
      expect(result.queue[0], isA<RankUpEvent>());
      expect(result.queue[1], isA<LevelUpEvent>());
      expect(result.queue[2], isA<TitleUnlockEvent>());
      // No rank-up overflow (the single rank-up survived).
      expect(result.overflow, isNull);
    });
  });
}
