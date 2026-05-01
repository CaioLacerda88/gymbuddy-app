import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/exceptions/app_exception.dart' as app;
import 'package:repsaga/core/offline/sync_error_mapper.dart';
import 'package:repsaga/l10n/app_localizations_en.dart';
import 'package:repsaga/l10n/app_localizations_pt.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// BUG-042: pin every exception class the mapper handles to the localized
/// l10n key it must produce. We use the EN locale's concrete strings as the
/// expectation source, then sanity-check the PT locale produces a
/// non-English, non-empty translation for each — that catches accidental
/// English fallbacks in pt-BR and verifies the mapping is locale-driven, not
/// language-leaking.
///
/// The mapper MUST NEVER return `error.toString()` or any substring of the
/// exception's internal state — those tests pass implicitly because we
/// compare to a fixed l10n string and assert no schema/error-class names
/// appear in the output.
void main() {
  final en = AppLocalizationsEn();
  final pt = AppLocalizationsPt();

  group('SyncErrorMapper.classify', () {
    group('auth errors → syncErrorSessionExpired', () {
      test('app.AuthException maps to session-expired copy', () {
        const error = app.AuthException('JWT expired', code: 'invalid_jwt');
        expect(SyncErrorMapper.classify(en, error), en.syncErrorSessionExpired);
      });

      test('supabase.AuthException maps to session-expired copy', () {
        const error = supabase.AuthException('refresh failed');
        expect(SyncErrorMapper.classify(en, error), en.syncErrorSessionExpired);
      });
    });

    group('network errors → syncErrorOffline', () {
      test('SocketException maps to offline copy', () {
        const error = SocketException('No route to host');
        expect(SyncErrorMapper.classify(en, error), en.syncErrorOffline);
      });

      test('TimeoutException maps to offline copy', () {
        final error = TimeoutException('upload timed out');
        expect(SyncErrorMapper.classify(en, error), en.syncErrorOffline);
      });

      test('HttpException maps to offline copy', () {
        const error = HttpException('connection closed');
        expect(SyncErrorMapper.classify(en, error), en.syncErrorOffline);
      });

      test('app.NetworkException maps to offline copy', () {
        const error = app.NetworkException('flaky link');
        expect(SyncErrorMapper.classify(en, error), en.syncErrorOffline);
      });
    });

    group('database errors → syncErrorRetryGeneric', () {
      test('supabase.PostgrestException (FK violation) maps to generic', () {
        const error = supabase.PostgrestException(
          message:
              'insert or update on table "personal_records" violates foreign '
              'key constraint "personal_records_set_id_fkey"',
          code: '23503',
        );
        final out = SyncErrorMapper.classify(en, error);
        expect(out, en.syncErrorRetryGeneric);
        // Information-disclosure pin: schema names must not leak.
        expect(out, isNot(contains('personal_records')));
        expect(out, isNot(contains('foreign key')));
        expect(out, isNot(contains('23503')));
      });

      test('app.DatabaseException maps to generic retry copy', () {
        const error = app.DatabaseException(
          'save_workout RPC returned null',
          code: 'rpc_null_result',
        );
        final out = SyncErrorMapper.classify(en, error);
        expect(out, en.syncErrorRetryGeneric);
        // Internal RPC names must not leak.
        expect(out, isNot(contains('save_workout')));
        expect(out, isNot(contains('rpc_null_result')));
      });

      test('TypeError (Dart cast failure) maps to generic retry copy', () {
        try {
          // Force a real TypeError so we test the actual runtime type
          // (a synthetic subclass would skip the `is TypeError` branch).
          // ignore: unused_local_variable
          final _ = (Object() as String);
          fail('expected TypeError');
        } on TypeError catch (e) {
          final out = SyncErrorMapper.classify(en, e);
          expect(out, en.syncErrorRetryGeneric);
          // Cast-error guts (`type 'Object' is not a subtype...`) must not leak.
          expect(out, isNot(contains('subtype')));
          expect(out, isNot(contains('Object')));
        }
      });
    });

    group('unknown errors → syncErrorUnknown', () {
      test('a plain Exception falls through to the unknown bucket', () {
        final error = Exception('something weird');
        final out = SyncErrorMapper.classify(en, error);
        expect(out, en.syncErrorUnknown);
        // The raw .toString() must not have leaked into the user message.
        expect(out, isNot(contains('something weird')));
      });

      test('a non-Exception Object also falls through', () {
        final out = SyncErrorMapper.classify(en, 'a bare string');
        expect(out, en.syncErrorUnknown);
        expect(out, isNot(contains('a bare string')));
      });
    });

    group('locale switching', () {
      test('pt-BR returns Portuguese copy, not English', () {
        const error = SocketException('offline');
        final ptOut = SyncErrorMapper.classify(pt, error);
        expect(ptOut, pt.syncErrorOffline);
        expect(ptOut, isNot(en.syncErrorOffline));
        expect(ptOut, isNotEmpty);
      });

      test('pt-BR generic copy differs from English generic copy', () {
        const error = supabase.PostgrestException(
          message: 'whatever',
          code: '23505',
        );
        expect(SyncErrorMapper.classify(pt, error), pt.syncErrorRetryGeneric);
        expect(
          SyncErrorMapper.classify(pt, error),
          isNot(SyncErrorMapper.classify(en, error)),
        );
      });
    });
  });

  group('SyncErrorMapper.toUserMessage', () {
    test('returns the same value as classify() for the same input', () {
      const error = SocketException('flaky');
      expect(
        SyncErrorMapper.toUserMessage(en, error),
        SyncErrorMapper.classify(en, error),
      );
    });
  });
}
