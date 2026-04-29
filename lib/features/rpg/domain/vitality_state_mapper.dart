import 'package:flutter/painting.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../models/body_part.dart';
import '../models/vitality_state.dart';
// Hide the legacy `VitalityState` data class — `VitalityCalculator.step`
// returns it, but this mapper deals exclusively with the four-state enum
// from models/vitality_state.dart. Keeping the calculator's class name as
// VitalityState (rather than renaming it) avoids churn across §8.1 sites.
import 'vitality_calculator.dart' show VitalityCalculator;

/// Single source of truth for everything Vitality-visual.
///
/// Phase 18d Stage 2 — collapses the §8.4 percentage thresholds, the
/// per-state palette, the per-body-part chart-line palette, and the
/// per-state copy keys into one class. Every consumer (rune halo, rank
/// stamp, body-part row, xp progress hairline, vitality radar, future
/// stats deep-dive table + chart + peak-loads list) reads from here.
///
/// **Why a single mapper:** the UX critic flagged that introducing a new
/// "color this body part" surface (the stats deep-dive chart in Stage 3)
/// without locking the body-part-to-color assignment in one place would
/// inevitably cause drift — chart line cyan, halo dot purple, progress
/// bar orange, the same body part wearing three colors. Locking the map
/// once here eliminates that class of bug structurally.
///
/// **Boundary semantics (spec §8.4):**
///   * `peak == 0`           → `dormant` ("Awaits your first stride")
///   * `0 < pct ≤ 0.30`      → `fading`  ("Conditioning lost — return…")
///   * `0.30 < pct ≤ 0.70`   → `active`  ("On the path")
///   * `0.70 < pct ≤ 1.0`    → `radiant` ("Path mastered")
///
/// `pct` is `clamp(ewma / peak, 0, 1)` — see [VitalityCalculator.percentage].
///
/// Why this lives in `domain/` and not `models/`: the boundary logic is a
/// state-derivation rule, not a data shape. The enum itself stays in
/// `models/vitality_state.dart` so existing call sites (10+ files) keep
/// their current import — this class just centralises the rules they all
/// rely on. The compatibility shim in `VitalityStateX.fromVitality`
/// delegates here.
class VitalityStateMapper {
  const VitalityStateMapper._();

  /// Boundary at which fading transitions to active (inclusive lower).
  /// Spec §8.4: 1-30% maps to Fading.
  static const double fadingMaxPct = 0.30;

  /// Boundary at which active transitions to radiant (inclusive lower).
  /// Spec §8.4: 31-70% maps to Active.
  static const double activeMaxPct = 0.70;

  /// Map a Vitality percentage (0..1) to the four-state §8.4 collapse.
  ///
  /// `pct == 0` is the dormant boundary — peak hasn't been established or
  /// EWMA fully decayed to zero. `pct > 1.0` is clamped to radiant (a guard
  /// against floating-point overshoot from numeric(14,4) round-trips).
  ///
  /// Boundary inclusivity matches spec §8.4:
  ///   * `pct = 0`     → dormant
  ///   * `pct = 0.30`  → fading  (right-edge inclusive)
  ///   * `pct = 0.70`  → active  (right-edge inclusive)
  ///   * `pct = 1.00`  → radiant
  static VitalityState fromPercent(double pct) {
    if (pct <= 0) return VitalityState.dormant;
    if (pct <= fadingMaxPct) return VitalityState.fading;
    if (pct <= activeMaxPct) return VitalityState.active;
    return VitalityState.radiant;
  }

  /// Map raw EWMA + peak to a state, normalising via
  /// [VitalityCalculator.percentage] first.
  ///
  /// `peak <= 0` always returns dormant — a body part with no recorded peak
  /// has never been trained, regardless of its current EWMA. This handles
  /// the day-1 user (peak == 0, ewma == 0) and protects against divide-by-
  /// zero in the percentage helper.
  ///
  /// Note: this replaces the latent bug in the original
  /// `VitalityStateX.fromVitality` which compared raw EWMA against literal
  /// 30/70 — that semantics treated EWMA as if it were already a 0..100
  /// percentage, but EWMA in `body_part_progress` is volume-derived (often
  /// thousands). The bug was masked because the 18a `record_set_xp`
  /// function never updated `vitality_ewma` (always 0). Once the 18d
  /// nightly job populates EWMA correctly, this percentage-based mapper is
  /// the only correct semantics.
  static VitalityState fromVitality({
    required double ewma,
    required double peak,
  }) {
    if (peak <= 0) return VitalityState.dormant;
    return fromPercent(VitalityCalculator.percentage(ewma: ewma, peak: peak));
  }

  // ---------------------------------------------------------------------------
  // Per-state colors (the rune-glow palette, locked to AppTheme tokens)
  // ---------------------------------------------------------------------------

  /// Stamp/border tint per state — used by [RankStamp] borders, the
  /// vitality-radar vertex dots, and the §13.3 stats-table state chip.
  ///
  /// Choices (per AppTheme palette):
  ///   * `dormant` → [AppColors.textDim] — cold, ash-gray; the rune is silent.
  ///   * `fading`  → [AppColors.primaryViolet] — the "lost path" tone, present
  ///                 but not loud.
  ///   * `active`  → [AppColors.hotViolet] — the default brand-bright violet,
  ///                 the rune at rest "on the path".
  ///   * `radiant` → [AppColors.heroGold] — the reward-only token, peak
  ///                 conditioning. Rendered through `RewardAccent` at the
  ///                 widget-tree level (see `lib/core/theme/README.md`).
  static Color borderColorFor(VitalityState s) {
    switch (s) {
      case VitalityState.dormant:
        return AppColors.textDim;
      case VitalityState.fading:
        return AppColors.primaryViolet;
      case VitalityState.active:
        return AppColors.hotViolet;
      case VitalityState.radiant:
        // §8.4 Radiant IS the reward signal (peak conditioning). Sinks are
        // CustomPainter Paint.color + Border.all + Paint().shader, none of
        // which read IconTheme/DefaultTextStyle from a RewardAccent
        // ancestor — so the widget-tree contract cannot apply here.
        // ignore: reward_accent — see comment above; structurally impossible to wrap painter sinks in RewardAccent
        return AppColors.heroGold;
    }
  }

  /// Halo glow tint per state. For most states this is the same as the
  /// border color (single source of truth for the rune palette); the
  /// indirection exists so a future design pass can split halo vs border
  /// without touching every consumer.
  static Color haloColorFor(VitalityState s) => borderColorFor(s);

  /// Progress-bar fill color per state. Hairlines and full progress bars
  /// alike use this — not the body-part color — because the progress bar
  /// communicates "current conditioning state" (a temporal signal) rather
  /// than "which body part" (an identity signal). Identity is conveyed by
  /// the row position + sigil; conditioning is conveyed by the color ramp.
  static Color progressBarColorFor(VitalityState s) => borderColorFor(s);

  // ---------------------------------------------------------------------------
  // Per-body-part chart palette (locked once)
  // ---------------------------------------------------------------------------

  /// Body-part → chart line / sigil tint when the surface needs to convey
  /// **which body part** rather than **which conditioning state**.
  ///
  /// Lock contract (UI-critic note): every surface that draws a per-body-
  /// part visual differentiation reads from this map. The §13.3 stats
  /// deep-dive trend chart (Stage 3), the future per-body-part history
  /// graph, and any "all six body parts at a glance" surface MUST consume
  /// these colors. Introducing a second source = inevitable drift across
  /// surfaces.
  ///
  /// Color choices (from AppTheme palette + spec §3 metaphors):
  ///   * `chest`     → [AppColors.hotViolet]    — bright primary, anchors the
  ///                   pressing identity at the top of the radar.
  ///   * `back`      → [AppColors.primaryViolet]— deep base violet, the
  ///                   pulling foundation that mirrors chest across the body.
  ///   * `legs`      → [AppColors.success]      — the green of foundation /
  ///                   ground-stride; lower-body roots the saga.
  ///   * `shoulders` → [AppColors.warning]      — warm yellow-amber, the
  ///                   "yoke" / overhead reach distinct from heroGold.
  ///   * `arms`      → [AppColors.error]        — red of the sinew; arms are
  ///                   the visible specialist rank (§9.1 Berserker).
  ///   * `core`      → [AppColors.textDim]      — neutral spine tone; core
  ///                   stabilises but doesn't lead the eye.
  ///   * `cardio`    → [AppColors.hair]         — muted hairline; v2 track,
  ///                   intentionally desaturated until earnable.
  ///
  /// `heroGold` is intentionally NOT in this map — it stays scarce as the
  /// reward token reserved for the `radiant` state and §13.2 rank-up
  /// celebrations.
  static const Map<BodyPart, Color> bodyPartColor = {
    BodyPart.chest: AppColors.hotViolet,
    BodyPart.back: AppColors.primaryViolet,
    BodyPart.legs: AppColors.success,
    BodyPart.shoulders: AppColors.warning,
    BodyPart.arms: AppColors.error,
    BodyPart.core: AppColors.textDim,
    BodyPart.cardio: AppColors.hair,
  };

  // ---------------------------------------------------------------------------
  // Localized copy (l10n)
  // ---------------------------------------------------------------------------

  /// Returns the localized marginalia copy line for [state] per spec §8.4 +
  /// §13.3. These copy lines render ONLY on the stats deep-dive screen —
  /// the character sheet stays number-free and copy-free, the rune state
  /// alone is the signal there.
  ///
  /// **Single source of truth.** This mapper owns the
  /// [VitalityState] → [AppLocalizations] string association; consumers
  /// just provide the [AppLocalizations] instance from their `BuildContext`
  /// (e.g. `AppLocalizations.of(context)!`). We deliberately do NOT return
  /// a raw key string — `AppLocalizations` (Flutter gen-l10n) has no
  /// runtime key-lookup API, so a key-returning helper would force every
  /// consumer to write a second switch from key back to getter, defeating
  /// the centralisation goal.
  static String localizedCopy(VitalityState state, AppLocalizations l10n) {
    switch (state) {
      case VitalityState.dormant:
        return l10n.vitalityCopyDormant;
      case VitalityState.fading:
        return l10n.vitalityCopyFading;
      case VitalityState.active:
        return l10n.vitalityCopyActive;
      case VitalityState.radiant:
        return l10n.vitalityCopyRadiant;
    }
  }
}
