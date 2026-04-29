import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local_storage/hive_service.dart';
import '../data/xp_repository.dart';
import '../domain/xp_calculator.dart';
import '../models/xp_breakdown.dart';
import '../models/xp_state.dart';

/// DI seam for the XP repository.
final xpRepositoryProvider = Provider<XpRepository>((ref) {
  return XpRepository(Supabase.instance.client);
});

/// Async roll-up of the current user's XP state.
///
/// UI consumers (home LVL line, paywall personalization, character sheet)
/// watch this provider and re-render when the state changes. Writes that
/// award XP must `ref.invalidate(xpProvider)` — or, for the happy path,
/// drive through [XpNotifier.awardForWorkout] which updates state directly.
///
/// **Phase 18e shim status (kept-alive decision, 2026-04-29):**
///
/// The Phase 18a RPG system (`rpgProgressProvider.characterState.characterLevel`)
/// is the canonical source of character level for everything net-new in
/// Phase 18 (saga screen, class badge, title detection, celebration overlays).
/// The Phase 17b gamification XP system shipped this `xpProvider` AND the
/// `SagaIntroOverlay` consumer that reads it on first-run.
///
/// We're keeping the gamification feature dir intact in v1 because:
///
///   1. **`SagaIntroOverlay` still reads from this provider.** Migrating
///      it to read from `rpgProgressProvider.characterState` requires a
///      separate UI pass (different LVL mapping, different rank palette,
///      different copy beats). That work is scoped to v1.1+.
///   2. **The first-run retro backfill flag (`hasRunRetroForUser`) lives
///      here.** Phase 18a's `backfill_rpg_v1` reuses the same Hive key
///      pattern; if we delete this file, the cold-start gate breaks for
///      every existing v1 user who hasn't yet seen the post-18a re-launch.
///   3. **The `awardForWorkout` call from `ActiveWorkoutNotifier` is a
///      no-op for users on the new RPG flow** because the RPG XP path
///      (`record_set_xp` inside `save_workout`) is the canonical writer.
///      The gamification award is server-idempotent — duplicate writes
///      just update `gamification_xp_state` rows that nothing in the RPG
///      v1 UX reads after `SagaIntroOverlay` has been dismissed. Removing
///      the call site is safe but not blocking for v1.
///
/// Removal is tracked as a v1.1+ task: migrate `SagaIntroOverlay` to read
/// from `rpgProgressProvider`, then delete `lib/features/gamification/`.
final xpProvider = AsyncNotifierProvider<XpNotifier, GamificationSummary>(
  XpNotifier.new,
);

class XpNotifier extends AsyncNotifier<GamificationSummary> {
  XpRepository get _repo => ref.read(xpRepositoryProvider);

  @override
  Future<GamificationSummary> build() async {
    return _repo.getSummary();
  }

  /// Award XP for a workout and update local state immediately.
  ///
  /// Returns the new summary so callers (workout save path) can feed the
  /// 17a celebration overlay without a second read.
  ///
  /// Flow:
  ///   1. Optimistically compute the projected summary from the current
  ///      total + the breakdown total. Emit it so the UI reacts within one
  ///      frame. (500ms acceptance criterion, PLAN §17b.)
  ///   2. Fire the RPC. On success, adopt the server-returned snapshot.
  ///   3. On failure, revert to the pre-award state and rethrow — the
  ///      caller decides whether to surface a snackbar.
  Future<GamificationSummary> awardForWorkout({
    required String userId,
    required XpBreakdown breakdown,
    required String workoutId,
    String source = 'workout',
  }) async {
    final previous = state.value ?? GamificationSummary.empty;
    if (breakdown.total <= 0) return previous;

    final optimistic = GamificationSummary.fromTotal(
      previous.totalXp + breakdown.total,
    );
    state = AsyncData(optimistic);

    try {
      final server = await _repo.awardXp(
        userId: userId,
        breakdown: breakdown,
        source: source,
        workoutId: workoutId,
      );
      state = AsyncData(server);
      return server;
    } catch (e, st) {
      // Revert to the pre-award value so the UI doesn't show phantom XP.
      state = AsyncData(previous);
      // Rethrow lets the caller log / retry / enqueue offline.
      Error.throwWithStackTrace(e, st);
    }
  }

  /// Trigger the server-side retroactive backfill and refresh state.
  ///
  /// Callers should guard against repeat invocation via
  /// [hasRunRetroForUser]. The server is idempotent regardless, but an
  /// unnecessary round-trip on every cold start adds perceptible latency.
  Future<void> runRetroBackfill(String userId) async {
    await _repo.runRetroBackfill(userId);
    _markRetroComplete(userId);
    ref.invalidateSelf();
  }
}

// ---------------------------------------------------------------------------
// Local-only "has retro run?" flag
// ---------------------------------------------------------------------------
//
// Used by the app-startup gate to drive `backfill_rpg_v1` once per user per
// device. `backfill_rpg_v1` is a chunked function looped from the Dart driver
// in `XpRepository.runRetroBackfill` until `out_is_complete=true`. The
// server-side `backfill_progress.completed_at` checkpoint is the source of
// truth for correctness (a re-run on a completed user is a no-op); this
// flag exists only to avoid the cold-start round-trip.

const String _kRetroKeyPrefix = 'saga_retro_run:';
const String _kSagaIntroSeenPrefix = 'saga_intro_seen:';

/// Whether the retroactive backfill has already been triggered for [userId]
/// from this device.
bool hasRunRetroForUser(String userId) {
  final box = Hive.box<dynamic>(HiveService.userPrefs);
  return (box.get('$_kRetroKeyPrefix$userId') as bool?) ?? false;
}

void _markRetroComplete(String userId) {
  final box = Hive.box<dynamic>(HiveService.userPrefs);
  box.put('$_kRetroKeyPrefix$userId', true);
}

/// Whether the first-run [SagaIntroOverlay] has been dismissed for [userId].
bool hasSeenSagaIntroForUser(String userId) {
  final box = Hive.box<dynamic>(HiveService.userPrefs);
  return (box.get('$_kSagaIntroSeenPrefix$userId') as bool?) ?? false;
}

/// Persist that [userId] has dismissed the saga intro overlay.
///
/// `box.put` awaits the IndexedDB write (on Flutter Web) but the browser
/// can race a page-reload against the transaction. `box.flush()` forces the
/// write to complete before returning, ensuring the flag survives an
/// immediate restart (e.g., explicit page.reload in E2E tests or a rapid
/// app restart on mobile after tapping BEGIN).
Future<void> markSagaIntroSeenForUser(String userId) async {
  final box = Hive.box<dynamic>(HiveService.userPrefs);
  await box.put('$_kSagaIntroSeenPrefix$userId', true);
  await box.flush();
}

/// Convenience: the currently displayable level from the async state, or 1
/// when still loading. Useful for the home LVL badge placeholder.
int currentLevelOrDefault(AsyncValue<GamificationSummary> summary) {
  return summary.when(
    data: (s) => s.currentLevel,
    loading: () => 1,
    error: (_, _) => 1,
  );
}

/// Convenience: the currently displayable rank from the async state, or
/// [Rank.rookie] when still loading.
Rank currentRankOrDefault(AsyncValue<GamificationSummary> summary) {
  return summary.when(
    data: (s) => s.rank,
    loading: () => Rank.rookie,
    error: (_, _) => Rank.rookie,
  );
}
