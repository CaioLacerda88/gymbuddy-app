import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/connectivity/connectivity_provider.dart';

void main() {
  group('onlineStatusProvider', () {
    test('emits true when overridden with online value', () {
      final container = ProviderContainer(
        overrides: [
          onlineStatusProvider.overrideWithValue(const AsyncData(true)),
        ],
      );
      addTearDown(container.dispose);

      final value = container.read(onlineStatusProvider).value;
      expect(value, isTrue);
    });

    test('emits false when overridden with offline value', () {
      final container = ProviderContainer(
        overrides: [
          onlineStatusProvider.overrideWithValue(const AsyncData(false)),
        ],
      );
      addTearDown(container.dispose);

      final value = container.read(onlineStatusProvider).value;
      expect(value, isFalse);
    });

    test('offline to online transition updates value', () async {
      final container = ProviderContainer(
        overrides: [
          onlineStatusProvider.overrideWithValue(const AsyncData(false)),
        ],
      );
      addTearDown(container.dispose);

      // Starts offline.
      expect(container.read(onlineStatusProvider).value, isFalse);

      // Transition to online.
      container.updateOverrides([
        onlineStatusProvider.overrideWithValue(const AsyncData(true)),
      ]);

      // Force listeners to process.
      container.read(onlineStatusProvider);
      expect(container.read(onlineStatusProvider).value, isTrue);
    });

    test('online to offline transition updates value', () async {
      final container = ProviderContainer(
        overrides: [
          onlineStatusProvider.overrideWithValue(const AsyncData(true)),
        ],
      );
      addTearDown(container.dispose);

      // Starts online.
      expect(container.read(onlineStatusProvider).value, isTrue);

      // Transition to offline.
      container.updateOverrides([
        onlineStatusProvider.overrideWithValue(const AsyncData(false)),
      ]);

      container.read(onlineStatusProvider);
      expect(container.read(onlineStatusProvider).value, isFalse);
    });
  });

  group('isOnlineProvider', () {
    test('returns true (optimistic) when stream is loading', () {
      final container = ProviderContainer(
        overrides: [
          onlineStatusProvider.overrideWithValue(const AsyncLoading()),
        ],
      );
      addTearDown(container.dispose);

      final value = container.read(isOnlineProvider);
      expect(value, isTrue);
    });

    test('returns true (optimistic) when stream is in error state', () {
      final container = ProviderContainer(
        overrides: [
          onlineStatusProvider.overrideWithValue(
            AsyncError<bool>(Exception('connectivity error'), StackTrace.empty),
          ),
        ],
      );
      addTearDown(container.dispose);

      // AsyncError.value is null, so the ?? true fallback must apply.
      final value = container.read(isOnlineProvider);
      expect(value, isTrue);
    });

    test('returns false when stream reports offline', () {
      final container = ProviderContainer(
        overrides: [
          onlineStatusProvider.overrideWithValue(const AsyncData(false)),
        ],
      );
      addTearDown(container.dispose);

      final value = container.read(isOnlineProvider);
      expect(value, isFalse);
    });

    test('returns true when stream reports online', () {
      final container = ProviderContainer(
        overrides: [
          onlineStatusProvider.overrideWithValue(const AsyncData(true)),
        ],
      );
      addTearDown(container.dispose);

      final value = container.read(isOnlineProvider);
      expect(value, isTrue);
    });
  });
}
