import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/radii.dart';
import '../../../../l10n/app_localizations.dart';
import '../../models/character_class.dart';

/// Class slot — always rendered, even when no class has been derived yet.
///
/// Day-1 copy is "The iron will name you." (en) / "O ferro lhe dará um nome."
/// (pt-BR). The placeholder shows while [characterClass] is null — i.e. while
/// the upstream provider is in `AsyncLoading` / `AsyncError`. Once data
/// arrives, the badge transitions to the resolved class label (always
/// non-null on data, since the resolver returns [CharacterClass.initiate]
/// for the day-0 rank distribution). The transition is immediate — no
/// schema or layout change is required when class derivation engages.
///
/// **L10n contract.** The badge takes a [CharacterClass] enum and resolves
/// the localized label here via the per-class accessor on [AppLocalizations]
/// (one accessor per class slug — `classInitiate`, `classBerserker`, …).
/// Keeping the lookup at the badge means the upstream provider stays
/// l10n-free and the widget tests can assert against either the slug or
/// the localized string.
///
/// **Visual hierarchy.** When a class is present, the badge fills with
/// [primaryViolet] tint and renders the label in [hotViolet]. The class
/// label is denser than the title pill (different weight + tint) so the two
/// read as distinct identity beats — class is who you are, title is what
/// you've earned.
class ClassBadge extends StatelessWidget {
  const ClassBadge({super.key, required this.characterClass});

  /// The currently-derived class. `null` on the day-1 placeholder
  /// (provider still loading or errored). Once data lands, the resolver
  /// always returns a non-null variant — there is no "unclassified" state.
  final CharacterClass? characterClass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cls = characterClass;

    final isStub = cls == null;
    final label = isStub
        ? l10n.classSlotPlaceholder
        : _localizedName(cls, l10n);
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

  /// Map an enum variant to its localized display name.
  ///
  /// The exhaustive switch is the structural guarantee that every class
  /// variant has a copy mapping — adding [CharacterClass.wayfarer] in v2
  /// produces a compile error here until the case is added, preventing a
  /// silent "unknown class" string from leaking to UI.
  static String _localizedName(CharacterClass cls, AppLocalizations l10n) {
    return switch (cls) {
      CharacterClass.initiate => l10n.classInitiate,
      CharacterClass.berserker => l10n.classBerserker,
      CharacterClass.bulwark => l10n.classBulwark,
      CharacterClass.sentinel => l10n.classSentinel,
      CharacterClass.pathfinder => l10n.classPathfinder,
      CharacterClass.atlas => l10n.classAtlas,
      CharacterClass.anchor => l10n.classAnchor,
      CharacterClass.ascendant => l10n.classAscendant,
    };
  }
}
