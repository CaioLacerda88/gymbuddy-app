/// Pins the contract of the JSON helpers used at every untrusted external
/// boundary in the repository layer (audit BUG-010). The helpers must:
///   1. Return the value when present and well-typed.
///   2. Throw [DatabaseException] (not a raw Dart cast error) when the field
///      is missing or has the wrong type.
///   3. Carry the field name in the message — that's what makes a production
///      Sentry breadcrumb actionable.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/data/json_helpers.dart';
import 'package:repsaga/core/exceptions/app_exception.dart';

void main() {
  group('requireField', () {
    test('returns the value when present and correctly typed', () {
      expect(requireField<String>({'k': 'v'}, 'k'), 'v');
      expect(requireField<int>({'k': 7}, 'k'), 7);
    });

    test('throws DatabaseException naming the field when key is absent', () {
      expect(
        () => requireField<String>(<String, dynamic>{}, 'user_id'),
        throwsA(
          isA<DatabaseException>().having(
            (e) => e.message,
            'message',
            contains('user_id'),
          ),
        ),
      );
    });

    test('throws DatabaseException naming the field when value is null', () {
      expect(
        () => requireField<String>({'user_id': null}, 'user_id'),
        throwsA(
          isA<DatabaseException>().having(
            (e) => e.message,
            'message',
            contains('user_id'),
          ),
        ),
      );
    });

    test(
      'throws DatabaseException with type info when value has wrong type',
      () {
        expect(
          () => requireField<String>({'k': 42}, 'k'),
          throwsA(
            isA<DatabaseException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('expected String'),
                )
                .having((e) => e.message, 'message', contains('got int')),
          ),
        );
      },
    );
  });

  group('optionalField', () {
    test('returns null for absent key', () {
      expect(optionalField<String>(<String, dynamic>{}, 'k'), isNull);
    });

    test('returns null for explicitly-null value', () {
      expect(optionalField<String>({'k': null}, 'k'), isNull);
    });

    test('returns the value when present and correctly typed', () {
      expect(optionalField<String>({'k': 'v'}, 'k'), 'v');
    });

    test('throws DatabaseException on present-but-wrong-type', () {
      expect(
        () => optionalField<String>({'k': 42}, 'k'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('requireInt', () {
    test('coerces num to int', () {
      expect(requireInt({'k': 7}, 'k'), 7);
      expect(requireInt({'k': 7.0}, 'k'), 7);
    });

    test('throws DatabaseException on missing', () {
      expect(
        () => requireInt(<String, dynamic>{}, 'character_level'),
        throwsA(
          isA<DatabaseException>().having(
            (e) => e.message,
            'message',
            contains('character_level'),
          ),
        ),
      );
    });

    test('throws DatabaseException on non-numeric type', () {
      expect(
        () => requireInt({'k': 'seven'}, 'k'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('requireDouble', () {
    test('coerces num to double', () {
      expect(requireDouble({'k': 7}, 'k'), 7.0);
      expect(requireDouble({'k': 7.5}, 'k'), 7.5);
    });

    test('throws DatabaseException on missing', () {
      expect(
        () => requireDouble(<String, dynamic>{}, 'lifetime_xp'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('requireDateTime', () {
    test('parses ISO-8601', () {
      final dt = requireDateTime({'k': '2026-04-30T12:34:56Z'}, 'k');
      expect(dt.year, 2026);
      expect(dt.month, 4);
      expect(dt.day, 30);
    });

    test('throws DatabaseException on missing', () {
      expect(
        () => requireDateTime(<String, dynamic>{}, 'started_at'),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('throws DatabaseException on malformed', () {
      expect(
        () => requireDateTime({'k': 'not-a-date'}, 'k'),
        throwsA(
          isA<DatabaseException>().having(
            (e) => e.code,
            'code',
            'json_bad_timestamp',
          ),
        ),
      );
    });
  });

  group('optionalDateTime', () {
    test('returns null for absent key', () {
      expect(optionalDateTime(<String, dynamic>{}, 'k'), isNull);
    });

    test('returns null for null value', () {
      expect(optionalDateTime({'k': null}, 'k'), isNull);
    });

    test('parses ISO-8601 when present', () {
      final dt = optionalDateTime({'k': '2026-01-01T00:00:00Z'}, 'k');
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
    });

    test('throws DatabaseException on present-but-malformed', () {
      expect(
        () => optionalDateTime({'k': 'garbage'}, 'k'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
