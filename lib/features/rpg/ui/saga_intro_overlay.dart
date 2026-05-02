import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/radii.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/reward_accent.dart';

/// First-run, 3-step explainer that introduces the gamification layer
/// (XP, LVL, rank). Pure presentation — the widget calls [onDismiss] when
/// the user taps "BEGIN" on the final step; the caller owns the
/// Hive-backed `saga_intro_seen` persistence (see `saga_intro_gate.dart`).
///
/// Visual direction (Arcane Ascent, §17.0c):
///   * Full-screen [AppColors.abyss] backdrop — no Material Dialog chrome.
///   * Rajdhani [AppTextStyles.headline] step titles with [AppColors.textCream].
///   * Inter [AppTextStyles.body] body copy with [AppColors.textDim].
///   * 80-dp hero SVG per step (hero silhouette / XP bolt / level sigil).
///   * Primary button is a Material [FilledButton] so it picks up the
///     primary-violet theme.
///
/// Phase 18-followups note (2026-04-29): the overlay used to take a
/// `Rank` parameter from the legacy gamification feature. After deleting
/// `lib/features/gamification/`, the rank label is computed by the gate
/// from the RPG `character_state` view (lifetime_xp + character_level)
/// and passed in as a pre-localized string. The overlay stays presentation-
/// only and has zero coupling to gamification or RPG models.
class SagaIntroOverlay extends StatefulWidget {
  const SagaIntroOverlay({
    required this.onDismiss,
    this.startingLevel = 1,
    this.rankLabel = '',
    super.key,
  });

  /// Called when the user taps "BEGIN" on the final step. The caller is
  /// responsible for flipping the `saga_intro_seen` pref and tearing the
  /// overlay down.
  final VoidCallback onDismiss;

  /// Level to display on the step-3 preview. Defaults to 1 for a fresh
  /// user; existing users get their retro-backfilled level from
  /// `character_state.character_level`.
  final int startingLevel;

  /// Pre-localized rank label for the step-3 preview ("ROOKIE", "IRON",
  /// "SILVER", ...). The gate computes this from `character_state` and
  /// resolves it through [AppLocalizations] so the overlay stays
  /// presentation-only.
  final String rankLabel;

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
              // BUG-025: header strip holds the centered step indicator and a
              // right-aligned Skip TextButton. Skip calls `widget.onDismiss`
              // directly — the gate persists `saga_intro_seen` regardless of
              // whether the user advanced through every step or bailed out.
              // Hidden on the final step since [_PrimaryButton] already
              // dismisses there ("BEGIN").
              SizedBox(
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _StepIndicator(step: _step, total: 3),
                    if (!isFinalStep)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Semantics(
                          container: true,
                          identifier: 'saga-intro-skip',
                          button: true,
                          label: l10n.sagaIntroSkip,
                          child: TextButton(
                            onPressed: widget.onDismiss,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textDim,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              // Visual pill stays ~32dp tall (controlled by
                              // padding + the label's font size), but the
                              // hit-test region extends to 48dp via
                              // `minimumSize` so we clear WCAG 2.5.5 / HIG
                              // touch-target guidance. `shrinkWrap` is kept
                              // so Material's default 48dp padding doesn't
                              // bloat the visible chrome.
                              minimumSize: const Size(48, 48),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              l10n.sagaIntroSkip,
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.textDim,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              Semantics(
                container: true,
                identifier: 'saga-intro-step-$_step',
                child: _StepContent(
                  step: _step,
                  l10n: l10n,
                  level: widget.startingLevel,
                  rankLabel: widget.rankLabel,
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
    required this.rankLabel,
  });

  final int step;
  final AppLocalizations l10n;
  final int level;
  final String rankLabel;

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
        l10n.sagaIntroStep3Title(level, rankLabel),
        l10n.sagaIntroStep3Body,
        AppIcons.levelUp,
        '$rankLabel rank',
      ),
    };

    // Step-3 is the "first-week warmth" moment where the scarcity rule
    // is intentionally relaxed (per PO research). We render the icon in
    // violet for steps 1-2 and gold on step 3 so onboarding builds
    // attachment before the app's normal scarcity budget kicks in. On
    // step 3 we wrap the hero SVG in a [RewardAccent] so the ambient
    // `IconTheme` paints the icon gold — `AppIcons.render` inherits the
    // icon color from its ancestor when no explicit `color:` is passed
    // (same contract as Material's `Icon`). This keeps the reward color
    // token reference structurally quarantined inside [RewardAccent] and
    // lets a future descendant (e.g. a "+N XP" text chip) share the
    // accent without each child plumbing the color through its call site.
    final isRewardStep = step == 2;
    final heroIcon = SizedBox(
      height: 160,
      child: Center(
        child: Semantics(
          label: semantic,
          child: isRewardStep
              ? AppIcons.render(icon, size: 96)
              : AppIcons.render(icon, color: AppColors.hotViolet, size: 96),
        ),
      ),
    );

    return Column(
      children: [
        if (isRewardStep) RewardAccent(child: heroIcon) else heroIcon,
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
