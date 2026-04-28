/// Widget tests for [RankUpOverlay] (Phase 18c).
///
/// Direction B "Rune Stamp" choreography (locked in WIP.md):
///   * 0–200ms — sigil ignites textDim → heroGold (easeIn)
///   * 200–500ms — heroGold hold + boxShadow grow
///   * 500–900ms — heroGold → hotViolet settle (decelerate)
///   * 900–1100ms — shadow color cross-fades heroGold → hotViolet
///   * Card scale 0.88 → 1.0 over 220ms easeOutBack
///   * Backdrop FadeTransition (abyss @ 0.72) over 180ms easeOut
///   * mediumImpact haptic at t=200ms (peak gold)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';
import 'package:repsaga/features/rpg/ui/overlays/rank_up_overlay.dart';
import 'package:repsaga/shared/widgets/reward_accent.dart';

import '../../../../helpers/test_material_app.dart';

Widget _wrap(Widget child) => TestMaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('RankUpOverlay', () {
    late int hapticMediumCount;

    setUp(() {
      hapticMediumCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate' &&
                call.arguments == 'HapticFeedbackType.mediumImpact') {
              hapticMediumCount += 1;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('renders the body-part name and rank numeral', (tester) async {
      await tester.pumpWidget(
        _wrap(const RankUpOverlay(bodyPart: BodyPart.chest, newRank: 5)),
      );
      // Mount + first frame.
      await tester.pump();

      expect(find.textContaining('CHEST'), findsOneWidget);
      expect(find.textContaining('5'), findsOneWidget);
    });

    testWidgets('rank numeral is wrapped in RewardAccent (heroGold)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const RankUpOverlay(bodyPart: BodyPart.chest, newRank: 12)),
      );
      await tester.pump();

      // The rank text must be a descendant of a RewardAccent — the scarcity
      // contract requires every gold pixel to flow through it.
      final rankFinder = find.textContaining('12');
      expect(rankFinder, findsOneWidget);
      final ancestor = find.ancestor(
        of: rankFinder,
        matching: find.byType(RewardAccent),
      );
      expect(ancestor, findsWidgets);
    });

    testWidgets('mediumImpact fires once at t=200ms (peak gold)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const RankUpOverlay(bodyPart: BodyPart.chest, newRank: 5)),
      );
      // Frame 0: not yet — haptic deferred to 200ms peak.
      await tester.pump();
      expect(hapticMediumCount, 0);

      // Advance past the 200ms peak — haptic should have fired exactly once.
      await tester.pump(const Duration(milliseconds: 220));
      expect(hapticMediumCount, 1);

      // Stay alive through the rest of the choreography — no extra haptic.
      await tester.pump(const Duration(milliseconds: 1000));
      expect(hapticMediumCount, 1);
    });

    testWidgets('completes the choreography without leaking tickers', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const RankUpOverlay(bodyPart: BodyPart.legs, newRank: 20)),
      );
      // 0-1100ms is the full choreography. Pump past it, then unmount.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      await tester.pump();
      // If the controller leaked, the tester would flag a pending timer at
      // teardown.
      expect(find.byType(RankUpOverlay), findsNothing);
    });
  });
}
