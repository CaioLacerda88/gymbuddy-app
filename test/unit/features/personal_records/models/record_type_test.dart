import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/personal_records/models/record_type.dart';

void main() {
  group('RecordType', () {
    test('fromString parses all valid values', () {
      expect(RecordType.fromString('max_weight'), RecordType.maxWeight);
      expect(RecordType.fromString('max_reps'), RecordType.maxReps);
      expect(RecordType.fromString('max_volume'), RecordType.maxVolume);
    });

    test('fromString throws on unknown value', () {
      expect(
        () => RecordType.fromString('unknown'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('toSnakeCase returns correct values', () {
      expect(RecordType.maxWeight.toSnakeCase, 'max_weight');
      expect(RecordType.maxReps.toSnakeCase, 'max_reps');
      expect(RecordType.maxVolume.toSnakeCase, 'max_volume');
    });

    test('displayName returns correct values', () {
      expect(RecordType.maxWeight.displayName, 'Max Weight');
      expect(RecordType.maxReps.displayName, 'Max Reps');
      expect(RecordType.maxVolume.displayName, 'Max Volume');
    });
  });
}
