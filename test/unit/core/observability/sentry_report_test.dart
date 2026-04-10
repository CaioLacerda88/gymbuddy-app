import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/observability/sentry_report.dart';

void main() {
  setUp(() {
    // Default enabled state
    SentryReport.setEnabled(true);
  });

  group('SentryReport.setEnabled', () {
    test('defaults to enabled', () {
      expect(SentryReport.isEnabled, true);
    });

    test('can be disabled and re-enabled', () {
      SentryReport.setEnabled(false);
      expect(SentryReport.isEnabled, false);
      SentryReport.setEnabled(true);
      expect(SentryReport.isEnabled, true);
    });
  });

  group('SentryReport.captureException', () {
    test('returns without error when disabled', () async {
      SentryReport.setEnabled(false);
      await expectLater(
        SentryReport.captureException(
          Exception('test'),
          stackTrace: StackTrace.current,
        ),
        completes,
      );
    });

    // When enabled, we cannot assert that Sentry.captureException was called
    // without a Sentry mock harness — that is out of scope. The gating
    // behavior is the thing we care about here.
  });

  group('SentryReport.addBreadcrumb', () {
    test('returns without error when disabled', () {
      SentryReport.setEnabled(false);
      expect(
        () => SentryReport.addBreadcrumb(category: 'test', message: 'x'),
        returnsNormally,
      );
    });
  });
}
