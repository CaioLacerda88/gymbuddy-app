import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/exceptions/app_exception.dart';
import 'package:gymbuddy_app/features/auth/data/auth_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class MockGoTrueClient extends Mock implements supabase.GoTrueClient {}

class FakeAuthResponse extends Fake implements supabase.AuthResponse {
  FakeAuthResponse({this.session});

  @override
  final supabase.Session? session;
}

void main() {
  late MockGoTrueClient mockAuth;
  late AuthRepository repo;

  setUp(() {
    mockAuth = MockGoTrueClient();
    repo = AuthRepository(mockAuth);
  });

  group('AuthRepository', () {
    group('signUpWithEmail', () {
      test('returns AuthResponse on success', () async {
        final response = FakeAuthResponse();
        when(
          () => mockAuth.signUp(email: 'a@b.com', password: '123456'),
        ).thenAnswer((_) async => response);

        final result = await repo.signUpWithEmail(
          email: 'a@b.com',
          password: '123456',
        );

        expect(result, same(response));
        verify(
          () => mockAuth.signUp(email: 'a@b.com', password: '123456'),
        ).called(1);
      });

      test('maps AuthApiException to AuthException', () async {
        when(
          () => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          supabase.AuthApiException(
            'User already registered',
            statusCode: '400',
          ),
        );

        expect(
          () => repo.signUpWithEmail(email: 'a@b.com', password: '123456'),
          throwsA(
            isA<AuthException>()
                .having((e) => e.message, 'message', 'User already registered')
                .having((e) => e.code, 'code', '400'),
          ),
        );
      });
    });

    group('signInWithEmail', () {
      test('returns AuthResponse on success', () async {
        final response = FakeAuthResponse();
        when(
          () =>
              mockAuth.signInWithPassword(email: 'a@b.com', password: '123456'),
        ).thenAnswer((_) async => response);

        final result = await repo.signInWithEmail(
          email: 'a@b.com',
          password: '123456',
        );

        expect(result, same(response));
      });

      test(
        'maps AuthApiException to AuthException on invalid credentials',
        () async {
          when(
            () => mockAuth.signInWithPassword(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          ).thenThrow(
            supabase.AuthApiException(
              'Invalid login credentials',
              statusCode: '401',
            ),
          );

          expect(
            () => repo.signInWithEmail(email: 'a@b.com', password: 'wrong'),
            throwsA(
              isA<AuthException>()
                  .having(
                    (e) => e.message,
                    'message',
                    'Invalid login credentials',
                  )
                  .having((e) => e.code, 'code', '401'),
            ),
          );
        },
      );
    });

    group('signOut', () {
      test('completes successfully', () async {
        when(() => mockAuth.signOut()).thenAnswer((_) async {});

        await expectLater(repo.signOut(), completes);
        verify(() => mockAuth.signOut()).called(1);
      });

      test('maps errors through mapException', () async {
        when(() => mockAuth.signOut()).thenThrow(Exception('Network error'));

        expect(() => repo.signOut(), throwsA(isA<NetworkException>()));
      });
    });

    group('refreshSession', () {
      test('returns AuthResponse on success', () async {
        final response = FakeAuthResponse();
        when(() => mockAuth.refreshSession()).thenAnswer((_) async => response);

        final result = await repo.refreshSession();

        expect(result, same(response));
      });

      test('maps AuthApiException on expired session', () async {
        when(() => mockAuth.refreshSession()).thenThrow(
          supabase.AuthApiException('Session expired', statusCode: '401'),
        );

        expect(
          () => repo.refreshSession(),
          throwsA(isA<AuthException>().having((e) => e.code, 'code', '401')),
        );
      });
    });

    group('currentSession', () {
      test('returns null when no session', () {
        when(() => mockAuth.currentSession).thenReturn(null);

        expect(repo.currentSession, isNull);
      });
    });

    group('onAuthStateChange', () {
      test('exposes the auth state stream', () {
        const stream = Stream<supabase.AuthState>.empty();
        when(() => mockAuth.onAuthStateChange).thenAnswer((_) => stream);

        expect(repo.onAuthStateChange(), same(stream));
      });
    });
  });
}
