import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/data/base_repository.dart';
import '../models/xp_breakdown.dart';
import '../models/xp_state.dart';

/// Data-layer gateway for the Phase 17b XP tables.
///
/// Exposes three operations the rest of the app needs:
///
///   * [getSummary]       — read the current user's roll-up, returned as a
///                          UI-shaped [GamificationSummary]. Missing row =
///                          brand-new user, returns [GamificationSummary.empty].
///   * [awardXp]          — write a single XP event via the `award_xp` RPC
///                          and return the freshly rolled-up summary.
///   * [runRetroBackfill] — invoke `retro_backfill_xp(p_user_id)` once per
///                          user. Idempotent server-side.
///
/// No business logic lives here — volume/intensity/PR math is the
/// calculator's job. The repository only translates between typed models
/// and Supabase call shapes.
class XpRepository extends BaseRepository {
  const XpRepository(this._client);

  final supabase.SupabaseClient _client;

  /// Read the caller's rolled-up XP state. Returns
  /// [GamificationSummary.empty] when no row exists yet.
  Future<GamificationSummary> getSummary() {
    return mapException(() async {
      final user = _client.auth.currentUser;
      if (user == null) return GamificationSummary.empty;

      final row = await _client
          .from('user_xp')
          .select('total_xp')
          .eq('user_id', user.id)
          .maybeSingle();

      if (row == null) return GamificationSummary.empty;
      final totalXp = (row['total_xp'] as num).toInt();
      // We intentionally recompute level + rank client-side from totalXp
      // rather than reading the server snapshot. This keeps the curve /
      // threshold tuning source-of-truth in Dart (XpCalculator) so future
      // retunes ship without a DB migration. See PLAN.md §17b.
      return GamificationSummary.fromTotal(totalXp);
    });
  }

  /// Award XP for a finished workout. Returns the fresh summary computed
  /// from the server-returned `total_xp`.
  ///
  /// [workoutId] is the workout that produced the award, or null for
  /// non-workout sources (future quest/milestone awards from 17e/17d).
  /// [source] must be one of the tokens the migration's CHECK enforces:
  /// `workout`, `pr`, `quest`, `comeback`, `milestone`, `retro`.
  ///
  /// The breakdown jsonb carries the component decomposition plus the
  /// client-computed `level` + `rank` snapshot so the server can store
  /// them without re-running the curve.
  Future<GamificationSummary> awardXp({
    required String userId,
    required XpBreakdown breakdown,
    required String source,
    String? workoutId,
  }) {
    return mapException(() async {
      if (breakdown.total <= 0) {
        // No points to award — the RPC's `amount > 0` CHECK would reject
        // the insert anyway. Return the current summary so callers can
        // treat every awardXp() invocation as "fresh state after save".
        return getSummary();
      }

      final projected = GamificationSummary.fromTotal(
        // Read fresh before awarding so the level snapshot encodes the
        // *post-award* total. Single round-trip is acceptable for 17b;
        // 17d will cache aggressively.
        (await getSummary()).totalXp + breakdown.total,
      );

      final payload = <String, dynamic>{
        ...breakdown.toJson(),
        // Client snapshot fields award_xp reads via p_breakdown->>.
        'level': projected.currentLevel,
        'rank': projected.rank.dbValue,
      };

      await _client.rpc(
        'award_xp',
        params: {
          'p_user_id': userId,
          'p_workout_id': workoutId,
          'p_amount': breakdown.total,
          'p_source': source,
          'p_breakdown': payload,
        },
      );

      return projected;
    });
  }

  /// Kick the server-side retroactive backfill for [userId]. Idempotent
  /// server-side (keyed by `(user_id, workout_id, source='retro')`).
  Future<void> runRetroBackfill(String userId) {
    return mapException(() async {
      await _client.rpc('retro_backfill_xp', params: {'p_user_id': userId});
    });
  }
}
