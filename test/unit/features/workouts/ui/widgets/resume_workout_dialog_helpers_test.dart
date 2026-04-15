import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/workouts/ui/widgets/resume_workout_dialog.dart';

void main() {
  group('isStaleWorkout', () {
    test('returns false at 5h59m59s (just under threshold)', () {
      const age = Duration(hours: 5, minutes: 59, seconds: 59);
      expect(isStaleWorkout(age), isFalse);
    });

    test('returns true at exactly 6h (threshold boundary)', () {
      const age = Duration(hours: 6);
      expect(isStaleWorkout(age), isTrue);
    });

    test('returns true well above threshold', () {
      const age = Duration(hours: 24);
      expect(isStaleWorkout(age), isTrue);
    });

    test('returns false for zero/negative ages', () {
      expect(isStaleWorkout(Duration.zero), isFalse);
      expect(isStaleWorkout(const Duration(seconds: -1)), isFalse);
    });
  });

  group('formatResumeAge', () {
    // Fixed reference "now" — all cases use a known anchor so assertions
    // are deterministic.
    final now = DateTime(2026, 4, 15, 14, 30); // Wed Apr 15 2026, 2:30 PM

    test('returns "less than an hour ago" when age < 1h', () {
      final startedAt = now.subtract(const Duration(minutes: 30));
      expect(formatResumeAge(startedAt, now), 'less than an hour ago');
    });

    test('returns "less than an hour ago" at exactly 59m59s', () {
      final startedAt = now.subtract(const Duration(minutes: 59, seconds: 59));
      expect(formatResumeAge(startedAt, now), 'less than an hour ago');
    });

    test('returns "1 hour ago" at exactly 1h00m00s same day', () {
      final startedAt = now.subtract(const Duration(hours: 1));
      expect(formatResumeAge(startedAt, now), '1 hour ago');
    });

    test('returns "N hours ago" for same-day ages between 1h and 24h', () {
      // Started at 8:30 AM, now is 2:30 PM same day → 6 hours.
      final startedAt = DateTime(2026, 4, 15, 8, 30);
      expect(formatResumeAge(startedAt, now), '6 hours ago');
    });

    test(
      'returns "yesterday at H:MM AM/PM" for a workout from previous day',
      () {
        // Started 9:30 AM the day before → 29 hours, previous calendar day.
        final startedAt = DateTime(2026, 4, 14, 9, 30);
        expect(formatResumeAge(startedAt, now), 'yesterday at 9:30 AM');
      },
    );

    test('midnight rollover: a 3h-old workout started yesterday reads as '
        '"yesterday at ..."', () {
      // "now" is right after midnight, workout started 3h earlier on the
      // previous calendar day.
      final earlyMorning = DateTime(2026, 4, 15, 2, 0);
      final startedAt = DateTime(2026, 4, 14, 23, 0);
      expect(formatResumeAge(startedAt, earlyMorning), 'yesterday at 11:00 PM');
    });

    test('yesterday branch formats midnight as "12:00 AM"', () {
      final startedAt = DateTime(2026, 4, 14, 0, 0);
      expect(formatResumeAge(startedAt, now), 'yesterday at 12:00 AM');
    });

    test('yesterday branch formats noon as "12:00 PM"', () {
      final startedAt = DateTime(2026, 4, 14, 12, 0);
      expect(formatResumeAge(startedAt, now), 'yesterday at 12:00 PM');
    });

    test('returns weekday name + time for ages 2-6 days old', () {
      // now = Wed Apr 15. 3 days earlier = Sun Apr 12, 9:30 AM.
      final startedAt = DateTime(2026, 4, 12, 9, 30);
      expect(formatResumeAge(startedAt, now), 'Sunday at 9:30 AM');
    });

    test('returns weekday name for a workout 6 days old', () {
      // now = Wed Apr 15. 6 days earlier = Thu Apr 9, 6:15 PM.
      final startedAt = DateTime(2026, 4, 9, 18, 15);
      expect(formatResumeAge(startedAt, now), 'Thursday at 6:15 PM');
    });

    test('returns "N days ago" for ages >= 7d', () {
      final startedAt = now.subtract(const Duration(days: 7));
      expect(formatResumeAge(startedAt, now), '7 days ago');
    });

    test('returns "N days ago" for much older workouts', () {
      final startedAt = now.subtract(const Duration(days: 30));
      expect(formatResumeAge(startedAt, now), '30 days ago');
    });

    test(
      'returns "less than an hour ago" for future startedAt (clock skew)',
      () {
        // Defensive: if the server clock is slightly ahead of the client,
        // startedAt can land in the future. The function must not crash or
        // emit gibberish — it falls through to the <1h branch.
        final startedAt = now.add(const Duration(minutes: 5));
        expect(formatResumeAge(startedAt, now), 'less than an hour ago');
      },
    );
  });
}
