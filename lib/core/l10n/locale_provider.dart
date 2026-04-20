import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/profile/providers/profile_providers.dart';
import '../local_storage/hive_service.dart';

const _hiveKey = 'locale';

/// Notifier for the app locale. Backed by the `user_prefs` Hive box.
/// Defaults to `Locale('en')` when no preference has been persisted.
///
/// Changing the locale updates both Hive (for next launch) and provider
/// state (for immediate rebuild). Additionally, the locale is synced to
/// Supabase as best-effort (fire-and-forget).
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

    // Best-effort sync to Supabase (fire-and-forget).
    _syncToRemote(locale.languageCode);
  }

  /// Called after login to reconcile local Hive locale with the remote
  /// Supabase profile locale. Supabase wins to support cross-device sync.
  Future<void> reconcileWithRemote() async {
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;

      final repo = ref.read(profileRepositoryProvider);
      final profile = await repo.getProfile(userId);
      if (profile == null) return;

      final remoteCode = profile.locale;
      final localCode = state.languageCode;

      if (remoteCode != localCode) {
        final box = Hive.box(HiveService.userPrefs);
        await box.put(_hiveKey, remoteCode);
        state = Locale(remoteCode);
      }
    } catch (e) {
      // Best-effort: if reconciliation fails, keep Hive value.
      developer.log(
        'Failed to reconcile locale with remote',
        error: e,
        name: 'LocaleNotifier',
      );
    }
  }

  /// Fire-and-forget sync of locale to the Supabase profile.
  void _syncToRemote(String languageCode) {
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;

      final repo = ref.read(profileRepositoryProvider);

      // Intentionally not awaited — fire-and-forget.
      repo.updateLocale(userId, languageCode).catchError((Object e) {
        developer.log(
          'Failed to sync locale to remote (async)',
          error: e,
          name: 'LocaleNotifier',
        );
      });
    } catch (e) {
      // Graceful fallback: Hive is already updated, UI works fine.
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
