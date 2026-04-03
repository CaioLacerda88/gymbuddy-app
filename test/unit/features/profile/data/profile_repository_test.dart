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
  });
}
