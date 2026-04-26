-- =============================================================================
-- Phase 18a — Emergency Rollback for migration 00040_rpg_system_v1
--
-- USE ONLY IF the live deploy of 00040 wedges the app and we need to revert
-- without losing in-flight workouts (sets / workouts tables are untouched by
-- this script — only the v1 RPG-specific objects are dropped).
--
-- WHAT THIS DOES:
--   1. Restores `save_workout` to the pre-18a definition (no record_set_xp call).
--   2. Drops every object created by 00040: tables, indexes, fns, procedure,
--      view, attribution columns on `exercises`, the IMMUTABLE helper fn, the
--      CHECK constraint.
--   3. Leaves `sets`, `workouts`, `workout_exercises`, `exercises` rows intact
--      so the user's training history is preserved.
--
-- WHAT THIS DOES NOT DO:
--   * Does NOT recreate the Phase 17b `user_xp` table or the `award_xp` RPC —
--     those were intentionally dropped by 00040 and are not coming back.
--     Running this rollback puts the app in a "no XP system" state until the
--     fixed forward migration ships. The home/saga screens that read RPG
--     state will degrade gracefully (Phase 18a does not ship UI).
--   * Does NOT restore `secondary_muscle_groups` if it existed pre-18a (it
--     didn't — 00040 introduced the column).
--
-- HOW TO RUN:
--   psql "$DATABASE_URL" -f scripts/emergency_rollback_phase18.sql
--
-- After running, verify with:
--   SELECT 1 FROM pg_proc WHERE proname IN ('record_set_xp','backfill_rpg_v1');
--   -- Expected: 0 rows.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Restore the pre-18a save_workout (no record_set_xp call)
-- ---------------------------------------------------------------------------
--
-- The 17b `save_workout` was the prior definition. Running this DROP+CREATE
-- restores it; if the prior definition diverges from this template at deploy
-- time, dump the live one BEFORE running 00040 and inline it here.

DROP FUNCTION IF EXISTS public.save_workout(jsonb, jsonb, jsonb);

CREATE OR REPLACE FUNCTION public.save_workout(
  p_workout   jsonb,
  p_exercises jsonb,
  p_sets      jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_workout_id uuid;
  v_user_id    uuid;
  v_result     jsonb;
BEGIN
  v_workout_id := (p_workout->>'id')::uuid;
  v_user_id    := (p_workout->>'user_id')::uuid;

  IF v_user_id IS NULL OR v_user_id <> auth.uid() THEN
    RAISE EXCEPTION 'unauthorized: workout user_id mismatch';
  END IF;

  INSERT INTO public.workouts (
    id, user_id, name, started_at, finished_at, duration_seconds, notes
  )
  VALUES (
    v_workout_id,
    v_user_id,
    p_workout->>'name',
    COALESCE((p_workout->>'started_at')::timestamptz, now()),
    (p_workout->>'finished_at')::timestamptz,
    (p_workout->>'duration_seconds')::int,
    p_workout->>'notes'
  )
  ON CONFLICT (id) DO UPDATE SET
    name             = EXCLUDED.name,
    finished_at      = EXCLUDED.finished_at,
    duration_seconds = EXCLUDED.duration_seconds,
    notes            = EXCLUDED.notes;

  INSERT INTO public.workout_exercises (
    id, workout_id, exercise_id, "order", rest_seconds
  )
  SELECT
    (e->>'id')::uuid,
    v_workout_id,
    (e->>'exercise_id')::uuid,
    (e->>'order')::int,
    (e->>'rest_seconds')::int
  FROM jsonb_array_elements(p_exercises) AS e
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.sets (
    id, workout_exercise_id, set_number, reps, weight, rpe,
    set_type, notes, is_completed
  )
  SELECT
    (s->>'id')::uuid,
    (s->>'workout_exercise_id')::uuid,
    (s->>'set_number')::int,
    (s->>'reps')::int,
    (s->>'weight')::numeric,
    (s->>'rpe')::numeric,
    s->>'set_type',
    s->>'notes',
    COALESCE((s->>'is_completed')::boolean, false)
  FROM jsonb_array_elements(p_sets) AS s
  ON CONFLICT (id) DO NOTHING;

  SELECT to_jsonb(w) INTO v_result FROM public.workouts w WHERE w.id = v_workout_id;
  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.save_workout(jsonb, jsonb, jsonb) TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Drop the 18a procedure + RPCs
-- ---------------------------------------------------------------------------

DROP PROCEDURE IF EXISTS public.backfill_rpg_v1(uuid);
DROP FUNCTION  IF EXISTS public._rpg_backfill_chunk(uuid, int);
DROP FUNCTION  IF EXISTS public.record_set_xp(uuid);
DROP FUNCTION  IF EXISTS public.rpg_rank_for_xp(numeric);
DROP FUNCTION  IF EXISTS public.rpg_cumulative_xp_for_rank(int);
DROP FUNCTION  IF EXISTS public.rpg_strength_mult(numeric, numeric);
DROP FUNCTION  IF EXISTS public.rpg_base_xp(numeric, int);
DROP FUNCTION  IF EXISTS public.rpg_intensity_for_reps(int);

-- ---------------------------------------------------------------------------
-- 3. Drop the derived view
-- ---------------------------------------------------------------------------

DROP VIEW IF EXISTS public.character_state;

-- ---------------------------------------------------------------------------
-- 4. Drop tables (CASCADE — drops their indexes + RLS policies + FKs)
-- ---------------------------------------------------------------------------

DROP TABLE IF EXISTS public.backfill_progress    CASCADE;
DROP TABLE IF EXISTS public.earned_titles        CASCADE;
DROP TABLE IF EXISTS public.exercise_peak_loads  CASCADE;
DROP TABLE IF EXISTS public.body_part_progress   CASCADE;
DROP TABLE IF EXISTS public.xp_events            CASCADE;

-- ---------------------------------------------------------------------------
-- 5. Drop attribution columns + helper fn + CHECK from `exercises`
-- ---------------------------------------------------------------------------

ALTER TABLE public.exercises
  DROP CONSTRAINT IF EXISTS xp_attribution_sums_to_one;

ALTER TABLE public.exercises
  DROP COLUMN IF EXISTS xp_attribution,
  DROP COLUMN IF EXISTS secondary_muscle_groups;

DROP FUNCTION IF EXISTS public.xp_attribution_sum(jsonb);

COMMIT;

-- =============================================================================
-- POST-ROLLBACK MANUAL CHECKLIST:
--   * App version that depends on 18a will throw on startup when reading
--     body_part_progress / character_state. Roll back the client to the
--     pre-18a build at the same time, OR confirm the client guards every RPG
--     read with a try/catch that degrades to "no rank yet".
--   * Capture a Sentry tag `rpg_rollback=phase18a_<date>` on the next deploy
--     so post-mortem queries can isolate impact.
--   * Re-run the offending tests against the rollback to confirm green
--     before re-attempting the forward migration.
-- =============================================================================
