/// Widget tests for [CelebrationOverflowCard] (Phase 18c).
///
/// Spec §13 / WIP: non-modal condensed card "N more rank-ups — open Saga".
/// 4s auto-dismiss, tappable to route handler, copy renders pluralized count,
/// muted "tap to continue" hint signals discoverability.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/ui/overlays/celebration_overflow_card.dart';

import '../../../../helpers/test_material_app.dart';

Widget _wrap({
  required int count,
  VoidCallback? onTap,
  VoidCallback? onAutoDismiss,
}) => TestMaterialApp(
  home: Scaffold(
    body: Center(
      child: CelebrationOverflowCard(
        overflowCount: count,
        onTap: onTap ?? () {},
        onAutoDismiss: onAutoDismiss ?? () {},
      ),
    ),
  ),
);

void main() {
  group('CelebrationOverflowCard', () {
    testWidgets('renders pluralized "N more rank-ups" copy', (tester) async {
      await tester.pumpWidget(_wrap(count: 2));
      await tester.pump();

      expect(find.textContaining('2'), findsWidgets);
      expect(find.textContaining('rank-ups'), findsOneWidget);
      expect(find.textContaining('Saga'), findsOneWidget);
    });

    testWidgets('renders singular form when overflowCount == 1', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(count: 1));
      await tester.pump();

      expect(find.textContaining('1 more rank-up'), findsOneWidget);
    });

    testWidgets('renders muted "Tap to continue" hint for discoverability', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(count: 2));
      await tester.pump();

      expect(find.text('Tap to continue'), findsOneWidget);
    });

    testWidgets('tap invokes onTap callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(count: 2, onTap: () => taps += 1));
      await tester.pump();

      await tester.tap(find.byType(CelebrationOverflowCard));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('auto-dismisses after 4 seconds', (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(
        _wrap(count: 2, onAutoDismiss: () => dismissed += 1),
      );
      await tester.pump();
      // Before 4s tick — no fire yet.
      await tester.pump(const Duration(milliseconds: 3900));
      expect(dismissed, 0);
      // After 4s tick — fires once.
      await tester.pump(const Duration(milliseconds: 200));
      expect(dismissed, 1);

      // Settle the widget (it may still be rendering).
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('does NOT auto-dismiss after unmount', (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(
        _wrap(count: 5, onAutoDismiss: () => dismissed += 1),
      );
      await tester.pump();
      // Sanity: timer hasn't fired immediately.
      expect(dismissed, 0);

      // Replace the widget BEFORE the 4s timer elapses — the timer should
      // not invoke onAutoDismiss after the widget is unmounted.
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 3000));
      expect(dismissed, 0);
    });
  });
}
