/// Pins the BUG-010 hardening of the `/pr-celebration` route's `state.extra`
/// envelope: malformed pushes redirect to `/home` instead of crashing the
/// navigator with a cryptic `as PRDetectionResult` cast error, and a builder
/// that runs without a redirect throws a typed [StateError] that names the
/// offending field.
///
/// The router-level wiring (the GoRoute itself) is exercised end-to-end by
/// the workout-finish E2E spec; this unit test pins the shape contract in
/// isolation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/router/app_router.dart';
import 'package:repsaga/features/personal_records/domain/pr_detection_service.dart';

void main() {
  // A canonical, well-formed extra payload — every test mutates this map and
  // re-runs the validator.
  Map<String, dynamic> validExtra() => <String, dynamic>{
    'result': const PRDetectionResult(newRecords: [], isFirstWorkout: false),
    'exerciseNames': <String, String>{'ex-1': 'Bench Press'},
    'planPromptRoutineId': 'routine-1',
    'planPromptRoutineName': 'Push Day',
  };

  group('validatePrCelebrationExtra (redirect gate)', () {
    test('accepts a well-formed extra map', () {
      expect(validatePrCelebrationExtra(validExtra()), isTrue);
    });

    test('accepts an extra map with both optional fields null', () {
      final extra = validExtra()
        ..['planPromptRoutineId'] = null
        ..['planPromptRoutineName'] = null;
      expect(validatePrCelebrationExtra(extra), isTrue);
    });

    test('rejects a null extra', () {
      expect(validatePrCelebrationExtra(null), isFalse);
    });

    test('rejects a non-Map extra (the wrong-shape push case)', () {
      expect(validatePrCelebrationExtra('definitely not a map'), isFalse);
      expect(validatePrCelebrationExtra(42), isFalse);
      expect(validatePrCelebrationExtra(<String>[]), isFalse);
    });

    test('rejects an extra missing the result field', () {
      final extra = validExtra()..remove('result');
      expect(validatePrCelebrationExtra(extra), isFalse);
    });

    test('rejects an extra with a wrong-typed result field (BUG-010)', () {
      final extra = validExtra()
        ..['result'] = 'a string, not a PRDetectionResult';
      expect(validatePrCelebrationExtra(extra), isFalse);
    });

    test('rejects an extra with a wrong-typed exerciseNames field', () {
      final extra = validExtra()..['exerciseNames'] = <String, int>{'ex-1': 7};
      expect(validatePrCelebrationExtra(extra), isFalse);
    });

    test('rejects a non-null planPromptRoutineId of wrong type', () {
      final extra = validExtra()..['planPromptRoutineId'] = 42;
      expect(validatePrCelebrationExtra(extra), isFalse);
    });

    test('rejects a non-null planPromptRoutineName of wrong type', () {
      final extra = validExtra()..['planPromptRoutineName'] = const <int>[];
      expect(validatePrCelebrationExtra(extra), isFalse);
    });
  });

  group('PrCelebrationArgs.fromExtra (builder fallback)', () {
    test('parses a well-formed extra map', () {
      final args = PrCelebrationArgs.fromExtra(validExtra());
      expect(args.result, isA<PRDetectionResult>());
      expect(args.exerciseNames, {'ex-1': 'Bench Press'});
      expect(args.planPromptRoutineId, 'routine-1');
      expect(args.planPromptRoutineName, 'Push Day');
    });

    test('preserves null optional fields', () {
      final extra = validExtra()
        ..['planPromptRoutineId'] = null
        ..['planPromptRoutineName'] = null;
      final args = PrCelebrationArgs.fromExtra(extra);
      expect(args.planPromptRoutineId, isNull);
      expect(args.planPromptRoutineName, isNull);
    });

    test('throws StateError when extra is not a Map', () {
      expect(
        () => PrCelebrationArgs.fromExtra('not a map'),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'throws StateError naming result when result has wrong type (BUG-010)',
      () {
        final extra = validExtra()..['result'] = 'string instead';
        expect(
          () => PrCelebrationArgs.fromExtra(extra),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('result'),
            ),
          ),
        );
      },
    );

    test('throws StateError naming exerciseNames when wrong type', () {
      final extra = validExtra()..['exerciseNames'] = <int, String>{1: 'a'};
      expect(
        () => PrCelebrationArgs.fromExtra(extra),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('exerciseNames'),
          ),
        ),
      );
    });

    test('throws StateError naming planPromptRoutineId when wrong type', () {
      final extra = validExtra()..['planPromptRoutineId'] = 42;
      expect(
        () => PrCelebrationArgs.fromExtra(extra),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('planPromptRoutineId'),
          ),
        ),
      );
    });
  });
}
