import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/exercises/providers/exercise_providers.dart';

void main() {
  group('exerciseByIdProvider', () {
    test('is a family provider parameterized by exercise ID', () {
      // Verify that the provider is a FutureProvider.family by checking
      // that creating two instances with different IDs gives different refs.
      // This is a structural test -- integration tests would verify
      // actual data fetching with mocked repositories.
      final provider1 = exerciseByIdProvider('ex-1');
      final provider2 = exerciseByIdProvider('ex-2');
      final same = exerciseByIdProvider('ex-1');

      // Different IDs should produce different provider instances.
      expect(provider1, isNot(equals(provider2)));
      // Same ID should produce the same provider instance.
      expect(provider1, equals(same));
    });
  });
}
