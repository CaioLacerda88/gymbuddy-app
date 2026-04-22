import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/observability/sentry_report.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  setUp(() {
    // Default enabled state
    SentryReport.setEnabled(true);
    SentryReport.debugSetCaptureFn(null);
  });

  tearDown(() {
    SentryReport.debugSetCaptureFn(null);
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

    test('enabled→disabled transition updates isEnabled even when Sentry SDK '
        'is not initialised (clearBreadcrumbs swallowed by try/catch)', () {
      // In unit tests the Sentry SDK is never initialized (no DSN), so
      // Sentry.configureScope throws internally. The try/catch in
      // setEnabled must swallow that and still update _enabled to false.
      // This guards the regression where an exception in clearBreadcrumbs
      // could leave _enabled == true after the opt-out toggle.
      expect(SentryReport.isEnabled, true);
      expect(
        () => SentryReport.setEnabled(false),
        returnsNormally,
        reason: 'clearBreadcrumbs failure must be swallowed, not thrown',
      );
      expect(SentryReport.isEnabled, false);
    });

    test(
      'disabled→disabled transition is a no-op (does not call clearBreadcrumbs)',
      () {
        // Only the wasEnabled && !value branch triggers clearBreadcrumbs.
        // Setting false→false must be a pure no-op (no SDK interaction).
        SentryReport.setEnabled(false);
        expect(() => SentryReport.setEnabled(false), returnsNormally);
        expect(SentryReport.isEnabled, false);
      },
    );
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

    test('forwards to injected capture function when enabled', () async {
      Object? capturedError;
      StackTrace? capturedStack;
      SentryReport.debugSetCaptureFn((
        Object error, {
        StackTrace? stackTrace,
      }) async {
        capturedError = error;
        capturedStack = stackTrace;
        return const SentryId.empty();
      });

      final err = Exception('real');
      final stack = StackTrace.current;
      await SentryReport.captureException(err, stackTrace: stack);

      expect(capturedError, same(err));
      expect(capturedStack, same(stack));
    });

    test('does NOT forward when disabled, even with injected fn', () async {
      var calls = 0;
      SentryReport.debugSetCaptureFn((
        Object error, {
        StackTrace? stackTrace,
      }) async {
        calls += 1;
        return const SentryId.empty();
      });
      SentryReport.setEnabled(false);

      await SentryReport.captureException(Exception('x'));

      expect(calls, 0);
    });

    test('swallows capture-fn exceptions (never bubbles)', () async {
      SentryReport.debugSetCaptureFn((
        Object error, {
        StackTrace? stackTrace,
      }) async {
        throw StateError('sentry itself blew up');
      });
      await expectLater(
        SentryReport.captureException(Exception('x')),
        completes,
      );
    });
  });

  group('SentryReport.addBreadcrumb', () {
    test('returns without error when disabled', () {
      SentryReport.setEnabled(false);
      expect(
        () => SentryReport.addBreadcrumb(category: 'test', message: 'x'),
        returnsNormally,
      );
    });

    test('debug-mode assert fires when data contains an email string', () {
      // Debug-only guard: release builds skip this check. Running under
      // `flutter test` always has asserts enabled so this is deterministic.
      SentryReport.setEnabled(true);
      expect(
        () => SentryReport.addBreadcrumb(
          category: 'auth',
          message: 'login attempt',
          data: {'username': 'alice@example.com'},
        ),
        throwsA(isA<Error>()),
        reason:
            'Breadcrumb data values that look like email must trip the '
            'debug assert — this is the PII firewall at the call site.',
      );
    });

    test('accepts bounded IDs in data without asserting', () {
      SentryReport.setEnabled(true);
      expect(
        () => SentryReport.addBreadcrumb(
          category: 'workout',
          message: 'finished workout',
          data: {
            'workout_id': 'abc-123',
            'routine_id': 'def-456',
            'workout_number': 42,
            'had_pr': true,
          },
        ),
        returnsNormally,
      );
    });
  });
}
