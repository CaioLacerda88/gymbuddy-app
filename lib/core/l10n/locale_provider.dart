import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../local_storage/hive_service.dart';

const _hiveKey = 'locale';

/// Notifier for the app locale. Backed by the `user_prefs` Hive box.
/// Defaults to `Locale('en')` when no preference has been persisted.
///
/// Changing the locale updates both Hive (for next launch) and provider
/// state (for immediate rebuild).
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final box = Hive.box(HiveService.userPrefs);
    final code = box.get(_hiveKey, defaultValue: 'en') as String;
    return Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    final box = Hive.box(HiveService.userPrefs);
    await box.put(_hiveKey, locale.languageCode);
    state = locale;
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
