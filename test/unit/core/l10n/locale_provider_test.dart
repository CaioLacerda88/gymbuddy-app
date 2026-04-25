import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/l10n/locale_provider.dart';
import 'package:repsaga/core/local_storage/hive_service.dart';
import 'package:repsaga/features/auth/providers/auth_providers.dart';
import 'package:repsaga/features/profile/data/profile_repository.dart';
import 'package:repsaga/features/profile/providers/profile_providers.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

/// Opens every Hive box LocaleNotifier touches: the user-prefs box for the
/// stored locale plus the four locale-affected caches that setLocale must
/// evict on switch.
Future<void> _openAllBoxes() async {
  await Hive.openBox<dynamic>(HiveService.userPrefs);
  await Hive.openBox<dynamic>(HiveService.exerciseCache);
  await Hive.openBox<dynamic>(HiveService.routineCache);
  await Hive.openBox<dynamic>(HiveService.prCache);
  await Hive.openBox<dynamic>(HiveService.workoutHistoryCache);
}

/// Seeds every locale-affected cache box with a sentinel value so tests can
/// assert post-switch eviction by checking emptiness.
Future<void> _seedLocaleCaches() async {
  await Hive.box<dynamic>(HiveService.exerciseCache).put('seed', 'value');
  await Hive.box<dynamic>(HiveService.routineCache).put('seed', 'value');
  await Hive.box<dynamic>(HiveService.prCache).put('seed', 'value');
  await Hive.box<dynamic>(HiveService.workoutHistoryCache).put('seed', 'value');
}

void main() {
  group('LocaleNotifier', () {
    late Directory tempDir;
    late ProviderContainer container;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('locale_test_');
      Hive.init(tempDir.path);
      await _openAllBoxes();
      container = ProviderContainer();
    });

    tearDown(() async {
      container.dispose();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('initial state is Locale("en") when no preference stored', () {
      final locale = container.read(localeProvider);

      expect(locale, const Locale('en'));
    });

    test('initial state reads stored locale from Hive', () async {
      final box = Hive.box<dynamic>(HiveService.userPrefs);
      await box.put('locale', 'pt');

      // Create a fresh container so the notifier re-reads from Hive.
      container.dispose();
      container = ProviderContainer();

      final locale = container.read(localeProvider);

      expect(locale, const Locale('pt'));
    });

    test('setLocale("pt") updates state to Locale("pt")', () async {
      final notifier = container.read(localeProvider.notifier);

      await notifier.setLocale(const Locale('pt'));

      expect(container.read(localeProvider), const Locale('pt'));
    });

    test('setLocale persists value to Hive', () async {
      final notifier = container.read(localeProvider.notifier);

      await notifier.setLocale(const Locale('pt'));

      final box = Hive.box<dynamic>(HiveService.userPrefs);
      expect(box.get('locale'), 'pt');
    });

    test('setLocale back to "en" after changing to "pt"', () async {
      final notifier = container.read(localeProvider.notifier);

      await notifier.setLocale(const Locale('pt'));
      expect(container.read(localeProvider), const Locale('pt'));

      await notifier.setLocale(const Locale('en'));
      expect(container.read(localeProvider), const Locale('en'));
    });

    test('setLocale stores only languageCode in Hive', () async {
      final notifier = container.read(localeProvider.notifier);

      await notifier.setLocale(const Locale('pt', 'BR'));

      final box = Hive.box<dynamic>(HiveService.userPrefs);
      expect(box.get('locale'), 'pt');
    });
  });

  group('LocaleNotifier.reconcileWithRemote', () {
    late Directory tempDir;
    late ProviderContainer container;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('locale_reconcile_');
      Hive.init(tempDir.path);
      await _openAllBoxes();
      container = ProviderContainer();
    });

    tearDown(() async {
      container.dispose();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('remote locale differs from local — updates to remote', () async {
      expect(container.read(localeProvider), const Locale('en'));

      await container.read(localeProvider.notifier).reconcileWithRemote('pt');

      expect(container.read(localeProvider), const Locale('pt'));
      final box = Hive.box<dynamic>(HiveService.userPrefs);
      expect(box.get('locale'), 'pt');
    });

    test(
      'remote locale same as local — no state change and no Hive write',
      () async {
        expect(container.read(localeProvider), const Locale('en'));

        await container.read(localeProvider.notifier).reconcileWithRemote('en');

        expect(container.read(localeProvider), const Locale('en'));
        final box = Hive.box<dynamic>(HiveService.userPrefs);
        expect(box.get('locale'), isNull);
      },
    );

    test('updates Hive so next launch uses remote locale', () async {
      await container.read(localeProvider.notifier).reconcileWithRemote('pt');

      // Fresh container re-reads from Hive.
      container.dispose();
      container = ProviderContainer();

      expect(container.read(localeProvider), const Locale('pt'));
    });
  });

  group('LocaleNotifier.setLocale remote sync', () {
    late Directory tempDir;
    late _MockProfileRepository mockRepo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('locale_sync_');
      Hive.init(tempDir.path);
      await _openAllBoxes();
      mockRepo = _MockProfileRepository();
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    ProviderContainer createContainer({String? userId}) {
      final c = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue(userId),
          profileRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('setLocale calls updateLocale on the profile repository', () async {
      when(
        () => mockRepo.updateLocale('user-1', 'pt'),
      ).thenAnswer((_) async {});

      final c = createContainer(userId: 'user-1');
      await c.read(localeProvider.notifier).setLocale(const Locale('pt'));

      // Give the fire-and-forget future a chance to complete.
      await Future<void>.delayed(Duration.zero);

      verify(() => mockRepo.updateLocale('user-1', 'pt')).called(1);
    });

    test('setLocale succeeds even when remote sync fails', () async {
      when(
        () => mockRepo.updateLocale('user-1', 'pt'),
      ).thenThrow(Exception('network error'));

      final c = createContainer(userId: 'user-1');
      await c.read(localeProvider.notifier).setLocale(const Locale('pt'));

      // State and Hive should still be updated despite remote failure.
      expect(c.read(localeProvider), const Locale('pt'));
      final box = Hive.box<dynamic>(HiveService.userPrefs);
      expect(box.get('locale'), 'pt');
    });

    test('setLocale does not call repo when user is not logged in', () async {
      final c = createContainer(userId: null);
      await c.read(localeProvider.notifier).setLocale(const Locale('pt'));

      // Give the fire-and-forget future a chance to complete.
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => mockRepo.updateLocale(any(), any()));
      // State should still update locally.
      expect(c.read(localeProvider), const Locale('pt'));
    });
  });

  // -------------------------------------------------------------------------
  // Phase 15f Stage 6 — Locale switch must evict the four locale-affected
  // Hive caches BEFORE remote sync. Without this, repositories rebuild and
  // happily return cached pt content under en (or vice versa).
  // -------------------------------------------------------------------------
  group('LocaleNotifier.setLocale cache eviction', () {
    late Directory tempDir;
    late ProviderContainer container;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('locale_evict_');
      Hive.init(tempDir.path);
      await _openAllBoxes();
      container = ProviderContainer();
    });

    tearDown(() async {
      container.dispose();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('clears exerciseCache, routineCache, prCache, '
        'workoutHistoryCache when locale changes', () async {
      await _seedLocaleCaches();

      // Sanity check — seeds landed.
      expect(Hive.box<dynamic>(HiveService.exerciseCache).length, 1);
      expect(Hive.box<dynamic>(HiveService.routineCache).length, 1);
      expect(Hive.box<dynamic>(HiveService.prCache).length, 1);
      expect(Hive.box<dynamic>(HiveService.workoutHistoryCache).length, 1);

      await container
          .read(localeProvider.notifier)
          .setLocale(const Locale('pt'));

      expect(Hive.box<dynamic>(HiveService.exerciseCache).isEmpty, isTrue);
      expect(Hive.box<dynamic>(HiveService.routineCache).isEmpty, isTrue);
      expect(Hive.box<dynamic>(HiveService.prCache).isEmpty, isTrue);
      expect(
        Hive.box<dynamic>(HiveService.workoutHistoryCache).isEmpty,
        isTrue,
      );
    });

    test(
      'does not clear caches when setLocale is called with the current locale',
      () async {
        // Container starts in en; setLocale('en') must be a no-op so we
        // don't wipe caches when callers re-emit the same locale.
        expect(container.read(localeProvider), const Locale('en'));

        await _seedLocaleCaches();

        await container
            .read(localeProvider.notifier)
            .setLocale(const Locale('en'));

        expect(Hive.box<dynamic>(HiveService.exerciseCache).length, 1);
        expect(Hive.box<dynamic>(HiveService.routineCache).length, 1);
        expect(Hive.box<dynamic>(HiveService.prCache).length, 1);
        expect(Hive.box<dynamic>(HiveService.workoutHistoryCache).length, 1);
      },
    );

    test('does not clear unrelated caches (lastSetsCache, activeWorkout, '
        'offlineQueue, userPrefs)', () async {
      // Open and seed unrelated boxes — these store locale-independent data
      // and must NOT be wiped on locale switch.
      final lastSets = await Hive.openBox<dynamic>(HiveService.lastSetsCache);
      final activeWorkout = await Hive.openBox<dynamic>(
        HiveService.activeWorkout,
      );
      final offlineQueue = await Hive.openBox<dynamic>(
        HiveService.offlineQueue,
      );
      await lastSets.put('exercise-id-1', 'last-sets-payload');
      await activeWorkout.put('current', 'workout-payload');
      await offlineQueue.put('op-1', 'queued-op');
      // userPrefs holds the locale itself plus other prefs — must survive.
      await Hive.box<dynamic>(
        HiveService.userPrefs,
      ).put('crash_reports_enabled', true);

      await container
          .read(localeProvider.notifier)
          .setLocale(const Locale('pt'));

      expect(lastSets.get('exercise-id-1'), 'last-sets-payload');
      expect(activeWorkout.get('current'), 'workout-payload');
      expect(offlineQueue.get('op-1'), 'queued-op');
      expect(
        Hive.box<dynamic>(HiveService.userPrefs).get('crash_reports_enabled'),
        isTrue,
      );
    });

    test(
      'cache eviction happens before state flips to the new locale',
      () async {
        // We assert ordering by relying on the fact that caches are cleared
        // synchronously inside setLocale BEFORE `state = locale` runs, which
        // is the value any downstream listener will see on rebuild.
        //
        // Structurally: if eviction happened AFTER state flip, a listener
        // observing `localeProvider` could read the new locale and refetch
        // through repositories that still see stale cached data. Verifying
        // that caches are empty at the exact moment state flips is the
        // strongest guarantee we can give in a unit test.
        await _seedLocaleCaches();

        bool sawEvictedCachesAtStateFlip = false;
        container.listen<Locale>(localeProvider, (prev, next) {
          if (next.languageCode == 'pt') {
            sawEvictedCachesAtStateFlip =
                Hive.box<dynamic>(HiveService.exerciseCache).isEmpty &&
                Hive.box<dynamic>(HiveService.routineCache).isEmpty &&
                Hive.box<dynamic>(HiveService.prCache).isEmpty &&
                Hive.box<dynamic>(HiveService.workoutHistoryCache).isEmpty;
          }
        });

        await container
            .read(localeProvider.notifier)
            .setLocale(const Locale('pt'));

        expect(
          sawEvictedCachesAtStateFlip,
          isTrue,
          reason:
              'caches must be empty at the moment localeProvider transitions '
              'to the new locale',
        );
      },
    );

    test('cache eviction happens before remote sync', () async {
      // Wire a profile repo that captures the cache emptiness at the moment
      // updateLocale is invoked. Eviction must precede remote sync so that
      // any reactive refetch triggered after sync reads under the new
      // locale, not from cached pt/en data.
      final mockRepo = _MockProfileRepository();
      bool? cachesEmptyAtSync;
      when(() => mockRepo.updateLocale(any(), any())).thenAnswer((_) async {
        cachesEmptyAtSync =
            Hive.box<dynamic>(HiveService.exerciseCache).isEmpty &&
            Hive.box<dynamic>(HiveService.routineCache).isEmpty &&
            Hive.box<dynamic>(HiveService.prCache).isEmpty &&
            Hive.box<dynamic>(HiveService.workoutHistoryCache).isEmpty;
      });

      final c = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('user-1'),
          profileRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(c.dispose);

      await _seedLocaleCaches();

      await c.read(localeProvider.notifier).setLocale(const Locale('pt'));
      // Allow the fire-and-forget sync future to settle.
      await Future<void>.delayed(Duration.zero);

      expect(
        cachesEmptyAtSync,
        isTrue,
        reason: 'caches must be evicted before _syncToRemote runs',
      );
    });
  });

  group('LocaleNotifier.reconcileWithRemote cache eviction', () {
    late Directory tempDir;
    late ProviderContainer container;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('locale_recon_evict_');
      Hive.init(tempDir.path);
      await _openAllBoxes();
      container = ProviderContainer();
    });

    tearDown(() async {
      container.dispose();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('clears locale-affected caches when remote locale differs', () async {
      await _seedLocaleCaches();

      await container.read(localeProvider.notifier).reconcileWithRemote('pt');

      expect(Hive.box<dynamic>(HiveService.exerciseCache).isEmpty, isTrue);
      expect(Hive.box<dynamic>(HiveService.routineCache).isEmpty, isTrue);
      expect(Hive.box<dynamic>(HiveService.prCache).isEmpty, isTrue);
      expect(
        Hive.box<dynamic>(HiveService.workoutHistoryCache).isEmpty,
        isTrue,
      );
    });

    test('does not clear caches when remote locale matches local', () async {
      await _seedLocaleCaches();

      await container.read(localeProvider.notifier).reconcileWithRemote('en');

      expect(Hive.box<dynamic>(HiveService.exerciseCache).length, 1);
      expect(Hive.box<dynamic>(HiveService.routineCache).length, 1);
      expect(Hive.box<dynamic>(HiveService.prCache).length, 1);
      expect(Hive.box<dynamic>(HiveService.workoutHistoryCache).length, 1);
    });
  });
}
