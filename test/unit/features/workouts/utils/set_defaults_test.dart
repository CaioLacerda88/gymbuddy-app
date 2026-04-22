import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';
import 'package:repsaga/features/workouts/models/weight_unit.dart';
import 'package:repsaga/features/workouts/utils/set_defaults.dart';

void main() {
  group('defaultSetValues — kg', () {
    test('barbell returns 20kg and 5 reps', () {
      final result = defaultSetValues(EquipmentType.barbell, WeightUnit.kg);
      expect(result.weight, 20.0);
      expect(result.reps, 5);
    });

    test('dumbbell returns 10kg and 10 reps', () {
      final result = defaultSetValues(EquipmentType.dumbbell, WeightUnit.kg);
      expect(result.weight, 10.0);
      expect(result.reps, 10);
    });

    test('cable returns 20kg and 10 reps', () {
      final result = defaultSetValues(EquipmentType.cable, WeightUnit.kg);
      expect(result.weight, 20.0);
      expect(result.reps, 10);
    });

    test('machine returns 20kg and 10 reps', () {
      final result = defaultSetValues(EquipmentType.machine, WeightUnit.kg);
      expect(result.weight, 20.0);
      expect(result.reps, 10);
    });

    test('bodyweight returns 0 weight and 10 reps', () {
      final result = defaultSetValues(EquipmentType.bodyweight, WeightUnit.kg);
      expect(result.weight, 0.0);
      expect(result.reps, 10);
    });

    test('bands returns 0 weight and 12 reps', () {
      final result = defaultSetValues(EquipmentType.bands, WeightUnit.kg);
      expect(result.weight, 0.0);
      expect(result.reps, 12);
    });

    test('kettlebell returns 16kg and 10 reps', () {
      final result = defaultSetValues(EquipmentType.kettlebell, WeightUnit.kg);
      expect(result.weight, 16.0);
      expect(result.reps, 10);
    });
  });

  group('defaultSetValues — lbs', () {
    test('barbell returns 45lbs and 5 reps', () {
      final result = defaultSetValues(EquipmentType.barbell, WeightUnit.lbs);
      expect(result.weight, 45.0);
      expect(result.reps, 5);
    });

    test('dumbbell returns 20lbs and 10 reps', () {
      final result = defaultSetValues(EquipmentType.dumbbell, WeightUnit.lbs);
      expect(result.weight, 20.0);
      expect(result.reps, 10);
    });

    test('cable returns 45lbs and 10 reps', () {
      final result = defaultSetValues(EquipmentType.cable, WeightUnit.lbs);
      expect(result.weight, 45.0);
      expect(result.reps, 10);
    });

    test('machine returns 45lbs and 10 reps', () {
      final result = defaultSetValues(EquipmentType.machine, WeightUnit.lbs);
      expect(result.weight, 45.0);
      expect(result.reps, 10);
    });

    test('bodyweight returns 0 weight and 10 reps regardless of unit', () {
      final result = defaultSetValues(EquipmentType.bodyweight, WeightUnit.lbs);
      expect(result.weight, 0.0);
      expect(result.reps, 10);
    });

    test('bands returns 0 weight and 12 reps regardless of unit', () {
      final result = defaultSetValues(EquipmentType.bands, WeightUnit.lbs);
      expect(result.weight, 0.0);
      expect(result.reps, 12);
    });

    test('kettlebell returns 35lbs and 10 reps', () {
      final result = defaultSetValues(EquipmentType.kettlebell, WeightUnit.lbs);
      expect(result.weight, 35.0);
      expect(result.reps, 10);
    });
  });

  group('defaultSetValues — zero-weight types', () {
    test('bodyweight weight is identical for both units', () {
      final kg = defaultSetValues(EquipmentType.bodyweight, WeightUnit.kg);
      final lbs = defaultSetValues(EquipmentType.bodyweight, WeightUnit.lbs);
      expect(kg.weight, lbs.weight);
      expect(kg.reps, lbs.reps);
    });

    test('bands weight is identical for both units', () {
      final kg = defaultSetValues(EquipmentType.bands, WeightUnit.kg);
      final lbs = defaultSetValues(EquipmentType.bands, WeightUnit.lbs);
      expect(kg.weight, lbs.weight);
      expect(kg.reps, lbs.reps);
    });
  });
}
