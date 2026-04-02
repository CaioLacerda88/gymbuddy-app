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
}
