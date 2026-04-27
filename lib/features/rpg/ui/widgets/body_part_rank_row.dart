import 'package:flutter/material.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_muscle_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../models/body_part.dart';
import '../../models/character_sheet_state.dart';
import '../../models/vitality_state.dart';
import 'body_part_localization.dart';
import 'rank_stamp.dart';
import 'xp_progress_hairline.dart';

/// One body-part codex row on the character sheet — composes the rune sigil,
/// localized name, [RankStamp], and [XpProgressHairline].
///
/// **Asymmetric awakening (kickoff lock):** rows that are fully untrained
/// (rank 1, 0 XP, peak 0) collapse to a compressed-height variant — sigil
/// ghosted, no rank stamp, no hairline, just the muscle-group label and a
/// dormant-rune sigil. Rows with any progress (rank > 1 OR vitality_peak > 0
/// OR totalXp > 0) render the full expanded variant. This keeps day-1 from
/// reading as "five empty stats waiting to be filled" — instead it reads as
/// "one path opening, five paths still asleep".
class BodyPartRankRow extends StatelessWidget {
  const BodyPartRankRow({super.key, required this.entry});

  final BodyPartSheetEntry entry;

  static const double _expandedHeight = 60;
  static const double _compressedHeight = 32;

  @override
  Widget build(BuildContext context) {
    if (entry.isUntrained) {
      return _CompressedRow(entry: entry);
    }
    return _ExpandedRow(entry: entry);
  }

  static double heightFor(BodyPartSheetEntry entry) =>
      entry.isUntrained ? _compressedHeight : _expandedHeight;
}

class _ExpandedRow extends StatelessWidget {
  const _ExpandedRow({required this.entry});

  final BodyPartSheetEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: BodyPartRankRow._expandedHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _Sigil(
              bodyPart: entry.bodyPart,
              tint: entry.vitalityState.borderColor,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _localizedName(entry.bodyPart, l10n),
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  XpProgressHairline(
                    xpInRank: entry.xpInRank,
                    xpForNextRank: entry.xpForNextRank,
                    vitalityState: entry.vitalityState,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            RankStamp(rank: entry.rank, vitalityState: entry.vitalityState),
          ],
        ),
      ),
    );
  }
}

class _CompressedRow extends StatelessWidget {
  const _CompressedRow({required this.entry});

  final BodyPartSheetEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: BodyPartRankRow._compressedHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Opacity(
              opacity: 0.4,
              child: _Sigil(
                bodyPart: entry.bodyPart,
                tint: AppColors.textDim,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _localizedName(entry.bodyPart, l10n),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textDim,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sigil extends StatelessWidget {
  const _Sigil({
    required this.bodyPart,
    required this.tint,
    required this.size,
  });

  final BodyPart bodyPart;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = _muscleAsset(bodyPart);
    return AppIcons.render(asset, color: tint, size: size);
  }
}

/// Map a body part to the canonical [AppMuscleIcons] asset path.
String _muscleAsset(BodyPart bodyPart) {
  switch (bodyPart) {
    case BodyPart.chest:
      return AppMuscleIcons.chest;
    case BodyPart.back:
      return AppMuscleIcons.back;
    case BodyPart.legs:
      return AppMuscleIcons.legs;
    case BodyPart.shoulders:
      return AppMuscleIcons.shoulders;
    case BodyPart.arms:
      return AppMuscleIcons.arms;
    case BodyPart.core:
      return AppMuscleIcons.core;
    case BodyPart.cardio:
      return AppMuscleIcons.cardio;
  }
}

// Body-part display name lookup is shared with the celebration overlays via
// `body_part_localization.dart`.
String _localizedName(BodyPart bodyPart, AppLocalizations l10n) =>
    localizedBodyPartName(bodyPart, l10n);
