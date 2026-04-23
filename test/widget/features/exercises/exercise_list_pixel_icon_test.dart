import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';

/// Verifies the `MuscleGroup` and `EquipmentType` enums resolve to valid
/// pixel asset paths for every value. Catches the "added a new enum value
/// but forgot to generate the PNG" class of regressions at test time
/// instead of at runtime in front of a user.
void main() {
  group('MuscleGroup.iconPath', () {
    test('returns assets/pixel/muscle/<name>.png for every enum value', () {
      for (final group in MuscleGroup.values) {
        expect(
          group.iconPath,
          'assets/pixel/muscle/${group.name}.png',
          reason: 'MuscleGroup.${group.name} is missing or mis-mapped.',
        );
      }
    });

    test('covers the 7 canonical muscle groups', () {
      // If this tips, the pixel asset set and the model drifted apart.
      // Either add the PNG or remove the enum value — do not silently regen
      // the test.
      expect(MuscleGroup.values.length, 7);
      expect(MuscleGroup.values.map((e) => e.name), {
        'chest',
        'back',
        'legs',
        'shoulders',
        'arms',
        'core',
        'cardio',
      });
    });
  });

  group('EquipmentType.iconPath', () {
    test('returns assets/pixel/equipment/<name>.png for every enum value', () {
      for (final type in EquipmentType.values) {
        expect(
          type.iconPath,
          'assets/pixel/equipment/${type.name}.png',
          reason: 'EquipmentType.${type.name} is missing or mis-mapped.',
        );
      }
    });

    test('covers the 7 canonical equipment types', () {
      expect(EquipmentType.values.length, 7);
      expect(EquipmentType.values.map((e) => e.name), {
        'barbell',
        'dumbbell',
        'cable',
        'machine',
        'bodyweight',
        'bands',
        'kettlebell',
      });
    });
  });
}
