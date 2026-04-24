/// Widget tests for [RewardAccent] — the single legal emitter of heroGold.
///
/// The scarcity framework hinges on this widget: violet is daily, gold is
/// reward. These tests verify that wrapping any Icon/Text subtree propagates
/// `AppColors.heroGold` automatically and that custom painters can look up
/// the same color via `RewardAccent.of(context)`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/shared/widgets/reward_accent.dart';

import '../../helpers/test_material_app.dart';

void main() {
  group('RewardAccent — IconTheme propagation', () {
    testWidgets('an Icon child inherits heroGold without explicit color', (
      tester,
    ) async {
      await tester.pumpWidget(
        const TestMaterialApp(
          home: Scaffold(
            body: Center(
              child: RewardAccent(
                child: Icon(Icons.emoji_events, key: ValueKey('trophy')),
              ),
            ),
          ),
        ),
      );

      final iconTheme = IconTheme.of(
        tester.element(find.byKey(const ValueKey('trophy'))),
      );
      expect(iconTheme.color, AppColors.heroGold);
    });

    testWidgets('a DefaultTextStyle child inherits heroGold', (tester) async {
      await tester.pumpWidget(
        const TestMaterialApp(
          home: Scaffold(
            body: Center(
              child: RewardAccent(
                child: Text('+125 XP', key: ValueKey('reward-text')),
              ),
            ),
          ),
        ),
      );

      final defaultStyle = DefaultTextStyle.of(
        tester.element(find.byKey(const ValueKey('reward-text'))),
      );
      expect(defaultStyle.style.color, AppColors.heroGold);
    });

    testWidgets('a Text child that specifies its own color is NOT overridden '
        '(inheritance respects explicit style)', (tester) async {
      await tester.pumpWidget(
        const TestMaterialApp(
          home: Scaffold(
            body: Center(
              child: RewardAccent(
                child: Text(
                  'explicit',
                  key: ValueKey('explicit-text'),
                  style: TextStyle(color: Color(0xFF00FF00)),
                ),
              ),
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(
        find.byKey(const ValueKey('explicit-text')),
      );
      expect(text.style?.color, const Color(0xFF00FF00));
    });
  });

  group('RewardAccent.of — custom painter lookup', () {
    testWidgets('returns heroGold when inside a RewardAccent ancestor', (
      tester,
    ) async {
      Color? capturedColor;

      await tester.pumpWidget(
        TestMaterialApp(
          home: Scaffold(
            body: Center(
              child: RewardAccent(
                child: Builder(
                  builder: (context) {
                    capturedColor = RewardAccent.of(context)?.color;
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(capturedColor, AppColors.heroGold);
    });

    testWidgets('returns null when there is no RewardAccent ancestor', (
      tester,
    ) async {
      Object? captured = 'sentinel';

      await tester.pumpWidget(
        TestMaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) {
                  captured = RewardAccent.of(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(captured, isNull);
    });
  });

  group('RewardAccent.color static', () {
    test('is the exact AppColors.heroGold token', () {
      expect(RewardAccent.color, AppColors.heroGold);
    });
  });
}
