import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/radii.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/reward_accent.dart';
import '../domain/xp_calculator.dart';

/// First-run, 3-step explainer that introduces the gamification layer
/// (XP, LVL, rank). Pure presentation — the widget calls [onDismiss] when
/// the user taps "BEGIN" on the final step; the caller owns the
/// Hive-backed `saga_intro_seen` persistence (see `xp_provider.dart`).
///
/// Visual direction (Arcane Ascent, §17.0c):
///   * Full-screen [AppColors.abyss] backdrop — no Material Dialog chrome.
///   * Rajdhani [AppTextStyles.headline] step titles with [AppColors.textCream].
///   * Inter [AppTextStyles.body] body copy with [AppColors.textDim].
///   * 80-dp hero SVG per step (hero silhouette / XP bolt / level sigil).
///   * Primary button is a Material [FilledButton] so it picks up the
///     primary-violet theme.
class SagaIntroOverlay extends StatefulWidget {
  const SagaIntroOverlay({
    required this.onDismiss,
    this.startingLevel = 1,
    this.startingRank = Rank.rookie,
    super.key,
  });

  /// Called when the user taps "BEGIN" on the final step. The caller is
  /// responsible for flipping the `saga_intro_seen` pref and tearing the
  /// overlay down.
  final VoidCallback onDismiss;

  /// Level to display on the step-3 preview. Defaults to 1 for a fresh
  /// user; existing users get their retro-backfilled level.
  final int startingLevel;

  /// Rank to display on the step-3 preview. Defaults to [Rank.rookie].
  final Rank startingRank;

  @override
  State<SagaIntroOverlay> createState() => _SagaIntroOverlayState();
}

class _SagaIntroOverlayState extends State<SagaIntroOverlay> {
  int _step = 0;

  void _advance() {
    if (_step >= 2) {
      widget.onDismiss();
      return;
    }
    setState(() => _step += 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isFinalStep = _step == 2;

    return Material(
      color: AppColors.abyss,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepIndicator(step: _step, total: 3),
              const Spacer(),
              Semantics(
                container: true,
                identifier: 'saga-intro-step-$_step',
                child: _StepContent(
                  step: _step,
                  l10n: l10n,
                  level: widget.startingLevel,
                  rank: widget.startingRank,
                ),
              ),
              const Spacer(),
              _PrimaryButton(
                label: isFinalStep ? l10n.sagaIntroBegin : l10n.sagaIntroNext,
                identifier: isFinalStep
                    ? 'saga-intro-begin'
                    : 'saga-intro-next',
                onPressed: _advance,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(total, (i) {
        final isActive = i == step;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            width: 20,
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? AppColors.hotViolet : AppColors.surface2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _StepContent extends StatelessWidget {
  const _StepContent({
    required this.step,
    required this.l10n,
    required this.level,
    required this.rank,
  });

  final int step;
  final AppLocalizations l10n;
  final int level;
  final Rank rank;

  @override
  Widget build(BuildContext context) {
    final (title, body, icon, semantic) = switch (step) {
      0 => (
        l10n.sagaIntroStep1Title,
        l10n.sagaIntroStep1Body,
        AppIcons.hero,
        'hero silhouette',
      ),
      1 => (
        l10n.sagaIntroStep2Title,
        l10n.sagaIntroStep2Body,
        AppIcons.xp,
        'xp icon',
      ),
      _ => (
        l10n.sagaIntroStep3Title(level, _rankLabel(l10n, rank)),
        l10n.sagaIntroStep3Body,
        AppIcons.levelUp,
        '${rank.dbValue} rank',
      ),
    };

    // Step-3 is the "first-week warmth" moment where the scarcity rule
    // is intentionally relaxed (per PO research). We render the icon in
    // violet for steps 1-2 and gold on step 3 so onboarding builds
    // attachment before the app's normal scarcity budget kicks in. The
    // step-3 gold is read from `RewardAccent.color` to keep the gold
    // reference quarantined to the reward-accent module.
    final iconColor = step == 2 ? RewardAccent.color : AppColors.hotViolet;

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: Center(
            child: Semantics(
              label: semantic,
              child: AppIcons.render(icon, color: iconColor, size: 96),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.headline.copyWith(
            color: AppColors.textCream,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            body,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textDim,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  static String _rankLabel(AppLocalizations l10n, Rank r) => switch (r) {
    Rank.rookie => l10n.sagaRankRookie,
    Rank.iron => l10n.sagaRankIron,
    Rank.copper => l10n.sagaRankCopper,
    Rank.silver => l10n.sagaRankSilver,
    Rank.gold => l10n.sagaRankGold,
    Rank.platinum => l10n.sagaRankPlatinum,
    Rank.diamond => l10n.sagaRankDiamond,
  };
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.identifier,
    required this.onPressed,
  });

  final String label;
  final String identifier;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      identifier: identifier,
      label: label,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryViolet,
          foregroundColor: AppColors.textCream,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusSm + 2),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: AppColors.textCream,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
