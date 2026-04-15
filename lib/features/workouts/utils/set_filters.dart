import '../models/exercise_set.dart';
import '../models/set_type.dart';

/// Shared predicate: a completed working set with a positive rep count.
///
/// A set counts as a "real" logged effort — eligible for PR detection and
/// progress-over-time charts — when ALL of these hold:
///
/// - `setType == SetType.working` (excludes warmup, dropset, failure)
/// - `isCompleted == true` (user actually ticked it off)
/// - `reps != null && reps > 0` (a zero-rep set is noise)
///
/// Extracted from `PRDetectionService` so the chart and PR detection share
/// one source of truth. Changing the predicate in one place must affect the
/// other — otherwise the two features can drift (e.g. chart includes warmup
/// sets that PR detection ignores, leading to a "PR" value lower than the
/// chart's visible peak).
bool isCompletedWorkingSet(ExerciseSet set) {
  return set.setType == SetType.working &&
      set.isCompleted &&
      (set.reps ?? 0) > 0;
}

/// Returns only the completed working sets from [sets].
///
/// Convenience wrapper around [isCompletedWorkingSet] for the common case of
/// filtering a list.
List<ExerciseSet> completedWorkingSets(Iterable<ExerciseSet> sets) {
  return sets.where(isCompletedWorkingSet).toList();
}
