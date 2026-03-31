import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/exceptions/app_exception.dart';
import 'package:gymbuddy_app/core/exceptions/error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  group('ErrorMapper.mapException', () {
    test('should map PostgrestException to DatabaseException', () {
      const error = supabase.PostgrestException(
        message: 'Row not found',
        code: '404',
      );

      final result = ErrorMapper.mapException(error);

      expect(result, isA<DatabaseException>());
      expect(result.message, 'Row not found');
      expect((result as DatabaseException).code, '404');
    });

    test('should map PostgrestException with null code to "unknown"', () {
      const error = supabase.PostgrestException(message: 'DB error');

      final result = ErrorMapper.mapException(error);

      expect(result, isA<DatabaseException>());
      expect((result as DatabaseException).code, 'unknown');
    });

    test('should map AuthApiException to AuthException', () {
      final error = supabase.AuthApiException(
        'Invalid login',
        statusCode: '401',
      );

      final result = ErrorMapper.mapException(error);

      expect(result, isA<AuthException>());
      expect(result.message, 'Invalid login');
      expect((result as AuthException).code, '401');
    });

    test('should map AuthApiException with null statusCode to "unknown"', () {
      final error = supabase.AuthApiException('Auth error');

      final result = ErrorMapper.mapException(error);

      expect(result, isA<AuthException>());
      expect((result as AuthException).code, 'unknown');
    });

    test('should pass through existing AppException unchanged', () {
      const error = NetworkException('No internet');

      final result = ErrorMapper.mapException(error);

      expect(result, same(error));
    });

    test('should map generic exception to NetworkException', () {
      final error = Exception('Something went wrong');

      final result = ErrorMapper.mapException(error);

      expect(result, isA<NetworkException>());
      expect(result.message, error.toString());
    });

    test('should map non-Exception errors to NetworkException', () {
      const error = 'raw string error';

      final result = ErrorMapper.mapException(error);

      expect(result, isA<NetworkException>());
      expect(result.message, 'raw string error');
    });
  });
}
