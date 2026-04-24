import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';

/// Launch surface shown while auth state resolves.
///
/// Renders the Rajdhani "REPSAGA" wordmark on the abyss-violet background
/// so there is no color flash between the native launch screen and the
/// first routed screen. The sigil above the wordmark is a placeholder
/// using the hero-silhouette `AppIcons.hero` until the user-supplied app
/// icon lands (Stage 6 of the Arcane migration).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyss,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcons.render(
              AppIcons.hero,
              color: AppColors.hotViolet,
              size: 96,
            ),
            const SizedBox(height: 24),
            Text(
              'REPSAGA',
              style: AppTextStyles.display.copyWith(
                fontSize: 40,
                letterSpacing: 0.08 * 40,
                color: AppColors.textCream,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.hotViolet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
