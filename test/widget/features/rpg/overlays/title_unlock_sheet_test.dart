/// Widget tests for [TitleUnlockSheet] (Phase 18c).
///
/// Spec §13.2: half-sheet at fixed 0.45 height, NO gradient (flat surface2),
/// rune watermark via Stack + IgnorePointer SVG, fixed copy hierarchy.
/// First-ever title wraps name in RewardAccent (heroGold); subsequent
/// titles render in textCream only.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';
import 'package:repsaga/features/rpg/models/title.dart' as rpg;
import 'package:repsaga/features/rpg/ui/overlays/title_unlock_sheet.dart';
import 'package:repsaga/shared/widgets/reward_accent.dart';

import '../../../../helpers/test_material_app.dart';

const _chestR5 = rpg.Title.bodyPart(
  slug: 'chest_r5_initiate_of_the_forge',
  bodyPart: BodyPart.chest,
  rankThreshold: 5,
);

Widget _wrap({
  required rpg.Title title,
  required bool isFirstEver,
  Future<void> Function()? onEquip,
}) => TestMaterialApp(
  home: Scaffold(
    body: TitleUnlockSheet(
      title: title,
      isFirstEver: isFirstEver,
      onEquip: onEquip ?? () async {},
    ),
  ),
);

void main() {
  group('TitleUnlockSheet', () {
    testWidgets('renders rank label, title name, and equip CTA', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(title: _chestR5, isFirstEver: true));
      await tester.pump();

      expect(find.textContaining('CHEST'), findsWidgets);
      expect(find.textContaining('5'), findsWidgets);
      expect(find.textContaining('Initiate'), findsOneWidget);
      expect(find.textContaining('EQUIP'), findsWidgets);
    });

    testWidgets('first-ever title wraps name in RewardAccent', (tester) async {
      await tester.pumpWidget(_wrap(title: _chestR5, isFirstEver: true));
      await tester.pump();

      final nameFinder = find.text('Initiate of the Forge');
      expect(nameFinder, findsOneWidget);
      final ancestor = find.ancestor(
        of: nameFinder,
        matching: find.byType(RewardAccent),
      );
      expect(
        ancestor,
        findsWidgets,
        reason: 'first-ever title must render in heroGold via RewardAccent',
      );
    });

    testWidgets('subsequent titles do NOT wrap name in RewardAccent', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(title: _chestR5, isFirstEver: false));
      await tester.pump();

      final nameFinder = find.text('Initiate of the Forge');
      expect(nameFinder, findsOneWidget);
      final ancestor = find.ancestor(
        of: nameFinder,
        matching: find.byType(RewardAccent),
      );
      expect(
        ancestor,
        findsNothing,
        reason:
            'subsequent titles should not consume the heroGold scarcity '
            'budget — they render in textCream only',
      );
    });

    testWidgets('equip button invokes onEquip callback', (tester) async {
      var equipCalls = 0;
      await tester.pumpWidget(
        _wrap(
          title: _chestR5,
          isFirstEver: true,
          onEquip: () async {
            equipCalls += 1;
          },
        ),
      );
      await tester.pump();

      await tester.tap(find.textContaining('EQUIP'));
      await tester.pump();
      // Pump for the async callback to settle.
      await tester.pump(const Duration(milliseconds: 100));

      expect(equipCalls, 1);
    });

    testWidgets('rune watermark is wrapped in IgnorePointer (decorative)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(title: _chestR5, isFirstEver: true));
      await tester.pump();
      // Spec: watermark must NOT capture pointer events. The
      // IgnorePointer guards the equip-button hit region from a
      // misalignment-induced miss.
      expect(find.byType(IgnorePointer), findsWidgets);
    });
  });
}
