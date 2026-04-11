import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/observability/sentry_init.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Unit tests for [scrubEmails] and [scrubEventPii].
///
/// These verify that email-like substrings are redacted from user-visible
/// Sentry event fields before they reach the tracker. This is our
/// defense-in-depth against third-party exceptions that echo user input.
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
}
