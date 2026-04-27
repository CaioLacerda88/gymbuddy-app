// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

import 'body_part.dart';
import 'body_part_progress.dart';
import 'vitality_state.dart';

part 'character_sheet_state.freezed.dart';

/// Per-body-part roll-up consumed by the character sheet UI.
///
/// Composes the raw [BodyPartProgress] row with two derived display values:
///   * [vitalityState] — the four-state §8.4 visual collapse, computed from
///     `vitalityEwma` + `vitalityPeak` once at provider time so widgets don't
///     re-derive it per rebuild.
///   * [xpInRank] / [xpForNextRank] — slice of `total_xp` relative to the
///     current rank, used by the hairline progress marker. Zero on the
///     untrained state (rank 1, total_xp 0).
///
/// **Why a separate model from [BodyPartProgress]:** the row is the wire
/// shape persisted in `body_part_progress`; this is the UI shape. Keeping
/// them split lets the provider absorb the rank-curve lookup without bloating
/// the wire model with display-only fields, and the curve is free to change
/// in 18e without forcing a migration to the persisted row.
@freezed
abstract class BodyPartSheetEntry with _$BodyPartSheetEntry {
  const factory BodyPartSheetEntry({
    required BodyPart bodyPart,
    required int rank,
    required double vitalityEwma,
    required double vitalityPeak,
    required VitalityState vitalityState,
    required double xpInRank,
    required double xpForNextRank,
    required double totalXp,
  }) = _BodyPartSheetEntry;

  const BodyPartSheetEntry._();

  /// True when the body part has never been trained (peak == 0 and rank 1).
  /// The character-sheet UI compresses these rows into a thinner secondary
  /// zone per the §13.4 onboarding gate.
  bool get isUntrained => vitalityPeak <= 0 && rank <= 1 && totalXp <= 0;
}

/// Top-level state for the `/profile` (Saga) character sheet.
///
/// Consumers: [CharacterSheetScreen]. The screen renders header (level +
/// class + active title) → vitality radar → six body-part rows → dormant
/// cardio row → three codex nav rows. Each block reads exactly the fields
/// it needs from this state so a refresh of one body-part row doesn't tear
/// the rest.
///
/// `className` is nullable because Phase 18b ships with a stub class
/// provider that always returns null — the slot still renders, but with the
/// "The iron will name you." placeholder copy. Real class derivation lands
/// in 18e (spec §9.2).
@freezed
abstract class CharacterSheetState with _$CharacterSheetState {
  const factory CharacterSheetState({
    required int characterLevel,
    required double lifetimeXp,
    required List<BodyPartSheetEntry> bodyPartProgress,
    String? activeTitle,
    String? className,
  }) = _CharacterSheetState;

  const CharacterSheetState._();

  /// Day-0 user (no XP earned, all body parts dormant). Drives the
  /// onboarding gate copy on the character sheet.
  bool get isZeroHistory => lifetimeXp <= 0;

  /// Mean Vitality EWMA across active (rank > 1 OR peak > 0) body parts.
  /// Drives the rune halo state in the header. Falls back to 0 when no body
  /// parts have been touched, which collapses the halo to Dormant.
  double get meanActiveVitality {
    final active = bodyPartProgress.where(
      (e) => e.vitalityPeak > 0 || e.rank > 1,
    );
    if (active.isEmpty) return 0;
    final total = active.fold<double>(0, (sum, e) => sum + e.vitalityEwma);
    return total / active.length;
  }

  /// Vitality state of the rune halo — derived from the mean Vitality across
  /// active body parts. Day-0 collapses to Dormant; a fresh first set
  /// awakens it to Fading or Active depending on volume.
  VitalityState get haloState {
    if (isZeroHistory) return VitalityState.dormant;
    final hasAnyPeak = bodyPartProgress.any((e) => e.vitalityPeak > 0);
    return VitalityStateX.fromVitality(
      vitalityEwma: meanActiveVitality,
      vitalityPeak: hasAnyPeak ? 1 : 0,
    );
  }
}
