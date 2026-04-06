import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/data/base_repository.dart';
import 'package:gymbuddy_app/core/exceptions/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class _TestRepository extends BaseRepository {
  const _TestRepository();
}

void main() {
  const repo = _TestRepository();

  group('BaseRepository.mapException', () {
    test('returns the result of a successful action', () async {
      final result = await repo.mapException(() async => 42);

      expect(result, 42);
    });

    test('rethrows AppException subtypes unchanged', () async {
      final exceptions = <AppException>[
        const AuthException('Unauthorized', code: '401'),
        const DatabaseException('Row not found', code: '404'),
        const NetworkException('No internet'),
        const ValidationException('Required', field: 'name'),
      ];

      for (final exception in exceptions) {
        await expectLater(
          () => repo.mapException(() async => throw exception),
          throwsA(same(exception)),
        );
      }
    });

    test('converts PostgrestException to DatabaseException', () async {
      const error = supabase.PostgrestException(
        message: 'Unique constraint violation',
        code: '23505',
      );

      await expectLater(
        () => repo.mapException(() async => throw error),
        throwsA(
          isA<DatabaseException>()
              .having(
                (e) => e.message,
                'message',
                'Unique constraint violation',
              )
              .having((e) => e.code, 'code', '23505'),
        ),
      );
    });

    test('converts AuthApiException to AuthException', () async {
      final error = supabase.AuthApiException(
        'Invalid credentials',
        statusCode: '401',
      );

      await expectLater(
        () => repo.mapException(() async => throw error),
        throwsA(
          isA<AuthException>()
              .having((e) => e.message, 'message', 'Invalid credentials')
              .having((e) => e.code, 'code', '401'),
        ),
      );
    });

    test('converts unknown exception to NetworkException', () async {
      final error = Exception('Something went wrong');

      await expectLater(
        () => repo.mapException(() async => throw error),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            'An unexpected error occurred.',
          ),
        ),
      );
    });
  });
}
