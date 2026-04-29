-- =============================================================================
-- Phase 18e — Cross-build distinction titles retroactive backfill
-- Migration: 00043_cross_build_titles_backfill
--
-- Spec §10.3 introduces five cross-build distinction titles whose unlock
-- predicate is a structural property of the user's full body-part rank
-- distribution (not a single threshold crossing). The Dart-side detector
-- (`CrossBuildTitleEvaluator`) runs every workout-finish; existing users
-- need a one-shot backfill so a power user who already qualifies sees
-- their titles immediately on app update rather than after their next save.
--
-- WHAT THIS MIGRATION DOES:
--   1. Defines `evaluate_cross_build_titles_for_user(uuid)` — pure SQL function
--      that mirrors the five Dart predicates exactly. Used by the backfill
--      and available for future server-side detector ports.
--   2. Inserts cross-build slugs into `earned_titles` for every existing
--      user whose rank distribution satisfies a predicate. `is_active = false`
--      (we don't auto-equip — the celebration overlay or titles screen
--      handles that), `earned_at = now()` (the unlock moment is the backfill
--      timestamp; the original strength build was earned over time but the
--      catalog didn't exist before this phase).
--   3. Idempotent via `ON CONFLICT (user_id, title_id) DO NOTHING` — re-running
--      this migration is a no-op for already-seeded rows. Safe for replay.
--
-- WHY SQL IN THE MIGRATION (NOT A CLIENT BACKFILL):
--   * The Dart detector requires a workout-finish to fire — without a server
--     pre-seed, a user who never finishes a workout post-upgrade would never
--     see titles they already structurally qualify for.
--   * Backfilling client-side would require every device to do the same work
--     redundantly (and rely on the user opening the app). One migration run
--     covers every user atomically, including users who hot-rotate devices.
--   * The predicates are pure functions of body_part_progress.rank — Postgres
--     computes them in a single GROUP BY without any client round-trip.
--
-- BOUNDARY MIRROR WITH DART:
--   Every predicate in this file MUST mirror `CrossBuildTitleEvaluator` line
--   for line. Dart and SQL evaluate the same rank distribution to the same
--   slug set. If you change a predicate here, change it there in the same PR
--   (and add a test that pins the boundary). The slug values
--   (pillar_walker, broad_shouldered, even_handed, iron_bound, saga_forged)
--   are the dbValue tokens of CrossBuildTriggerId — forever-stable join keys
--   with `earned_titles.title_id`.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Helper function — pure SQL mirror of CrossBuildTitleEvaluator.evaluate
-- ---------------------------------------------------------------------------
--
-- Returns the set of cross-build slugs that fire for the given user's
-- current rank distribution. Cardio is intentionally excluded (v1 cardio
-- doesn't earn XP; the iron_bound predicate's cardio condition is a v2
-- concern). Missing body_part_progress rows default to rank 1 — this
-- matches `RpgProgressSnapshot.progressFor` and the resolver convention.
--
-- IMMUTABLE? No — it reads body_part_progress, so it's STABLE at best.
-- We mark it STABLE so the planner can cache within a query but not across
-- statements. PARALLEL SAFE because it only reads from RLS-isolated rows
-- and never writes.

CREATE OR REPLACE FUNCTION public.evaluate_cross_build_titles_for_user(p_user_id uuid)
RETURNS TABLE (slug text)
LANGUAGE plpgsql
STABLE
PARALLEL SAFE
AS $$
DECLARE
  v_chest      int;
  v_back       int;
  v_legs       int;
  v_shoulders  int;
  v_arms       int;
  v_core       int;
  v_max_rank   int;
  v_min_rank   int;
  v_spread     numeric;
BEGIN
  -- Project rank by body part. COALESCE to 1 for missing rows
  -- (the SQL default-row insert in record_set_xp creates rows lazily, so a
  -- user who has never trained a particular body part may have no row).
  SELECT
    COALESCE(MAX(CASE WHEN body_part = 'chest'     THEN rank END), 1),
    COALESCE(MAX(CASE WHEN body_part = 'back'      THEN rank END), 1),
    COALESCE(MAX(CASE WHEN body_part = 'legs'      THEN rank END), 1),
    COALESCE(MAX(CASE WHEN body_part = 'shoulders' THEN rank END), 1),
    COALESCE(MAX(CASE WHEN body_part = 'arms'      THEN rank END), 1),
    COALESCE(MAX(CASE WHEN body_part = 'core'      THEN rank END), 1)
  INTO v_chest, v_back, v_legs, v_shoulders, v_arms, v_core
  FROM public.body_part_progress
  WHERE user_id = p_user_id
    AND body_part IN ('chest', 'back', 'legs', 'shoulders', 'arms', 'core');

  -- pillar_walker: legs >= 40 AND legs >= 2 * arms
  IF v_legs >= 40 AND v_legs >= 2 * v_arms THEN
    slug := 'pillar_walker'; RETURN NEXT;
  END IF;

  -- broad_shouldered: chest+back+shoulders >= 2 * (legs+core)
  --                   AND chest >= 30 AND back >= 30 AND shoulders >= 30
  IF v_chest >= 30
     AND v_back >= 30
     AND v_shoulders >= 30
     AND (v_chest + v_back + v_shoulders) >= 2 * (v_legs + v_core) THEN
    slug := 'broad_shouldered'; RETURN NEXT;
  END IF;

  -- even_handed: every track >= 30 AND (max - min) / max <= 0.30
  --
  -- The min-rank-30 floor matches CrossBuildTitleEvaluator.evenHandedMinRank.
  -- The 0.30 spread matches CrossBuildTitleEvaluator.evenHandedSpreadFraction.
  -- Float division mirrors Dart's `(maxRank - minRank) / maxRank` semantics.
  IF v_chest >= 30
     AND v_back >= 30
     AND v_legs >= 30
     AND v_shoulders >= 30
     AND v_arms >= 30
     AND v_core >= 30 THEN
    v_max_rank := GREATEST(v_chest, v_back, v_legs, v_shoulders, v_arms, v_core);
    v_min_rank := LEAST(v_chest, v_back, v_legs, v_shoulders, v_arms, v_core);
    v_spread := (v_max_rank - v_min_rank)::numeric / v_max_rank::numeric;
    IF v_spread <= 0.30 THEN
      slug := 'even_handed'; RETURN NEXT;
    END IF;
  END IF;

  -- iron_bound: chest >= 60 AND back >= 60 AND legs >= 60
  -- (cardio condition deferred to v2)
  IF v_chest >= 60 AND v_back >= 60 AND v_legs >= 60 THEN
    slug := 'iron_bound'; RETURN NEXT;
  END IF;

  -- saga_forged: every active track >= 60
  IF v_chest >= 60
     AND v_back >= 60
     AND v_legs >= 60
     AND v_shoulders >= 60
     AND v_arms >= 60
     AND v_core >= 60 THEN
    slug := 'saga_forged'; RETURN NEXT;
  END IF;

  RETURN;
END;
$$;

GRANT EXECUTE ON FUNCTION public.evaluate_cross_build_titles_for_user(uuid)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- One-shot backfill — every existing user with body_part_progress rows
-- ---------------------------------------------------------------------------
--
-- For every distinct user with at least one body_part_progress row, evaluate
-- the cross-build predicates and insert any firing slugs into earned_titles.
-- ON CONFLICT DO NOTHING preserves the original earned_at on re-runs and
-- never overwrites a user-equipped title's is_active flag.
--
-- The seed-time earned_at = now() is intentional. The original strength
-- build was earned over many workouts, but the catalog didn't exist before
-- this migration — the unlock event is "this title became real for you,
-- right now." Future workouts that re-fire the predicate will hit the
-- detector's alreadyEarnedSlugs guard and not re-insert.

INSERT INTO public.earned_titles (user_id, title_id, earned_at, is_active)
SELECT
  u.user_id,
  cb.slug,
  now(),
  FALSE
FROM (
  SELECT DISTINCT user_id
  FROM public.body_part_progress
) u
CROSS JOIN LATERAL public.evaluate_cross_build_titles_for_user(u.user_id) cb
ON CONFLICT (user_id, title_id) DO NOTHING;

COMMIT;
