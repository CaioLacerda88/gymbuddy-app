import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/radii.dart';
import '../../../../l10n/app_localizations.dart';

/// Class slot — always rendered, even when class is null.
///
/// Day-1 copy is "The iron will name you." (en) / "O ferro lhe dará um nome."
/// (pt-BR), per the kickoff lock. The kickoff explicitly rejected an
/// "Initiate" default because it reads as a finished state, when the real
/// intent is "your class is yet to emerge." The placeholder communicates
/// pre-class-emergence; the badge transitions to a real label the moment
/// 18e ships, with no schema change required.
///
/// When a class is present, the badge fills with [primaryViolet] tint and
/// renders the label in [hotViolet]. Hierarchy: class label is denser than
/// the title pill (different weight + tint) so the two read as distinct
/// identity beats.
class ClassBadge extends StatelessWidget {
  const ClassBadge({super.key, required this.className});

  final String? className;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final name = className;

    final isStub = name == null || name.isEmpty;
    final label = isStub ? l10n.classSlotPlaceholder : name;
    final textColor = isStub ? AppColors.textDim : AppColors.hotViolet;
    final borderColor = isStub
        ? AppColors.hair
        : AppColors.hotViolet.withValues(alpha: 0.6);
    final fillColor = isStub
        ? AppColors.surface
        : AppColors.primaryViolet.withValues(alpha: 0.18);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: fillColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(kRadiusSm + 2),
      ),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: textColor,
          fontStyle: isStub ? FontStyle.italic : FontStyle.normal,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
