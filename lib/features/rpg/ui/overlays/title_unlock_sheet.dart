import 'package:flutter/material.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/reward_accent.dart';
import '../../models/title.dart' as rpg;
import '../widgets/body_part_localization.dart';
import '../widgets/title_localization.dart';

/// Post-workout title-unlock half-sheet (Phase 18c, spec §13.2).
///
/// **Layout (locked):**
///   * Background: `surface2` flat — NO gradient. The watermark ([AppIcons.hero]
///     SVG at 180dp, `textDim @ 0.04`) sits bottom-right under an
///     [IgnorePointer] so it cannot intercept the equip-button hit region.
///   * Drag handle: 32×3dp pill in [AppColors.hair] at the top, replacing
///     Material's default white handle.
///   * Reading order: rank label → title name → flavor → equip CTA.
///   * Rank label: Inter 600 13sp uppercase 0.12em tracking, [AppColors.hotViolet].
///   * Title name: Rajdhani 700 32sp centered. If [isFirstEver] the name is
///     wrapped in a [RewardAccent] so the name renders in [AppColors.heroGold]
///     — every subsequent unlock keeps the name in [AppColors.textCream] to
///     preserve the gold-scarcity contract.
///   * Flavor: Inter 400 14sp [AppColors.textDim], 1.5 line-height, max 2
///     lines, ellipsis. Sheet height is fixed (0.45) so flavor truncation is
///     intentional — long-flavor titles don't expand the sheet.
///   * Equip: filled [ElevatedButton], full width, 56dp height, [AppColors.primaryViolet]
///     background, "EQUIP TITLE" Rajdhani 600 13sp uppercase via [l10n.equipTitleButton].
///
/// **Why a stand-alone widget (not coupled to `showModalBottomSheet`):**
/// The widget renders the contents that go inside a [DraggableScrollableSheet]
/// fixed at 0.45 height. Keeping it body-only makes it independently testable
/// (no NavigatorState boilerplate in widget tests) and lets the orchestrator
/// (`ActiveWorkoutNotifier`) wrap it in either a draggable sheet or a stack
/// overlay depending on the platform's gesture conventions.
///
/// **Equip contract:** [onEquip] is `Future<void>` so the parent can `await`
/// the Supabase RPC (`equip_title`) and pop the sheet on success. Errors are
/// surfaced by the parent — this widget is presentation-only.
class TitleUnlockSheet extends StatelessWidget {
  const TitleUnlockSheet({
    super.key,
    required this.title,
    required this.isFirstEver,
    required this.onEquip,
  });

  /// The title catalog entry (slug + body part + rank threshold). Display
  /// copy resolves through [localizedTitleCopy].
  final rpg.Title title;

  /// True only on the user's first-ever earned title — the only condition
  /// under which the title name renders in [AppColors.heroGold]. Subsequent
  /// titles render in [AppColors.textCream].
  final bool isFirstEver;

  /// Invoked when the user taps the EQUIP CTA. Parent persists `is_active`
  /// via the `equip_title` RPC and pops the sheet on success.
  final Future<void> Function() onEquip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final copy = localizedTitleCopy(title.slug, l10n);
    final bodyPartName = localizedBodyPartName(
      title.bodyPart,
      l10n,
    ).toUpperCase();

    final nameText = Text(
      copy?.name ?? title.slug,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.display.copyWith(
        fontSize: 32,
        // textCream is the default; RewardAccent overrides via DefaultTextStyle.
        color: AppColors.textCream,
      ),
    );

    return Semantics(
      identifier: 'title-unlock-sheet',
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Stack(
          children: [
            // Rune watermark — bottom-right, decorative, IgnorePointer guards
            // the equip-button hit region from a misalignment-induced miss.
            Positioned(
              right: -24,
              bottom: -24,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.04,
                  child: AppIcons.render(
                    AppIcons.hero,
                    color: AppColors.textDim,
                    size: 180,
                  ),
                ),
              ),
            ),
            // Foreground content.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle pill.
                  Center(
                    child: Container(
                      width: 32,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppColors.hair,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Rank label — "{BODY PART} · RANK {N} TITLE" via the
                  // localized arb template, hotViolet, uppercase, tracking.
                  Text(
                    l10n.titleUnlockRankLabel(
                      bodyPartName,
                      title.rankThreshold,
                    ),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.label.copyWith(
                      fontSize: 13,
                      color: AppColors.hotViolet,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Title name. First-ever titles render in heroGold via
                  // RewardAccent; subsequent titles stay in textCream so the
                  // gold scarcity budget isn't depleted.
                  if (isFirstEver) RewardAccent(child: nameText) else nameText,
                  if (copy != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      copy.flavor,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        color: AppColors.textDim,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Equip CTA. 56dp height, filled primaryViolet, label
                  // "EQUIP TITLE" Rajdhani 600 13sp uppercase.
                  // The E2E selector targets this via role=button[name="EQUIP TITLE"]
                  // rather than flt-semantics-identifier to ensure the actual
                  // button action node is clicked (not a wrapper container).
                  Semantics(
                    identifier: 'equip-title-button',
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: onEquip,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryViolet,
                          foregroundColor: AppColors.textCream,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          l10n.equipTitleButton,
                          style: AppTextStyles.headline.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.12 * 13,
                            color: AppColors.textCream,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
