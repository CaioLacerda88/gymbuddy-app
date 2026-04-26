import 'package:flutter/painting.dart';

import '../../../core/theme/app_theme.dart';

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
enum VitalityState {
  /// Vitality_peak == 0. Body part has never been trained; rune is silent
  /// and waiting for the first attributed set to awaken it.
  dormant,

  /// 1-30%. Conditioning lost — return to the path. Sigil renders at full
  /// opacity with a desaturated breathing-pulse halo.
  fading,

  /// 31-70%. Default "on the path" state. Static halo, attention-conserving.
  active,

  /// 71-100%. Peak conditioning. Sigil enlarged 10%, gold halo, sweep
  /// highlight cycle (~4-5s).
  radiant,
}

/// Mapping helpers for [VitalityState].
///
/// `fromVitality` collapses a continuous Vitality EWMA (0..100) into the four
/// discrete visual states per spec §8.4. `borderColor` is the canonical color
/// used by [RankStamp] borders, [RuneHalo] glows, and other consumers — kept
/// here so all four states share a single source of truth and palette drift
/// is impossible.
extension VitalityStateX on VitalityState {
  /// Color associated with this state — used for rank stamp borders, halo
  /// glow tints, and rune sigil tinting on body-part rows.
  Color get borderColor {
    switch (this) {
      case VitalityState.dormant:
        return AppColors.textDim;
      case VitalityState.fading:
        return AppColors.primaryViolet;
      case VitalityState.active:
        return AppColors.hotViolet;
      case VitalityState.radiant:
        // ignore: reward_accent — §8.4 Radiant IS the reward signal (peak conditioning). Sinks are CustomPainter Paint.color + Border.all + Paint().shader, none of which read IconTheme/DefaultTextStyle from a RewardAccent ancestor.
        return AppColors.heroGold;
    }
  }

  /// Map a Vitality % (0..100) plus the user's lifetime peak to a visual
  /// state. The peak is required because a never-trained body part (peak
  /// == 0) is Dormant regardless of its current EWMA — see spec §8.4.
  ///
  /// Bounds are inclusive on the lower side, exclusive on the upper:
  ///   * peak == 0       → Dormant ("Awaits your first stride")
  ///   * 0 < % ≤ 30      → Fading
  ///   * 30 < % ≤ 70     → Active
  ///   * 70 < % ≤ 100    → Radiant
  static VitalityState fromVitality({
    required double vitalityEwma,
    required double vitalityPeak,
  }) {
    if (vitalityPeak <= 0) return VitalityState.dormant;
    if (vitalityEwma <= 30) return VitalityState.fading;
    if (vitalityEwma <= 70) return VitalityState.active;
    return VitalityState.radiant;
  }
}
