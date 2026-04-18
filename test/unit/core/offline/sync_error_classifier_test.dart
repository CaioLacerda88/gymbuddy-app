import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/offline/sync_error_classifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  group('SyncErrorClassifier', () {
    group('isTerminal', () {
      test('returns true for 400 Bad Request', () {
        const error = supabase.PostgrestException(
          message: 'Bad Request',
          code: '400',
        );
        expect(SyncErrorClassifier.isTerminal(error), isTrue);
      });

      test('returns false for 401 Unauthorized (JWT auto-refresh)', () {
        const error = supabase.PostgrestException(
          message: 'Unauthorized',
          code: '401',
        );
        expect(SyncErrorClassifier.isTerminal(error), isFalse);
      });

      test('returns true for 403 Forbidden', () {
        const error = supabase.PostgrestException(
          message: 'Forbidden',
          code: '403',
        );
        expect(SyncErrorClassifier.isTerminal(error), isTrue);
      });

      test('returns true for 404 Not Found', () {
        const error = supabase.PostgrestException(
          message: 'Not Found',
          code: '404',
        );
        expect(SyncErrorClassifier.isTerminal(error), isTrue);
      });

      test('returns true for 409 Conflict', () {
        const error = supabase.PostgrestException(
          message: 'Conflict',
          code: '409',
        );
        expect(SyncErrorClassifier.isTerminal(error), isTrue);
      });

      test('returns true for 422 Unprocessable Entity', () {
        const error = supabase.PostgrestException(
          message: 'Unprocessable',
          code: '422',
        );
        expect(SyncErrorClassifier.isTerminal(error), isTrue);
      });

      test('returns false for 500 Internal Server Error', () {
        const error = supabase.PostgrestException(message: 'ISE', code: '500');
        expect(SyncErrorClassifier.isTerminal(error), isFalse);
      });

      test('returns false for 502 Bad Gateway', () {
        const error = supabase.PostgrestException(
          message: 'Bad Gateway',
          code: '502',
        );
        expect(SyncErrorClassifier.isTerminal(error), isFalse);
      });

      test('returns false for 503 Service Unavailable', () {
        const error = supabase.PostgrestException(
          message: 'Unavailable',
          code: '503',
        );
        expect(SyncErrorClassifier.isTerminal(error), isFalse);
      });

      test('returns false for SocketException', () {
        expect(
          SyncErrorClassifier.isTerminal(const SocketException('refused')),
          isFalse,
        );
      });

      test('returns false for TimeoutException', () {
        expect(
          SyncErrorClassifier.isTerminal(TimeoutException('timeout')),
          isFalse,
        );
      });

      test('returns false for AuthException', () {
        expect(
          SyncErrorClassifier.isTerminal(
            const supabase.AuthException('JWT expired'),
          ),
          isFalse,
        );
      });

      test('returns false for unknown exception types', () {
        expect(SyncErrorClassifier.isTerminal(Exception('random')), isFalse);
      });

      test('returns false for PostgrestException with non-numeric code', () {
        const error = supabase.PostgrestException(
          message: 'Unknown',
          code: 'PGRST',
        );
        expect(SyncErrorClassifier.isTerminal(error), isFalse);
      });
    });
  });
}
