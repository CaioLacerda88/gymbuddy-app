import 'dart:math' as math;

/// Vitality EWMA (spec §8).
///
/// Asymmetric exponentially-weighted moving average on weekly volume per
/// body part. Rebuilds fast (τ_up = 14 days), decays slow (τ_down = 42 days)
/// — empirically grounded in myonuclear retention literature
/// (Bruusgaard 2010, Seaborne 2018, Psilander 2019).
///
/// **τ is in days** in the spec. The Python sim works in weeks because the
/// driver runs weekly (`-1 / 2.0` weeks ≡ `-7 / 14.0` days — the same α).
/// We store the raw τ in days to keep the unit-conversion site explicit
/// and to make a future per-day driver (Phase 18d) a constant swap.
///
/// All formulas operate on **weekly volume aggregates** (sum of
/// `attribution[bp] × volume_load` over the past 7 days). The driver layer
/// in Phase 18d schedules a daily run; this calculator is unit-independent
/// — it does the math, not the scheduling.
class VitalityCalculator {
  const VitalityCalculator._();

  /// τ_up in days — rebuild time constant. ~2 weeks.
  static const double tauUpDays = 14.0;

  /// τ_down in days — decay time constant. ~6 weeks.
  static const double tauDownDays = 42.0;

  /// Sample period for the alphas — the cadence the EWMA is updated at.
  /// Default is weekly because that matches both the rolling weekly-volume
  /// window and the spec §8.1 derivation. The driver in 18d will pass a
  /// 7-day step.
  static const double samplePeriodDays = 7.0;

  /// `α_up = 1 - exp(-Δt / τ_up)` where Δt is one sample period.
  /// At Δt=7d, τ_up=14d → α_up ≈ 0.3935.
  static double get alphaUp => 1.0 - math.exp(-samplePeriodDays / tauUpDays);

  /// `α_down = 1 - exp(-Δt / τ_down)` where Δt is one sample period.
  /// At Δt=7d, τ_down=42d → α_down ≈ 0.1535.
  static double get alphaDown =>
      1.0 - math.exp(-samplePeriodDays / tauDownDays);

  /// Single-step EWMA update.
  ///
  /// - If the new weekly volume meets or exceeds the prior EWMA, use
  ///   [alphaUp] (rebuild fast).
  /// - Otherwise use [alphaDown] (decay slow).
  ///
  /// Peak is permanent — never decays. Returns the new (ewma, peak) pair;
  /// caller persists.
  static VitalityState step({
    required double priorEwma,
    required double priorPeak,
    required double weeklyVolume,
  }) {
    final alpha = weeklyVolume >= priorEwma ? alphaUp : alphaDown;
    final newEwma = alpha * weeklyVolume + (1.0 - alpha) * priorEwma;
    final newPeak = newEwma > priorPeak ? newEwma : priorPeak;
    return VitalityState(ewma: newEwma, peak: newPeak);
  }

  /// `Vitality_pct = clamp(ewma / peak, 0, 1)`.
  ///
  /// When peak is zero (untrained body part), returns 0 — the rune is
  /// dormant and there is no meaningful ratio.
  static double percentage({required double ewma, required double peak}) {
    if (peak <= 0) return 0;
    final p = ewma / peak;
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p;
  }
}

/// Snapshot of EWMA + peak after one update step. Plain value class — not
/// persisted directly; the repository UPSERTs the two columns on
/// `body_part_progress`.
class VitalityState {
  const VitalityState({required this.ewma, required this.peak});

  final double ewma;
  final double peak;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VitalityState && other.ewma == ewma && other.peak == peak);

  @override
  int get hashCode => Object.hash(ewma, peak);

  @override
  String toString() => 'VitalityState(ewma: $ewma, peak: $peak)';
}
