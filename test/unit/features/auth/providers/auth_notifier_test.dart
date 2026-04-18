import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/exceptions/app_exception.dart';
import 'package:gymbuddy_app/core/local_storage/hive_service.dart';
import 'package:gymbuddy_app/features/auth/data/auth_repository.dart';
import 'package:gymbuddy_app/features/auth/providers/auth_providers.dart';
import 'package:gymbuddy_app/features/auth/providers/notifiers/auth_notifier.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthRepository extends Mock implements AuthRepository {}

class MockHiveService extends Mock implements HiveService {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [ProviderContainer] wired up with the mocked repository
/// and [HiveService]. The returned container must be disposed by the caller.
ProviderContainer _createContainer({
  required MockAuthRepository mockRepo,
  required MockHiveService mockHive,
  supabase.Session? initialSession,
}) {
  when(() => mockRepo.currentSession).thenReturn(initialSession);

  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(mockRepo),
      hiveServiceProvider.overrideWithValue(mockHive),
    ],
  );

  // Force the notifier to build so _repo and _hive are assigned.
  container.read(authNotifierProvider);

  return container;
}

/// Waits for the notifier's state to settle past [AsyncLoading].
Future<void> _waitForSettled(ProviderContainer container) async {
  // Pump micro-tasks so AsyncValue.guard completes.
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthRepository mockRepo;
  late MockHiveService mockHive;

  setUp(() {
    mockRepo = MockAuthRepository();
    mockHive = MockHiveService();
  });

  group('AuthNotifier.signOut', () {
    test('signs out then clears Hive caches', () async {
      when(() => mockHive.clearAll()).thenAnswer((_) async {});
      when(() => mockRepo.signOut()).thenAnswer((_) async {});

      final container = _createContainer(
        mockRepo: mockRepo,
        mockHive: mockHive,
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).signOut();
      await _waitForSettled(container);

      verifyInOrder([() => mockRepo.signOut(), () => mockHive.clearAll()]);
      expect(
        container.read(authNotifierProvider),
        isA<AsyncData<dynamic>>().having((d) => d.value, 'value', isNull),
      );
    });

    test('propagates error if signOut fails', () async {
      when(() => mockHive.clearAll()).thenAnswer((_) async {});
      when(
        () => mockRepo.signOut(),
      ).thenThrow(const NetworkException('No connection'));

      final container = _createContainer(
        mockRepo: mockRepo,
        mockHive: mockHive,
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).signOut();
      await _waitForSettled(container);

      expect(container.read(authNotifierProvider), isA<AsyncError<dynamic>>());
    });

    test('signs out successfully even if clearAll throws', () async {
      when(() => mockRepo.signOut()).thenAnswer((_) async {});
      when(() => mockHive.clearAll()).thenThrow(Exception('Hive I/O error'));

      final container = _createContainer(
        mockRepo: mockRepo,
        mockHive: mockHive,
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).signOut();
      await _waitForSettled(container);

      verify(() => mockRepo.signOut()).called(1);
      expect(
        container.read(authNotifierProvider),
        isA<AsyncData<dynamic>>().having((d) => d.value, 'value', isNull),
      );
    });
  });

  group('AuthNotifier.deleteAccount', () {
    test('clears Hive caches on successful delete', () async {
      when(
        () => mockRepo.deleteAccount(
          platform: any(named: 'platform'),
          appVersion: any(named: 'appVersion'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockHive.clearAll()).thenAnswer((_) async {});
      when(() => mockRepo.signOut()).thenAnswer((_) async {});

      final container = _createContainer(
        mockRepo: mockRepo,
        mockHive: mockHive,
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).deleteAccount();
      await _waitForSettled(container);

      verify(() => mockHive.clearAll()).called(1);
      // State ends as AsyncData(null) — session cleared.
      expect(
        container.read(authNotifierProvider),
        isA<AsyncData<dynamic>>().having((d) => d.value, 'value', isNull),
      );
    });

    test('does NOT clear caches when deleteAccount fails', () async {
      when(
        () => mockRepo.deleteAccount(
          platform: any(named: 'platform'),
          appVersion: any(named: 'appVersion'),
        ),
      ).thenThrow(const DatabaseException('Delete failed', code: 'PGRST000'));
      when(() => mockHive.clearAll()).thenAnswer((_) async {});

      final container = _createContainer(
        mockRepo: mockRepo,
        mockHive: mockHive,
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).deleteAccount();
      await _waitForSettled(container);

      verifyNever(() => mockHive.clearAll());
      expect(container.read(authNotifierProvider), isA<AsyncError<dynamic>>());
    });

    test(
      'swallows signOut error after successful delete (best-effort sign-out)',
      () async {
        // The account is gone server-side. Even if the local signOut() call
        // throws (e.g. token already invalid), the state must still resolve
        // to AsyncData(null) — the delete succeeded and the session is gone.
        when(
          () => mockRepo.deleteAccount(
            platform: any(named: 'platform'),
            appVersion: any(named: 'appVersion'),
          ),
        ).thenAnswer((_) async {});
        when(() => mockHive.clearAll()).thenAnswer((_) async {});
        when(
          () => mockRepo.signOut(),
        ).thenThrow(const NetworkException('Already signed out'));

        final container = _createContainer(
          mockRepo: mockRepo,
          mockHive: mockHive,
        );
        addTearDown(container.dispose);

        await container.read(authNotifierProvider.notifier).deleteAccount();
        await _waitForSettled(container);

        // clearAll was called (account successfully deleted).
        verify(() => mockHive.clearAll()).called(1);
        // State resolves to AsyncData(null), not AsyncError — the sign-out
        // error must be swallowed per the documented intent.
        expect(
          container.read(authNotifierProvider),
          isA<AsyncData<dynamic>>().having((d) => d.value, 'value', isNull),
        );
      },
    );
  });
}
