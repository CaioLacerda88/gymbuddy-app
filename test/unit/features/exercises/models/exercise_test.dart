import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';

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

    test('fromJson handles asymmetric image URLs', () {
      final json = TestExerciseFactory.create(
        imageStartUrl: 'https://example.com/start.jpg',
      );

      final exercise = Exercise.fromJson(json);

      expect(exercise.imageStartUrl, 'https://example.com/start.jpg');
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

    test('fromJson parses description and formTips when present', () {
      final json = TestExerciseFactory.create(
        description: 'A hip-hinge movement targeting the hamstrings.',
        formTips: 'Keep bar close\nHinge at hips\nSqueeze glutes',
      );

      final exercise = Exercise.fromJson(json);

      expect(
        exercise.description,
        'A hip-hinge movement targeting the hamstrings.',
      );
      expect(
        exercise.formTips,
        'Keep bar close\nHinge at hips\nSqueeze glutes',
      );
    });

    test('fromJson sets description and formTips to null when absent', () {
      final json = TestExerciseFactory.create();

      final exercise = Exercise.fromJson(json);

      expect(exercise.description, isNull);
      expect(exercise.formTips, isNull);
    });

    test('toJson round-trip preserves description and formTips', () {
      final json = TestExerciseFactory.create(
        description: 'Targets chest and anterior deltoids.',
        formTips: 'Full range of motion\nControl the descent',
      );
      final exercise = Exercise.fromJson(json);
      final roundTripped = Exercise.fromJson(exercise.toJson());

      expect(roundTripped.description, exercise.description);
      expect(roundTripped.formTips, exercise.formTips);
      expect(roundTripped, exercise);
    });

    test('toJson round-trip preserves null description and formTips', () {
      final json = TestExerciseFactory.create();
      final exercise = Exercise.fromJson(json);
      final roundTripped = Exercise.fromJson(exercise.toJson());

      expect(roundTripped.description, isNull);
      expect(roundTripped.formTips, isNull);
    });

    test('fromJson parses exercise with description but no formTips', () {
      final json = TestExerciseFactory.create(
        description: 'A compound push movement.',
      );

      final exercise = Exercise.fromJson(json);

      expect(exercise.description, 'A compound push movement.');
      expect(exercise.formTips, isNull);
    });

    test('fromJson parses exercise with formTips but no description', () {
      final json = TestExerciseFactory.create(
        formTips: 'Keep elbows at 45 degrees\nDrive through heels',
      );

      final exercise = Exercise.fromJson(json);

      expect(exercise.description, isNull);
      expect(
        exercise.formTips,
        'Keep elbows at 45 degrees\nDrive through heels',
      );
    });
  });
}
