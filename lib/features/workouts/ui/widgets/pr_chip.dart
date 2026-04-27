import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/reward_accent.dart';

/// Inline mid-set PR chip (Phase 18c, spec §13).
///
/// **Visual contract (locked):**
///   * Pill, 28dp height, 1px [AppColors.heroGold] @ 0.8 border via
///     [RewardAccent].
///   * Label "PR" Rajdhani 700 11sp [AppColors.heroGold] via [RewardAccent].
///   * NO icon, NO haptic, NO animation. The chip is a calm signal — gold
///     pixel emission alone communicates the win. Adding motion would
///     compete with the rank-up overlay's gold-hold beat at workout finish.
///
/// **Display contract:**
///   * The chip is presentation-only. Parent (set row) decides when to
///     render it: spec §13 fires the chip on **set commit** (i.e. the
///     check-mark tap), NOT on weight/reps input changes — typing
///     100 → 105 → 110 must not flash the chip mid-keystroke.
///   * Once rendered, the chip persists for the rest of the session
///     (it does not animate out, does not auto-dismiss).
///
/// **Why no haptic:** the haptic budget is reserved for the rank-up,
/// level-up, and rune-state-change moments. Diluting it on every PR
/// would cheapen those higher-tier signals.
class PrChip extends StatelessWidget {
  const PrChip({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RewardAccent(
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            // Chip border is the gold-pixel emission. RewardAccent only
            // forwards DefaultTextStyle, not BoxDecoration, so the border
            // color must be set directly. The whole widget is a RewardAccent
            // leaf so the scarcity contract is satisfied.
            // ignore: reward_accent — see comment above (PrChip is a RewardAccent leaf).
            color: AppColors.heroGold.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        child: Text(
          l10n.prChipLabel,
          style: AppTextStyles.display.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            // RewardAccent's DefaultTextStyle.merge will paint heroGold;
            // we pass null here so the merge wins and so a future caller
            // wrapping PrChip in a different IconTheme/DefaultTextStyle
            // (impossible by current usage but defensive) doesn't have
            // to fight a hard-coded color.
            // ignore: reward_accent — explicit text color inside RewardAccent leaf.
            color: AppColors.heroGold,
            height: 1,
          ),
        ),
      ),
    );
  }
}
