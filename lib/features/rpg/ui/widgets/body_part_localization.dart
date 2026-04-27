import '../../../../l10n/app_localizations.dart';
import '../../models/body_part.dart';

/// Maps a [BodyPart] enum to its localized display string.
///
/// Lives at the feature root (not inside a widget) so the rank-up overlay,
/// title-unlock sheet, character sheet, and titles screen all share a single
/// implementation. Phase 18b had this duplicated as a private function in
/// `body_part_rank_row.dart`; Phase 18c promotes it to feature scope as the
/// celebration overlays grew the second consumer.
String localizedBodyPartName(BodyPart bodyPart, AppLocalizations l10n) {
  switch (bodyPart) {
    case BodyPart.chest:
      return l10n.muscleGroupChest;
    case BodyPart.back:
      return l10n.muscleGroupBack;
    case BodyPart.legs:
      return l10n.muscleGroupLegs;
    case BodyPart.shoulders:
      return l10n.muscleGroupShoulders;
    case BodyPart.arms:
      return l10n.muscleGroupArms;
    case BodyPart.core:
      return l10n.muscleGroupCore;
    case BodyPart.cardio:
      return l10n.muscleGroupCardio;
  }
}
