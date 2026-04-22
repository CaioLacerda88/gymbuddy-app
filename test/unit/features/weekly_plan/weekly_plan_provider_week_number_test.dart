/// Deterministic tests for [computeWeekNumberSinceSignup].
///
/// Drives the function with an explicit `now:` so results are independent
/// of wall-clock time.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/weekly_plan/providers/weekly_plan_provider.dart';

void main() {
  group('computeWeekNumberSinceSignup', () {
    test('null createdAt returns null', () {
      expect(computeWeekNumberSinceSignup(null), isNull);
    });

    test('empty createdAt returns null', () {
      expect(computeWeekNumberSinceSignup(''), isNull);
    });

    test('malformed createdAt returns null', () {
      expect(computeWeekNumberSinceSignup('not-a-date'), isNull);
    });

    test('same day as signup is week 1', () {
      final now = DateTime.parse('2026-01-01T12:00:00Z');
      expect(computeWeekNumberSinceSignup('2026-01-01T08:00:00Z', now: now), 1);
    });

    test('day 6 post-signup is still week 1', () {
      final now = DateTime.parse('2026-01-07T00:00:00Z');
      expect(computeWeekNumberSinceSignup('2026-01-01T00:00:00Z', now: now), 1);
    });

    test('day 7 post-signup rolls over to week 2', () {
      final now = DateTime.parse('2026-01-08T00:00:00Z');
      expect(computeWeekNumberSinceSignup('2026-01-01T00:00:00Z', now: now), 2);
    });

    test('day 27 post-signup is week 4', () {
      // 27 ~/ 7 + 1 = 3 + 1 = 4
      final now = DateTime.parse('2026-01-28T00:00:00Z');
      expect(computeWeekNumberSinceSignup('2026-01-01T00:00:00Z', now: now), 4);
    });

    test('clock skew (future createdAt) clamps to week 1', () {
      final now = DateTime.parse('2026-01-01T00:00:00Z');
      expect(computeWeekNumberSinceSignup('2026-12-31T00:00:00Z', now: now), 1);
    });

    test('handles year-long signup correctly', () {
      // 365 days = 52 full weeks + 1 day = week 53
      final now = DateTime.parse('2027-01-01T00:00:00Z');
      expect(
        computeWeekNumberSinceSignup('2026-01-01T00:00:00Z', now: now),
        53,
      );
    });
  });
}
