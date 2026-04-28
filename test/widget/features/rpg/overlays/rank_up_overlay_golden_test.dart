/// Golden tests for [RankUpOverlay] (Phase 18c, spec §13).
///
/// The rank-up overlay is the highest-risk paint surface in the celebration
/// queue — a multi-stage `ColorTween` driving a `BoxShadow` halo whose blur,
/// spread, and color all change phase between t=200ms and t=1100ms.
/// Assertion-only tests in `rank_up_overlay_test.dart` cover the haptic
/// timing, copy, and `RewardAccent` ancestry but cannot pin the visual
/// state at intermediate frames. Two goldens lock the most semantically
/// meaningful frames:
///
///   * **Peak gold (t=400ms)** — sigil holds heroGold, halo at full blur
///     (24) + spread (6), shadow color heroGold @ 0.5. This is the apex
///     of the celebration; a regression that broke the gold-hold beat
///     would shift the sigil color or shrink the halo here.
///   * **Settled (t=1100ms)** — sigil at hotViolet @ 0.9, shadow has
///     cross-faded to hotViolet @ 0.45. This is the "rune set into the
///     character sheet" terminal state and the perceptual bridge to the
///     Active RuneHalo.
///
/// Re-bake the goldens with:
///   flutter test --update-goldens \
///     test/widget/features/rpg/overlays/rank_up_overlay_golden_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';
import 'package:repsaga/features/rpg/ui/overlays/rank_up_overlay.dart';

import '../../../../helpers/test_material_app.dart';

Widget _wrap() {
  return const TestMaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          height: 360,
          child: RepaintBoundary(
            child: RankUpOverlay(bodyPart: BodyPart.chest, newRank: 5),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('RankUpOverlay golden', () {
    testWidgets('peak gold at t=400ms — heroGold hold + halo at full blur', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap());
      // Advance into the gold-hold beat (200-500ms). t=400ms hits the
      // halo at full blur (24) + spread (6), shadow color heroGold @ 0.5.
      await tester.pump(const Duration(milliseconds: 400));

      await expectLater(
        find.byType(RankUpOverlay),
        matchesGoldenFile('goldens/rank_up_overlay_peak_gold.png'),
      );
    });

    testWidgets('settled state at t=1100ms — hotViolet sigil + faded halo', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap());
      // Advance to the timeline tail. The settle tween (500-900ms) and
      // shadow cross-fade (900-1100ms) have both completed.
      await tester.pump(const Duration(milliseconds: 1100));

      await expectLater(
        find.byType(RankUpOverlay),
        matchesGoldenFile('goldens/rank_up_overlay_settled.png'),
      );
    });
  });
}
