import '../../exercises/models/exercise.dart';
import '../models/weight_unit.dart';

/// Returns sensible default weight and reps for a new set based on the
/// exercise's equipment type and the user's preferred weight unit.
///
/// These values are pre-populated suggestions — the user can always edit
/// before completing the set.
({double weight, int reps}) defaultSetValues(
  EquipmentType equipmentType,
  WeightUnit weightUnit,
) {
  return switch (equipmentType) {
    EquipmentType.barbell => (
      weight: weightUnit == WeightUnit.kg ? 20.0 : 45.0,
      reps: 5,
    ),
    EquipmentType.dumbbell => (
      weight: weightUnit == WeightUnit.kg ? 10.0 : 20.0,
      reps: 10,
    ),
    EquipmentType.cable || EquipmentType.machine => (
      weight: weightUnit == WeightUnit.kg ? 20.0 : 45.0,
      reps: 10,
    ),
    EquipmentType.bodyweight => (weight: 0.0, reps: 10),
    EquipmentType.bands => (weight: 0.0, reps: 12),
    EquipmentType.kettlebell => (
      weight: weightUnit == WeightUnit.kg ? 16.0 : 35.0,
      reps: 10,
    ),
  };
}
