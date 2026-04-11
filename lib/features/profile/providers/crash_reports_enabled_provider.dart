import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/local_storage/hive_service.dart';
import '../../../core/observability/sentry_report.dart';

const _hiveKey = 'crash_reports_enabled';

/// Notifier for the "Send crash reports" user preference. Backed by the
/// `user_prefs` Hive box. Defaults to `true` (opt-out, not opt-in).
///
/// Setting the value persists immediately and updates [SentryReport] so the
/// change takes effect for all subsequent captures and breadcrumbs.
class CrashReportsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = Hive.box(HiveService.userPrefs);
    final value = box.get(_hiveKey, defaultValue: true) as bool;
    // Keep the static SentryReport flag in sync with the Hive-backed state
    // so invalidation/rebuild (hot reload, future ref.invalidate) cannot
    // diverge the runtime toggle from the persisted preference.
    SentryReport.setEnabled(value);
    return value;
  }

  Future<void> setEnabled(bool enabled) async {
    final box = Hive.box(HiveService.userPrefs);
    await box.put(_hiveKey, enabled);
    SentryReport.setEnabled(enabled);
    state = enabled;
  }
}

final crashReportsEnabledProvider =
    NotifierProvider<CrashReportsEnabledNotifier, bool>(
      CrashReportsEnabledNotifier.new,
    );
