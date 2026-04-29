import '../models/body_part.dart';
import '../models/body_part_progress.dart';
import '../models/celebration_event.dart';
import '../models/title.dart';
import '../providers/rpg_progress_provider.dart';
import 'title_unlock_detector.dart';

/// Pure builder that derives the post-finish [CelebrationEvent] list from the
/// pre/post [RpgProgressSnapshot] pair plus the title catalog.
///
/// **Why this lives in `domain/` instead of inlined into the notifier:** the
/// notifier owns side-effects — Hive saves, Supabase calls, analytics, route
/// transitions. Diff logic is pure: same inputs → same output, no `ref`, no
/// async, no IO. Keeping it pure means the orchestrator's tests can swap in
/// fixed snapshots without standing up a Riverpod container, and a future
/// refactor of the save flow can re-route the builder anywhere (e.g. an
/// offline-replay path that builds events from Hive on sync) without
/// rewriting the diff math.
///
/// **Boundary semantics (locked):**
///   * **Rank-up:** post.rank > pre.rank for a body part. Pre row missing is
///     treated as `rank=1, totalXp=0` (matches [RpgProgressSnapshot.progressFor]
///     and the SQL default-row shape).
///   * **Level-up:** post.characterLevel > pre.characterLevel. The
///     character-state view is canonical — we don't recompute levels client-side.
///   * **First-awakening:** a body part where pre had `totalXp == 0` (or no
///     row at all) AND post.totalXp > 0. Throttled to ONE event total per
///     `build` call — even if multiple body parts wake up in the same finish.
///     The notifier passes `suppressFirstAwakening: true` once the per-session
///     flag has fired, which fully suppresses the event for subsequent
///     finishes in the same session.
///   * **Title-unlock (per-body-part):** delegated to
///     [TitleUnlockDetector.detect] given the rank deltas and the pre-save
///     earned-slug set. Already-earned slugs are filtered by the detector.
///   * **Title-unlock (character-level):** delegated to
///     [TitleUnlockDetector.detectCharacterLevel] given the pre/post
///     character-level pair. Half-open interval semantics mirror the
///     per-body-part path.
///   * **Title-unlock (cross-build):** delegated to
///     [TitleUnlockDetector.detectCrossBuild] given the post-save rank
///     distribution. Predicate evaluation runs every finish (cheap, O(1));
///     idempotency via the same already-earned guard.
///
/// **Why first-awakening throttle is in the builder, not the queue:** the
/// queue applies a presentation-cap (3 visible overlays); the awakening
/// throttle is a **session-level invariant** owned by the orchestrator
/// (`ActiveWorkoutNotifier._firstAwakeningFiredThisSession`). The notifier
/// passes the flag in; the builder never decides to suppress on its own.
/// This keeps the builder honest: a unit test that produces two awakenings
/// in one snapshot transition deterministically gets the first one,
/// regardless of any sibling state the notifier happens to hold.
class CelebrationEventBuilder {
  const CelebrationEventBuilder._();

  /// Build the unordered event list from a pre/post snapshot pair.
  ///
  /// Output ordering is **builder-defined but deterministic**:
  /// rank-ups (in canonical [activeBodyParts] order) → level-up → titles
  /// (catalog order) → first-awakening last. [CelebrationQueue.build]
  /// re-orders into the playback canonical order; consumers should not
  /// depend on this list's ordering.
  static List<CelebrationEvent> build({
    required RpgProgressSnapshot pre,
    required RpgProgressSnapshot post,
    required List<Title> catalog,
    required Set<String> alreadyEarnedSlugs,
    required bool suppressFirstAwakening,
  }) {
    final events = <CelebrationEvent>[];

    // ---- Rank-ups + rank deltas (also fed into the title detector) ----
    final deltas = <RankDelta>[];
    for (final bodyPart in activeBodyParts) {
      final preRow = pre.byBodyPart[bodyPart];
      final postRow = post.byBodyPart[bodyPart];
      if (postRow == null) continue;
      final oldRank = preRow?.rank ?? 1;
      final newRank = postRow.rank;
      if (newRank > oldRank) {
        events.add(
          CelebrationEvent.rankUp(bodyPart: bodyPart, newRank: newRank),
        );
        deltas.add(
          RankDelta(bodyPart: bodyPart, oldRank: oldRank, newRank: newRank),
        );
      }
    }

    // ---- Character level-up (single, derived from character_state) ----
    if (post.characterState.characterLevel >
        pre.characterState.characterLevel) {
      events.add(
        CelebrationEvent.levelUp(newLevel: post.characterState.characterLevel),
      );
    }

    // ---- Title unlocks via the three detectors ----
    //
    // Order: per-body-part → character-level → cross-build. The
    // [CelebrationQueue] re-orders into the playback canonical order; this
    // sequence here is purely for diff stability (same inputs → same list).
    //
    // We grow [alreadyEarnedSlugs] as we go so a slug that fires on multiple
    // detectors doesn't double-emit. In practice this can't happen — every
    // catalog entry has a distinct slug regardless of variant — but the
    // belt-and-suspenders guard means a future catalog overlap is contained
    // at the builder rather than rippling into the queue.
    if (catalog.isNotEmpty) {
      final earnedSoFar = Set<String>.from(alreadyEarnedSlugs);

      // Per-body-part — only fires if the workout produced rank deltas.
      if (deltas.isNotEmpty) {
        final unlocked = TitleUnlockDetector.detect(
          deltas: deltas,
          alreadyEarnedSlugs: earnedSoFar,
          catalog: catalog,
        );
        for (final t in unlocked) {
          events.add(CelebrationEvent.titleUnlock(slug: t.slug));
          earnedSoFar.add(t.slug);
        }
      }

      // Character-level — only fires on a level-up. Reuses the level-up
      // boundary check above.
      final oldLevel = pre.characterState.characterLevel;
      final newLevel = post.characterState.characterLevel;
      if (newLevel > oldLevel) {
        final unlocked = TitleUnlockDetector.detectCharacterLevel(
          oldLevel: oldLevel,
          newLevel: newLevel,
          alreadyEarnedSlugs: earnedSoFar,
          catalog: catalog,
        );
        for (final t in unlocked) {
          events.add(CelebrationEvent.titleUnlock(slug: t.slug));
          earnedSoFar.add(t.slug);
        }
      }

      // Cross-build — runs every finish (predicates are O(1) and the
      // already-earned guard handles idempotency). Built from the post
      // snapshot's rank map to capture any structural threshold the
      // workout pushed the user across.
      final postRanks = <BodyPart, int>{
        for (final bp in activeBodyParts) bp: post.byBodyPart[bp]?.rank ?? 1,
      };
      final crossBuildUnlocked = TitleUnlockDetector.detectCrossBuild(
        rankMap: postRanks,
        alreadyEarnedSlugs: earnedSoFar,
        catalog: catalog,
      );
      for (final t in crossBuildUnlocked) {
        events.add(CelebrationEvent.titleUnlock(slug: t.slug));
        earnedSoFar.add(t.slug);
      }
    }

    // ---- First-awakening (at most one, throttled by the notifier flag) ----
    if (!suppressFirstAwakening) {
      for (final bodyPart in activeBodyParts) {
        final preRow = pre.byBodyPart[bodyPart];
        final postRow = post.byBodyPart[bodyPart];
        if (postRow == null) continue;
        final wasUntouched = preRow == null || _isUntouched(preRow);
        final isNowTouched = postRow.totalXp > 0;
        if (wasUntouched && isNowTouched) {
          events.add(CelebrationEvent.firstAwakening(bodyPart: bodyPart));
          break; // throttle: at most one awakening per finish
        }
      }
    }

    return events;
  }

  /// A body-part row is "untouched" when no XP has accrued. Rank can be 1
  /// for either an untouched row (default-row insert) or a barely-trained
  /// row (1 XP), but only `totalXp == 0` reliably indicates "fresh" since
  /// the rank ladder bottoms at 1.
  static bool _isUntouched(BodyPartProgress row) => row.totalXp <= 0;
}
