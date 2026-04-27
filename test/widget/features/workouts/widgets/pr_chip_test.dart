/// Widget tests for [PrChip] (Phase 18c).
///
/// Spec §13: inline mid-set PR chip. Renders "PR" Rajdhani 700 11sp in
/// heroGold via RewardAccent, 1px heroGold @ 0.8 border. NO icon, NO
/// haptic, NO animation. Persists for the session — toggling visibility
/// is the PARENT's responsibility (PrChip is shown/hidden by the set row).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/workouts/ui/widgets/pr_chip.dart';
import 'package:repsaga/shared/widgets/reward_accent.dart';

import '../../../../helpers/test_material_app.dart';

Widget _wrap(Widget child) => TestMaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('PrChip', () {
    testWidgets('renders "PR" label', (tester) async {
      await tester.pumpWidget(_wrap(const PrChip()));
      await tester.pump();

      expect(find.text('PR'), findsOneWidget);
    });

    testWidgets('wraps the label in RewardAccent (heroGold scarcity)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const PrChip()));
      await tester.pump();

      final labelFinder = find.text('PR');
      expect(labelFinder, findsOneWidget);
      final accentAncestor = find.ancestor(
        of: labelFinder,
        matching: find.byType(RewardAccent),
      );
      expect(
        accentAncestor,
        findsOneWidget,
        reason:
            'PR chip must emit heroGold pixels via RewardAccent — the '
            'scarcity contract requires the gold border AND label both '
            'flow through the single sanctioned widget.',
      );
    });

    testWidgets('renders no icon (spec: NO icon, NO animation)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const PrChip()));
      await tester.pump();

      // Spec rejects iconography to keep the chip terse and inline.
      expect(find.byType(Icon), findsNothing);
    });
  });
}
