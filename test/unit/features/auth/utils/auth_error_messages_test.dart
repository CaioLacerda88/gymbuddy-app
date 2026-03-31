import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/auth/utils/auth_error_messages.dart';

void main() {
  group('AuthErrorMessages.fromError', () {
    test('maps invalid login credentials', () {
      final message = AuthErrorMessages.fromError(
        Exception('Invalid login credentials'),
      );
      expect(message, 'Wrong email or password. Please try again.');
    });

    test('maps invalid_credentials code', () {
      final message = AuthErrorMessages.fromError(
        Exception('invalid_credentials'),
      );
      expect(message, 'Wrong email or password. Please try again.');
    });

    test('maps email not confirmed', () {
      final message = AuthErrorMessages.fromError(
        Exception('Email not confirmed'),
      );
      expect(message, 'Please check your inbox and confirm your email first.');
    });

    test('maps user already registered', () {
      final message = AuthErrorMessages.fromError(
        Exception('User already registered'),
      );
      expect(
        message,
        'An account with this email already exists. Try logging in instead.',
      );
    });

    test('maps rate limit error', () {
      final message = AuthErrorMessages.fromError(
        Exception('email rate limit exceeded'),
      );
      expect(message, 'Too many attempts. Please wait a moment and try again.');
    });

    test('maps weak password', () {
      final message = AuthErrorMessages.fromError(
        Exception('Password should be at least 6 characters'),
      );
      expect(message, 'Password is too weak. Use at least 6 characters.');
    });

    test('maps network error', () {
      final message = AuthErrorMessages.fromError(
        Exception('SocketException: Connection refused'),
      );
      expect(
        message,
        'No internet connection. Check your network and try again.',
      );
    });

    test('maps timeout error', () {
      final message = AuthErrorMessages.fromError(Exception('Request timeout'));
      expect(message, 'Request timed out. Please try again.');
    });

    test('maps expired token/otp', () {
      final message = AuthErrorMessages.fromError(Exception('otp has expired'));
      expect(
        message,
        'The confirmation link has expired. Please request a new one.',
      );
    });

    test('returns fallback for unknown errors', () {
      final message = AuthErrorMessages.fromError(
        Exception('some random error xyz'),
      );
      expect(message, 'Something went wrong. Please try again.');
    });
  });
}
