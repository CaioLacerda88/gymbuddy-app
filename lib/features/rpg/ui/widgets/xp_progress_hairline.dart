import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/vitality_state.dart';

/// 1px hairline + dot marker showing rank progress (xp_in_rank /
/// xp_for_next_rank).
///
/// The kickoff lock specifies a hairline, NOT a filled bar. A filled bar
/// dominates the row and re-introduces the "stat-bar grid" feel the radar
/// was meant to replace. The hairline reads as "current-state mark on a
/// trajectory" — quiet, glanceable, doesn't compete with the rank stamp.
///
/// Dot color = vitality state color, line color = [hair] divider tone.
class XpProgressHairline extends StatelessWidget {
  const XpProgressHairline({
    super.key,
    required this.xpInRank,
    required this.xpForNextRank,
    required this.vitalityState,
    this.height = 8,
  });

  final double xpInRank;
  final double xpForNextRank;
  final VitalityState vitalityState;

  /// Total reserved height — the line itself is 1 dp; the rest is padding
  /// so the dot doesn't clip vertically.
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fraction = xpForNextRank <= 0
            ? 1.0
            : (xpInRank / xpForNextRank).clamp(0.0, 1.0);
        // Inset the dot so its edge stays inside the line on the extremes.
        const dotRadius = 3.0;
        final dotCenterX = (fraction * (width - dotRadius * 2)) + dotRadius;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: height / 2,
                child: Container(height: 1, color: AppColors.hair),
              ),
              Positioned(
                left: dotCenterX - dotRadius,
                top: (height / 2) - dotRadius,
                child: Container(
                  width: dotRadius * 2,
                  height: dotRadius * 2,
                  decoration: BoxDecoration(
                    color: vitalityState.borderColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
