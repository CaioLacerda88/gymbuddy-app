import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/auth/utils/auth_error_messages.dart';
import 'package:repsaga/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() {
    l10n = lookupAppLocalizations(const Locale('en'));
  });

  group('AuthErrorMessages.fromError', () {
    test('maps invalid login credentials', () {
      final message = AuthErrorMessages.fromError(
        Exception('Invalid login credentials'),
        l10n,
      );
      expect(message, l10n.authErrorInvalidCredentials);
    });

    test('maps invalid_credentials code', () {
      final message = AuthErrorMessages.fromError(
        Exception('invalid_credentials'),
        l10n,
      );
      expect(message, l10n.authErrorInvalidCredentials);
    });

    test('maps email not confirmed', () {
      final message = AuthErrorMessages.fromError(
        Exception('Email not confirmed'),
        l10n,
      );
      expect(message, l10n.authErrorEmailNotConfirmed);
    });

    test('maps user already registered', () {
      final message = AuthErrorMessages.fromError(
        Exception('User already registered'),
        l10n,
      );
      expect(message, l10n.authErrorAlreadyRegistered);
    });

    test('maps rate limit error', () {
      final message = AuthErrorMessages.fromError(
        Exception('email rate limit exceeded'),
        l10n,
      );
      expect(message, l10n.authErrorRateLimit);
    });

    test('maps weak password', () {
      final message = AuthErrorMessages.fromError(
        Exception('Password should be at least 6 characters'),
        l10n,
      );
      expect(message, l10n.authErrorWeakPassword);
    });

    test('maps network error', () {
      final message = AuthErrorMessages.fromError(
        Exception('SocketException: Connection refused'),
        l10n,
      );
      expect(message, l10n.authErrorNetwork);
    });

    test('maps timeout error', () {
      final message = AuthErrorMessages.fromError(
        Exception('Request timeout'),
        l10n,
      );
      expect(message, l10n.authErrorTimeout);
    });

    test('maps expired token/otp', () {
      final message = AuthErrorMessages.fromError(
        Exception('otp has expired'),
        l10n,
      );
      expect(message, l10n.authErrorTokenExpired);
    });

    test('returns fallback for unknown errors', () {
      final message = AuthErrorMessages.fromError(
        Exception('some random error xyz'),
        l10n,
      );
      expect(message, l10n.authErrorGeneric);
    });
  });
}
