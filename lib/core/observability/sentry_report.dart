import 'package:sentry_flutter/sentry_flutter.dart';

/// Thin static gating wrapper around Sentry. Call sites use this instead of
/// `Sentry.captureException` / `Sentry.addBreadcrumb` directly so the
/// "Send crash reports" opt-out toggle can short-circuit all sends from a
/// single place.
///
/// Initialized to enabled. `main.dart` should call `setEnabled` after reading
/// the persisted flag from Hive, and the Profile screen toggle calls it when
/// the user flips the switch.
class SentryReport {
  SentryReport._();

  static bool _enabled = true;

  /// Whether Sentry sends are currently enabled.
  static bool get isEnabled => _enabled;

  /// Enable or disable Sentry sends at runtime.
  static void setEnabled(bool value) {
    _enabled = value;
  }

  /// Reports an exception to Sentry if enabled, otherwise no-op.
  static Future<void> captureException(
    Object error, {
    StackTrace? stackTrace,
  }) async {
    if (!_enabled) return;
    try {
      await Sentry.captureException(error, stackTrace: stackTrace);
    } catch (_) {
      // Never let Sentry's own failures bubble up.
    }
  }

  /// Adds a breadcrumb if enabled, otherwise no-op.
  static void addBreadcrumb({
    required String category,
    required String message,
    Map<String, Object?>? data,
    SentryLevel level = SentryLevel.info,
  }) {
    if (!_enabled) return;
    try {
      Sentry.addBreadcrumb(
        Breadcrumb(
          category: category,
          message: message,
          data: data,
          level: level,
        ),
      );
    } catch (_) {
      // Never let Sentry's own failures bubble up.
    }
  }
}
