import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pixel_image.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      // Deep-void fill so the wordmark reads against the same background
      // the rest of the app launches into. Avoids a color flash between
      // splash and first routed screen.
      backgroundColor: AppColors.deepVoid,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PixelImage(
              'assets/pixel/branding/repsaga_wordmark.png',
              semanticLabel: 'RepSaga',
              width: 256,
            ),
            SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.glowLavender,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
