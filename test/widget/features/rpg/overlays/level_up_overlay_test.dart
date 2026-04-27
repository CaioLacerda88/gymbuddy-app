/// Widget tests for [LevelUpOverlay] (Phase 18c).
///
/// Differentiation contract from RankUpOverlay (locked in WIP.md):
///   * Glyph: numeral itself (Rajdhani 700 64sp), no muscle icon.
///   * Pure heroGold throughout — no settle into hotViolet.
///   * SlideTransition Offset(0.08, 0) → Offset.zero, 200ms easeOutCubic.
///   * NO backdrop dim.
///   * heavyImpact at t=0 (RankUp = medium at peak; LevelUp = heavy at entry).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/ui/overlays/level_up_overlay.dart';
import 'package:repsaga/shared/widgets/reward_accent.dart';

import '../../../../helpers/test_material_app.dart';

Widget _wrap(Widget child) =>
    TestMaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('LevelUpOverlay', () {
    late int hapticHeavyCount;

    setUp(() {
      hapticHeavyCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate' &&
                call.arguments == 'HapticFeedbackType.heavyImpact') {
              hapticHeavyCount += 1;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('renders LEVEL {N} numeral and label', (tester) async {
      await tester.pumpWidget(_wrap(const LevelUpOverlay(newLevel: 3)));
      await tester.pump();

      expect(find.textContaining('3'), findsOneWidget);
      expect(find.textContaining('LEVEL'), findsOneWidget);
    });

    testWidgets('numeral is wrapped in RewardAccent (heroGold)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const LevelUpOverlay(newLevel: 7)));
      await tester.pump();

      final numeral = find.text('7');
      expect(numeral, findsOneWidget);
      final ancestor = find.ancestor(
        of: numeral,
        matching: find.byType(RewardAccent),
      );
      expect(ancestor, findsWidgets);
    });

    testWidgets('heavyImpact fires exactly once at t=0', (tester) async {
      await tester.pumpWidget(_wrap(const LevelUpOverlay(newLevel: 3)));
      await tester.pump();
      expect(hapticHeavyCount, 1);

      // No additional haptic across the rest of the lifetime.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));
      expect(hapticHeavyCount, 1);
    });

    testWidgets('does NOT render a full-screen backdrop dim layer', (
      tester,
    ) async {
      // Level-up specifically excludes a backdrop dim; stacking dims when
      // already in a queue is oppressive.
      await tester.pumpWidget(_wrap(const LevelUpOverlay(newLevel: 3)));
      await tester.pump();

      // No `Positioned.fill` with a ColoredBox in the level-up subtree
      // (there's no Positioned at all since the overlay isn't a Stack).
      expect(find.byType(Positioned), findsNothing);
    });

    testWidgets('completes the entry animation cleanly', (tester) async {
      await tester.pumpWidget(_wrap(const LevelUpOverlay(newLevel: 12)));
      await tester.pump();
      // Slide entry is 200ms.
      await tester.pump(const Duration(milliseconds: 250));

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      await tester.pump();
      expect(find.byType(LevelUpOverlay), findsNothing);
    });
  });
}
