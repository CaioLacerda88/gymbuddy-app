import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/personal_records/models/personal_record.dart';
import 'package:gymbuddy_app/features/personal_records/models/record_type.dart';

import '../../../../fixtures/test_factories.dart';

void main() {
  group('PersonalRecord', () {
    test('fromJson creates model from snake_case fields', () {
      final json = TestPersonalRecordFactory.create(
        id: 'pr-test',
        userId: 'user-test',
        exerciseId: 'exercise-test',
        recordType: 'max_reps',
        value: 15.0,
        achievedAt: '2026-03-15T10:00:00Z',
        setId: 'set-test',
      );

      final record = PersonalRecord.fromJson(json);

      expect(record.id, 'pr-test');
      expect(record.userId, 'user-test');
      expect(record.exerciseId, 'exercise-test');
      expect(record.recordType, RecordType.maxReps);
      expect(record.value, 15.0);
      expect(record.achievedAt, DateTime.utc(2026, 3, 15, 10));
      expect(record.setId, 'set-test');
    });

    test('fromJson / toJson roundtrip', () {
      final json = TestPersonalRecordFactory.create(
        id: 'pr-round',
        recordType: 'max_volume',
        value: 640.0,
      );

      final record = PersonalRecord.fromJson(json);
      final output = record.toJson();

      // Re-parse and compare
      final roundTripped = PersonalRecord.fromJson(output);
      expect(roundTripped.id, record.id);
      expect(roundTripped.userId, record.userId);
      expect(roundTripped.exerciseId, record.exerciseId);
      expect(roundTripped.recordType, record.recordType);
      expect(roundTripped.value, record.value);
      expect(roundTripped.setId, record.setId);
    });

    test('fromJson with default factory values', () {
      final json = TestPersonalRecordFactory.create();

      final record = PersonalRecord.fromJson(json);

      expect(record.id, 'pr-001');
      expect(record.userId, 'user-001');
      expect(record.exerciseId, 'exercise-001');
      expect(record.recordType, RecordType.maxWeight);
      expect(record.value, 100.0);
    });

    test('fromJson handles null setId', () {
      final json = TestPersonalRecordFactory.create(setId: null);

      final record = PersonalRecord.fromJson(json);

      expect(record.setId, isNull);
    });
  });
}
