-- =============================================================================
-- Cluster 3 — RPG progression UX (BUG-015)
-- Migration: 00049_broad_shouldered_ratio_rebalance
--
-- Rebalances the `broad_shouldered` cross-build predicate from
--   chest+back+shoulders >= 2.0 * (legs+core)
-- down to
--   chest+back+shoulders >= 1.6 * (legs+core)
-- to mirror the Dart change in
-- `lib/features/rpg/domain/cross_build_title_evaluator.dart` (BUG-015).
--
-- Why the rebalance:
--   The original 2× ratio was effectively unreachable for any lifter who
--   trained legs at all. PO audit (2026-05-02) found the typical Brazilian
--   academy lifter runs push/pull 3–4×/week + legs 1×/week, and 1.6× catches
--   that profile while still reading as a genuine upper-body specialist
--   (a 50/50 split still routes elsewhere).
--
-- Boundary mirror with Dart:
--   The Dart predicate uses integer arithmetic (`upper * 10 >= lower * 16`)
--   to avoid float drift at the boundary. We use the same form here so SQL
--   and Dart agree exactly at every boundary value (e.g. upper=96, lower=60
--   fires in both; upper=90, lower=57 fails in both).
--
-- Approach:
--   CREATE OR REPLACE the function from 00045 (which itself replaced the
--   00043 original to add the ownership check). We preserve the ownership
--   check, the rest of the predicates, signature, volatility, parallel
--   safety, language, and EXECUTE grants — only the broad_shouldered branch
--   changes.
--
-- Idempotent: CREATE OR REPLACE overwrites the existing definition. Re-runs
-- are no-ops (function body is identical post-migration).
--
-- NOTE: Supabase CLI wraps every migration file in an implicit transaction;
-- adding our own BEGIN/COMMIT here would nest transactions. (Same comment
-- as 00043 / 00045.)
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
  -- Ownership check (BUG-030, preserved from 00045).
  IF auth.uid() IS NOT NULL AND auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'unauthorized: caller does not own p_user_id'
      USING ERRCODE = '42501';
  END IF;

  -- Project rank by body part. COALESCE to 1 for missing rows.
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

  -- broad_shouldered (BUG-015 rebalance):
  --   chest+back+shoulders >= 1.6 * (legs+core)
  --   AND chest >= 30 AND back >= 30 AND shoulders >= 30
  --
  -- Integer arithmetic (`upper * 10 >= lower * 16`) mirrors the Dart
  -- predicate exactly to avoid float-drift mismatches at the boundary.
  IF v_chest >= 30
     AND v_back >= 30
     AND v_shoulders >= 30
     AND (v_chest + v_back + v_shoulders) * 10 >= (v_legs + v_core) * 16 THEN
    slug := 'broad_shouldered'; RETURN NEXT;
  END IF;

  -- even_handed: every track >= 30 AND (max - min) / max <= 0.30
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

  -- iron_bound: chest >= 60 AND back >= 60 AND legs >= 60 (cardio v2)
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
