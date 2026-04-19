import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/l10n/locale_provider.dart';
import 'package:gymbuddy_app/core/local_storage/hive_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

      // Even if a Locale with a country code is passed, only languageCode
      // is persisted.
      await notifier.setLocale(const Locale('pt', 'BR'));

      final box = Hive.box<dynamic>(HiveService.userPrefs);
      expect(box.get('locale'), 'pt');
    });
  });
}
