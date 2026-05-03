/// Widget tests for [CelebrationPlayer.play] — Phase 18c reviewer fixes.
///
/// Locks the new return contract:
///   * Empty queue + no overflow → returns [CelebrationPlayResult.notTapped].
///   * Overflow card auto-dismiss → returns `notTapped`.
///   * Overflow card user-tap → returns [CelebrationPlayResult.tapped].
///   * [TitleUnlockSheet] is barrier-dismissable (tap outside resolves
///     gracefully without throwing; the player advances).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/domain/celebration_queue.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';
import 'package:repsaga/features/rpg/models/celebration_event.dart';
import 'package:repsaga/features/rpg/models/title.dart' as rpg;
import 'package:repsaga/features/rpg/ui/celebration_player.dart';
import 'package:repsaga/features/rpg/ui/overlays/celebration_overflow_card.dart';
import 'package:repsaga/features/rpg/ui/overlays/level_up_overlay.dart';
import 'package:repsaga/features/rpg/ui/overlays/rank_up_overlay.dart';
import 'package:repsaga/features/rpg/ui/overlays/title_unlock_sheet.dart';

import '../../../helpers/test_material_app.dart';

const _chestR5 = rpg.Title.bodyPart(
  slug: 'chest_r5_initiate_of_the_forge',
  bodyPart: BodyPart.chest,
  rankThreshold: 5,
);

void main() {
  group('CelebrationPlayer.play return contract', () {
    testWidgets('returns notTapped for an empty queue', (tester) async {
      late CelebrationPlayResult result;
      await tester.pumpWidget(
        TestMaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await CelebrationPlayer.play(
                    context,
                    result: const CelebrationQueueResult(
                      queue: <CelebrationEvent>[],
                    ),
                    catalog: const <rpg.Title>[],
                    hasPriorEarnedTitles: false,
                    onEquipTitle: (_) async {},
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();

      expect(result.userTappedOverflow, isFalse);
    });

    testWidgets('returns notTapped when the overflow card auto-dismisses', (
      tester,
    ) async {
      late CelebrationPlayResult result;
      await tester.pumpWidget(
        TestMaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await CelebrationPlayer.play(
                    context,
                    result: const CelebrationQueueResult(
                      queue: <CelebrationEvent>[],
                      overflow: OverflowPayload(remainingRankUps: 2),
                    ),
                    catalog: const <rpg.Title>[],
                    hasPriorEarnedTitles: false,
                    onEquipTitle: (_) async {},
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();
      // Card mounts.
      expect(find.byType(CelebrationOverflowCard), findsOneWidget);
      // Auto-dismiss after 4s.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(result.userTappedOverflow, isFalse);
    });

    testWidgets('returns tapped when the user taps the overflow card', (
      tester,
    ) async {
      late CelebrationPlayResult result;
      await tester.pumpWidget(
        TestMaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await CelebrationPlayer.play(
                    context,
                    result: const CelebrationQueueResult(
                      queue: <CelebrationEvent>[],
                      overflow: OverflowPayload(remainingRankUps: 3),
                    ),
                    catalog: const <rpg.Title>[],
                    hasPriorEarnedTitles: false,
                    onEquipTitle: (_) async {},
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();
      expect(find.byType(CelebrationOverflowCard), findsOneWidget);

      // Tap the card — should resolve with userTappedOverflow == true.
      await tester.tap(find.byType(CelebrationOverflowCard));
      await tester.pump();

      expect(result.userTappedOverflow, isTrue);
    });
  });

  group('CelebrationPlayer multi-event sequence', () {
    // Companion coverage for the BUG-017 e2e regression
    // (`rank-up-celebration.spec.ts:431`). The actual root cause of that
    // failure was the cap-at-3 queue dropping the title (see
    // `CelebrationQueue` test "BUG-017 regression"), but this widget test
    // pins the orchestration contract on the player side: given a queue
    // that contains [RankUp, LevelUp, TitleUnlock], the player must
    //   * play the rank-up overlay for its full 1100ms hold
    //   * insert the 200ms inter-event gap
    //   * play the level-up overlay for its full 1100ms hold
    //   * mount the title sheet AFTER both overlays have played out
    //   * NOT short-circuit through the title loop on `context.mounted`
    //     checks while the route stack is mid-transition.
    // Without this lock, a future `_playOverlay` refactor that races the
    // pop-completer against the next-iteration await could silently drop
    // the title sheet, regressing the spec.
    testWidgets(
      'plays rank-up → level-up → title sheet without dropping the title',
      (tester) async {
        late CelebrationPlayResult result;
        var equipCalls = 0;

        await tester.pumpWidget(
          TestMaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await CelebrationPlayer.play(
                      context,
                      result: const CelebrationQueueResult(
                        queue: <CelebrationEvent>[
                          CelebrationEvent.rankUp(
                            bodyPart: BodyPart.chest,
                            newRank: 5,
                          ),
                          CelebrationEvent.levelUp(newLevel: 2),
                          CelebrationEvent.titleUnlock(
                            slug: 'chest_r5_initiate_of_the_forge',
                          ),
                        ],
                      ),
                      catalog: const <rpg.Title>[_chestR5],
                      hasPriorEarnedTitles: false,
                      onEquipTitle: (_) async {
                        equipCalls += 1;
                      },
                    );
                  },
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('go'));
        await tester.pump();

        // Phase 1: rank-up overlay mounts.
        expect(find.byType(RankUpOverlay), findsOneWidget);
        expect(find.byType(LevelUpOverlay), findsNothing);
        expect(find.byType(TitleUnlockSheet), findsNothing);

        // Hold for 1100ms (full rank-up window) then auto-pop.
        await tester.pump(const Duration(milliseconds: 1100));
        // After the auto-pop runs, the dialog route is popped — pump a
        // frame to let the route transition complete.
        await tester.pump(const Duration(milliseconds: 350));
        // 200ms inter-event gap.
        await tester.pump(const Duration(milliseconds: 200));
        // showDialog re-mount frame.
        await tester.pump(const Duration(milliseconds: 50));

        // Phase 2: level-up overlay should now be on screen.
        expect(find.byType(RankUpOverlay), findsNothing);
        expect(find.byType(LevelUpOverlay), findsOneWidget);
        expect(find.byType(TitleUnlockSheet), findsNothing);

        // Pump JUST 200ms of the 1100ms hold and assert the level-up is
        // STILL visible. Pins the per-event hold so a future scheduler
        // change cannot accidentally short the level-up window (which
        // would cut into the title sheet's mount frame).
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          find.byType(LevelUpOverlay),
          findsOneWidget,
          reason: 'level-up must hold for the full 1100ms hold window',
        );

        // Hold for the remaining 900ms then auto-pop.
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pump(const Duration(milliseconds: 350));

        // Phase 3: title-unlock sheet mounts.
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(LevelUpOverlay), findsNothing);
        expect(
          find.byType(TitleUnlockSheet),
          findsOneWidget,
          reason: 'title sheet must render after both overlays play through',
        );

        // Tap the equip CTA.
        final equipButton = find.text('EQUIP TITLE');
        expect(equipButton, findsOneWidget);
        await tester.tap(equipButton);
        await tester.pumpAndSettle();

        expect(equipCalls, 1);
        expect(result.userTappedOverflow, isFalse);
      },
    );
  });

  group('CelebrationPlayer title sheet dismiss', () {
    testWidgets(
      'title sheet is barrier-dismissable; player advances on tap-outside',
      (tester) async {
        late CelebrationPlayResult result;
        var equipCalls = 0;

        await tester.pumpWidget(
          TestMaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await CelebrationPlayer.play(
                      context,
                      result: const CelebrationQueueResult(
                        queue: <CelebrationEvent>[
                          CelebrationEvent.titleUnlock(
                            slug: 'chest_r5_initiate_of_the_forge',
                          ),
                        ],
                      ),
                      catalog: const <rpg.Title>[_chestR5],
                      hasPriorEarnedTitles: false,
                      onEquipTitle: (_) async {
                        equipCalls += 1;
                      },
                    );
                  },
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('go'));
        await tester.pump();
        // Sheet route mounts; allow the modal animation to settle.
        await tester.pump(const Duration(milliseconds: 350));

        // The title sheet body is on screen.
        expect(find.byType(TitleUnlockSheet), findsOneWidget);

        // Tap outside the sheet (top of the screen) to dismiss via the
        // barrier. Since enableDrag is disabled but isDismissible is true
        // (default), the barrier tap should pop the sheet.
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        // Sheet is gone; the play() future has resolved without invoking
        // onEquip.
        expect(find.byType(TitleUnlockSheet), findsNothing);
        expect(equipCalls, 0);
        expect(result.userTappedOverflow, isFalse);
      },
    );
  });
}
