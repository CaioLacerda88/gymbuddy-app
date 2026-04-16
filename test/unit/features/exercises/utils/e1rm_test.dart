import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/features/exercises/utils/e1rm.dart';
import 'package:gymbuddy_app/features/workouts/models/exercise_set.dart';
import 'package:gymbuddy_app/features/workouts/models/set_type.dart';

ExerciseSet _set({
  String id = 'set-001',
  double? weight = 100,
  int? reps = 5,
  SetType setType = SetType.working,
  bool isCompleted = true,
}) {
  return ExerciseSet(
    id: id,
    workoutExerciseId: 'we-001',
    setNumber: 1,
    weight: weight,
    reps: reps,
    setType: setType,
    isCompleted: isCompleted,
    createdAt: DateTime(2026),
  );
}

void main() {
  group('e1RM — Epley formula', () {
    test('at 1 rep: weight × (1 + 1/30)', () {
      expect(e1RM(100, 1), closeTo(100 * (1 + 1 / 30), 1e-9));
      expect(e1RM(100, 1), closeTo(103.3333333, 1e-6));
    });

    test('at 5 reps: weight × (1 + 5/30)', () {
      expect(e1RM(100, 5), closeTo(100 * (1 + 5 / 30), 1e-9));
      expect(e1RM(100, 5), closeTo(116.6666666, 1e-6));
    });

    test('at 10 reps: weight × (1 + 10/30)', () {
      expect(e1RM(100, 10), closeTo(100 * (1 + 10 / 30), 1e-9));
      expect(e1RM(100, 10), closeTo(133.3333333, 1e-6));
    });

    test('weight 0 → 0 regardless of reps', () {
      expect(e1RM(0, 1), 0);
      expect(e1RM(0, 5), 0);
      expect(e1RM(0, 100), 0);
    });

    test('reps 0 → 0 (invalid set, no strength number)', () {
      expect(e1RM(100, 0), 0);
      expect(e1RM(200, 0), 0);
    });

    test('negative reps → 0 (defensive guard)', () {
      expect(e1RM(100, -1), 0);
      expect(e1RM(100, -5), 0);
    });

    test('negative weight → 0 (defensive guard)', () {
      expect(e1RM(-10, 5), 0);
      expect(e1RM(-100, 1), 0);
    });
  });

  group('peakE1Rm', () {
    test('empty list → 0', () {
      expect(peakE1Rm(const []), 0);
    });

    test('returns max e1RM across completed working sets', () {
      // Three working sets; highest e1RM wins.
      // (100 kg × 5) → 116.67, (120 kg × 3) → 132.0, (140 kg × 1) → 144.67
      final sets = [
        _set(id: 'a', weight: 100, reps: 5),
        _set(id: 'b', weight: 120, reps: 3),
        _set(id: 'c', weight: 140, reps: 1),
      ];

      expect(peakE1Rm(sets), closeTo(140 * (1 + 1 / 30), 1e-9));
    });

    test('heaviest weight does not always win — rep count matters', () {
      // (100 kg × 10) → 133.33 beats (110 kg × 3) → 121.0
      final sets = [
        _set(id: 'a', weight: 100, reps: 10),
        _set(id: 'b', weight: 110, reps: 3),
      ];

      expect(peakE1Rm(sets), closeTo(100 * (1 + 10 / 30), 1e-9));
    });

    test('ignores warmup sets', () {
      final sets = [
        _set(id: 'a', weight: 200, reps: 5, setType: SetType.warmup),
        _set(id: 'b', weight: 100, reps: 5),
      ];

      expect(peakE1Rm(sets), closeTo(100 * (1 + 5 / 30), 1e-9));
    });

    test('ignores dropset sets', () {
      final sets = [
        _set(id: 'a', weight: 200, reps: 5, setType: SetType.dropset),
        _set(id: 'b', weight: 100, reps: 5),
      ];

      expect(peakE1Rm(sets), closeTo(100 * (1 + 5 / 30), 1e-9));
    });

    test('ignores failure sets', () {
      final sets = [
        _set(id: 'a', weight: 200, reps: 5, setType: SetType.failure),
        _set(id: 'b', weight: 100, reps: 5),
      ];

      expect(peakE1Rm(sets), closeTo(100 * (1 + 5 / 30), 1e-9));
    });

    test('ignores incomplete sets', () {
      final sets = [
        _set(id: 'a', weight: 200, reps: 5, isCompleted: false),
        _set(id: 'b', weight: 100, reps: 5),
      ];

      expect(peakE1Rm(sets), closeTo(100 * (1 + 5 / 30), 1e-9));
    });

    test('ignores null-weight sets', () {
      final sets = [
        _set(id: 'a', weight: null, reps: 5),
        _set(id: 'b', weight: 100, reps: 5),
      ];

      expect(peakE1Rm(sets), closeTo(100 * (1 + 5 / 30), 1e-9));
    });

    test('ignores zero-weight sets (bodyweight)', () {
      final sets = [
        _set(id: 'a', weight: 0, reps: 5),
        _set(id: 'b', weight: 100, reps: 5),
      ];

      expect(peakE1Rm(sets), closeTo(100 * (1 + 5 / 30), 1e-9));
    });

    test('all sets disqualified → 0', () {
      final sets = [
        _set(id: 'a', weight: 200, reps: 5, setType: SetType.warmup),
        _set(id: 'b', weight: 200, reps: 5, isCompleted: false),
      ];

      expect(peakE1Rm(sets), 0);
    });
  });

  group('Unit conversion', () {
    test('kgToLb(kg) → kg * 2.20462', () {
      expect(kgToLb(1), closeTo(2.20462, 1e-9));
      expect(kgToLb(0), 0);
      expect(kgToLb(100), closeTo(220.462, 1e-9));
    });

    test('lbToKg(lb) → lb / 2.20462', () {
      expect(lbToKg(2.20462), closeTo(1, 1e-9));
      expect(lbToKg(0), 0);
      expect(lbToKg(220.462), closeTo(100, 1e-9));
    });

    test('round-trip preserves value within 1e-6 tolerance', () {
      for (final original in <double>[1, 20, 45, 100, 225, 315, 405]) {
        final roundTrip = lbToKg(kgToLb(original));
        expect(roundTrip, closeTo(original, 1e-6));
      }
    });
  });
}
