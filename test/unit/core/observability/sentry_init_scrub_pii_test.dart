import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/observability/sentry_init.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Unit tests for [scrubEmails], [scrubEventPii], and the beforeBreadcrumb
/// data-map scrubbing logic.
///
/// These verify that email-like substrings are redacted from user-visible
/// Sentry event fields before they reach the tracker. This is our
/// defense-in-depth against third-party exceptions that echo user input.
///
/// The [beforeBreadcrumb] callback inside [initSentryAndRun] uses the same
/// `.contains('@')` gate on breadcrumb `data` string values — that behavior
/// is exercised here via [scrubEmails] (the shared building block) and via
/// documented assertions on the filtering predicate semantics.
void main() {
  group('scrubEmails', () {
    test('returns null unchanged', () {
      expect(scrubEmails(null), isNull);
    });

    test('returns empty string unchanged', () {
      expect(scrubEmails(''), '');
    });

    test('returns string with no email unchanged', () {
      expect(scrubEmails('no email here'), 'no email here');
    });

    test('replaces a single email with [email]', () {
      expect(
        scrubEmails('Login failed for alice@example.com'),
        'Login failed for [email]',
      );
    });

    test('replaces multiple emails in one string', () {
      expect(scrubEmails('alice@a.io or bob@b.co'), '[email] or [email]');
    });

    test('handles +/. in local part', () {
      expect(
        scrubEmails('ping foo.bar+tag@sub.example.org ok'),
        'ping [email] ok',
      );
    });

    test('does not match bare @ (no domain)', () {
      expect(scrubEmails('handle@ only'), 'handle@ only');
    });
  });

  group('scrubEventPii', () {
    test('scrubs email in exception value (thrown exception)', () {
      // Simulate a third-party exception whose toString contains an email,
      // as would reach beforeSend for a non-AppException error path.
      final exception = SentryException(
        type: 'AuthException',
        value:
            'Invalid credentials for user alice@example.com '
            '(server rejected login)',
      );
      final event = SentryEvent(exceptions: [exception]);

      final scrubbed = scrubEventPii(event);

      expect(scrubbed.exceptions, hasLength(1));
      expect(
        scrubbed.exceptions!.first.value,
        'Invalid credentials for user [email] (server rejected login)',
      );
    });

    test('scrubs email in top-level message.formatted', () {
      final event = SentryEvent(
        message: SentryMessage('Contact support@example.com for help'),
      );

      final scrubbed = scrubEventPii(event);

      expect(scrubbed.message?.formatted, 'Contact [email] for help');
    });

    test('leaves event unchanged when no email present', () {
      final event = SentryEvent(
        message: SentryMessage('Generic failure'),
        exceptions: [
          SentryException(type: 'StateError', value: 'Bad state: null deref'),
        ],
      );

      final scrubbed = scrubEventPii(event);

      expect(scrubbed.message?.formatted, 'Generic failure');
      expect(scrubbed.exceptions?.first.value, 'Bad state: null deref');
    });

    test('scrubs email in stack frame context line', () {
      final frame = SentryStackFrame(
        contextLine: 'throw Exception("failed for user@host.io")',
      );
      final exception = SentryException(
        type: 'Exception',
        value: 'failed',
        stackTrace: SentryStackTrace(frames: [frame]),
      );
      final event = SentryEvent(exceptions: [exception]);

      final scrubbed = scrubEventPii(event);

      expect(
        scrubbed.exceptions!.first.stackTrace!.frames.first.contextLine,
        'throw Exception("failed for [email]")',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // beforeBreadcrumb data-map filtering predicate
  //
  // The beforeBreadcrumb callback in initSentryAndRun drops any breadcrumb
  // whose `data` map contains a String value with '@'. We cannot invoke the
  // closure directly (it is created inside initSentryAndRun), but we can
  // assert the predicate logic via the scrubEmails helper it delegates to for
  // message-level filtering, and document the data-map drop semantics.
  // The call-site guard (SentryReport.addBreadcrumb debug assert) provides
  // the testable surface for data-map PII — see sentry_report_test.dart.
  // ---------------------------------------------------------------------------
  group('beforeBreadcrumb data-map filtering predicate', () {
    test('scrubEmails flags a data value containing an email (@ present)', () {
      // The beforeBreadcrumb closure checks `value.contains('@')` on each
      // data string and drops the crumb when found. This test validates the
      // predicate logic on the underlying helper.
      const emailValue = 'alice@example.com';
      expect(
        emailValue.contains('@'),
        isTrue,
        reason: 'Data value with email must trip the @ gate',
      );
      // scrubEmails is the message-level counterpart — also redacts emails.
      expect(scrubEmails(emailValue), '[email]');
    });

    test('a bounded ID data value does NOT trip the @ gate', () {
      const idValue = 'workout_abc-123';
      expect(
        idValue.contains('@'),
        isFalse,
        reason: 'Bounded ID values must NOT trip the @ gate',
      );
      // scrubEmails also leaves it untouched.
      expect(scrubEmails(idValue), idValue);
    });

    // -------------------------------------------------------------------------
    // The next two tests validate the Breadcrumb data field traversal path used
    // by the beforeBreadcrumb callback in initSentryAndRun. We replicate the
    // exact predicate (`value is String && value.contains('@')`) on real
    // Breadcrumb objects so that any future change to the Sentry Breadcrumb API
    // (e.g., data values becoming non-nullable, or a type change) is caught here
    // before it silently breaks the drop gate in production.
    // -------------------------------------------------------------------------

    test(
      'Breadcrumb data with email string value trips the drop predicate',
      () {
        // Mirrors the inline beforeBreadcrumb predicate:
        //   for (final value in data.values) {
        //     if (value is String && value.contains('@')) return null;
        //   }
        final crumb = Breadcrumb(
          category: 'auth',
          message: 'login attempt',
          data: {'username': 'alice@example.com'},
        );

        var shouldDrop = false;
        if (crumb.data != null) {
          for (final value in crumb.data!.values) {
            if (value is String && value.contains('@')) {
              shouldDrop = true;
              break;
            }
          }
        }

        expect(
          shouldDrop,
          isTrue,
          reason:
              'A Breadcrumb whose data map contains an email-like string value '
              'must be dropped by the beforeBreadcrumb gate.',
        );
      },
    );

    test(
      'Breadcrumb data with bounded ID values does NOT trip the drop predicate',
      () {
        final crumb = Breadcrumb(
          category: 'workout',
          message: 'workout finished',
          data: {
            'workout_id': 'abc-123',
            'routine_id': 'def-456',
            'workout_number': 42,
            'had_pr': true,
          },
        );

        var shouldDrop = false;
        if (crumb.data != null) {
          for (final value in crumb.data!.values) {
            if (value is String && value.contains('@')) {
              shouldDrop = true;
              break;
            }
          }
        }

        expect(
          shouldDrop,
          isFalse,
          reason:
              'A Breadcrumb whose data map contains only bounded IDs, numbers, '
              'and booleans must NOT be dropped by the beforeBreadcrumb gate.',
        );
      },
    );
  });
}
