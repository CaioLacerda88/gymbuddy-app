import 'package:flutter/painting.dart';

import '../domain/vitality_state_mapper.dart';

/// Visual state of a body-part's rune sigil, derived from Vitality %.
///
/// Per design spec §8.4, Vitality % is **never displayed as a number on the
/// primary character sheet** — it drives the rune's visual state instead.
/// The thresholds below are the canonical contract: Dormant for never-trained
/// (peak == 0), Fading for stepped-off-the-path conditioning, Active for the
/// default "on the path" state, Radiant for peak conditioning.
///
/// The Stats Deep-Dive screen (Phase 18d, §13.3) is the only surface that
/// shows the underlying numeric percentage.
///
/// **State derivation lives in [VitalityStateMapper].** This file owns only
/// the enum + a back-compat extension that delegates. New code should
/// import [VitalityStateMapper] directly and call `fromPercent` /
/// `fromVitality` on it.
enum VitalityState {
  /// Vitality_peak == 0. Body part has never been trained; rune is silent
  /// and waiting for the first attributed set to awaken it.
  dormant,

  /// 1-30% of permanent peak. Conditioning lost — return to the path.
  /// Sigil renders at full opacity with a desaturated breathing-pulse halo.
  fading,

  /// 31-70% of permanent peak. Default "on the path" state. Static halo,
  /// attention-conserving.
  active,

  /// 71-100% of permanent peak. Peak conditioning. Sigil enlarged 10%, gold
  /// halo, sweep highlight cycle (~4-5s).
  radiant,
}

/// Compatibility shim around [VitalityStateMapper] — preserves the existing
/// `state.borderColor` / `VitalityStateX.fromVitality(...)` call shape used
/// by character_sheet_state.dart, character_sheet_provider.dart, and the
/// existing widget/unit tests. New code should use [VitalityStateMapper]
/// directly.
extension VitalityStateX on VitalityState {
  /// Color associated with this state — delegates to
  /// [VitalityStateMapper.borderColorFor] so all surfaces (rank stamp,
  /// rune halo, vitality radar vertex dots, xp progress hairline) share a
  /// single palette source of truth.
  Color get borderColor => VitalityStateMapper.borderColorFor(this);

  /// Map a raw Vitality EWMA + permanent peak to a visual state.
  ///
  /// Delegates to [VitalityStateMapper.fromVitality] which normalises to
  /// the percentage `clamp(ewma / peak, 0, 1)` first and then dispatches
  /// to the §8.4 boundary thresholds. Boundary semantics:
  ///
  ///   * `peak == 0`              → Dormant ("Awaits your first stride")
  ///   * `0 < pct ≤ 0.30`         → Fading
  ///   * `0.30 < pct ≤ 0.70`      → Active
  ///   * `0.70 < pct ≤ 1.0`       → Radiant
  ///
  /// `ewma == 0` with `peak > 0` (fully decayed) still computes
  /// `pct = 0/peak = 0` and falls into Dormant — matches spec §8.4
  /// "fully fallen off the path" case (a body part you trained once and
  /// have completely lost conditioning on).
  static VitalityState fromVitality({
    required double vitalityEwma,
    required double vitalityPeak,
  }) =>
      VitalityStateMapper.fromVitality(ewma: vitalityEwma, peak: vitalityPeak);
}
