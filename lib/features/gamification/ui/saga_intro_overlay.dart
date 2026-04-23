import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/pixel_image.dart';
import '../../../shared/widgets/pixel_panel.dart';
import '../domain/xp_calculator.dart';

/// First-run, 3-step pixel-art explainer that introduces the gamification
/// layer (XP, LVL, rank). Pure presentation — the widget calls [onDismiss]
/// when the user taps "BEGIN" on the final step; the caller owns the
/// Hive-backed `saga_intro_seen` persistence (see `xp_provider.dart`).
///
/// Visual direction (per PLAN §17b + §17.0):
///   * Full-screen `AppColors.deepVoid` backdrop — no Material Dialog chrome.
///   * Pixel-art hero image per step (PixelImage, nearest-neighbor).
///   * Press-Start-2P headline via [AppTextStyles.pixelHero].
///   * Body copy in [AppTextStyles.pixelLabel] 10pt for the cadence-match
///     (small, crunchy pixel text against the hero).
///   * Primary button is a [PixelPanel]-wrapped tap target — no Material
///     button, no rounded corners.
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
      // A full-screen Material with our deep-void background keeps the
      // overlay Ink-response-free (no ripple, no elevation tint). Using
      // Material over Container lets descendant widgets (like the pixel
      // button's InkWell) still ripple correctly when present.
      color: AppColors.deepVoid,
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
            width: 16,
            height: 4,
            color: isActive ? AppColors.hotGold : AppColors.ironGrey,
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
    final (title, body, asset, semantic) = switch (step) {
      0 => (
        l10n.sagaIntroStep1Title,
        l10n.sagaIntroStep1Body,
        'assets/pixel/story/your_saga_begins.png',
        'story illustration',
      ),
      1 => (
        l10n.sagaIntroStep2Title,
        l10n.sagaIntroStep2Body,
        'assets/pixel/micro/xp_crystal.png',
        'xp crystal',
      ),
      _ => (
        l10n.sagaIntroStep3Title(level, _rankLabel(l10n, rank)),
        l10n.sagaIntroStep3Body,
        _rankAsset(rank),
        '${rank.dbValue} rank',
      ),
    };

    return Column(
      children: [
        SizedBox(
          height: 192,
          child: Center(
            child: PixelImage(asset, semanticLabel: semantic, height: 160),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.pixelHero.copyWith(
            color: AppColors.creamLight,
            fontSize: 20,
            // Press-Start-2P with normal line-height renders clipped
            // ascenders on small headlines; bump to 1.4 for multi-line.
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            body,
            textAlign: TextAlign.center,
            style: AppTextStyles.pixelLabel.copyWith(
              color: AppColors.glowLavender,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  static String _rankAsset(Rank r) => switch (r) {
    Rank.rookie => 'assets/pixel/ranks/rookie.png',
    Rank.iron => 'assets/pixel/ranks/iron.png',
    Rank.copper => 'assets/pixel/ranks/copper.png',
    Rank.silver => 'assets/pixel/ranks/silver.png',
    Rank.gold => 'assets/pixel/ranks/gold.png',
    Rank.platinum => 'assets/pixel/ranks/platinum.png',
    Rank.diamond => 'assets/pixel/ranks/diamond.png',
  };

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
    // Material button chrome would leak rounded corners + M3 elevation
    // tint into the pixel-art surface. We use a PixelPanel as the visual
    // frame and an InkWell for the tap feedback. The InkWell's splash
    // remains rectangular because PixelPanel clips to the square border.
    return Semantics(
      button: true,
      container: true,
      identifier: identifier,
      label: label,
      child: InkWell(
        onTap: onPressed,
        // Disable the default ripple colour cascade — our palette doesn't
        // have a "splash" token and the ripple reads pink-ish against
        // deepVoid otherwise.
        splashColor: AppColors.arcanePurple,
        highlightColor: AppColors.stoneViolet,
        child: PixelPanel(
          fill: PixelPanelFill.duskPurple,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.pixelLabel.copyWith(
                color: AppColors.hotGold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
