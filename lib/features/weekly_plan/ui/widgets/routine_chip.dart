import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/radii.dart';
import '../../../../l10n/app_localizations.dart';

/// Visual states for a routine chip in the weekly bucket.
enum RoutineChipState {
  /// Completed — green tint, checkmark, collapsed width.
  done,

  /// Up next — solid green, primary CTA, taller.
  next,

  /// Remaining — ghosted, not yet reached in sequence.
  remaining,
}

/// A pill-shaped chip representing a routine in the weekly bucket.
///
/// Three states per spec:
/// - [RoutineChipState.done]: 44dp, green checkmark, no name text
/// - [RoutineChipState.next]: 60dp, solid green, black text, secondary exercise count line
/// - [RoutineChipState.remaining]: 48dp, ghosted, sequence number + name at reduced opacity
class RoutineChip extends StatelessWidget {
  const RoutineChip({
    required this.sequenceNumber,
    required this.routineName,
    required this.chipState,
    this.exerciseCount,
    this.onTap,
    super.key,
  });

  final int sequenceNumber;
  final String routineName;
  final RoutineChipState chipState;

  /// Number of exercises in the routine. Shown on the `next` chip as a
  /// secondary line (e.g. "6 exercises").
  final int? exerciseCount;

  final VoidCallback? onTap;

  static const _doneColor = AppColors.emeraldGreen;
  static const _cardColor = AppColors.stoneViolet;

  @override
  Widget build(BuildContext context) {
    return switch (chipState) {
      RoutineChipState.done => _buildDone(context),
      RoutineChipState.next => _buildNext(context),
      RoutineChipState.remaining => _buildRemaining(context),
    };
  }

  Widget _buildDone(BuildContext context) {
    return Container(
      height: 44,
      constraints: const BoxConstraints(minWidth: 44),
      decoration: BoxDecoration(
        color: _doneColor.withValues(alpha: 0.13),
        border: Border.all(color: _doneColor, width: 1),
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: const Center(
        child: Icon(Icons.check, color: _doneColor, size: 20),
      ),
    );
  }

  Widget _buildNext(BuildContext context) {
    final theme = Theme.of(context);
    final hasExerciseCount = exerciseCount != null && exerciseCount! > 0;

    return Material(
      color: _doneColor,
      borderRadius: BorderRadius.circular(kRadiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusLg),
        onTap: onTap,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  // Sequence-number badge on the emerald-green CTA: a dark
                  // overlay on top of the green Material. Palette has no
                  // near-black token, so we use deepVoid (#0D0319) with a
                  // ~26% alpha to tint the green without a full blackout.
                  color: AppColors.deepVoid.withValues(alpha: 0.26),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$sequenceNumber',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.deepVoid,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routineName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.deepVoid,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (hasExerciseCount)
                      Text(
                        AppLocalizations.of(
                          context,
                        ).exercisesCount(exerciseCount!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.deepVoid.withValues(alpha: 0.54),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemaining(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: _cardColor,
      borderRadius: BorderRadius.circular(kRadiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusLg),
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.pureWhite.withValues(alpha: 0.13),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(kRadiusLg),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.pureWhite.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$sequenceNumber',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.pureWhite.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  routineName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.pureWhite.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
