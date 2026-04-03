import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/profile/models/profile.dart';

void main() {
  group('Profile model', () {
    test('fromJson creates Profile correctly', () {
      final json = {
        'id': 'user-123',
        'display_name': 'John',
        'fitness_level': 'intermediate',
        'weight_unit': 'kg',
        'created_at': '2026-01-01T00:00:00Z',
      };
      final profile = Profile.fromJson(json);
      expect(profile.id, 'user-123');
      expect(profile.displayName, 'John');
      expect(profile.fitnessLevel, 'intermediate');
      expect(profile.weightUnit, 'kg');
    });

    test('toJson produces correct map', () {
      const profile = Profile(
        id: 'user-123',
        displayName: 'John',
        fitnessLevel: 'beginner',
        weightUnit: 'lbs',
      );
      final json = profile.toJson();
      expect(json['id'], 'user-123');
      expect(json['display_name'], 'John');
      expect(json['fitness_level'], 'beginner');
      expect(json['weight_unit'], 'lbs');
    });

    test('defaults weightUnit to kg', () {
      final profile = Profile.fromJson({'id': 'user-123'});
      expect(profile.weightUnit, 'kg');
    });

    test('copyWith produces new instance', () {
      const profile = Profile(id: 'user-123', weightUnit: 'kg');
      final updated = profile.copyWith(weightUnit: 'lbs');
      expect(updated.weightUnit, 'lbs');
      expect(profile.weightUnit, 'kg');
    });

    test('displayName is null when absent from json', () {
      final profile = Profile.fromJson({'id': 'user-123'});
      expect(profile.displayName, isNull);
    });

    test('fitnessLevel is null when absent from json', () {
      final profile = Profile.fromJson({'id': 'user-123'});
      expect(profile.fitnessLevel, isNull);
    });

    test('two profiles with same fields are equal', () {
      const a = Profile(id: 'user-1', displayName: 'Alice', weightUnit: 'kg');
      const b = Profile(id: 'user-1', displayName: 'Alice', weightUnit: 'kg');
      expect(a, equals(b));
    });

    test('two profiles with different weightUnit are not equal', () {
      const a = Profile(id: 'user-1', weightUnit: 'kg');
      const b = Profile(id: 'user-1', weightUnit: 'lbs');
      expect(a, isNot(equals(b)));
    });

    test('parses createdAt datetime correctly', () {
      final json = {'id': 'user-1', 'created_at': '2026-03-15T08:30:00.000Z'};
      final profile = Profile.fromJson(json);
      expect(profile.createdAt, isA<DateTime>());
      expect(profile.createdAt!.year, 2026);
      expect(profile.createdAt!.month, 3);
      expect(profile.createdAt!.day, 15);
    });
  });
}
