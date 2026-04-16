import '../../workouts/models/exercise_set.dart';
import '../../workouts/utils/set_filters.dart';

/// Estimated one-rep max using the Epley formula: `weight × (1 + reps/30)`.
///
/// This is the primary strength metric for the progress chart — it normalizes
/// across rep ranges so a 5×5 → 3×10 programming switch doesn't show a
/// misleading line drop. Same formula used by Strong, Hevy, and most serious
/// lifting apps.
///
/// Returns `0` for any invalid input (non-positive weight or reps) — upstream
/// consumers should already be filtering via [isCompletedWorkingSet], but the
/// guard here keeps callers honest and prevents negative/NaN propagation into
/// chart rendering.
double e1RM(double weight, int reps) {
  if (weight <= 0 || reps <= 0) return 0;
  return weight * (1 + reps / 30);
}

/// Maximum [e1RM] across completed working sets in [sets].
///
/// Uses [isCompletedWorkingSet] so warmup / dropset / failure / incomplete
/// sets are excluded — same predicate as PR detection and the raw-weight
/// chart series. Empty list (or all sets disqualified) returns `0`.
double peakE1Rm(List<ExerciseSet> sets) {
  double peak = 0;
  for (final set in sets) {
    if (!isCompletedWorkingSet(set)) continue;
    final weight = set.weight ?? 0;
    if (weight <= 0) continue;
    final reps = set.reps ?? 0;
    final value = e1RM(weight, reps);
    if (value > peak) peak = value;
  }
  return peak;
}

/// Conversion factor from kilograms to pounds (1 kg ≈ 2.20462 lb).
///
/// Kept as a module-level constant so conversion logic is centralized and the
/// same rounding applies whether the chart is rendering an axis label or the
/// PR card is showing a summary number.
const double _kgPerLb = 2.20462;

/// Convert kilograms to pounds.
double kgToLb(double kg) => kg * _kgPerLb;

/// Convert pounds to kilograms.
double lbToKg(double lb) => lb / _kgPerLb;
