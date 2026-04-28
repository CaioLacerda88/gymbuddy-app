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

void main() {
  group('CelebrationQueue.build', () {
    test('preserves causal order: rank-ups → level-up → title unlock', () {
      // Spec §13.2: rank-up overlays narrate the body-part progression, the
      // character-level overlay caps that off, then the title half-sheet
      // crowns the workout. The queue must enforce this regardless of the
      // input order produced by `record_set_xp`.
      final result = CelebrationQueue.build(
        events: const [
          CelebrationEvent.titleUnlock(
            slug: 'chest_r5_initiate_of_the_forge',
            bodyPart: BodyPart.chest,
            rankThreshold: 5,
          ),
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
          CelebrationEvent.titleUnlock(
            slug: 'chest_r5_initiate_of_the_forge',
            bodyPart: BodyPart.chest,
            rankThreshold: 5,
          ),
        ],
      );

      expect(result.queue, hasLength(3));
      expect(result.overflow, isNull);
    });

    test('cap-at-3: rank-ups fight for slots before level-up + title', () {
      // 4 rank-ups + 1 level-up + 1 title = 6 events, cap at 3. Spec §13.2:
      // narrative reads cleaner when at least one rank-up + the level-up +
      // the title survive. Trim from the LOW-rank end of the rank-up list.
      final result = CelebrationQueue.build(
        events: const [
          CelebrationEvent.rankUp(bodyPart: BodyPart.chest, newRank: 30),
          CelebrationEvent.rankUp(bodyPart: BodyPart.back, newRank: 20),
          CelebrationEvent.rankUp(bodyPart: BodyPart.legs, newRank: 10),
          CelebrationEvent.rankUp(bodyPart: BodyPart.arms, newRank: 5),
          CelebrationEvent.levelUp(newLevel: 4),
          CelebrationEvent.titleUnlock(
            slug: 'chest_r30_forge_born',
            bodyPart: BodyPart.chest,
            rankThreshold: 30,
          ),
        ],
      );

      // Top rank-up wins, then the level-up + title (causal closers).
      expect(result.queue, hasLength(3));
      expect(result.queue[0], isA<RankUpEvent>());
      expect((result.queue[0] as RankUpEvent).newRank, 30);
      expect(result.queue[1], isA<LevelUpEvent>());
      expect(result.queue[2], isA<TitleUnlockEvent>());
      // 3 rank-ups got dropped in favor of level + title.
      expect(result.overflow, isNotNull);
      expect(result.overflow!.remainingRankUps, 3);
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
          CelebrationEvent.titleUnlock(
            slug: 'chest_r5_initiate_of_the_forge',
            bodyPart: BodyPart.chest,
            rankThreshold: 5,
          ),
          CelebrationEvent.titleUnlock(
            slug: 'chest_r10_plate_bearer',
            bodyPart: BodyPart.chest,
            rankThreshold: 10,
          ),
          CelebrationEvent.rankUp(bodyPart: BodyPart.chest, newRank: 11),
        ],
      );

      // 1 rank + 2 titles = 3 slots, no overflow.
      expect(result.queue, hasLength(3));
      expect(result.queue.whereType<TitleUnlockEvent>(), hasLength(2));
      expect(result.overflow, isNull);
    });
  });
}
