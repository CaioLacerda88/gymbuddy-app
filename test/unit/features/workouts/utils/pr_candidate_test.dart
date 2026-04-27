/// Unit tests for [isPrCandidateAfterCommit] (Phase 18c, spec §13).
///
/// Mid-session PR detection is a presentation-layer heuristic — the
/// canonical PR detection runs at workout finish via [PrDetectionService]
/// and writes the durable record. The chip is a **provisional signal**:
/// "this set, on commit, looks like a personal record relative to what
/// you've done this session and last session." If the chip is wrong, the
/// final detection will simply not write a record — the user sees no PR
/// celebration at workout end. False positives are tolerable; missed
/// celebrations would feel like the app stole a moment.
///
/// **Locked criteria (heuristic-by-design):**
///   * The set must be completed AND have positive weight AND positive reps.
///     A bodyweight working set (weight=0) is not a chip-eligible PR — the
///     server-side detection has its own bodyweight ladder; the chip
///     defers to that.
///   * The set is a candidate when its `weight × reps` (Epley-1RM proxy)
///     exceeds every other completed working set's `weight × reps` for the
///     same exercise — both this session and the prior-session [lastSet]
///     reference. Warmup, dropset, and failure sets are excluded because
///     PR semantics are working-set semantics.
///   * The set itself is excluded from the comparison (a set is never its
///     own PR rival), so the chip survives a re-tap of an already-completed
///     set.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/workouts/models/exercise_set.dart';
import 'package:repsaga/features/workouts/models/set_type.dart';
import 'package:repsaga/features/workouts/utils/pr_candidate.dart';

ExerciseSet _set({
  required String id,
  required int setNumber,
  double? weight,
  int? reps,
  bool isCompleted = true,
  SetType setType = SetType.working,
}) => ExerciseSet(
  id: id,
  workoutExerciseId: 'we-1',
  setNumber: setNumber,
  weight: weight,
  reps: reps,
  setType: setType,
  isCompleted: isCompleted,
  createdAt: DateTime.utc(2026, 4, 26),
);

void main() {
  group('isPrCandidateAfterCommit', () {
    test('returns false when the set is not completed', () {
      // Pre-commit: the chip must NOT flash mid-keystroke (spec §13). The
      // gate is `isCompleted` — typing 100 → 105 → 110 reps without
      // tapping the checkmark must keep the chip dormant.
      final candidate = _set(
        id: 's1',
        setNumber: 1,
        weight: 100,
        reps: 5,
        isCompleted: false,
      );
      expect(
        isPrCandidateAfterCommit(
          set: candidate,
          allSetsThisExercise: [candidate],
          lastWorkoutSets: const [],
        ),
        isFalse,
      );
    });

    test('returns false when the set is not a working set', () {
      // Warmup, dropset, and failure sets carry different PR semantics —
      // the chip is for working-set PRs only. Server-side detection runs
      // its own logic on those.
      final warmup = _set(
        id: 's1',
        setNumber: 1,
        weight: 60,
        reps: 5,
        setType: SetType.warmup,
      );
      expect(
        isPrCandidateAfterCommit(
          set: warmup,
          allSetsThisExercise: [warmup],
          lastWorkoutSets: const [],
        ),
        isFalse,
      );
    });

    test('returns false for bodyweight (weight=0) sets', () {
      // Bodyweight ladder is server-side — chip defers. A 50-rep dip set
      // is a PR but not in this code path.
      final bodyweight = _set(id: 's1', setNumber: 1, weight: 0, reps: 50);
      expect(
        isPrCandidateAfterCommit(
          set: bodyweight,
          allSetsThisExercise: [bodyweight],
          lastWorkoutSets: const [],
        ),
        isFalse,
      );
    });

    test('returns true for a first completed working set with no history', () {
      // Brand-new exercise: any committed working set is a session-best by
      // definition. The chip fires because there's no prior set to beat.
      final s1 = _set(id: 's1', setNumber: 1, weight: 100, reps: 5);
      expect(
        isPrCandidateAfterCommit(
          set: s1,
          allSetsThisExercise: [s1],
          lastWorkoutSets: const [],
        ),
        isTrue,
      );
    });

    test('returns true when the set beats every prior session set', () {
      // 100 × 5 = 500 in last session; 105 × 5 = 525 this session beats it.
      final lastSession = [
        _set(id: 'l1', setNumber: 1, weight: 100, reps: 5),
        _set(id: 'l2', setNumber: 2, weight: 100, reps: 5),
      ];
      final committed = _set(id: 's1', setNumber: 1, weight: 105, reps: 5);
      expect(
        isPrCandidateAfterCommit(
          set: committed,
          allSetsThisExercise: [committed],
          lastWorkoutSets: lastSession,
        ),
        isTrue,
      );
    });

    test('returns false when a prior session set has higher weight×reps', () {
      // Last session's 110 × 5 = 550; this session's 105 × 5 = 525 is
      // worse. No chip.
      final lastSession = [_set(id: 'l1', setNumber: 1, weight: 110, reps: 5)];
      final committed = _set(id: 's1', setNumber: 1, weight: 105, reps: 5);
      expect(
        isPrCandidateAfterCommit(
          set: committed,
          allSetsThisExercise: [committed],
          lastWorkoutSets: lastSession,
        ),
        isFalse,
      );
    });

    test(
      'returns false when an earlier set in this workout has higher weight×reps',
      () {
        // First set of the day: 110 × 5 = 550 (chip lit). Set 2: 105 × 5 =
        // 525, no chip. Set 3 (back to 110 × 5 again): not strictly
        // greater than the existing best, so no chip — the heuristic
        // requires strict-greater to avoid double-flashing on the SAME
        // committed peak.
        final s1 = _set(id: 's1', setNumber: 1, weight: 110, reps: 5);
        final s2 = _set(id: 's2', setNumber: 2, weight: 105, reps: 5);
        final s3 = _set(id: 's3', setNumber: 3, weight: 110, reps: 5);
        final allSets = [s1, s2, s3];

        // Chip on set 2 — must NOT light because s1 beat it.
        expect(
          isPrCandidateAfterCommit(
            set: s2,
            allSetsThisExercise: allSets,
            lastWorkoutSets: const [],
          ),
          isFalse,
        );

        // Chip on set 3 — same as s1's value; strict-greater rule means
        // no chip. Otherwise multiple identical-PR sets would each light.
        expect(
          isPrCandidateAfterCommit(
            set: s3,
            allSetsThisExercise: allSets,
            lastWorkoutSets: const [],
          ),
          isFalse,
        );
      },
    );

    test('excludes warmup and dropset rivals from the comparison', () {
      // A warmup at 200 × 1 = 200 must NOT block the working set 100 × 5
      // from chipping. The heuristic compares working-set against
      // working-set only.
      final warmup = _set(
        id: 'w1',
        setNumber: 1,
        weight: 200,
        reps: 1,
        setType: SetType.warmup,
      );
      final committed = _set(id: 's1', setNumber: 2, weight: 100, reps: 5);
      expect(
        isPrCandidateAfterCommit(
          set: committed,
          allSetsThisExercise: [warmup, committed],
          lastWorkoutSets: const [],
        ),
        isTrue,
      );
    });
  });
}
