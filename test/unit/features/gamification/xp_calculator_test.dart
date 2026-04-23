import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/gamification/domain/xp_calculator.dart';
import 'package:repsaga/features/gamification/models/xp_breakdown.dart';
import 'package:repsaga/features/personal_records/models/record_type.dart';
import 'package:repsaga/features/workouts/models/exercise_set.dart';
import 'package:repsaga/features/workouts/models/set_type.dart';

/// Builds a completed working [ExerciseSet] with the given weight/reps/rpe.
///
/// Non-completed or non-working sets are intentionally excluded from the
/// formula — tests that want to prove those exclusions construct them
/// inline via overrides.
ExerciseSet _set({
  double? weight,
  int? reps,
  int? rpe,
  bool isCompleted = true,
  SetType setType = SetType.working,
  String id = 's',
}) {
  return ExerciseSet(
    id: id,
    workoutExerciseId: 'we',
    setNumber: 1,
    weight: weight,
    reps: reps,
    rpe: rpe,
    setType: setType,
    isCompleted: isCompleted,
    createdAt: DateTime(2026, 1, 1),
  );
}

XpPrAward _weightPr() => const XpPrAward(recordType: RecordType.maxWeight);
XpPrAward _repPr() => const XpPrAward(recordType: RecordType.maxReps);
XpPrAward _volumePr() => const XpPrAward(recordType: RecordType.maxVolume);

void main() {
  group('XpCalculator.compute — base', () {
    test('always returns base 50 even with zero sets', () {
      final b = XpCalculator.compute(sets: const [], prs: const []);
      expect(b.base, 50);
      expect(b.total, 50);
    });

    test('base is not doubled by itself without comeback', () {
      final b = XpCalculator.compute(sets: const [], prs: const []);
      expect(b.base, 50);
      expect(b.comeback, 0);
    });
  });

  group('XpCalculator.compute — volume floor(totalKg / 500)', () {
    test('zero totalKg yields 0 volume xp', () {
      final b = XpCalculator.compute(sets: const [], prs: const []);
      expect(b.volume, 0);
    });

    test('totalKg = 499 yields 0 volume xp (floor)', () {
      // 100kg x 4r + 99kg x 1r = 499
      final b = XpCalculator.compute(
        sets: [
          _set(weight: 100, reps: 4, id: 'a'),
          _set(weight: 99, reps: 1, id: 'b'),
        ],
        prs: const [],
      );
      expect(b.volume, 0);
    });

    test('totalKg = 500 yields 1 volume xp', () {
      final b = XpCalculator.compute(
        sets: [_set(weight: 100, reps: 5, id: 'a')],
        prs: const [],
      );
      expect(b.volume, 1);
    });

    test('totalKg = 5000 yields 10 volume xp', () {
      final b = XpCalculator.compute(
        sets: [_set(weight: 100, reps: 50, id: 'a')],
        prs: const [],
      );
      expect(b.volume, 10);
    });

    test('non-completed sets are excluded from volume', () {
      final b = XpCalculator.compute(
        sets: [_set(weight: 100, reps: 10, id: 'a', isCompleted: false)],
        prs: const [],
      );
      expect(b.volume, 0);
    });

    test('warm-up sets are excluded from volume', () {
      final b = XpCalculator.compute(
        sets: [_set(weight: 100, reps: 10, id: 'a', setType: SetType.warmup)],
        prs: const [],
      );
      expect(b.volume, 0);
    });
  });

  group('XpCalculator.compute — intensity sum((rpe-5)*10) for rpe>5', () {
    test('rpe=5 yields 0 intensity xp', () {
      final b = XpCalculator.compute(
        sets: [_set(weight: 100, reps: 5, rpe: 5, id: 'a')],
        prs: const [],
      );
      expect(b.intensity, 0);
    });

    test('rpe=6 yields 10 intensity xp', () {
      final b = XpCalculator.compute(
        sets: [_set(weight: 100, reps: 5, rpe: 6, id: 'a')],
        prs: const [],
      );
      expect(b.intensity, 10);
    });

    test('rpe=10 yields 50 intensity xp', () {
      final b = XpCalculator.compute(
        sets: [_set(weight: 100, reps: 5, rpe: 10, id: 'a')],
        prs: const [],
      );
      expect(b.intensity, 50);
    });

    test('mix of rpe across sets sums correctly', () {
      // (6-5)*10 + (8-5)*10 + (10-5)*10 = 10 + 30 + 50 = 90
      final b = XpCalculator.compute(
        sets: [
          _set(weight: 100, reps: 5, rpe: 6, id: 'a'),
          _set(weight: 100, reps: 5, rpe: 8, id: 'b'),
          _set(weight: 100, reps: 5, rpe: 10, id: 'c'),
        ],
        prs: const [],
      );
      expect(b.intensity, 90);
    });

    test('rpe below 5 and equal to 5 are both filtered out', () {
      final b = XpCalculator.compute(
        sets: [
          _set(weight: 100, reps: 5, rpe: 1, id: 'a'),
          _set(weight: 100, reps: 5, rpe: 3, id: 'b'),
          _set(weight: 100, reps: 5, rpe: 5, id: 'c'),
        ],
        prs: const [],
      );
      expect(b.intensity, 0);
    });
  });

  group('XpCalculator.compute — PRs', () {
    test('zero PRs yields 0 pr xp', () {
      final b = XpCalculator.compute(sets: const [], prs: const []);
      expect(b.pr, 0);
    });

    test('one maxWeight PR yields 100 pr xp', () {
      final b = XpCalculator.compute(sets: const [], prs: [_weightPr()]);
      expect(b.pr, 100);
    });

    test('one maxReps PR yields 50 pr xp', () {
      final b = XpCalculator.compute(sets: const [], prs: [_repPr()]);
      expect(b.pr, 50);
    });

    test('maxVolume PR yields 50 pr xp (same rate as reps)', () {
      final b = XpCalculator.compute(sets: const [], prs: [_volumePr()]);
      expect(b.pr, 50);
    });

    test('multi-PR sums across types', () {
      // 100 + 50 + 50 = 200
      final b = XpCalculator.compute(
        sets: const [],
        prs: [_weightPr(), _repPr(), _volumePr()],
      );
      expect(b.pr, 200);
    });

    test('two heavy PRs yield 200 pr xp (one per exercise possible)', () {
      final b = XpCalculator.compute(
        sets: const [],
        prs: [_weightPr(), _weightPr()],
      );
      expect(b.pr, 200);
    });
  });

  group('XpCalculator.compute — quest', () {
    test('hasCompletedQuest=false yields 0 quest xp', () {
      final b = XpCalculator.compute(
        sets: const [],
        prs: const [],
        hasCompletedQuest: false,
      );
      expect(b.quest, 0);
    });

    test('hasCompletedQuest=true yields 75 quest xp', () {
      final b = XpCalculator.compute(
        sets: const [],
        prs: const [],
        hasCompletedQuest: true,
      );
      expect(b.quest, 75);
    });
  });

  group('XpCalculator.compute — comeback multiplier applied last', () {
    test('isComeback=false leaves components unchanged (no multiplier)', () {
      final b = XpCalculator.compute(
        sets: [_set(weight: 100, reps: 5, rpe: 6, id: 'a')],
        prs: [_weightPr()],
      );
      // base 50 + volume 1 + intensity 10 + pr 100 = 161
      expect(b.base, 50);
      expect(b.volume, 1);
      expect(b.intensity, 10);
      expect(b.pr, 100);
      expect(b.comeback, 0);
      expect(b.total, 161);
    });

    test('isComeback=true applies x2 to the sum of all other components', () {
      final b = XpCalculator.compute(
        sets: [_set(weight: 100, reps: 5, rpe: 6, id: 'a')],
        prs: [_weightPr()],
        isComeback: true,
      );
      // (50 + 1 + 10 + 100) * 2 = 322
      // comeback component = bonus added = 161
      expect(b.base, 50);
      expect(b.volume, 1);
      expect(b.intensity, 10);
      expect(b.pr, 100);
      expect(b.quest, 0);
      expect(b.comeback, 161);
      expect(b.total, 322);
    });

    test(
      'isComeback=true + quest: multiplier still applied to every component',
      () {
        final b = XpCalculator.compute(
          sets: [_set(weight: 100, reps: 5, rpe: 6, id: 'a')],
          prs: [_weightPr()],
          isComeback: true,
          hasCompletedQuest: true,
        );
        // (50 + 1 + 10 + 100 + 75) * 2 = 472
        expect(b.quest, 75);
        expect(b.comeback, 50 + 1 + 10 + 100 + 75);
        expect(b.total, 472);
      },
    );

    test(
      'isComeback on a zero-activity workout still multiplies the base-50 floor',
      () {
        final b = XpCalculator.compute(
          sets: const [],
          prs: const [],
          isComeback: true,
        );
        expect(b.base, 50);
        expect(b.comeback, 50);
        expect(b.total, 100);
      },
    );
  });

  group('XpCalculator.compute — composite / golden-ish cases', () {
    test('realistic session: 3x5 squat @ 100kg RPE 8 + 1 heavy PR', () {
      final sets = [
        _set(weight: 100, reps: 5, rpe: 8, id: 's1'),
        _set(weight: 100, reps: 5, rpe: 8, id: 's2'),
        _set(weight: 100, reps: 5, rpe: 8, id: 's3'),
      ];
      final b = XpCalculator.compute(sets: sets, prs: [_weightPr()]);

      // totalKg = 1500 → volume = 3
      // intensity per set = (8-5)*10 = 30; 3 sets = 90
      // base 50 + volume 3 + intensity 90 + pr 100 = 243
      expect(b.volume, 3);
      expect(b.intensity, 90);
      expect(b.pr, 100);
      expect(b.total, 243);
    });

    test('breakdown.total == sum of components (no rounding drift)', () {
      final b = XpCalculator.compute(
        sets: [
          _set(weight: 80, reps: 8, rpe: 7, id: 'a'),
          _set(weight: 80, reps: 8, rpe: 9, id: 'b'),
        ],
        prs: [_weightPr(), _repPr()],
        hasCompletedQuest: true,
        isComeback: true,
      );
      expect(
        b.total,
        b.base + b.volume + b.intensity + b.pr + b.quest + b.comeback,
      );
    });
  });

  group('XpBreakdown.zero helper', () {
    test('is all-zero', () {
      const z = XpBreakdown.zero;
      expect(z.base, 0);
      expect(z.volume, 0);
      expect(z.intensity, 0);
      expect(z.pr, 0);
      expect(z.quest, 0);
      expect(z.comeback, 0);
      expect(z.total, 0);
    });
  });
}
