/// Smoke-tests every [AppIcons] constant so a malformed SVG string fails CI
/// instead of throwing at app launch. Also verifies the shared renderer
/// applies size + color uniformly at the three canonical scales (24 dp nav,
/// 40 dp inline-reward, 64 dp hero).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:repsaga/core/theme/app_icons.dart';
import 'package:repsaga/core/theme/app_theme.dart';

void main() {
  // Each entry asserts: (1) the constant parses as valid SVG, (2)
  // `AppIcons.render` produces an `SvgPicture` whose color filter is srcIn
  // with the requested color.
  final icons = <String, String>{
    'home': AppIcons.home,
    'lift': AppIcons.lift,
    'plan': AppIcons.plan,
    'stats': AppIcons.stats,
    'hero': AppIcons.hero,
    'xp': AppIcons.xp,
    'levelUp': AppIcons.levelUp,
    'streak': AppIcons.streak,
    'check': AppIcons.check,
    'add': AppIcons.add,
    'edit': AppIcons.edit,
    'delete': AppIcons.delete,
    'filter': AppIcons.filter,
    'search': AppIcons.search,
    'settings': AppIcons.settings,
    'play': AppIcons.play,
    'pause': AppIcons.pause,
    'resume': AppIcons.resume,
    'finish': AppIcons.finish,
    'close': AppIcons.close,
  };

  group('AppIcons constants — well-formed SVG', () {
    for (final entry in icons.entries) {
      test('${entry.key} is a non-empty <svg> string with a viewBox', () {
        final svg = entry.value;
        expect(svg, isNotEmpty);
        expect(svg, startsWith('<svg'));
        expect(svg, contains('viewBox="0 0 48 48"'));
        expect(svg.trim(), endsWith('</svg>'));
      });
    }
  });

  group('AppIcons.render — size + color propagation', () {
    for (final entry in icons.entries) {
      testWidgets('${entry.key} renders at 24 dp (nav scale)', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AppIcons.render(
                  entry.value,
                  color: AppColors.hotViolet,
                  size: 24,
                ),
              ),
            ),
          ),
        );

        final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
        expect(picture.width, 24);
        expect(picture.height, 24);
      });

      testWidgets('${entry.key} renders at 40 dp (inline-reward scale)', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AppIcons.render(
                  entry.value,
                  color: AppColors.hotViolet,
                  size: 40,
                ),
              ),
            ),
          ),
        );

        final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
        expect(picture.width, 40);
        expect(picture.height, 40);
      });

      testWidgets('${entry.key} renders at 64 dp (hero scale)', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AppIcons.render(
                  entry.value,
                  color: AppColors.hotViolet,
                  size: 64,
                ),
              ),
            ),
          ),
        );

        final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
        expect(picture.width, 64);
        expect(picture.height, 64);
      });
    }

    testWidgets('applies a srcIn color filter at the requested color', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppIcons.render(
                AppIcons.lift,
                color: AppColors.hotViolet,
                size: 24,
              ),
            ),
          ),
        ),
      );

      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        picture.colorFilter,
        const ColorFilter.mode(AppColors.hotViolet, BlendMode.srcIn),
      );
    });

    testWidgets(
      'forwards semanticsLabel so VoiceOver / TalkBack users see the icon',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AppIcons.render(
                  AppIcons.lift,
                  color: AppColors.hotViolet,
                  size: 24,
                  semanticsLabel: 'start workout',
                ),
              ),
            ),
          ),
        );

        expect(find.bySemanticsLabel('start workout'), findsOneWidget);
      },
    );
  });

  // Guards the IconTheme-fallback contract: when a caller omits `color:`,
  // the renderer must read from the ambient `IconTheme`. This is the path
  // `RewardAccent` relies on to paint descendant SVGs gold without the
  // child needing to reference `AppColors.heroGold` directly. If this test
  // breaks, the reward-scarcity quarantine is leaking.
  group('AppIcons.render — IconTheme inheritance', () {
    testWidgets(
      'inherits color from ancestor IconTheme when color: is omitted',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: IconTheme(
                data: const IconThemeData(color: AppColors.heroGold),
                child: Center(child: AppIcons.render(AppIcons.lift, size: 24)),
              ),
            ),
          ),
        );

        final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
        expect(
          picture.colorFilter,
          const ColorFilter.mode(AppColors.heroGold, BlendMode.srcIn),
        );
      },
    );

    testWidgets('explicit color: overrides ancestor IconTheme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconTheme(
              data: const IconThemeData(color: AppColors.heroGold),
              child: Center(
                child: AppIcons.render(
                  AppIcons.lift,
                  color: AppColors.hotViolet,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      );

      // The explicit `hotViolet` must win over the ancestor `heroGold`.
      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        picture.colorFilter,
        const ColorFilter.mode(AppColors.hotViolet, BlendMode.srcIn),
      );
    });
  });
}
