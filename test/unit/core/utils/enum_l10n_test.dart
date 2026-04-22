import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/utils/enum_l10n.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';
import 'package:repsaga/features/personal_records/models/record_type.dart';
import 'package:repsaga/features/workouts/models/set_type.dart';
import 'package:repsaga/features/workouts/models/weight_unit.dart';
import 'package:repsaga/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('MuscleGroupL10n', () {
    test('all values return non-empty strings', () {
      for (final value in MuscleGroup.values) {
        expect(value.localizedName(l10n), isNotEmpty);
      }
    });

    test('chest returns "Chest"', () {
      expect(MuscleGroup.chest.localizedName(l10n), 'Chest');
    });

    test('cardio returns "Cardio"', () {
      expect(MuscleGroup.cardio.localizedName(l10n), 'Cardio');
    });
  });

  group('EquipmentTypeL10n', () {
    test('all values return non-empty strings', () {
      for (final value in EquipmentType.values) {
        expect(value.localizedName(l10n), isNotEmpty);
      }
    });

    test('barbell returns "Barbell"', () {
      expect(EquipmentType.barbell.localizedName(l10n), 'Barbell');
    });

    test('bodyweight returns "Bodyweight"', () {
      expect(EquipmentType.bodyweight.localizedName(l10n), 'Bodyweight');
    });
  });

  group('SetTypeL10n', () {
    test('all values return non-empty strings', () {
      for (final value in SetType.values) {
        expect(value.localizedName(l10n), isNotEmpty);
      }
    });

    test('working returns "Working"', () {
      expect(SetType.working.localizedName(l10n), 'Working');
    });

    test('warmup returns "Warm-up"', () {
      expect(SetType.warmup.localizedName(l10n), 'Warm-up');
    });
  });

  group('RecordTypeL10n', () {
    test('all values return non-empty strings', () {
      for (final value in RecordType.values) {
        expect(value.localizedName(l10n), isNotEmpty);
      }
    });

    test('maxWeight returns "Max Weight"', () {
      expect(RecordType.maxWeight.localizedName(l10n), 'Max Weight');
    });

    test('maxVolume returns "Max Volume"', () {
      expect(RecordType.maxVolume.localizedName(l10n), 'Max Volume');
    });
  });

  group('WeightUnitL10n', () {
    test('all values return non-empty strings', () {
      for (final value in WeightUnit.values) {
        expect(value.localizedName(l10n), isNotEmpty);
      }
    });

    test('kg returns "KG"', () {
      expect(WeightUnit.kg.localizedName(l10n), 'KG');
    });

    test('lbs returns "LBS"', () {
      expect(WeightUnit.lbs.localizedName(l10n), 'LBS');
    });
  });
}
