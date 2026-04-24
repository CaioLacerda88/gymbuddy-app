/// Smoke-tests every [AppMuscleIcons] constant so a typo'd asset path fails
/// CI instead of silently rendering an empty glyph at runtime. Mirrors the
/// contract in `test/unit/core/theme/app_icons_test.dart` — each muscle glyph
/// must:
///   1. Resolve to a `.svg` asset under `assets/icons/v3-silhouette/`.
///   2. Use `fill="currentColor"` in-file so a single asset recolors via
///      `AppIcons.render` (the pack already ships that way; we verify the
///      render behavior via color-filter assertions below).
///   3. Render at 24 / 48 / 64 dp with an explicit color AND inherit from an
///      ancestor `IconTheme` when `color:` is omitted.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_icons.dart';
import 'package:repsaga/core/theme/app_muscle_icons.dart';
import 'package:repsaga/core/theme/app_theme.dart';

void main() {
  final icons = <String, String>{
    'chest': AppMuscleIcons.chest,
    'back': AppMuscleIcons.back,
    'legs': AppMuscleIcons.legs,
    'shoulders': AppMuscleIcons.shoulders,
    'arms': AppMuscleIcons.arms,
    'core': AppMuscleIcons.core,
    'cardio': AppMuscleIcons.cardio,
  };

  group('AppMuscleIcons constants — v3-silhouette asset paths', () {
    for (final entry in icons.entries) {
      test(
        '${entry.key} is an asset path under assets/icons/v3-silhouette/',
        () {
          final path = entry.value;
          expect(path, isNotEmpty);
          expect(path, startsWith('assets/icons/v3-silhouette/'));
          expect(path, endsWith('.svg'));
        },
      );
    }
  });

  group('AppMuscleIcons — AppIcons.render size + color propagation', () {
    for (final entry in icons.entries) {
      for (final size in const [24.0, 48.0, 64.0]) {
        testWidgets('${entry.key} renders at ${size.toInt()} dp with explicit '
            'color', (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: AppIcons.render(
                    entry.value,
                    color: AppColors.hotViolet,
                    size: size,
                  ),
                ),
              ),
            ),
          );

          final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
          expect(picture.width, size);
          expect(picture.height, size);
          expect(
            picture.colorFilter,
            const ColorFilter.mode(AppColors.hotViolet, BlendMode.srcIn),
          );
        });
      }

      testWidgets('${entry.key} inherits color from ancestor IconTheme '
          'when color: is omitted', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: IconTheme.merge(
                data: const IconThemeData(color: AppColors.hotViolet),
                child: Center(child: AppIcons.render(entry.value, size: 24)),
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
    }
  });
}
