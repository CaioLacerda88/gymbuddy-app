/// Locks in the Arcane Ascent palette (§17.0c) and typography rhythm.
///
/// The 12 color tokens + 7 text styles are the single source of truth every
/// screen paints through. If this test ever has to change to make CI pass,
/// treat that as a palette-change review — update the design doc first, not
/// the assertion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';

void main() {
  group('AppColors — Arcane Ascent 12-token palette', () {
    test('abyss is #0D0319', () {
      expect(AppColors.abyss, const Color(0xFF0D0319));
    });

    test('surface is #1A0F2E', () {
      expect(AppColors.surface, const Color(0xFF1A0F2E));
    });

    test('surface2 is #241640', () {
      expect(AppColors.surface2, const Color(0xFF241640));
    });

    test('primaryViolet is #6A2FA8', () {
      expect(AppColors.primaryViolet, const Color(0xFF6A2FA8));
    });

    test('hotViolet is #B36DFF', () {
      expect(AppColors.hotViolet, const Color(0xFFB36DFF));
    });

    test('heroGold is #FFB800 (reward-scarcity-gated)', () {
      // Intentionally asserted here despite the reward-accent lint.
      // This file is on the check_reward_accent.sh allow-list
      // (lib/core/theme/app_theme.dart owns the constant; test files are
      // automatically skipped by the script's `lib/` scope), so the lock-in
      // assertion does not break the scarcity rule.
      expect(AppColors.heroGold, const Color(0xFFFFB800));
    });

    test('textCream is #EEE7FA', () {
      expect(AppColors.textCream, const Color(0xFFEEE7FA));
    });

    test('textDim is #9C8DB8', () {
      expect(AppColors.textDim, const Color(0xFF9C8DB8));
    });

    test('success is #62C46D', () {
      expect(AppColors.success, const Color(0xFF62C46D));
    });

    test('warning is #FFB84D', () {
      expect(AppColors.warning, const Color(0xFFFFB84D));
    });

    test('error is #FF6B6B', () {
      expect(AppColors.error, const Color(0xFFFF6B6B));
    });

    test('hair is rgba(179,109,255,0.14)', () {
      // 0x24 == 36 == round(255 * 0.14).
      expect(AppColors.hair, const Color(0x24B36DFF));
    });
  });

  group('AppTextStyles — font families', () {
    // GoogleFonts stamps the family as "<Family>_<Variant>" (see
    // google_fonts/src/google_fonts_family_with_variant.dart). Locking a
    // `startsWith` assertion is resilient to fallback renames while still
    // failing loudly if someone swaps the family in app_theme.dart.

    test('display uses Rajdhani', () {
      expect(AppTextStyles.display.fontFamily, startsWith('Rajdhani'));
    });

    test('headline uses Rajdhani', () {
      expect(AppTextStyles.headline.fontFamily, startsWith('Rajdhani'));
    });

    test('title uses Inter', () {
      expect(AppTextStyles.title.fontFamily, startsWith('Inter'));
    });

    test('body uses Inter', () {
      expect(AppTextStyles.body.fontFamily, startsWith('Inter'));
    });

    test('bodySmall uses Inter', () {
      expect(AppTextStyles.bodySmall.fontFamily, startsWith('Inter'));
    });

    test('label uses Inter', () {
      expect(AppTextStyles.label.fontFamily, startsWith('Inter'));
    });

    test('numeric uses Rajdhani with tabular figures', () {
      expect(AppTextStyles.numeric.fontFamily, startsWith('Rajdhani'));
      expect(
        AppTextStyles.numeric.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });
  });

  group('AppTheme.dark', () {
    test('is Material 3', () {
      expect(AppTheme.dark.useMaterial3, isTrue);
    });

    test('is a dark-brightness theme', () {
      expect(AppTheme.dark.brightness, Brightness.dark);
    });

    test('scaffold background is AppColors.abyss', () {
      expect(AppTheme.dark.scaffoldBackgroundColor, AppColors.abyss);
    });

    test('primary color is AppColors.primaryViolet', () {
      expect(AppTheme.dark.colorScheme.primary, AppColors.primaryViolet);
    });

    test('surface is AppColors.surface', () {
      expect(AppTheme.dark.colorScheme.surface, AppColors.surface);
    });

    test('onSurface is AppColors.textCream', () {
      expect(AppTheme.dark.colorScheme.onSurface, AppColors.textCream);
    });

    test('error color is AppColors.error', () {
      expect(AppTheme.dark.colorScheme.error, AppColors.error);
    });
  });
}
