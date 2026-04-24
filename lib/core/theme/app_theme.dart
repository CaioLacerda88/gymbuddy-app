import 'package:flutter/material.dart';

/// Locked RepSaga pixel-art palette (20 tokens).
///
/// These hex values are the single source of truth for every color in the app.
/// They were chosen for the pixel-art visual direction (see
/// `tasks/mockups/chatgpt-pixel-art-prompt.md` §1.3) and must not be
/// extended or substituted without updating the palette-tokens test.
///
/// Nothing else in `lib/` should ship a raw `Color(0x…)` — `scripts/check_hardcoded_colors.sh`
/// enforces this for `lib/features/`.
class AppColors {
  const AppColors._();

  // Background / stone
  static const deepVoid = Color(0xFF0D0319);
  static const duskPurple = Color(0xFF2A0E4A);
  static const stoneViolet = Color(0xFF3A1466);
  static const arcaneIndigo = Color(0xFF6A2FA8);
  static const arcanePurple = Color(0xFF8A3DC1);
  static const glowLavender = Color(0xFFB36DFF);

  // Metal / chrome
  static const ironGrey = Color(0xFF4A4560);
  static const stoneGrey = Color(0xFF6A6585);

  // Leather / ember
  static const emberShadow = Color(0xFF2A1A0F);
  static const bronzeShadow = Color(0xFF7A4D00);

  // Gold family (hero / reward)
  static const oldGold = Color(0xFFD9B864);
  static const questGold = Color(0xFFFFB800);
  static const hotGold = Color(0xFFFFD54F);
  static const creamLight = Color(0xFFFFF1B8);
  static const parchment = Color(0xFFF3E6C6);

  // Stat accents
  static const emeraldGreen = Color(0xFF3EC46D);
  static const skyBlue = Color(0xFF3BB0E6);
  static const iceBlue = Color(0xFF7FD1F2);
  static const hazardRed = Color(0xFFE03A3A);

  // Utility
  static const pureWhite = Color(0xFFFFFFFF);
}

/// Typography tokens that sit on top of the Material `TextTheme`.
///
/// Body/title copy stays on the default stack (Inter/Roboto) — Press-Start-2P
/// is unreadable for paragraphs. The pixel styles are *moment* styles for
/// LVL numbers, "NEW RECORD" banners, and small chip labels.
class AppTextStyles {
  const AppTextStyles._();

  /// Press-Start-2P 32pt — hero numerals + celebration banner copy.
  ///
  /// Press-Start-2P looks crisp at integer sizes (8/16/24/32pt) and blurry at
  /// fractional ones. Keep to the multiples.
  static const pixelHero = TextStyle(
    fontFamily: 'PressStart2P',
    fontSize: 32,
    height: 1.0,
    letterSpacing: 0,
  );

  /// Press-Start-2P 10pt — small chip labels, streak-count badges, XP counters.
  static const pixelLabel = TextStyle(
    fontFamily: 'PressStart2P',
    fontSize: 10,
    height: 1.0,
    letterSpacing: 0,
  );
}

class AppTheme {
  const AppTheme._();

  // Role → palette mapping. `AppTheme.primaryGradient` /
  // `destructiveGradient` / `prBadgeColor` remain the public API; they are
  // now assembled from palette tokens.
  static const _primaryColor = AppColors.arcanePurple;
  static const _surfaceColor = AppColors.duskPurple;
  static const _backgroundColor = AppColors.deepVoid;
  static const _cardColor = AppColors.stoneViolet;
  static const _errorColor = AppColors.hazardRed;

  static const primaryGradient = LinearGradient(
    colors: [AppColors.arcanePurple, AppColors.arcaneIndigo],
  );

  static const destructiveGradient = LinearGradient(
    colors: [AppColors.hazardRed, AppColors.bronzeShadow],
  );

  /// Color for personal record badges (trophy icons on workout detail).
  static const prBadgeColor = AppColors.hotGold;

  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      primary: _primaryColor,
      onPrimary: AppColors.pureWhite,
      secondary: AppColors.glowLavender,
      onSecondary: AppColors.deepVoid,
      surface: _surfaceColor,
      onSurface: AppColors.pureWhite,
      error: _errorColor,
      onError: AppColors.pureWhite,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _backgroundColor,
      textTheme: _textTheme,
      cardTheme: _cardTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      inputDecorationTheme: _inputDecorationTheme,
      segmentedButtonTheme: _segmentedButtonTheme,
      // Material's default FAB is a circle. Pixel-art rejects circles:
      // a RoundedRectangleBorder with the default zero-radius produces the
      // square silhouette the rest of the theme converges on.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(),
      ),
      // 2px chamfer on the top corners only. A fully sharp top edge against
      // a rounded scrim reads as a clip artifact rather than a modal
      // surface; 2px is the smallest value that still signals "overlay".
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
        ),
      ),
      // Floating behavior + 2px chamfer so the SnackBar reads as feedback
      // that's been dropped on top of the scene, not a bar fused to the
      // status row. Behavior is explicit here; anything that overrides it
      // per-call-site is doing so intentionally.
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
      ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  static const _textTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 48,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.5,
    ),
    displayMedium: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    ),
    headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
    headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 16),
    bodyMedium: TextStyle(fontSize: 14),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
  );

  static const _cardTheme = CardThemeData(
    color: _cardColor,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  );

  static final _elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _primaryColor,
      foregroundColor: AppColors.pureWhite,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
  );

  /// Dark-surface tuning for Material 3 `SegmentedButton`.
  ///
  /// The M3 default renders underpowered on our dusk-purple surface: the
  /// selected container is barely tinted and the unselected label drops to
  /// ~0.38 alpha, making both states read ghostly. This theme bumps selected
  /// visibility (primary tint at 0.15, primary foreground, weight 600) and
  /// lifts unselected foreground to 0.75 alpha so both segments stay legible
  /// on dark surfaces.
  static final _segmentedButtonTheme = SegmentedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return _primaryColor.withValues(alpha: 0.15);
        }
        return Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return _primaryColor;
        }
        return AppColors.pureWhite.withValues(alpha: 0.75);
      }),
      textStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(fontWeight: FontWeight.w600);
        }
        return const TextStyle(fontWeight: FontWeight.w500);
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return BorderSide(color: _primaryColor.withValues(alpha: 0.5));
        }
        return BorderSide(color: AppColors.pureWhite.withValues(alpha: 0.15));
      }),
    ),
  );

  static const _inputDecorationTheme = InputDecorationThemeData(
    filled: true,
    fillColor: _cardColor,
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: _primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: _errorColor, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: _errorColor, width: 2),
    ),
  );
}
