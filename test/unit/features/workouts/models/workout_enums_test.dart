import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/workouts/models/set_type.dart';
import 'package:gymbuddy_app/features/workouts/models/weight_unit.dart';

void main() {
  group('SetType', () {
    group('displayName', () {
      test('working has correct displayName', () {
        expect(SetType.working.displayName, 'Working');
      });

      test('warmup has correct displayName', () {
        expect(SetType.warmup.displayName, 'Warm-up');
      });

      test('dropset has correct displayName', () {
        expect(SetType.dropset.displayName, 'Drop Set');
      });

      test('failure has correct displayName', () {
        expect(SetType.failure.displayName, 'To Failure');
      });

      test('all values have non-empty displayName', () {
        for (final type in SetType.values) {
          expect(type.displayName, isNotEmpty);
        }
      });
    });

    group('fromString', () {
      test('parses working', () {
        expect(SetType.fromString('working'), SetType.working);
      });

      test('parses warmup', () {
        expect(SetType.fromString('warmup'), SetType.warmup);
      });

      test('parses dropset', () {
        expect(SetType.fromString('dropset'), SetType.dropset);
      });

      test('parses failure', () {
        expect(SetType.fromString('failure'), SetType.failure);
      });

      test('round-trips all values via name', () {
        for (final type in SetType.values) {
          expect(SetType.fromString(type.name), type);
        }
      });

      test('throws StateError for invalid value', () {
        expect(() => SetType.fromString('invalid'), throwsA(isA<StateError>()));
      });

      test('throws StateError for empty string', () {
        expect(() => SetType.fromString(''), throwsA(isA<StateError>()));
      });

      test('throws StateError for uppercase variant', () {
        expect(() => SetType.fromString('Working'), throwsA(isA<StateError>()));
      });
    });
  });

  group('WeightUnit', () {
    group('displayName', () {
      test('kg displays as KG', () {
        expect(WeightUnit.kg.displayName, 'KG');
      });

      test('lbs displays as LBS', () {
        expect(WeightUnit.lbs.displayName, 'LBS');
      });

      test('all values have non-empty displayName', () {
        for (final unit in WeightUnit.values) {
          expect(unit.displayName, isNotEmpty);
        }
      });
    });

    group('defaultIncrement', () {
      test('kg increment is 2.5', () {
        expect(WeightUnit.kg.defaultIncrement, 2.5);
      });

      test('lbs increment is 5.0', () {
        expect(WeightUnit.lbs.defaultIncrement, 5.0);
      });

      test('increments are positive for all values', () {
        for (final unit in WeightUnit.values) {
          expect(unit.defaultIncrement, greaterThan(0));
        }
      });
    });

    group('fromString', () {
      test('parses kg', () {
        expect(WeightUnit.fromString('kg'), WeightUnit.kg);
      });

      test('parses lbs', () {
        expect(WeightUnit.fromString('lbs'), WeightUnit.lbs);
      });

      test('round-trips all values via name', () {
        for (final unit in WeightUnit.values) {
          expect(WeightUnit.fromString(unit.name), unit);
        }
      });

      test('throws StateError for invalid value', () {
        expect(
          () => WeightUnit.fromString('invalid'),
          throwsA(isA<StateError>()),
        );
      });

      test('throws StateError for uppercase KG', () {
        expect(() => WeightUnit.fromString('KG'), throwsA(isA<StateError>()));
      });
    });
  });
}
