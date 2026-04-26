import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/data/base_repository.dart';
import '../models/xp_breakdown.dart';
import '../models/xp_state.dart';

/// Data-layer gateway for the user's XP roll-up.
///
/// **Phase 18a transitional shim:** the Phase 17b `user_xp` table and
/// `award_xp` / `retro_backfill_xp` RPCs were dropped in migration
/// `00040_rpg_system_v1`. The class is intentionally kept so the home/saga
/// surfaces (Phase 17 UI) keep rendering during the 18a → 18b transition.
/// The internal contract changed:
///
///   * [getSummary] now reads the `character_state` derived view and maps
///     `lifetime_xp` (sum of body-part XP across the six v1 strength
///     tracks) to `total_xp`. Level + rank are still computed client-side
///     by `GamificationSummary.fromTotal`.
///   * [awardXp] is a no-op. The server-side `record_set_xp` RPC (called
///     transitively from `save_workout`) already records XP per set, so
///     the post-save Dart award is redundant. The method is preserved so
///     `XpNotifier.awardForWorkout` keeps compiling; it returns a fresh
///     summary read from `character_state`.
///   * [runRetroBackfill] now invokes `backfill_rpg_v1(p_user_id)` (the
///     chunked procedure with advisory lock + checkpoint). Server-side
///     idempotent — re-runs replay any sets not yet processed.
///
/// **Why a shim and not a removal:** Phase 18a explicitly does not ship a
/// new UI surface. Removing `xpProvider` would break the home LVL line and
/// saga intro overlay until 18b. Re-pointing the same shape at the new
/// data keeps the running app stable through the transition.
class XpRepository extends BaseRepository {
  const XpRepository(this._client);

  final supabase.SupabaseClient _client;

  /// Read the caller's rolled-up XP state. Returns
  /// [GamificationSummary.empty] when the user has no `body_part_progress`
  /// rows yet (brand-new account, or pre-backfill).
  Future<GamificationSummary> getSummary() {
    return mapException(() async {
      final user = _client.auth.currentUser;
      if (user == null) return GamificationSummary.empty;

      // 18a: read the `character_state` view. RLS scopes to the caller, so
      // we don't need an explicit user filter.
      final row = await _client
          .from('character_state')
          .select('lifetime_xp')
          .maybeSingle();

      if (row == null) return GamificationSummary.empty;
      // lifetime_xp is numeric(14,2); coerce to int (the 17b LVL curve
      // operates on integer XP totals, and rounding to int loses < 1 XP).
      final totalXp = (row['lifetime_xp'] as num).toInt();
      return GamificationSummary.fromTotal(totalXp);
    });
  }

  /// **18a no-op.** The post-save Dart award path is preserved for the
  /// 17b LVL line / saga intro consumers, but the actual write happens
  /// inside `record_set_xp` (called from `save_workout` per set). This
  /// method just re-reads the post-save summary so the notifier's
  /// optimistic state can be reconciled with server truth.
  ///
  /// Parameters are accepted but ignored — they were the 17b `award_xp`
  /// RPC payload. Callers don't need to be updated; once 18b lands the
  /// new saga screen, the [XpNotifier.awardForWorkout] call site is
  /// removed entirely.
  Future<GamificationSummary> awardXp({
    required String userId,
    required XpBreakdown breakdown,
    required String source,
    String? workoutId,
  }) {
    return mapException(getSummary);
  }

  /// Kick the chunked retroactive backfill for [userId]. Idempotent
  /// server-side via the `xp_events(user_id, set_id)` UNIQUE INDEX —
  /// calling twice replays only sets that haven't already produced a
  /// row (idempotency-via-comparison, not idempotency-via-flag).
  ///
  /// 18a contract: `backfill_rpg_v1` is a chunked function that
  /// processes up to 500 sets per call and returns
  /// `(processed, total_processed, is_complete)`. We loop until
  /// `is_complete = true`. The full architecture is documented on
  /// `RpgRepository.runBackfill` — this shim mirrors that loop because
  /// the saga-intro-gate consumer doesn't yet hold an `RpgRepository`
  /// (that wiring lands in 18b alongside the new UI).
  Future<void> runRetroBackfill(String userId) {
    return mapException(() async {
      const maxIterations = 5000;
      for (var i = 0; i < maxIterations; i++) {
        final result = await _client.rpc(
          'backfill_rpg_v1',
          params: {'p_user_id': userId, 'p_chunk_size': 500},
        );
        final isComplete = _readIsComplete(result);
        if (isComplete) return;
      }
    });
  }

  bool _readIsComplete(dynamic result) {
    if (result is List && result.isNotEmpty) {
      final row = result.first as Map;
      return (row['out_is_complete'] as bool?) ?? false;
    }
    if (result is Map) {
      return (result['out_is_complete'] as bool?) ?? false;
    }
    return false;
  }
}
