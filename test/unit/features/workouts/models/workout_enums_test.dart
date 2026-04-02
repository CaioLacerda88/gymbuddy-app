import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/workouts/models/set_type.dart';
import 'package:gymbuddy_app/features/workouts/models/weight_unit.dart';

void main() {
  group('SetType', () {
    test('all values have non-empty displayName', () {
      for (final type in SetType.values) {
        expect(type.displayName, isNotEmpty);
      }
      // Spot-check a non-trivial mapping
      expect(SetType.warmup.displayName, 'Warm-up');
      expect(SetType.dropset.displayName, 'Drop Set');
    });

    test('fromString round-trips all values', () {
      for (final type in SetType.values) {
        expect(SetType.fromString(type.name), type);
      }
    });

    test('fromString throws StateError for invalid input', () {
      expect(() => SetType.fromString('invalid'), throwsA(isA<StateError>()));
      expect(() => SetType.fromString(''), throwsA(isA<StateError>()));
      expect(() => SetType.fromString('Working'), throwsA(isA<StateError>()));
    });
  });

  group('WeightUnit', () {
    test('displayName returns uppercase', () {
      expect(WeightUnit.kg.displayName, 'KG');
      expect(WeightUnit.lbs.displayName, 'LBS');
    });

    test('defaultIncrement returns correct values', () {
      expect(WeightUnit.kg.defaultIncrement, 2.5);
      expect(WeightUnit.lbs.defaultIncrement, 5.0);
    });

    test('fromString round-trips all values', () {
      for (final unit in WeightUnit.values) {
        expect(WeightUnit.fromString(unit.name), unit);
      }
    });

    test('fromString throws StateError for invalid input', () {
      expect(
        () => WeightUnit.fromString('invalid'),
        throwsA(isA<StateError>()),
      );
      expect(() => WeightUnit.fromString('KG'), throwsA(isA<StateError>()));
    });
  });
}
