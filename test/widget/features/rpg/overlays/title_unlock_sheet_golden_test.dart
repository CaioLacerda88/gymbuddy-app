/// Golden tests for [TitleUnlockSheet] (Phase 18c, spec §13.2).
///
/// The sheet's most fragile invariant is the gold-scarcity contract: the
/// first-ever earned title MUST render in heroGold via [RewardAccent]; every
/// subsequent unlock MUST stay in textCream. Assertion tests in
/// `title_unlock_sheet_test.dart` verify the [RewardAccent] ancestor
/// presence, but only goldens catch the visual difference (gold vs cream
/// pixel color of the title-name text) plus the rune watermark layout.
///
/// Two goldens are locked:
///
///   * **First-ever unlock** — `isFirstEver: true`. Title name renders in
///     heroGold. This is the only sheet state where gold lights up.
///   * **Subsequent unlock** — `isFirstEver: false`. Title name renders in
///     textCream. Used for every unlock after #1.
///
/// Re-bake with:
///   flutter test --update-goldens \
///     test/widget/features/rpg/overlays/title_unlock_sheet_golden_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';
import 'package:repsaga/features/rpg/models/title.dart' as rpg;
import 'package:repsaga/features/rpg/ui/overlays/title_unlock_sheet.dart';

import '../../../../helpers/test_material_app.dart';

const _chestR5 = rpg.Title(
  slug: 'chest_r5_initiate_of_the_forge',
  bodyPart: BodyPart.chest,
  rankThreshold: 5,
);

Widget _wrap({required bool isFirstEver}) {
  return TestMaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          height: 420,
          child: RepaintBoundary(
            child: TitleUnlockSheet(
              title: _chestR5,
              isFirstEver: isFirstEver,
              onEquip: () async {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('TitleUnlockSheet golden', () {
    testWidgets('first-ever unlock — title name in heroGold', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(isFirstEver: true));
      await tester.pump();

      await expectLater(
        find.byType(TitleUnlockSheet),
        matchesGoldenFile('goldens/title_unlock_sheet_first_ever.png'),
      );
    });

    testWidgets('subsequent unlock — title name in textCream', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(isFirstEver: false));
      await tester.pump();

      await expectLater(
        find.byType(TitleUnlockSheet),
        matchesGoldenFile('goldens/title_unlock_sheet_subsequent.png'),
      );
    });
  });
}
