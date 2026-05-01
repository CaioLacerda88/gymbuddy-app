/// Unit tests pinning the BUG-010 hardening of [CharacterState.fromJson]
/// and [BackfillProgress.fromJson]: malformed/missing fields must surface as
/// a typed [DatabaseException] (not a cryptic Dart cast error).
///
/// The Supabase plumbing (the auth/from/select chain) is exercised in the
/// integration suite; re-faking it here for a fromJson contract would only
/// test the fake. These tests target the public factory directly — the
/// boundary the audit list called out.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/exceptions/app_exception.dart';
import 'package:repsaga/features/rpg/data/rpg_repository.dart';

void main() {
  group('CharacterState.fromJson', () {
    Map<String, dynamic> validRow() => <String, dynamic>{
      'user_id': 'u-001',
      'character_level': 12,
      'max_rank': 5,
      'min_rank': 2,
      'lifetime_xp': 4321.5,
    };

    test('parses a well-formed row', () {
      final state = CharacterState.fromJson(validRow());
      expect(state.userId, 'u-001');
      expect(state.characterLevel, 12);
      expect(state.maxRank, 5);
      expect(state.minRank, 2);
      expect(state.lifetimeXp, 4321.5);
    });

    test('coerces int lifetime_xp to double (PostgREST numeric quirk)', () {
      final state = CharacterState.fromJson({
        ...validRow(),
        'lifetime_xp': 4321,
      });
      expect(state.lifetimeXp, 4321.0);
    });

    test('throws DatabaseException naming user_id when missing (BUG-010)', () {
      final row = validRow()..remove('user_id');
      expect(
        () => CharacterState.fromJson(row),
        throwsA(
          isA<DatabaseException>().having(
            (e) => e.message,
            'message',
            contains('user_id'),
          ),
        ),
      );
    });

    test('throws DatabaseException naming character_level when missing', () {
      final row = validRow()..remove('character_level');
      expect(
        () => CharacterState.fromJson(row),
        throwsA(
          isA<DatabaseException>().having(
            (e) => e.message,
            'message',
            contains('character_level'),
          ),
        ),
      );
    });

    test('throws DatabaseException on wrong-typed user_id', () {
      final row = validRow()..['user_id'] = 42;
      expect(
        () => CharacterState.fromJson(row),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('BackfillProgress.fromJson', () {
    Map<String, dynamic> validRow() => <String, dynamic>{
      'user_id': 'u-001',
      'last_set_id': 'set-abc',
      'last_set_ts': '2026-04-30T12:00:00Z',
      'sets_processed': 1500,
      'started_at': '2026-04-30T11:00:00Z',
      'updated_at': '2026-04-30T11:30:00Z',
      'completed_at': null,
    };

    test('parses a well-formed in-flight row', () {
      final progress = BackfillProgress.fromJson(validRow());
      expect(progress.userId, 'u-001');
      expect(progress.lastSetId, 'set-abc');
      expect(progress.lastSetTs, isNotNull);
      expect(progress.setsProcessed, 1500);
      expect(progress.completedAt, isNull);
      expect(progress.isComplete, isFalse);
    });

    test('parses a completed row', () {
      final row = validRow()..['completed_at'] = '2026-04-30T12:00:00Z';
      final progress = BackfillProgress.fromJson(row);
      expect(progress.isComplete, isTrue);
    });

    test('handles all optional null fields gracefully', () {
      final row = validRow()
        ..['last_set_id'] = null
        ..['last_set_ts'] = null;
      final progress = BackfillProgress.fromJson(row);
      expect(progress.lastSetId, isNull);
      expect(progress.lastSetTs, isNull);
    });

    test('throws DatabaseException naming user_id when missing (BUG-010)', () {
      final row = validRow()..remove('user_id');
      expect(
        () => BackfillProgress.fromJson(row),
        throwsA(
          isA<DatabaseException>().having(
            (e) => e.message,
            'message',
            contains('user_id'),
          ),
        ),
      );
    });

    test('throws DatabaseException naming sets_processed when missing', () {
      final row = validRow()..remove('sets_processed');
      expect(
        () => BackfillProgress.fromJson(row),
        throwsA(
          isA<DatabaseException>().having(
            (e) => e.message,
            'message',
            contains('sets_processed'),
          ),
        ),
      );
    });

    test(
      'throws DatabaseException naming started_at when timestamp malformed',
      () {
        final row = validRow()..['started_at'] = 'not-an-iso-date';
        expect(
          () => BackfillProgress.fromJson(row),
          throwsA(
            isA<DatabaseException>()
                .having((e) => e.message, 'message', contains('started_at'))
                .having((e) => e.code, 'code', 'json_bad_timestamp'),
          ),
        );
      },
    );
  });
}
