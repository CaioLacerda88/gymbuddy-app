import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';

/// Guardrail test for the 20 locked RepSaga palette tokens.
///
/// If any hex drifts the entire pixel-art direction drifts with it — every
/// generated PNG was authored against these exact values, and the palette
/// lock is referenced by name in `tasks/mockups/chatgpt-pixel-art-prompt.md`.
///
/// DO NOT "fix" this test by changing the expected values. If a role genuinely
/// needs a different color, update the mockup brief and the palette lock
/// together, then this test.
void main() {
  group('AppColors palette tokens', () {
    test('exposes all 20 locked RepSaga hex values', () {
      // Background / stone
      expect(AppColors.deepVoid, const Color(0xFF0D0319));
      expect(AppColors.duskPurple, const Color(0xFF2A0E4A));
      expect(AppColors.stoneViolet, const Color(0xFF3A1466));
      expect(AppColors.arcaneIndigo, const Color(0xFF6A2FA8));
      expect(AppColors.arcanePurple, const Color(0xFF8A3DC1));
      expect(AppColors.glowLavender, const Color(0xFFB36DFF));

      // Metal / chrome
      expect(AppColors.ironGrey, const Color(0xFF4A4560));
      expect(AppColors.stoneGrey, const Color(0xFF6A6585));

      // Leather / ember
      expect(AppColors.emberShadow, const Color(0xFF2A1A0F));
      expect(AppColors.bronzeShadow, const Color(0xFF7A4D00));

      // Gold family
      expect(AppColors.oldGold, const Color(0xFFD9B864));
      expect(AppColors.questGold, const Color(0xFFFFB800));
      expect(AppColors.hotGold, const Color(0xFFFFD54F));
      expect(AppColors.creamLight, const Color(0xFFFFF1B8));
      expect(AppColors.parchment, const Color(0xFFF3E6C6));

      // Stat accents
      expect(AppColors.emeraldGreen, const Color(0xFF3EC46D));
      expect(AppColors.skyBlue, const Color(0xFF3BB0E6));
      expect(AppColors.iceBlue, const Color(0xFF7FD1F2));
      expect(AppColors.hazardRed, const Color(0xFFE03A3A));

      // Utility
      expect(AppColors.pureWhite, const Color(0xFFFFFFFF));
    });

    test('prBadgeColor maps to hotGold', () {
      expect(AppTheme.prBadgeColor, AppColors.hotGold);
    });
  });

  group('AppTextStyles pixel styles', () {
    test('pixelHero uses Press-Start-2P at 32pt with h1.0, ls0', () {
      expect(AppTextStyles.pixelHero.fontFamily, 'PressStart2P');
      expect(AppTextStyles.pixelHero.fontSize, 32);
      expect(AppTextStyles.pixelHero.height, 1.0);
      expect(AppTextStyles.pixelHero.letterSpacing, 0);
    });

    test('pixelLabel uses Press-Start-2P at 10pt with h1.0, ls0', () {
      expect(AppTextStyles.pixelLabel.fontFamily, 'PressStart2P');
      expect(AppTextStyles.pixelLabel.fontSize, 10);
      expect(AppTextStyles.pixelLabel.height, 1.0);
      expect(AppTextStyles.pixelLabel.letterSpacing, 0);
    });
  });
}
