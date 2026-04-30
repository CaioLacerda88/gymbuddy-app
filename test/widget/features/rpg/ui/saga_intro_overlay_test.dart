/// Widget tests for [SagaIntroOverlay] (Phase 18 follow-ups rewire).
///
/// The overlay used to take a `Rank` enum from the legacy gamification
/// feature. After deleting `lib/features/gamification/`, the rank is
/// resolved by [SagaIntroGate] from `character_state.lifetime_xp` and
/// passed in as a pre-localized string. These tests pin the
/// presentation-only contract: step navigation, dismiss callback, and
/// step-3 preview rendering against arbitrary level / rank-label inputs.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/ui/saga_intro_overlay.dart';

import '../../../../helpers/test_material_app.dart';

void main() {
  group('SagaIntroOverlay', () {
    testWidgets('renders step 1 with NEXT button and no BEGIN', (tester) async {
      await tester.pumpWidget(
        TestMaterialApp(home: SagaIntroOverlay(onDismiss: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('YOUR TRAINING IS YOUR CHARACTER'), findsOneWidget);
      expect(find.text('NEXT'), findsOneWidget);
      expect(find.text('BEGIN'), findsNothing);
    });

    testWidgets('tapping NEXT advances to step 2', (tester) async {
      await tester.pumpWidget(
        TestMaterialApp(home: SagaIntroOverlay(onDismiss: () {})),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      expect(find.text('XP FROM EVERY SET, PR, QUEST'), findsOneWidget);
      expect(find.text('NEXT'), findsOneWidget);
    });

    testWidgets(
      'tapping NEXT twice reaches step 3 which shows BEGIN (not NEXT)',
      (tester) async {
        await tester.pumpWidget(
          TestMaterialApp(home: SagaIntroOverlay(onDismiss: () {})),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();

        expect(find.textContaining('LVL 1'), findsOneWidget);
        expect(find.text('BEGIN'), findsOneWidget);
        expect(find.text('NEXT'), findsNothing);
      },
    );

    testWidgets('tapping BEGIN on step 3 fires onDismiss exactly once', (
      tester,
    ) async {
      var dismissed = 0;
      await tester.pumpWidget(
        TestMaterialApp(
          home: SagaIntroOverlay(onDismiss: () => dismissed += 1),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BEGIN'));
      await tester.pumpAndSettle();

      expect(dismissed, 1);
    });

    testWidgets('step 3 renders the user-specific LVL + rank label', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestMaterialApp(
          home: SagaIntroOverlay(
            onDismiss: () {},
            startingLevel: 8,
            rankLabel: 'IRON',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      // Step-3 headline format: "LVL {n} — {RANK}"
      expect(find.textContaining('LVL 8'), findsOneWidget);
      expect(find.textContaining('IRON'), findsOneWidget);
    });
  });
}
