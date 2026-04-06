import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/exceptions/app_exception.dart';

void main() {
  group('AppException toString', () {
    test('AuthException formats with runtime type and message', () {
      const exception = AuthException('Token expired', code: 'expired');
      expect(exception.toString(), 'AuthException: Token expired');
    });

    test('DatabaseException formats with runtime type and message', () {
      const exception = DatabaseException('Query failed', code: '500');
      expect(exception.toString(), 'DatabaseException: Query failed');
    });

    test('NetworkException formats with runtime type and message', () {
      const exception = NetworkException('Timeout');
      expect(exception.toString(), 'NetworkException: Timeout');
    });

    test('ValidationException formats with runtime type and message', () {
      const exception = ValidationException('Invalid format', field: 'phone');
      expect(exception.toString(), 'ValidationException: Invalid format');
    });
  });

  group('AppException userMessage', () {
    test('AuthException returns safe auth message', () {
      const exception = AuthException(
        'Database error querying schema',
        code: '500',
      );
      expect(
        exception.userMessage,
        'Authentication error. Please log in again.',
      );
    });

    test('DatabaseException returns safe generic message', () {
      const exception = DatabaseException(
        'violates foreign key constraint on table "sets"',
        code: '23503',
      );
      expect(exception.userMessage, 'Something went wrong. Please try again.');
      expect(exception.userMessage, isNot(contains('sets')));
      expect(exception.userMessage, isNot(contains('foreign key')));
    });

    test('NetworkException returns safe network message', () {
      const exception = NetworkException(
        'SocketException: OS Error: Connection refused',
      );
      expect(
        exception.userMessage,
        'No internet connection. Please check your network.',
      );
      expect(exception.userMessage, isNot(contains('Socket')));
    });

    test('ValidationException userMessage equals message (safe by design)', () {
      const exception = ValidationException(
        'Name must not be empty',
        field: 'name',
      );
      expect(exception.userMessage, 'Name must not be empty');
    });
  });
}
