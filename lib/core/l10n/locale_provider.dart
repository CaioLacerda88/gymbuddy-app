import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/profile/providers/profile_providers.dart';
import '../local_storage/hive_service.dart';

const _hiveKey = 'locale';

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

    _syncToRemote(locale.languageCode);
  }

  Future<void> reconcileWithRemote(String remoteCode) async {
    final localCode = state.languageCode;
    if (remoteCode == localCode) return;

    final box = Hive.box(HiveService.userPrefs);
    await box.put(_hiveKey, remoteCode);
    state = Locale(remoteCode);
  }

  void _syncToRemote(String languageCode) {
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;

      final repo = ref.read(profileRepositoryProvider);

      repo.updateLocale(userId, languageCode).catchError((Object e) {
        developer.log(
          'Failed to sync locale to remote (async)',
          error: e,
          name: 'LocaleNotifier',
        );
      });
    } catch (e) {
      developer.log(
        'Failed to sync locale to remote (sync)',
        error: e,
        name: 'LocaleNotifier',
      );
    }
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
