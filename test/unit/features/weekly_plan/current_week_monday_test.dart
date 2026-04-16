/// Unit tests for the currentWeekMonday() helper.
///
/// This function determines the Monday boundary used by the weekly-plan
/// provider to anchor the active week. Edge cases:
///   - Monday itself (no subtraction needed)
///   - Sunday (6 days to subtract)
///   - Mid-week days
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/weekly_plan/providers/weekly_plan_provider.dart';

void main() {
  group('currentWeekMonday()', () {
    test('returns Monday itself when called on a Monday', () {
      // 2026-04-06 is a Monday
      final monday = DateTime(2026, 4, 6);
      final result = currentWeekMonday(monday);
      expect(result, DateTime(2026, 4, 6));
      expect(result.weekday, 1); // Monday
    });

    test('returns the previous Monday when called on a Tuesday', () {
      // 2026-04-07 is a Tuesday
      final tuesday = DateTime(2026, 4, 7);
      final result = currentWeekMonday(tuesday);
      expect(result, DateTime(2026, 4, 6));
    });

    test('returns the previous Monday when called on a Wednesday', () {
      // 2026-04-08 is a Wednesday
      final wednesday = DateTime(2026, 4, 8);
      final result = currentWeekMonday(wednesday);
      expect(result, DateTime(2026, 4, 6));
    });

    test('returns the previous Monday when called on a Saturday', () {
      // 2026-04-11 is a Saturday
      final saturday = DateTime(2026, 4, 11);
      final result = currentWeekMonday(saturday);
      expect(result, DateTime(2026, 4, 6));
    });

    test('returns Monday 6 days back when called on a Sunday', () {
      // 2026-04-12 is a Sunday (weekday == 7)
      final sunday = DateTime(2026, 4, 12);
      final result = currentWeekMonday(sunday);
      expect(result, DateTime(2026, 4, 6));
    });

    test('returns correct Monday when crossing a month boundary', () {
      // 2026-05-01 is a Friday — Monday was 2026-04-27
      final friday = DateTime(2026, 5, 1);
      final result = currentWeekMonday(friday);
      expect(result, DateTime(2026, 4, 27));
    });

    test('returns correct Monday when crossing a year boundary', () {
      // 2026-01-01 is a Thursday — Monday was 2025-12-29
      final thursday = DateTime(2026, 1, 1);
      final result = currentWeekMonday(thursday);
      expect(result, DateTime(2025, 12, 29));
    });

    test('result is always midnight (time stripped)', () {
      final wednesday = DateTime(2026, 4, 8, 15, 30, 45);
      final result = currentWeekMonday(wednesday);
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
    });

    test('result weekday is always Monday (1)', () {
      // Test all 7 days of a week.
      final referenceMonday = DateTime(2026, 4, 6);
      for (int i = 0; i < 7; i++) {
        final day = referenceMonday.add(Duration(days: i));
        final result = currentWeekMonday(day);
        expect(
          result.weekday,
          1,
          reason: 'Expected Monday for input weekday ${day.weekday}',
        );
      }
    });
  });
}
