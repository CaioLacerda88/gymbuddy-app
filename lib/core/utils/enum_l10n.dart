import '../../features/exercises/models/exercise.dart';
import '../../features/personal_records/models/record_type.dart';
import '../../features/workouts/models/set_type.dart';
import '../../features/workouts/models/weight_unit.dart';
import '../../l10n/app_localizations.dart';

/// Localized display names for [MuscleGroup] values.
extension MuscleGroupL10n on MuscleGroup {
  String localizedName(AppLocalizations l10n) => switch (this) {
    MuscleGroup.chest => l10n.muscleGroupChest,
    MuscleGroup.back => l10n.muscleGroupBack,
    MuscleGroup.legs => l10n.muscleGroupLegs,
    MuscleGroup.shoulders => l10n.muscleGroupShoulders,
    MuscleGroup.arms => l10n.muscleGroupArms,
    MuscleGroup.core => l10n.muscleGroupCore,
    MuscleGroup.cardio => l10n.muscleGroupCardio,
  };
}

/// Localized display names for [EquipmentType] values.
extension EquipmentTypeL10n on EquipmentType {
  String localizedName(AppLocalizations l10n) => switch (this) {
    EquipmentType.barbell => l10n.equipmentBarbell,
    EquipmentType.dumbbell => l10n.equipmentDumbbell,
    EquipmentType.cable => l10n.equipmentCable,
    EquipmentType.machine => l10n.equipmentMachine,
    EquipmentType.bodyweight => l10n.equipmentBodyweight,
    EquipmentType.bands => l10n.equipmentBands,
    EquipmentType.kettlebell => l10n.equipmentKettlebell,
  };
}

/// Localized display names for [SetType] values.
extension SetTypeL10n on SetType {
  String localizedName(AppLocalizations l10n) => switch (this) {
    SetType.working => l10n.setTypeWorking,
    SetType.warmup => l10n.setTypeWarmup,
    SetType.dropset => l10n.setTypeDropset,
    SetType.failure => l10n.setTypeFailure,
  };
}

/// Localized display names for [RecordType] values.
extension RecordTypeL10n on RecordType {
  String localizedName(AppLocalizations l10n) => switch (this) {
    RecordType.maxWeight => l10n.recordTypeMaxWeight,
    RecordType.maxReps => l10n.recordTypeMaxReps,
    RecordType.maxVolume => l10n.recordTypeMaxVolume,
  };
}

/// Localized display names for [WeightUnit] values.
extension WeightUnitL10n on WeightUnit {
  String localizedName(AppLocalizations l10n) => switch (this) {
    WeightUnit.kg => l10n.weightUnitKg,
    WeightUnit.lbs => l10n.weightUnitLbs,
  };
}
