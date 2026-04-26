import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/radii.dart';

/// Small pill that renders the user's currently equipped title.
///
/// Renders [SizedBox.shrink] when `title` is null — the slot is hidden, not
/// replaced by a placeholder, per spec §13.1. Phase 18b ships with no
/// titles equipped (the [activeTitleProvider] stub returns null), so this
/// widget is effectively dormant until 18c lands the title catalog +
/// equip flow.
class ActiveTitlePill extends StatelessWidget {
  const ActiveTitlePill({super.key, required this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = title;
    if (t == null || t.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border.all(
          color: AppColors.hotViolet.withValues(alpha: 0.5),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(kRadiusSm + 2),
      ),
      child: Text(
        t,
        style: theme.textTheme.labelMedium?.copyWith(
          color: AppColors.hotViolet,
        ),
      ),
    );
  }
}
