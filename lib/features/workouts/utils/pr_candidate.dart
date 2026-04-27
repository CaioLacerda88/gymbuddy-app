import '../models/exercise_set.dart';
import '../models/set_type.dart';

/// Mid-session PR-chip candidacy heuristic (Phase 18c, spec §13).
///
/// **Purpose:** decide whether the inline "PR" pill should render next to a
/// just-committed set in [SetRow]. This is a **provisional signal** — the
/// canonical PR detection runs at workout finish via [PrDetectionService]
/// and writes the durable record. This heuristic exists so the lifter sees
/// the win as it happens, without waiting for finish flow.
///
/// **Why a strict-greater heuristic on `weight × reps`:** the spec rejects
/// haptic, animation, and any other signal beyond gold pixels for this
/// chip. The chip is a visual receipt, not a bell. The simplest rule that
/// avoids both false-flash mid-keystroke and double-flash on identical
/// committed sets is strict-greater volume against:
///   1. Every prior completed working set in this workout for this exercise.
///   2. Every set in the prior session for this exercise (passed by the
///      caller — the parent already maintains [SetRow.lastSet] for the
///      previous-session hint).
///
/// **Why not consult [PRDetectionResult] directly:** that service is
/// session-finishing — it reads cached `pr_cache` rows and returns the
/// finished workout's actual records. Wiring it to the per-keystroke set
/// row would force a Hive read on every commit, plus it doesn't yet
/// support sub-workout queries. The heuristic is local, instant, and has
/// no downstream side-effects.
///
/// **False positives (acceptable):** the heuristic doesn't see lifetime
/// records — only this session + last session. A set that's a session-best
/// but not a lifetime PR will still light the chip. The user's mental
/// model is "this is my best of the day" which matches; the durable record
/// list in `/prs` remains the source of truth for lifetime PRs.
///
/// **False negatives (acceptable):** a brand-new exercise the user has
/// never done before will fire the chip on the first committed set, which
/// is correct; an exercise with last-session sets where no this-session
/// set beats them simply won't fire — also correct (it would be a lie).
bool isPrCandidateAfterCommit({
  required ExerciseSet set,
  required List<ExerciseSet> allSetsThisExercise,
  required List<ExerciseSet> lastWorkoutSets,
}) {
  // Gate 1: must be a committed working set with positive load.
  if (!set.isCompleted) return false;
  if (set.setType != SetType.working) return false;
  final weight = set.weight ?? 0;
  final reps = set.reps ?? 0;
  if (weight <= 0 || reps <= 0) return false;

  final committedVolume = weight * reps;

  // Gate 2: strict-greater than every other working-set rival in this
  // workout for this exercise. Exclude `set` itself so re-committing the
  // peak set doesn't disqualify it.
  for (final s in allSetsThisExercise) {
    if (s.id == set.id) continue;
    if (s.setType != SetType.working) continue;
    if (!s.isCompleted) continue;
    final w = s.weight ?? 0;
    final r = s.reps ?? 0;
    if (w <= 0 || r <= 0) continue;
    if (w * r >= committedVolume) return false;
  }

  // Gate 3: strict-greater than every prior-session set. The previous
  // session is passed in by the caller — the screen already maintains
  // `lastSets` for the per-row hint. We don't filter by setType here
  // because prior-session rows come from `getLastWorkoutSets` which is
  // already filtered to working sets server-side.
  for (final s in lastWorkoutSets) {
    final w = s.weight ?? 0;
    final r = s.reps ?? 0;
    if (w <= 0 || r <= 0) continue;
    if (w * r >= committedVolume) return false;
  }

  return true;
}
