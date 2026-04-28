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
import 'package:repsaga/features/rpg/ui/overlays/title_unlock_sheet.dart';

import '../../../helpers/test_material_app.dart';

const _chestR5 = rpg.Title(
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
                            bodyPart: BodyPart.chest,
                            rankThreshold: 5,
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
