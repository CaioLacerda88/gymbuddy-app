import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/l10n/locale_provider.dart';
import 'package:gymbuddy_app/core/local_storage/hive_service.dart';
import 'package:gymbuddy_app/features/auth/providers/auth_providers.dart';
import 'package:gymbuddy_app/features/profile/data/profile_repository.dart';
import 'package:gymbuddy_app/features/profile/providers/profile_providers.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  group('LocaleNotifier', () {
    late Directory tempDir;
    late ProviderContainer container;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('locale_test_');
      Hive.init(tempDir.path);
      await Hive.openBox<dynamic>(HiveService.userPrefs);
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
      await Hive.openBox<dynamic>(HiveService.userPrefs);
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
      await Hive.openBox<dynamic>(HiveService.userPrefs);
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
}
