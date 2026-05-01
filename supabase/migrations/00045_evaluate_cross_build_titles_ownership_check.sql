-- =============================================================================
-- Cluster 7 — DB integrity (BUG-030)
-- Migration: 00045_evaluate_cross_build_titles_ownership_check
--
-- Adds an ownership check to `evaluate_cross_build_titles_for_user(p_user_id)`.
-- The function was originally introduced in 00043 with EXECUTE granted to
-- `authenticated`, but it accepts an arbitrary `p_user_id` and reads from
-- `body_part_progress` without verifying that the caller owns the row set.
--
-- Although no current UI exposes another user's data, the function is
-- callable from any authenticated session via PostgREST RPC. Locking the
-- ownership boundary down before any social surface ships avoids a future
-- footgun (cross-user rank distribution leak via the returned slug list).
--
-- Approach: CREATE OR REPLACE the function with the exact same body, but
-- gate entry on `auth.uid() = p_user_id`. We preserve:
--   * Return type: TABLE (slug text)
--   * Volatility: STABLE
--   * Parallelism: PARALLEL SAFE
--   * Language: plpgsql
--
-- We intentionally do NOT mark the function SECURITY DEFINER. The original
-- relied on RLS on body_part_progress + the caller's own credentials, and
-- the ownership check below preserves that contract.
--
-- Idempotent: CREATE OR REPLACE overwrites the existing definition. Re-runs
-- are no-ops (function body is identical post-migration).
--
-- NOTE: Supabase CLI wraps every migration file in an implicit transaction;
-- adding our own BEGIN/COMMIT here would nest transactions. (Same comment
-- as 00043.)
-- =============================================================================

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
  -- Ownership check (BUG-030).
  -- Reject any AUTHENTICATED caller whose auth.uid() does not match
  -- p_user_id. Sessions where auth.uid() is NULL — i.e., service_role,
  -- postgres role, pg_cron jobs, future server-side detectors — are
  -- intentionally allowed through. Those execution contexts have already
  -- been authenticated at the infrastructure layer (DB role gating, JWT
  -- service-role claim) and have legitimate cross-user reasons to invoke
  -- this function (recompute, backfill, audit). The rejection is targeted
  -- at the only attack surface that exists today: an authenticated end
  -- user passing some other user's UUID via PostgREST.
  IF auth.uid() IS NOT NULL AND auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'unauthorized: caller does not own p_user_id'
      USING ERRCODE = '42501';
  END IF;

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

-- Re-grant EXECUTE so post-replace permissions match the original 00043 grant.
-- service_role retains access for any future server-side detector that runs
-- with elevated credentials (it bypasses the ownership check by design).
GRANT EXECUTE ON FUNCTION public.evaluate_cross_build_titles_for_user(uuid)
  TO authenticated, service_role;
