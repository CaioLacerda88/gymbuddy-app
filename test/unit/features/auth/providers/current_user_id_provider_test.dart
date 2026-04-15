import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/auth/providers/auth_providers.dart';

// currentUserIdProvider is a one-liner over Supabase.instance.client — there
// is no branching to cover in its body. These tests pin the String? contract
// via overrideWithValue, which is how all downstream consumers read the
// provider.
void main() {
  group('currentUserIdProvider', () {
    test('returns the stubbed user id when signed in', () {
      const signedInId = '00000000-0000-4000-8000-000000000001';
      final container = ProviderContainer(
        overrides: [currentUserIdProvider.overrideWithValue(signedInId)],
      );
      addTearDown(container.dispose);

      expect(container.read(currentUserIdProvider), signedInId);
    });

    test('returns null when signed out', () {
      final container = ProviderContainer(
        overrides: [currentUserIdProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      expect(container.read(currentUserIdProvider), isNull);
    });
  });
}
