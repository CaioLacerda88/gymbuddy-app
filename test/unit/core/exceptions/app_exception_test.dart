import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/exceptions/app_exception.dart';

void main() {
  group('AuthException', () {
    test('should store message correctly', () {
      const exception = AuthException('Invalid credentials', code: 'invalid');

      expect(exception.message, 'Invalid credentials');
    });

    test('should store code correctly', () {
      const exception = AuthException('Unauthorized', code: 'auth/expired');

      expect(exception.code, 'auth/expired');
    });

    test('should format toString with runtime type and message', () {
      const exception = AuthException('Token expired', code: 'expired');

      expect(exception.toString(), 'AuthException: Token expired');
    });
  });

  group('DatabaseException', () {
    test('should store message correctly', () {
      const exception = DatabaseException('Row not found', code: '404');

      expect(exception.message, 'Row not found');
    });

    test('should store code correctly', () {
      const exception = DatabaseException('Conflict', code: '23505');

      expect(exception.code, '23505');
    });

    test('should format toString with runtime type and message', () {
      const exception = DatabaseException('Query failed', code: '500');

      expect(exception.toString(), 'DatabaseException: Query failed');
    });
  });

  group('NetworkException', () {
    test('should store message correctly', () {
      const exception = NetworkException('No internet connection');

      expect(exception.message, 'No internet connection');
    });

    test('should format toString with runtime type and message', () {
      const exception = NetworkException('Timeout');

      expect(exception.toString(), 'NetworkException: Timeout');
    });
  });

  group('ValidationException', () {
    test('should store message correctly', () {
      const exception = ValidationException(
        'Field is required',
        field: 'email',
      );

      expect(exception.message, 'Field is required');
    });

    test('should store field name correctly', () {
      const exception = ValidationException(
        'Must be positive',
        field: 'weight',
      );

      expect(exception.field, 'weight');
    });

    test('should format toString with runtime type and message', () {
      const exception = ValidationException('Invalid format', field: 'phone');

      expect(exception.toString(), 'ValidationException: Invalid format');
    });
  });
}
