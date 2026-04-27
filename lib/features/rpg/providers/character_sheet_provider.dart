import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/rank_curve.dart';
import '../models/body_part.dart';
import '../models/body_part_progress.dart';
import '../models/character_sheet_state.dart';
import '../models/vitality_state.dart';
import 'active_title_provider.dart';
import 'class_provider.dart';
import 'rpg_progress_provider.dart';

/// Composed character-sheet snapshot — derived from
/// [rpgProgressProvider] (server data) + [activeTitleProvider] (Phase 18c
/// stub) + [characterClassProvider] (Phase 18e stub).
///
/// **Composition direction.** This provider depends on three lower-level
/// providers. None of them depend on it. UI consumers watch this single
/// provider and read a fully-derived [CharacterSheetState] — no widget
/// recomputes the rank slice, vitality state, or class label. Idempotent:
/// re-evaluating with the same inputs produces the same state.
///
/// **Why `Provider` not `AsyncNotifier`:** the heavy lifting (network +
/// DB reads) lives in [rpgProgressProvider]; this layer is a pure
/// transform. Wrapping it in an AsyncNotifier would force a redundant
/// loading state on every rank-curve recompute. Instead we return
/// `AsyncValue<CharacterSheetState>` directly, propagating the upstream
/// async state with `.whenData`.
///
/// **Day-0 fallback:** when no body-part progress rows exist server-side,
/// the upstream provider yields the canonical empty snapshot. This
/// transform expands it into six placeholder entries (rank 1, 0 XP,
/// Dormant) so the UI iterates a fixed-length list instead of branching
/// on emptiness.
final characterSheetProvider = Provider<AsyncValue<CharacterSheetState>>((ref) {
  final progressAsync = ref.watch(rpgProgressProvider);
  final activeTitle = ref.watch(activeTitleProvider);
  final className = ref.watch(characterClassProvider);

  return progressAsync.whenData((snapshot) {
    return _composeSheet(
      snapshot: snapshot,
      activeTitle: activeTitle,
      className: className,
    );
  });
});

/// Pure transform from upstream data → UI shape. Extracted so unit tests
/// can pin the rank-curve math without spinning up a ProviderContainer.
CharacterSheetState _composeSheet({
  required RpgProgressSnapshot snapshot,
  required String? activeTitle,
  required String? className,
}) {
  final entries = activeBodyParts
      .map((bodyPart) {
        final progress = snapshot.progressFor(bodyPart);
        return _entryFor(progress);
      })
      .toList(growable: false);

  return CharacterSheetState(
    characterLevel: snapshot.characterState.characterLevel,
    lifetimeXp: snapshot.characterState.lifetimeXp,
    bodyPartProgress: entries,
    activeTitle: activeTitle,
    className: className,
  );
}

/// Fold a single [BodyPartProgress] row into a [BodyPartSheetEntry] —
/// adds the §8.4 vitality state collapse and the rank-curve XP slice.
BodyPartSheetEntry _entryFor(BodyPartProgress progress) {
  final rank = progress.rank;
  final totalXp = progress.totalXp;
  final xpInRank = RankCurve.xpInRank(totalXp, rank);
  final xpForNextRank = rank >= RankCurve.maxRank
      ? 0.0
      : RankCurve.xpToNext(rank);

  final vitalityState = VitalityStateX.fromVitality(
    vitalityEwma: progress.vitalityEwma,
    vitalityPeak: progress.vitalityPeak,
  );

  return BodyPartSheetEntry(
    bodyPart: progress.bodyPart,
    rank: rank,
    vitalityEwma: progress.vitalityEwma,
    vitalityPeak: progress.vitalityPeak,
    vitalityState: vitalityState,
    xpInRank: xpInRank,
    xpForNextRank: xpForNextRank,
    totalXp: totalXp,
  );
}
