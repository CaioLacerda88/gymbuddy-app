import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/exercises/models/exercise.dart';

import '../../../../fixtures/test_factories.dart';

void main() {
  group('MuscleGroup', () {
    group('displayName', () {
      test('capitalizes first letter', () {
        expect(MuscleGroup.chest.displayName, 'Chest');
        expect(MuscleGroup.back.displayName, 'Back');
        expect(MuscleGroup.legs.displayName, 'Legs');
        expect(MuscleGroup.shoulders.displayName, 'Shoulders');
        expect(MuscleGroup.arms.displayName, 'Arms');
        expect(MuscleGroup.core.displayName, 'Core');
      });
    });

    group('fromString', () {
      test('returns correct enum for valid values', () {
        for (final group in MuscleGroup.values) {
          expect(MuscleGroup.fromString(group.name), group);
        }
      });

      test('throws StateError for invalid value', () {
        expect(
          () => MuscleGroup.fromString('invalid'),
          throwsA(isA<StateError>()),
        );
      });
    });
  });

  group('EquipmentType', () {
    group('displayName', () {
      test('capitalizes first letter', () {
        expect(EquipmentType.barbell.displayName, 'Barbell');
        expect(EquipmentType.dumbbell.displayName, 'Dumbbell');
        expect(EquipmentType.cable.displayName, 'Cable');
        expect(EquipmentType.machine.displayName, 'Machine');
        expect(EquipmentType.bodyweight.displayName, 'Bodyweight');
        expect(EquipmentType.bands.displayName, 'Bands');
        expect(EquipmentType.kettlebell.displayName, 'Kettlebell');
      });
    });

    group('fromString', () {
      test('returns correct enum for valid values', () {
        for (final type in EquipmentType.values) {
          expect(EquipmentType.fromString(type.name), type);
        }
      });

      test('throws StateError for invalid value', () {
        expect(
          () => EquipmentType.fromString('invalid'),
          throwsA(isA<StateError>()),
        );
      });
    });
  });

  group('Exercise', () {
    test('fromJson parses complete data', () {
      final json = TestExerciseFactory.create(
        userId: 'user-001',
        deletedAt: '2026-02-01T00:00:00Z',
      );

      final exercise = Exercise.fromJson(json);

      expect(exercise.id, 'exercise-001');
      expect(exercise.name, 'Bench Press');
      expect(exercise.muscleGroup, MuscleGroup.chest);
      expect(exercise.equipmentType, EquipmentType.barbell);
      expect(exercise.isDefault, true);
      expect(exercise.userId, 'user-001');
      expect(exercise.deletedAt, DateTime.parse('2026-02-01T00:00:00Z'));
      expect(exercise.createdAt, DateTime.parse('2026-01-01T00:00:00Z'));
    });

    test('fromJson handles nullable fields as null', () {
      final json = TestExerciseFactory.create();

      final exercise = Exercise.fromJson(json);

      expect(exercise.userId, isNull);
      expect(exercise.deletedAt, isNull);
    });

    test('toJson round-trip preserves data', () {
      final originalJson = TestExerciseFactory.create(userId: 'user-001');
      final exercise = Exercise.fromJson(originalJson);
      final roundTripped = Exercise.fromJson(exercise.toJson());

      expect(roundTripped, exercise);
    });

    test('equality works via Freezed == operator', () {
      final json = TestExerciseFactory.create();
      final a = Exercise.fromJson(json);
      final b = Exercise.fromJson(json);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('equality detects differences', () {
      final a = Exercise.fromJson(TestExerciseFactory.create(name: 'Squat'));
      final b = Exercise.fromJson(
        TestExerciseFactory.create(name: 'Bench Press'),
      );

      expect(a, isNot(b));
    });

    test('copyWith creates modified copy', () {
      final exercise = Exercise.fromJson(TestExerciseFactory.create());
      final modified = exercise.copyWith(name: 'Deadlift');

      expect(modified.name, 'Deadlift');
      expect(modified.id, exercise.id);
      expect(modified.muscleGroup, exercise.muscleGroup);
    });
  });
}
