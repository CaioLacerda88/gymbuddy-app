import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/exercises/models/exercise.dart';

import '../../../../fixtures/test_factories.dart';

void main() {
  group('MuscleGroup', () {
    test('displayName capitalizes first letter for all values', () {
      for (final group in MuscleGroup.values) {
        expect(group.displayName[0], group.displayName[0].toUpperCase());
        expect(group.displayName.length, greaterThan(1));
      }
    });

    test('fromString round-trips all values', () {
      for (final group in MuscleGroup.values) {
        expect(MuscleGroup.fromString(group.name), group);
      }
    });

    test('fromString throws StateError for invalid value', () {
      expect(
        () => MuscleGroup.fromString('invalid'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('EquipmentType', () {
    test('displayName capitalizes first letter for all values', () {
      for (final type in EquipmentType.values) {
        expect(type.displayName[0], type.displayName[0].toUpperCase());
        expect(type.displayName.length, greaterThan(1));
      }
    });

    test('fromString round-trips all values', () {
      for (final type in EquipmentType.values) {
        expect(EquipmentType.fromString(type.name), type);
      }
    });

    test('fromString throws StateError for invalid value', () {
      expect(
        () => EquipmentType.fromString('invalid'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Exercise', () {
    test('fromJson parses complete data including image URLs', () {
      final json = TestExerciseFactory.create(
        userId: 'user-001',
        deletedAt: '2026-02-01T00:00:00Z',
        imageStartUrl: 'https://example.com/start.jpg',
        imageEndUrl: 'https://example.com/end.jpg',
      );

      final exercise = Exercise.fromJson(json);

      expect(exercise.id, 'exercise-001');
      expect(exercise.name, 'Bench Press');
      expect(exercise.muscleGroup, MuscleGroup.chest);
      expect(exercise.equipmentType, EquipmentType.barbell);
      expect(exercise.isDefault, true);
      expect(exercise.userId, 'user-001');
      expect(exercise.deletedAt, DateTime.parse('2026-02-01T00:00:00Z'));
      expect(exercise.imageStartUrl, 'https://example.com/start.jpg');
      expect(exercise.imageEndUrl, 'https://example.com/end.jpg');
    });

    test('fromJson handles null optional fields', () {
      final json = TestExerciseFactory.create();

      final exercise = Exercise.fromJson(json);

      expect(exercise.userId, isNull);
      expect(exercise.deletedAt, isNull);
      expect(exercise.imageStartUrl, isNull);
      expect(exercise.imageEndUrl, isNull);
    });

    test('toJson round-trip preserves data', () {
      final originalJson = TestExerciseFactory.create(
        userId: 'user-001',
        imageStartUrl: 'https://example.com/start.jpg',
        imageEndUrl: 'https://example.com/end.jpg',
      );
      final exercise = Exercise.fromJson(originalJson);
      final roundTripped = Exercise.fromJson(exercise.toJson());

      expect(roundTripped, exercise);
    });
  });
}
