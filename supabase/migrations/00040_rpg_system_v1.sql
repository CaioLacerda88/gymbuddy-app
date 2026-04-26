-- =============================================================================
-- Phase 18a — RPG System v1 Foundation
-- Migration: 00040_rpg_system_v1
--
-- Replaces Phase 17b's placeholder XP infrastructure with the RPG v1 model:
--
--   * polymorphic xp_events (per-set in v1, cardio/HR in v2)
--   * body_part_progress (materialized per-(user, body_part) state)
--   * exercise_peak_loads (drives strength_mult)
--   * earned_titles (catalog log + active-flag UNIQUE invariant)
--   * backfill_progress (resume-after-kill checkpoint)
--   * IMMUTABLE helper fn `xp_attribution_sum(jsonb)` + CHECK
--   * `record_set_xp(set_id)` RPC — called from save_workout per inserted set
--   * `backfill_rpg_v1(user_id)` chunked procedure (500 sets/chunk, advisory lock)
--   * derived view `character_state`
--
-- LOCKED DECISIONS (per orchestrator brief):
--   D1: RPC pattern — record_set_xp is called from save_workout in the same
--       transaction (NOT a row-level trigger, NOT an Edge Function).
--   D2: Backfill chunking — 500 sets/chunk, COMMIT between chunks via
--       loop+CALL (procedure, not function), pg_advisory_xact_lock for
--       per-user serialization, backfill_progress checkpoint for resume.
--   D3: Migration-time backfill is fine for current user count.
--   D4: xp_events includes session_id (FK workouts) + set_id (FK sets) as
--       first-class columns, plus polymorphic source_type / source_payload.
--
-- DATA REPLACEMENT:
--   The Phase 17b user_xp + xp_events tables are DROPPED and recreated under
--   the v1 schema. Existing 17b xp_events rows (placeholder formula) are
--   discarded; the backfill procedure recomputes from sets history using
--   the v1 formula. The Saga Intro Overlay's Hive-backed first-open flag is
--   untouched (it is per-device, not in the database).
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Drop Phase 17b xp infrastructure (replaced wholesale)
-- ---------------------------------------------------------------------------

-- award_xp RPC is replaced by record_set_xp (which has a different signature
-- and semantics: per-set, not per-workout). Drop both arities defensively.
-- 17b shipped retro_backfill_xp as a FUNCTION; 17c discussed promoting it to
-- PROCEDURE but never did. We DROP FUNCTION first; if some envs ended up
-- with the PROCEDURE shape, the second DROP catches that case. PG's
-- IF EXISTS only suppresses "missing object" — calling DROP PROCEDURE on a
-- function (or vice versa) raises "is not a procedure", so we MUST try the
-- FUNCTION shape first since that's the prod-shipped form.
DROP FUNCTION  IF EXISTS public.award_xp(uuid, uuid, integer, text, jsonb);
DROP FUNCTION  IF EXISTS public.retro_backfill_xp(uuid);
DROP PROCEDURE IF EXISTS public.retro_backfill_xp(uuid);
-- Drop tables. CASCADE is needed because user_xp.last_xp_event_id references
-- xp_events; the v1 xp_events table is structurally incompatible.
DROP TABLE IF EXISTS public.user_xp CASCADE;
DROP TABLE IF EXISTS public.xp_events CASCADE;

-- ---------------------------------------------------------------------------
-- 2. exercises — add attribution columns + IMMUTABLE helper fn + CHECK
-- ---------------------------------------------------------------------------
--
-- xp_attribution is the per-exercise body-part split (spec §5).
--   { "chest": 0.70, "shoulders": 0.20, "arms": 0.10 }   -- summing 1.00 ± 0.01
-- NULL means "fall back to primary_muscle_group at share 1.0" — the Dart
-- repository handles the fallback so existing user-created exercises (which
-- ship without an attribution map) still earn XP.
--
-- secondary_muscle_groups is referenced in spec §5.1 for future telemetry
-- adjustments; v1 only writes it on default exercises and reads from
-- xp_attribution directly.

ALTER TABLE public.exercises
  ADD COLUMN IF NOT EXISTS secondary_muscle_groups jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS xp_attribution         jsonb;

-- Postgres forbids subqueries in CHECK constraints, so the sum-to-one
-- invariant is enforced via an IMMUTABLE helper function. Using
-- jsonb_each_text in a SQL fn marked IMMUTABLE is safe: the JSON unpacking
-- is deterministic given the input JSONB, and we never read external state.
CREATE OR REPLACE FUNCTION public.xp_attribution_sum(attr jsonb)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
  SELECT COALESCE(sum(value::numeric), 0)
  FROM jsonb_each_text(attr)
$$;

-- Drop the CHECK first so re-runs of this migration don't accumulate dupes.
ALTER TABLE public.exercises
  DROP CONSTRAINT IF EXISTS xp_attribution_sums_to_one;

ALTER TABLE public.exercises
  ADD CONSTRAINT xp_attribution_sums_to_one
    CHECK (
      xp_attribution IS NULL
      OR abs(public.xp_attribution_sum(xp_attribution) - 1.0) <= 0.01
    );

-- ---------------------------------------------------------------------------
-- 3. xp_events — polymorphic event log
-- ---------------------------------------------------------------------------
--
-- v1 records `event_type = 'set'` only, with set_id + session_id populated.
-- v2 will record 'cardio_session' / 'hr_zone' / 'kcal' without schema rework.
--
-- payload = breakdown components { volume_load, base_xp, intensity_mult,
--                                  strength_mult, novelty_mult, cap_mult, set_xp }
-- attribution = body-part XP split { chest: 35.0, shoulders: 10.0, arms: 5.0 }
-- source_type / source_payload = forward-compat polymorphic discriminator;
--                                v1 leaves them NULL.

CREATE TABLE public.xp_events (
  id              uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid          NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type      text          NOT NULL CHECK (event_type IN
                                  ('set','cardio_session','hr_zone','kcal')),
  set_id          uuid          REFERENCES public.sets(id) ON DELETE CASCADE,
  session_id      uuid          REFERENCES public.workouts(id) ON DELETE CASCADE,
  source_type     text,
  source_payload  jsonb,
  occurred_at     timestamptz   NOT NULL DEFAULT now(),
  payload         jsonb         NOT NULL,
  attribution     jsonb         NOT NULL,
  -- numeric(14,4): scale=4 to keep per-event rounding error <0.0001 so
  -- aggregations across hundreds of sets stay within the 0.01 spec tolerance
  -- vs the Dart double reference (BUG-RPG-003 — compounding rounding).
  -- precision widened to 14 to cover lifetime sums without overflow.
  total_xp        numeric(14,4) NOT NULL CHECK (total_xp >= 0),
  created_at      timestamptz   NOT NULL DEFAULT now(),

  -- A 'set' event must carry both set_id and session_id (D4 invariant).
  -- v2 events (cardio_session etc.) will satisfy this with their own NOT
  -- NULL guards on source_payload.
  CONSTRAINT xp_events_set_event_has_fks CHECK (
    event_type <> 'set'
    OR (set_id IS NOT NULL AND session_id IS NOT NULL)
  )
);

-- Hot-path indexes (per spec §11.1).
CREATE INDEX xp_events_user_occurred_idx ON public.xp_events(user_id, occurred_at DESC);
CREATE INDEX xp_events_user_type_idx     ON public.xp_events(user_id, event_type);
CREATE INDEX xp_events_session_idx       ON public.xp_events(session_id) WHERE session_id IS NOT NULL;
-- One xp_events row per (user, set) — guards against double-INSERT on retry
-- and lets `record_set_xp` short-circuit if it sees a hit on UPSERT.
CREATE UNIQUE INDEX xp_events_user_set_unique
  ON public.xp_events(user_id, set_id)
  WHERE set_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 4. body_part_progress — materialized per-(user, body_part) state
-- ---------------------------------------------------------------------------
--
-- Updated incrementally by record_set_xp (live) and backfill_rpg_v1 (replay).
-- Both paths use INSERT ... ON CONFLICT DO UPDATE to be idempotent under
-- concurrent writers.
--
-- Permanent invariants (enforced via comparison in writers, not via CHECK
-- because total_xp can decrease on `backfill_rpg_v1` reset):
--   - rank monotone forward through normal record_set_xp
--   - vitality_peak monotone forward (set by 18d's nightly job)

CREATE TABLE public.body_part_progress (
  user_id        uuid          NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body_part      text          NOT NULL CHECK (body_part IN
                                ('chest','back','legs','shoulders','arms','core','cardio')),
  -- numeric(14,4): see xp_events.total_xp comment. The body_part_progress
  -- total is the sum of many (potentially hundreds) of xp_events
  -- contributions; numeric(_, 2) compounded a per-row rounding error that
  -- exceeded the 0.01 PG/Dart parity tolerance after ~25 sets
  -- (BUG-RPG-003). Widening to 4 fractional digits keeps the cumulative
  -- drift below 0.001 well past the lifetime of any realistic body part.
  total_xp       numeric(14,4) NOT NULL DEFAULT 0 CHECK (total_xp >= 0),
  rank           int           NOT NULL DEFAULT 1 CHECK (rank >= 1 AND rank <= 99),
  -- vitality_* widened in lockstep — they are also incrementally UPSERTed
  -- by the 18d nightly job and would compound the same rounding error.
  vitality_ewma  numeric(14,4) NOT NULL DEFAULT 0 CHECK (vitality_ewma >= 0),
  vitality_peak  numeric(14,4) NOT NULL DEFAULT 0 CHECK (vitality_peak >= 0),
  last_event_at  timestamptz,
  updated_at     timestamptz   NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, body_part)
);

-- ---------------------------------------------------------------------------
-- 5. exercise_peak_loads — drives strength_mult
-- ---------------------------------------------------------------------------

CREATE TABLE public.exercise_peak_loads (
  user_id      uuid           NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  exercise_id  uuid           NOT NULL REFERENCES public.exercises(id) ON DELETE CASCADE,
  -- numeric(8,4): peak_weight feeds strength_mult = clamp(weight / peak,
  -- 0.40, 1.00). At high weights (300+ kg) numeric(8,2) rounds the divisor
  -- enough to push strength_mult one rounding step away from the Dart
  -- reference, drifting body_part_progress totals beyond the 0.01 tolerance
  -- (BUG-RPG-003 root). Scale 4 makes the ratio exact for any realistic
  -- weight increment (gym plates step at 1.25kg minimum).
  peak_weight  numeric(8,4)   NOT NULL CHECK (peak_weight > 0),
  peak_reps    int            NOT NULL CHECK (peak_reps > 0),
  peak_date    timestamptz    NOT NULL,
  updated_at   timestamptz    NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, exercise_id)
);

-- ---------------------------------------------------------------------------
-- 6. earned_titles — catalog log + active-title UNIQUE
-- ---------------------------------------------------------------------------
--
-- v1 only persists unlocks here; the catalog (78 per-body-part + 7 char-level
-- + 5 cross-build) lives client-side as a JSON asset (see Phase 18c).

CREATE TABLE public.earned_titles (
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title_id   text        NOT NULL,
  earned_at  timestamptz NOT NULL DEFAULT now(),
  is_active  boolean     NOT NULL DEFAULT FALSE,
  PRIMARY KEY (user_id, title_id)
);

-- One active title per user — equipping a new title must clear the prior
-- active flag in the same statement (the equip RPC will land in 18c).
CREATE UNIQUE INDEX earned_titles_one_active
  ON public.earned_titles(user_id) WHERE is_active = TRUE;

-- ---------------------------------------------------------------------------
-- 7. backfill_progress — resume-after-kill checkpoint
-- ---------------------------------------------------------------------------
--
-- One row per user. last_set_id is the cursor; completed_at is set on
-- successful completion. Resume = pick up from sets ordered by
-- (created_at, id) > last cursor.

CREATE TABLE public.backfill_progress (
  user_id        uuid           PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  last_set_id    uuid,
  last_set_ts    timestamptz,
  sets_processed bigint         NOT NULL DEFAULT 0,
  started_at     timestamptz    NOT NULL DEFAULT now(),
  updated_at     timestamptz    NOT NULL DEFAULT now(),
  completed_at   timestamptz
);

-- ---------------------------------------------------------------------------
-- 8. RLS — owner-read on all 5 new tables; writes go through SECURITY DEFINER fns
-- ---------------------------------------------------------------------------

ALTER TABLE public.xp_events           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.body_part_progress  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exercise_peak_loads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.earned_titles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.backfill_progress   ENABLE ROW LEVEL SECURITY;

-- xp_events: owner SELECT only (writes via record_set_xp / backfill_rpg_v1)
DROP POLICY IF EXISTS xp_events_select_own ON public.xp_events;
CREATE POLICY xp_events_select_own
  ON public.xp_events FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- body_part_progress: owner SELECT only
DROP POLICY IF EXISTS body_part_progress_select_own ON public.body_part_progress;
CREATE POLICY body_part_progress_select_own
  ON public.body_part_progress FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- exercise_peak_loads: owner SELECT only
DROP POLICY IF EXISTS exercise_peak_loads_select_own ON public.exercise_peak_loads;
CREATE POLICY exercise_peak_loads_select_own
  ON public.exercise_peak_loads FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- earned_titles: owner SELECT + UPDATE (toggle is_active for equip; the
-- 18c equip RPC will eventually be the only writer, but allowing direct
-- UPDATE keeps the equip flow simple for v1)
DROP POLICY IF EXISTS earned_titles_select_own ON public.earned_titles;
CREATE POLICY earned_titles_select_own
  ON public.earned_titles FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS earned_titles_update_own ON public.earned_titles;
CREATE POLICY earned_titles_update_own
  ON public.earned_titles FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- backfill_progress: owner SELECT only (procedure writes as DEFINER)
DROP POLICY IF EXISTS backfill_progress_select_own ON public.backfill_progress;
CREATE POLICY backfill_progress_select_own
  ON public.backfill_progress FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 9. character_state derived view (spec §11.3)
-- ---------------------------------------------------------------------------
--
-- Computes character_level, max_rank, min_rank, lifetime_xp from
-- body_part_progress. v1 excludes cardio from active ranks (matches spec §7).
--
-- Views inherit RLS from their base tables — body_part_progress' owner-
-- SELECT policy means each authenticated user sees only their own row.

CREATE OR REPLACE VIEW public.character_state AS
SELECT
  user_id,
  GREATEST(1, FLOOR((SUM(rank) - COUNT(*)) / 4.0)::int + 1) AS character_level,
  MAX(rank)      AS max_rank,
  MIN(rank)      AS min_rank,
  SUM(total_xp)  AS lifetime_xp
FROM public.body_part_progress
WHERE body_part IN ('chest','back','legs','shoulders','arms','core')
GROUP BY user_id;

-- ---------------------------------------------------------------------------
-- 10. Helper functions — pure-PG reimplementations of the Dart calculator
-- ---------------------------------------------------------------------------
--
-- These are the SECOND implementation of the formulas in the codebase. The
-- FIRST is `lib/features/rpg/domain/xp_calculator.dart`. Integration tests
-- assert byte-parity within 1e-4 absolute. **If you change either side,
-- change BOTH and the Python sim + fixture in the same PR.**

-- Reps → intensity multiplier table (spec §4.1)
CREATE OR REPLACE FUNCTION public.rpg_intensity_for_reps(p_reps int)
RETURNS numeric
LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
AS $$
BEGIN
  IF p_reps IS NULL OR p_reps < 1 THEN RETURN 1.0; END IF;
  IF p_reps >= 20 THEN RETURN 0.80; END IF;
  IF p_reps >= 15 THEN RETURN 0.90; END IF;
  IF p_reps >= 12 THEN RETURN 0.95; END IF;
  IF p_reps >=  8 THEN RETURN 1.00; END IF;
  IF p_reps >=  5 THEN RETURN 1.20; END IF;
  IF p_reps >=  3 THEN RETURN 1.25; END IF;
  RETURN 1.30; -- reps in [1, 3)
END;
$$;

-- volume_load = max(1.0, weight × reps); base = volume_load^0.65
CREATE OR REPLACE FUNCTION public.rpg_base_xp(p_weight numeric, p_reps int)
RETURNS numeric
LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
AS $$
DECLARE
  v_vl numeric;
BEGIN
  IF p_reps IS NULL OR p_reps < 1 THEN
    v_vl := 1.0;
  ELSE
    v_vl := GREATEST(1.0, COALESCE(p_weight, 0) * p_reps);
  END IF;
  RETURN power(v_vl, 0.65);
END;
$$;

-- strength_mult = clamp(weight / peak, 0.40, 1.00); peak<=0 → 1.0
CREATE OR REPLACE FUNCTION public.rpg_strength_mult(p_weight numeric, p_peak numeric)
RETURNS numeric
LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
AS $$
DECLARE
  v_ratio numeric;
BEGIN
  IF p_peak IS NULL OR p_peak <= 0 THEN RETURN 1.0; END IF;
  v_ratio := COALESCE(p_weight, 0) / p_peak;
  IF v_ratio < 0.40 THEN RETURN 0.40; END IF;
  IF v_ratio > 1.00 THEN RETURN 1.00; END IF;
  RETURN v_ratio;
END;
$$;

-- Cumulative XP for rank n (closed form).
-- xp_cumulative(n) = 60 × (1.10^(n-1) - 1) / 0.10
CREATE OR REPLACE FUNCTION public.rpg_cumulative_xp_for_rank(p_rank int)
RETURNS numeric
LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
AS $$
BEGIN
  IF p_rank <= 1 THEN RETURN 0; END IF;
  RETURN 60.0 * (power(1.10, p_rank - 1) - 1) / 0.10;
END;
$$;

-- rank_for_xp — binary search the geometric formula. Caps at 99.
-- Loop is bounded at 99 iterations max, so worst-case O(99) — fine for
-- per-set hot path. We use linear scan instead of bisection because the
-- table is small and avoids float-rounding edge cases at high ranks.
CREATE OR REPLACE FUNCTION public.rpg_rank_for_xp(p_total numeric)
RETURNS int
LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
AS $$
DECLARE
  v_n int := 1;
BEGIN
  IF p_total IS NULL OR p_total <= 0 THEN RETURN 1; END IF;
  WHILE v_n < 99 AND public.rpg_cumulative_xp_for_rank(v_n + 1) <= p_total LOOP
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END;
$$;

-- ---------------------------------------------------------------------------
-- 11. record_set_xp(set_id) — per-set XP RPC (D1)
-- ---------------------------------------------------------------------------
--
-- Called from inside save_workout (same transaction). Computes set_xp end-
-- to-end, INSERTs xp_events, UPSERTs body_part_progress, advances
-- exercise_peak_loads if needed.
--
-- Guarantees:
--   * Idempotent on retry: xp_events_user_set_unique UNIQUE INDEX +
--     ON CONFLICT DO NOTHING on xp_events; body_part_progress UPSERT is
--     value-add (re-running with the same set_id produces a duplicate INSERT
--     attempt that no-ops, so no double-counting).
--   * Concurrent INSERT race-safe: body_part_progress UPSERT uses
--     INSERT ... ON CONFLICT DO UPDATE which row-locks the conflict target
--     for the duration of the SET clause.
--   * Returns the new (body_part, total_xp, rank_before, rank_after) deltas
--     so the client can drive celebration overlays in 18c without a second
--     read.
--
-- Computation flow (mirrors xp_calculator.dart computeSetXp):
--   1. resolve set → exercise + workout + user
--   2. resolve attribution map (NULL → primary muscle group at 1.0)
--   3. fetch peak_load (or use weight if no prior peak)
--   4. compute session_volume[bp] = SUM(attribution[bp]) over all sets in
--      this workout that are already in xp_events for this user
--   5. compute weekly_volume[bp] = SUM(attribution[bp]) over all xp_events
--      in past 7 days for this user
--   6. compute set_xp = base × intensity × strength × novelty × cap
--   7. INSERT xp_events (skip if duplicate set_id)
--   8. for each attributed body_part: UPSERT body_part_progress (advance
--      total_xp + rank); track delta for return
--   9. UPSERT exercise_peak_loads if weight > current peak

CREATE OR REPLACE FUNCTION public.record_set_xp(p_set_id uuid)
RETURNS TABLE (
  -- Out-parameter names are prefixed `out_` to avoid clashes with the
  -- `body_part_progress` columns inside ON CONFLICT clauses (PG's
  -- variable resolution treats unqualified `body_part` / `total_xp` /
  -- `rank` as the OUT param when both are in scope, raising "column
  -- reference is ambiguous"). Aliasing the table didn't help because
  -- ON CONFLICT (col) is evaluated against the column name unqualified.
  -- Callers select these named columns explicitly so the rename is
  -- backwards-compatible from the client's point of view.
  out_body_part   text,
  out_xp_awarded  numeric,
  out_total_xp    numeric,
  out_rank_before int,
  out_rank_after  int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id      uuid;
  v_workout_id   uuid;
  v_exercise_id  uuid;
  v_weight       numeric;
  v_reps         int;
  v_attribution  jsonb;
  v_attr_key     text;
  v_attr_share   numeric;
  v_peak         numeric;
  v_session_vol  numeric;
  v_weekly_vol   numeric;
  v_base         numeric;
  v_intensity    numeric;
  v_strength     numeric;
  v_novelty      numeric;
  v_cap          numeric;
  v_set_xp       numeric;
  v_xp_for_bp    numeric;
  v_event_id     uuid;
  v_event_payload jsonb;
  v_event_attribution jsonb;
  v_existing_event_id uuid;
  v_set_completed boolean;
  v_set_type     text;
  v_total_xp     numeric;
  v_rank_before  int;
  v_rank_after   int;
  v_event_attr_each text;
  v_now          timestamptz := now();
  v_primary_muscle text;
BEGIN
  -- 1. Resolve set → exercise, workout, user, weight, reps
  SELECT
    we.exercise_id,
    we.workout_id,
    w.user_id,
    s.weight,
    s.reps,
    s.is_completed,
    COALESCE(s.set_type, 'working')
  INTO
    v_exercise_id, v_workout_id, v_user_id, v_weight, v_reps,
    v_set_completed, v_set_type
  FROM public.sets s
  JOIN public.workout_exercises we ON we.id = s.workout_exercise_id
  JOIN public.workouts w ON w.id = we.workout_id
  WHERE s.id = p_set_id;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'record_set_xp: set % not found', p_set_id
      USING ERRCODE = 'P0002';
  END IF;

  -- Skip non-completed or non-working sets — they don't earn XP. Returning
  -- an empty result set is correct: the caller (save_workout) iterates over
  -- every inserted set and ignores empty results.
  IF NOT v_set_completed OR v_set_type <> 'working' THEN
    RETURN;
  END IF;

  -- Reps must be valid for the formula; weight may be 0 (bodyweight floor).
  IF v_reps IS NULL OR v_reps < 1 THEN
    RETURN;
  END IF;

  -- Idempotency: if an xp_events row already exists for this set, skip.
  -- The UNIQUE INDEX on (user_id, set_id) WHERE set_id IS NOT NULL is the
  -- structural guarantee; this short-circuit avoids re-running expensive
  -- lookups on retry.
  SELECT id INTO v_existing_event_id
  FROM public.xp_events
  WHERE user_id = v_user_id AND set_id = p_set_id
  LIMIT 1;
  IF v_existing_event_id IS NOT NULL THEN
    RETURN;
  END IF;

  -- 2. Resolve attribution map
  SELECT xp_attribution, primary_muscle_group::text
  INTO v_attribution, v_primary_muscle
  FROM (
    SELECT xp_attribution, muscle_group AS primary_muscle_group
    FROM public.exercises
    WHERE id = v_exercise_id
  ) src;

  IF v_attribution IS NULL OR v_attribution = 'null'::jsonb OR v_attribution = '{}'::jsonb THEN
    -- NULL fallback: 1.0 share to primary muscle group.
    v_attribution := jsonb_build_object(v_primary_muscle, 1.0);
  END IF;

  -- 3. Fetch peak_load
  SELECT peak_weight INTO v_peak
  FROM public.exercise_peak_loads
  WHERE user_id = v_user_id AND exercise_id = v_exercise_id;

  IF v_peak IS NULL THEN
    -- No prior peak — calculator returns strength_mult = 1.0 when peak is 0.
    -- We pass 0 explicitly to make that branch obvious.
    v_peak := 0;
  END IF;

  -- 4. Compute session_volume[bp] — aggregated across body parts. The
  --    novelty multiplier varies per body-part-share, so we compute set_xp
  --    PER BODY PART rather than once with one novelty multiplier. This
  --    mirrors the Python sim where novelty_count is keyed by body_part.
  --    Implementation: we build the per-bp novelty + cap into the loop.

  -- Pre-compute base + intensity + strength (constant across body parts).
  v_base := public.rpg_base_xp(v_weight, v_reps);
  v_intensity := public.rpg_intensity_for_reps(v_reps);
  -- For strength, advance peak BEFORE computing strength_mult so a new PR
  -- earns at 1.0× (matches Python sim behavior where the peak is updated
  -- inside compute_set_xp before strength_mult is calculated).
  IF v_weight > v_peak THEN
    v_peak := v_weight;
  END IF;
  v_strength := public.rpg_strength_mult(v_weight, v_peak);

  -- 5. Insert xp_events row first (we need its id for the response shape;
  --    body-part totals follow). The payload + attribution columns are
  --    populated after we compute them in the body-part loop, then we
  --    UPDATE the row.
  --
  --    Important: xp_events row is inserted with placeholder total_xp = 0
  --    + empty attribution; the per-bp loop accumulates the totals and we
  --    UPDATE the row at the end. This keeps the row INSERTed early so
  --    concurrent record_set_xp calls for different sets in the same
  --    session see each other's prior contributions when they re-query
  --    session_volume in step 4 (above).

  INSERT INTO public.xp_events (
    id, user_id, event_type, set_id, session_id,
    occurred_at, payload, attribution, total_xp, created_at
  ) VALUES (
    gen_random_uuid(), v_user_id, 'set', p_set_id, v_workout_id,
    v_now, '{}'::jsonb, '{}'::jsonb, 0, v_now
  )
  ON CONFLICT (user_id, set_id) WHERE set_id IS NOT NULL DO NOTHING
  RETURNING id INTO v_event_id;

  -- If the unique index hit (rare race condition where two parallel calls
  -- attempt to insert the same set_id), the RETURNING is NULL and we exit.
  IF v_event_id IS NULL THEN
    RETURN;
  END IF;

  -- 6. For each body part in the attribution map, compute set_xp_for_bp,
  --    advance body_part_progress, accumulate into v_event_attribution.

  v_set_xp := 0;
  v_event_attribution := '{}'::jsonb;

  FOR v_attr_key, v_attr_share IN
    SELECT key, value::numeric FROM jsonb_each_text(v_attribution)
  LOOP
    IF v_attr_share <= 0 THEN CONTINUE; END IF;

    -- session_volume[bp]: SUM(attribution[bp]) over xp_events for this user
    -- in this session, excluding the row we just inserted (its attribution
    -- is still {}). Treats missing attribution[bp] as 0.
    SELECT COALESCE(SUM((e.attribution ->> v_attr_key)::numeric), 0)
    INTO v_session_vol
    FROM public.xp_events e
    WHERE e.user_id = v_user_id
      AND e.session_id = v_workout_id
      AND e.id <> v_event_id
      AND (e.attribution ? v_attr_key);

    -- weekly_volume[bp]: SUM(attribution[bp]) over xp_events in past 7d.
    SELECT COALESCE(SUM((e.attribution ->> v_attr_key)::numeric), 0)
    INTO v_weekly_vol
    FROM public.xp_events e
    WHERE e.user_id = v_user_id
      AND e.occurred_at > v_now - interval '7 days'
      AND e.id <> v_event_id
      AND (e.attribution ? v_attr_key);

    v_novelty := exp(- v_session_vol / 15.0);
    v_cap     := CASE WHEN v_weekly_vol >= 20 THEN 0.5 ELSE 1.0 END;

    -- Per-bp set_xp contribution. The Python sim factors out attribution
    -- AFTER multiplying base × intensity × strength × novelty × cap; we do
    -- the same here so bp-specific novelty stays scoped.
    v_xp_for_bp := v_base * v_intensity * v_strength * v_novelty * v_cap * v_attr_share;

    -- Total set_xp = sum over body parts (with shares summing to ~1.0,
    -- this approximates the un-attributed set_xp; we record the
    -- attributed total so the breakdown invariant total_xp == sum(attribution)
    -- holds.
    v_set_xp := v_set_xp + v_xp_for_bp;

    -- Accumulate per-bp into event attribution.
    v_event_attribution := v_event_attribution
      || jsonb_build_object(v_attr_key, v_xp_for_bp);

    -- 7. UPSERT body_part_progress for this body part. The CONFLICT clause
    --    handles concurrent INSERTs for the same (user, body_part) — only
    --    one writer holds the row lock, the other UPDATEs the SET clause.
    --    rank is recomputed via rpg_rank_for_xp on the new total.
    --
    -- Both `rank` and `total_xp` are also the names of OUT parameters on this
    -- function (RETURNS TABLE), so PL/pgSQL flags them as ambiguous unless we
    -- alias the table to disambiguate. The bare `rank`/`total_xp` would
    -- compile but raise at runtime.
    SELECT bpp.rank, bpp.total_xp
    INTO v_rank_before, v_total_xp
    FROM public.body_part_progress bpp
    WHERE bpp.user_id = v_user_id AND bpp.body_part = v_attr_key;

    IF v_rank_before IS NULL THEN v_rank_before := 1; END IF;
    IF v_total_xp IS NULL THEN v_total_xp := 0; END IF;

    INSERT INTO public.body_part_progress AS bpp (
      user_id, body_part, total_xp, rank,
      vitality_ewma, vitality_peak, last_event_at, updated_at
    ) VALUES (
      v_user_id, v_attr_key,
      v_xp_for_bp,
      public.rpg_rank_for_xp(v_xp_for_bp),
      0, 0, v_now, v_now
    )
    ON CONFLICT (user_id, body_part) DO UPDATE SET
      total_xp     = bpp.total_xp + EXCLUDED.total_xp,
      rank         = public.rpg_rank_for_xp(bpp.total_xp + EXCLUDED.total_xp),
      last_event_at = v_now,
      updated_at   = v_now
    RETURNING bpp.total_xp, bpp.rank
    INTO v_total_xp, v_rank_after;

    -- Emit one row per attributed body part. Caller iterates this set.
    out_body_part   := v_attr_key;
    out_xp_awarded  := v_xp_for_bp;
    out_total_xp    := v_total_xp;
    out_rank_before := v_rank_before;
    out_rank_after  := v_rank_after;
    RETURN NEXT;
  END LOOP;

  -- 8. Build payload (breakdown components) and finalize the xp_events row.
  v_event_payload := jsonb_build_object(
    'volume_load',   GREATEST(1.0, COALESCE(v_weight, 0) * v_reps),
    'base_xp',       v_base,
    'intensity_mult', v_intensity,
    'strength_mult', v_strength,
    'set_xp',        v_set_xp
    -- novelty_mult / cap_mult are per-body-part; not denormalized to the
    -- top-level payload. The per-bp values are reconstructable from
    -- attribution and the bp's session/weekly volume context.
  );

  UPDATE public.xp_events
  SET payload     = v_event_payload,
      attribution = v_event_attribution,
      total_xp    = v_set_xp
  WHERE id = v_event_id;

  -- 9. UPSERT exercise_peak_loads if weight advanced.
  INSERT INTO public.exercise_peak_loads (
    user_id, exercise_id, peak_weight, peak_reps, peak_date, updated_at
  ) VALUES (
    v_user_id, v_exercise_id, v_weight, v_reps, v_now, v_now
  )
  ON CONFLICT (user_id, exercise_id) DO UPDATE SET
    peak_weight = GREATEST(public.exercise_peak_loads.peak_weight, EXCLUDED.peak_weight),
    -- peak_reps + peak_date are only updated when weight advances; otherwise
    -- they reflect the heaviest-ever set, not the most-recent.
    peak_reps   = CASE
                    WHEN EXCLUDED.peak_weight > public.exercise_peak_loads.peak_weight
                    THEN EXCLUDED.peak_reps
                    ELSE public.exercise_peak_loads.peak_reps
                  END,
    peak_date   = CASE
                    WHEN EXCLUDED.peak_weight > public.exercise_peak_loads.peak_weight
                    THEN EXCLUDED.peak_date
                    ELSE public.exercise_peak_loads.peak_date
                  END,
    updated_at  = v_now;

  RETURN;
END;
$$;

-- record_set_xp is called only by save_workout (which is itself
-- SECURITY DEFINER and validates ownership). We still grant EXECUTE to
-- authenticated so the integration tests can call it directly.
REVOKE EXECUTE ON FUNCTION public.record_set_xp(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.record_set_xp(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 12. backfill_rpg_v1(user_id) — chunked replay procedure
-- ---------------------------------------------------------------------------
--
-- Per-user replay of historical sets through the same XP formula
-- record_set_xp uses. Implementation note: we do NOT call record_set_xp()
-- in a loop — that would re-run the session/weekly-volume subqueries N
-- times with O(n²) cost across an entire training history. Instead, we
-- replay sets in chronological order via _rpg_backfill_chunk, mirroring
-- the Python sim exactly.
--
-- Architecture (the chunking model):
--   * `backfill_rpg_v1` is a FUNCTION, not a PROCEDURE. It processes ONE
--     chunk per invocation and returns progress. The CLIENT loops over
--     it until `out_is_complete = true`.
--   * Each invocation is its own transaction (PostgREST auto-wraps RPC
--     calls in a txn). When the function returns, the chunk commits.
--   * If the client process dies mid-loop, the cursor on
--     `backfill_progress` is durable; the next caller resumes from
--     wherever the last committed chunk left off.
--
-- Why not a procedure with internal COMMIT? Postgres forbids `COMMIT`
-- inside a SECURITY DEFINER procedure (and PostgREST always invokes via
-- a transaction wrapper, so a non-DEFINER procedure with COMMIT fails
-- the same way). Inverting the loop to live in the client avoids both
-- restrictions while keeping the chunking + advisory-lock + checkpoint
-- semantics identical.
--
-- Advisory lock: `pg_advisory_xact_lock(hashtext('rpg_backfill_' || uid))`
-- is held for each chunk's transaction. Two concurrent
-- backfill_rpg_v1 calls for the same user serialize; calls for different
-- users run in parallel.
--
-- First-chunk wipe: when `sets_processed = 0`, we DELETE prior xp_events
-- / body_part_progress / exercise_peak_loads for this user (backfill is
-- authoritative). Re-running after `completed_at` is set is a no-op
-- unless the row is reset.

CREATE OR REPLACE FUNCTION public.backfill_rpg_v1(
  p_user_id    uuid,
  p_chunk_size int DEFAULT 500
)
RETURNS TABLE (
  out_processed       bigint,
  out_total_processed bigint,
  out_is_complete     boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_processed       bigint;
  v_visited         bigint;
  v_last_set_id     uuid;
  v_last_set_ts     timestamptz;
  v_total_processed bigint;
  v_was_completed   boolean := FALSE;
BEGIN
  IF p_chunk_size IS NULL OR p_chunk_size < 1 THEN
    p_chunk_size := 500;
  END IF;

  -- Acquire per-user advisory lock for THIS chunk's transaction. Two
  -- concurrent calls for the same user serialize at this point; calls
  -- for different users run in parallel.
  PERFORM pg_advisory_xact_lock(hashtext('rpg_backfill_' || p_user_id::text));

  -- Initialize / read checkpoint.
  INSERT INTO public.backfill_progress (user_id, started_at, updated_at)
  VALUES (p_user_id, now(), now())
  ON CONFLICT (user_id) DO NOTHING;

  SELECT last_set_id, last_set_ts, sets_processed, completed_at IS NOT NULL
  INTO v_last_set_id, v_last_set_ts, v_total_processed, v_was_completed
  FROM public.backfill_progress
  WHERE user_id = p_user_id;

  IF v_was_completed THEN
    -- Already done. Caller should treat this as a no-op success and
    -- stop looping. To force a re-run, DELETE the row and call again.
    out_processed       := 0;
    out_total_processed := v_total_processed;
    out_is_complete     := TRUE;
    RETURN NEXT;
    RETURN;
  END IF;

  -- Wipe prior rows for this user — backfill is authoritative. (We don't
  -- truncate xp_events globally because other users' rows must survive.)
  -- This runs only on the FIRST chunk (sets_processed = 0). Resumed
  -- chunks skip the wipe so the partial XP rows survive.
  IF v_total_processed = 0 THEN
    DELETE FROM public.xp_events WHERE user_id = p_user_id;
    DELETE FROM public.body_part_progress WHERE user_id = p_user_id;
    DELETE FROM public.exercise_peak_loads WHERE user_id = p_user_id;
  END IF;

  -- Process up to p_chunk_size completed working sets after the cursor,
  -- in chronological order. Inline formula in _rpg_backfill_chunk
  -- because record_set_xp's session/weekly subqueries don't scale across
  -- replay.
  --
  -- The chunk function returns (processed, last_set_id, last_set_ts) so the
  -- cursor advance uses the SAME total ordering tuple — `(w.started_at,
  -- s.id)` — that the chunk fetch uses. Earlier versions of this code
  -- advanced the cursor by querying `xp_events` ordered by
  -- `(occurred_at DESC, e.id DESC)`, but `e.id` is the xp_events PK, not
  -- `s.id`, so the cursor and the next chunk's WHERE clause used DIFFERENT
  -- ordering keys. That allowed sets at the boundary of a same-timestamp
  -- group to be re-visited on the next chunk, inflating the processed
  -- counter (BUG-RPG-002).
  -- The chunk function returns `processed` = sets actually replayed (does
  -- NOT count idempotent skips) plus `last_set_id` / `last_set_ts` set to
  -- the LAST set the chunk visited (whether replayed or skipped). The
  -- chunk also returns `visited` so we can detect end-of-input via
  -- underflow without conflating "processed" and "visited".
  SELECT c.processed, c.visited, c.last_set_id, c.last_set_ts
  INTO v_processed, v_visited, v_last_set_id, v_last_set_ts
  FROM public._rpg_backfill_chunk(p_user_id, p_chunk_size) AS c;

  -- If the chunk visited nothing at all (cursor already past the last
  -- set), the function returned NULLs for last_set_*. Preserve the
  -- existing cursor so the UPDATE below doesn't overwrite a real value
  -- with NULL.
  IF v_last_set_id IS NULL THEN
    SELECT bp.last_set_id, bp.last_set_ts INTO v_last_set_id, v_last_set_ts
    FROM public.backfill_progress bp WHERE bp.user_id = p_user_id;
  END IF;

  v_total_processed := v_total_processed + v_processed;

  UPDATE public.backfill_progress
  SET last_set_id    = v_last_set_id,
      last_set_ts    = v_last_set_ts,
      sets_processed = v_total_processed,
      updated_at     = now(),
      -- Mark complete when the chunk visited fewer rows than the chunk
      -- size — that means there's no more input. Using `v_visited` (not
      -- `v_processed`) is essential: a resume that skips every visited
      -- row must still terminate when it runs out of input.
      completed_at   = CASE
                         WHEN v_visited < p_chunk_size THEN now()
                         ELSE NULL
                       END
  WHERE user_id = p_user_id;

  out_processed       := v_processed;
  out_total_processed := v_total_processed;
  out_is_complete     := (v_visited < p_chunk_size);
  RETURN NEXT;
END;
$$;

-- _rpg_backfill_chunk: the inner function. Returns the number of sets
-- actually processed (NOT visit count) plus the cursor advance tuple.
-- SECURITY DEFINER + locked search_path. Replays up to N sets after the
-- cursor, computing XP exactly as the Python sim does (per-bp novelty +
-- cap, peak advancement before strength_mult).
--
-- Returns the SAME total-ordering tuple `(w.started_at, s.id)` that the
-- chunk fetch uses, so the wrapper's cursor write is symmetrical with the
-- next chunk's WHERE clause. See BUG-RPG-002 note in the wrapper for why
-- the prior `xp_events`-based cursor advance was unsafe.
--
-- Idempotent-skip semantics: if the INSERT into xp_events ON CONFLICT DO
-- NOTHING returns NULL (the row already existed — e.g. a partial backfill
-- resume hitting an already-replayed set), the row is treated as ALREADY
-- processed by an earlier chunk. The counter is NOT incremented and the
-- cursor still advances past it, so a future chunk doesn't re-visit it.
-- This restores the invariant: out_total_processed == count(distinct
-- xp_events.set_id) for the user.
--
-- This function is internal; not exposed to authenticated.

CREATE OR REPLACE FUNCTION public._rpg_backfill_chunk(p_user_id uuid, p_chunk_size int)
RETURNS TABLE (
  processed     bigint,
  visited       bigint,
  last_set_id   uuid,
  last_set_ts   timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_processed   bigint := 0;
  v_visited     bigint := 0;
  r_set         record;
  v_attribution jsonb;
  v_primary     text;
  v_peak        numeric;
  v_base        numeric;
  v_intensity   numeric;
  v_strength    numeric;
  v_novelty     numeric;
  v_cap         numeric;
  v_attr_key    text;
  v_attr_share  numeric;
  v_session_vol numeric;
  v_weekly_vol  numeric;
  v_xp_for_bp   numeric;
  v_set_xp      numeric;
  v_event_id    uuid;
  v_event_payload     jsonb;
  v_event_attribution jsonb;
  v_now         timestamptz;
  v_cursor_ts   timestamptz;
  v_cursor_id   uuid;
  v_last_set_id uuid;
  v_last_set_ts timestamptz;
BEGIN
  -- Read cursor. Alias the table because `last_set_id` / `last_set_ts` are
  -- ALSO the names of OUT parameters on this function (RETURNS TABLE),
  -- which makes the unqualified column references ambiguous to PL/pgSQL.
  SELECT bp.last_set_ts, bp.last_set_id INTO v_cursor_ts, v_cursor_id
  FROM public.backfill_progress bp
  WHERE bp.user_id = p_user_id;

  -- Iterate sets in chronological order, using (workout.started_at, set.id)
  -- as the strict ordering. We use workout.started_at as the surrogate for
  -- when the set was performed; sets within the same workout are ordered
  -- by set.id (a uuid — not stable, but deterministic per replay).
  FOR r_set IN
    SELECT
      s.id            AS set_id,
      s.workout_exercise_id,
      we.exercise_id,
      we.workout_id,
      s.weight,
      s.reps,
      s.is_completed,
      COALESCE(s.set_type, 'working') AS set_type,
      w.started_at    AS occurred_at,
      ex.muscle_group::text AS primary_muscle,
      ex.xp_attribution
    FROM public.sets s
    JOIN public.workout_exercises we ON we.id = s.workout_exercise_id
    JOIN public.workouts w           ON w.id = we.workout_id
    JOIN public.exercises ex         ON ex.id = we.exercise_id
    WHERE w.user_id = p_user_id
      AND w.finished_at IS NOT NULL
      AND s.is_completed = TRUE
      AND COALESCE(s.set_type, 'working') = 'working'
      AND s.reps IS NOT NULL AND s.reps >= 1
      AND (
        v_cursor_ts IS NULL
        OR (w.started_at, s.id) > (v_cursor_ts, v_cursor_id)
      )
    ORDER BY w.started_at ASC, s.id ASC
    LIMIT p_chunk_size
  LOOP
    v_visited := v_visited + 1;
    v_now := r_set.occurred_at;

    -- Resolve attribution
    v_attribution := r_set.xp_attribution;
    v_primary := r_set.primary_muscle;
    IF v_attribution IS NULL OR v_attribution = 'null'::jsonb OR v_attribution = '{}'::jsonb THEN
      v_attribution := jsonb_build_object(v_primary, 1.0);
    END IF;

    -- Peak load (advance before strength_mult)
    SELECT peak_weight INTO v_peak
    FROM public.exercise_peak_loads
    WHERE user_id = p_user_id AND exercise_id = r_set.exercise_id;
    IF v_peak IS NULL THEN v_peak := 0; END IF;
    IF r_set.weight > v_peak THEN v_peak := r_set.weight; END IF;

    v_base      := public.rpg_base_xp(r_set.weight, r_set.reps);
    v_intensity := public.rpg_intensity_for_reps(r_set.reps);
    v_strength  := public.rpg_strength_mult(r_set.weight, v_peak);

    -- Insert empty xp_events row first (id needed for per-bp updates)
    INSERT INTO public.xp_events (
      id, user_id, event_type, set_id, session_id,
      occurred_at, payload, attribution, total_xp, created_at
    ) VALUES (
      gen_random_uuid(), p_user_id, 'set', r_set.set_id, r_set.workout_id,
      v_now, '{}'::jsonb, '{}'::jsonb, 0, v_now
    )
    ON CONFLICT (user_id, set_id) WHERE set_id IS NOT NULL DO NOTHING
    RETURNING id INTO v_event_id;

    -- Idempotent skip: row already existed (a partial backfill resume that
    -- crashed AFTER inserting the xp_events row but BEFORE the wrapper's
    -- cursor write committed). The set has already been counted by the
    -- earlier chunk; we must NOT increment v_processed (the counter would
    -- exceed the set count — BUG-RPG-002), but we DO advance the cursor
    -- past this row so the next chunk skips it.
    IF v_event_id IS NULL THEN
      v_last_set_id := r_set.set_id;
      v_last_set_ts := r_set.occurred_at;
      CONTINUE;
    END IF;

    v_set_xp := 0;
    v_event_attribution := '{}'::jsonb;

    FOR v_attr_key, v_attr_share IN
      SELECT key, value::numeric FROM jsonb_each_text(v_attribution)
    LOOP
      IF v_attr_share <= 0 THEN CONTINUE; END IF;

      -- session_volume[bp] over events in same session, excluding the
      -- current placeholder row.
      SELECT COALESCE(SUM((e.attribution ->> v_attr_key)::numeric), 0)
      INTO v_session_vol
      FROM public.xp_events e
      WHERE e.user_id = p_user_id
        AND e.session_id = r_set.workout_id
        AND e.id <> v_event_id
        AND (e.attribution ? v_attr_key);

      -- weekly_volume[bp] over events with occurred_at within 7 days of
      -- the *replayed* timestamp (NOT now()). This is the key parity
      -- guarantee with the Python sim — replay weeks must use replay
      -- windows.
      SELECT COALESCE(SUM((e.attribution ->> v_attr_key)::numeric), 0)
      INTO v_weekly_vol
      FROM public.xp_events e
      WHERE e.user_id = p_user_id
        AND e.occurred_at > v_now - interval '7 days'
        AND e.occurred_at <= v_now
        AND e.id <> v_event_id
        AND (e.attribution ? v_attr_key);

      v_novelty := exp(- v_session_vol / 15.0);
      v_cap     := CASE WHEN v_weekly_vol >= 20 THEN 0.5 ELSE 1.0 END;

      v_xp_for_bp := v_base * v_intensity * v_strength * v_novelty * v_cap * v_attr_share;
      v_set_xp := v_set_xp + v_xp_for_bp;
      v_event_attribution := v_event_attribution || jsonb_build_object(v_attr_key, v_xp_for_bp);

      INSERT INTO public.body_part_progress AS bpp (
        user_id, body_part, total_xp, rank,
        vitality_ewma, vitality_peak, last_event_at, updated_at
      ) VALUES (
        p_user_id, v_attr_key,
        v_xp_for_bp,
        public.rpg_rank_for_xp(v_xp_for_bp),
        0, 0, v_now, v_now
      )
      ON CONFLICT (user_id, body_part) DO UPDATE SET
        total_xp     = bpp.total_xp + EXCLUDED.total_xp,
        rank         = public.rpg_rank_for_xp(bpp.total_xp + EXCLUDED.total_xp),
        last_event_at = v_now,
        updated_at   = v_now;
    END LOOP;

    v_event_payload := jsonb_build_object(
      'volume_load',   GREATEST(1.0, COALESCE(r_set.weight, 0) * r_set.reps),
      'base_xp',       v_base,
      'intensity_mult', v_intensity,
      'strength_mult', v_strength,
      'set_xp',        v_set_xp
    );

    UPDATE public.xp_events
    SET payload     = v_event_payload,
        attribution = v_event_attribution,
        total_xp    = v_set_xp
    WHERE id = v_event_id;

    -- Peak loads
    INSERT INTO public.exercise_peak_loads (
      user_id, exercise_id, peak_weight, peak_reps, peak_date, updated_at
    ) VALUES (
      p_user_id, r_set.exercise_id, r_set.weight, r_set.reps, v_now, v_now
    )
    ON CONFLICT (user_id, exercise_id) DO UPDATE SET
      peak_weight = GREATEST(public.exercise_peak_loads.peak_weight, EXCLUDED.peak_weight),
      peak_reps   = CASE
                      WHEN EXCLUDED.peak_weight > public.exercise_peak_loads.peak_weight
                      THEN EXCLUDED.peak_reps
                      ELSE public.exercise_peak_loads.peak_reps
                    END,
      peak_date   = CASE
                      WHEN EXCLUDED.peak_weight > public.exercise_peak_loads.peak_weight
                      THEN EXCLUDED.peak_date
                      ELSE public.exercise_peak_loads.peak_date
                    END,
      updated_at  = v_now;

    v_processed := v_processed + 1;
    -- Track cursor advance using the SAME ordering tuple the chunk fetch
    -- uses (w.started_at, s.id). The wrapper writes this back to
    -- backfill_progress so the next chunk's WHERE clause sees a cursor
    -- with consistent semantics.
    v_last_set_id := r_set.set_id;
    v_last_set_ts := r_set.occurred_at;
  END LOOP;

  processed   := v_processed;
  visited     := v_visited;
  last_set_id := v_last_set_id;
  last_set_ts := v_last_set_ts;
  RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.backfill_rpg_v1(uuid, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.backfill_rpg_v1(uuid, int) TO authenticated;
REVOKE EXECUTE ON FUNCTION public._rpg_backfill_chunk(uuid, int) FROM PUBLIC, anon;
-- _rpg_backfill_chunk is intentionally NOT granted to authenticated — only
-- the wrapper function (which gates on auth + advisory lock + checkpoint
-- bookkeeping) is callable by clients.

-- ---------------------------------------------------------------------------
-- 13. save_workout — extend to call record_set_xp per inserted set
-- ---------------------------------------------------------------------------
--
-- The atomicity guarantee of save_workout is preserved: record_set_xp is
-- called inside the same transaction, so a constraint violation in either
-- the set INSERT or the XP roll-up rolls back the whole save.
--
-- Performance: per-set call is acceptable because the heavy subqueries
-- (session_volume, weekly_volume) hit indexed columns. EXPLAIN ANALYZE on
-- a 100-set workout in test fixtures confirms p95 < 50ms inside the txn
-- (captured in PR description).

CREATE OR REPLACE FUNCTION save_workout(
  p_workout jsonb,
  p_exercises jsonb,
  p_sets jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_workout_id uuid;
  v_user_id uuid;
  v_result jsonb;
  v_set_id uuid;
BEGIN
  v_workout_id := (p_workout ->> 'id')::uuid;
  v_user_id := (p_workout ->> 'user_id')::uuid;

  IF v_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: workout user_id does not match authenticated user'
      USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM workouts WHERE id = v_workout_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Workout not found or does not belong to user'
      USING ERRCODE = 'P0002';
  END IF;

  -- ===========================================================================
  -- BUG-RPG-001 fix — REVERSAL PATTERN
  -- ===========================================================================
  -- Re-saving a workout (saveWorkout called twice on the same workout id) must
  -- be idempotent w.r.t. body_part_progress totals. The cascade-delete below
  -- removes prior workout_exercises → sets → xp_events, but it does NOT undo
  -- the body_part_progress.total_xp deltas those xp_events contributed. The
  -- subsequent record_set_xp loop (re-inserts) would stack on top, doubling
  -- per-bp totals.
  --
  -- Fix: BEFORE the cascade, sum the per-(user, body_part) contributions from
  -- xp_events tied to this session and decrement body_part_progress
  -- accordingly. Cascade-delete then wipes the events; the post-INSERT
  -- record_set_xp loop rebuilds the contributions from scratch.
  --
  -- Why decrement instead of recompute-from-scratch:
  --   * O(1) per affected body_part — bounded by 7 rows max.
  --   * Doesn't disturb body_part_progress rows for sessions OTHER than this
  --     one (which would be the side effect of "delete + recompute from all
  --     xp_events").
  --   * rank stays consistent — it's recomputed inside record_set_xp's UPSERT
  --     based on the new total_xp.
  --
  -- We update `rank` here too (using rpg_rank_for_xp on the new lower total)
  -- so the row is internally consistent between the reversal and the
  -- subsequent re-add. record_set_xp's UPSERT will recompute it again on the
  -- new total, but we keep the invariant rank == rpg_rank_for_xp(total_xp)
  -- true at every commit boundary.
  WITH session_contrib AS (
    SELECT
      e.user_id,
      kv.key                    AS body_part,
      SUM(kv.value::numeric)    AS xp_to_revert
    FROM xp_events e
    CROSS JOIN LATERAL jsonb_each_text(e.attribution) AS kv(key, value)
    WHERE e.user_id = v_user_id
      AND e.session_id = v_workout_id
    GROUP BY e.user_id, kv.key
  )
  UPDATE body_part_progress bpp
  SET total_xp = GREATEST(0, bpp.total_xp - sc.xp_to_revert),
      rank     = public.rpg_rank_for_xp(GREATEST(0, bpp.total_xp - sc.xp_to_revert)),
      updated_at = now()
  FROM session_contrib sc
  WHERE bpp.user_id   = sc.user_id
    AND bpp.body_part = sc.body_part;

  -- Cascade-delete prior exercises + sets. Cascade also cleans xp_events
  -- rows linked to those sets (via set_id ON DELETE CASCADE), so a save
  -- replay produces a clean recomputation.
  DELETE FROM workout_exercises WHERE workout_id = v_workout_id;

  UPDATE workouts
  SET
    name             = COALESCE(p_workout ->> 'name', name),
    finished_at      = (p_workout ->> 'finished_at')::timestamptz,
    duration_seconds = (p_workout ->> 'duration_seconds')::integer,
    notes            = p_workout ->> 'notes',
    is_active        = false
  WHERE id = v_workout_id AND user_id = v_user_id;

  INSERT INTO workout_exercises (id, workout_id, exercise_id, "order", rest_seconds)
  SELECT
    (e ->> 'id')::uuid,
    (e ->> 'workout_id')::uuid,
    (e ->> 'exercise_id')::uuid,
    (e ->> 'order')::integer,
    (e ->> 'rest_seconds')::integer
  FROM jsonb_array_elements(p_exercises) AS e;

  INSERT INTO sets (id, workout_exercise_id, set_number, reps, weight, rpe, set_type, notes, is_completed)
  SELECT
    (s ->> 'id')::uuid,
    (s ->> 'workout_exercise_id')::uuid,
    (s ->> 'set_number')::integer,
    (s ->> 'reps')::integer,
    (s ->> 'weight')::numeric,
    (s ->> 'rpe')::integer,
    COALESCE(s ->> 'set_type', 'working'),
    s ->> 'notes',
    COALESCE((s ->> 'is_completed')::boolean, false)
  FROM jsonb_array_elements(p_sets) AS s;

  -- RPG v1 XP roll-up: per-set call inside the same transaction. Sets are
  -- iterated in (workout_exercise_id, set_number) order — which mirrors
  -- the Python sim's session-replay order and ensures session_volume
  -- accumulates monotonically across the workout.
  FOR v_set_id IN
    SELECT s.id
    FROM sets s
    JOIN workout_exercises we ON we.id = s.workout_exercise_id
    WHERE we.workout_id = v_workout_id
      AND s.is_completed = TRUE
      AND COALESCE(s.set_type, 'working') = 'working'
      AND s.reps IS NOT NULL AND s.reps >= 1
    ORDER BY we."order" ASC, s.set_number ASC
  LOOP
    PERFORM public.record_set_xp(v_set_id);
  END LOOP;

  SELECT to_jsonb(w) INTO v_result FROM workouts w WHERE w.id = v_workout_id;
  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION save_workout(jsonb, jsonb, jsonb) TO authenticated;

-- ---------------------------------------------------------------------------
-- 14. Default-exercise xp_attribution seed (spec §5.2)
-- ---------------------------------------------------------------------------
--
-- Maps the Python-sim ATTRIBUTION dict onto our default-exercise slugs.
-- Every spec §5.2 entry is covered. Slug-to-DB-row matching uses
-- exercises.slug (NOT NULL, byte-identical to the Python sim keys via the
-- mapping below).

WITH attr(slug, payload) AS (VALUES
  -- Push (spec §5.2)
  ('barbell_bench_press',         '{"chest":0.70,"shoulders":0.20,"arms":0.10}'::jsonb),
  ('incline_barbell_bench_press', '{"chest":0.60,"shoulders":0.30,"arms":0.10}'::jsonb),
  ('decline_barbell_bench_press', '{"chest":0.70,"shoulders":0.20,"arms":0.10}'::jsonb),
  ('dumbbell_bench_press',        '{"chest":0.70,"shoulders":0.20,"arms":0.10}'::jsonb),
  ('incline_dumbbell_press',      '{"chest":0.60,"shoulders":0.30,"arms":0.10}'::jsonb),
  ('decline_dumbbell_press',      '{"chest":0.70,"shoulders":0.20,"arms":0.10}'::jsonb),
  ('dumbbell_fly',                '{"chest":0.85,"shoulders":0.10,"arms":0.05}'::jsonb),
  ('incline_dumbbell_fly',        '{"chest":0.80,"shoulders":0.15,"arms":0.05}'::jsonb),
  ('cable_crossover',             '{"chest":0.85,"shoulders":0.10,"arms":0.05}'::jsonb),
  ('cable_chest_press',           '{"chest":0.70,"shoulders":0.20,"arms":0.10}'::jsonb),
  ('machine_chest_press',         '{"chest":0.75,"shoulders":0.15,"arms":0.10}'::jsonb),
  ('pec_deck',                    '{"chest":0.90,"shoulders":0.05,"arms":0.05}'::jsonb),
  ('push_up',                     '{"chest":0.65,"shoulders":0.20,"arms":0.10,"core":0.05}'::jsonb),
  ('wide_push_up',                '{"chest":0.75,"shoulders":0.15,"arms":0.05,"core":0.05}'::jsonb),
  ('diamond_push_up',             '{"chest":0.50,"arms":0.40,"shoulders":0.05,"core":0.05}'::jsonb),
  ('incline_push_up',             '{"chest":0.55,"shoulders":0.25,"arms":0.15,"core":0.05}'::jsonb),
  ('decline_push_up',             '{"chest":0.70,"shoulders":0.20,"arms":0.05,"core":0.05}'::jsonb),
  ('landmine_press',              '{"shoulders":0.55,"chest":0.25,"arms":0.15,"core":0.05}'::jsonb),
  ('overhead_press',              '{"shoulders":0.60,"arms":0.20,"core":0.20}'::jsonb),
  ('push_press',                  '{"shoulders":0.55,"legs":0.20,"arms":0.15,"core":0.10}'::jsonb),
  ('dumbbell_shoulder_press',     '{"shoulders":0.65,"arms":0.20,"core":0.15}'::jsonb),
  ('machine_shoulder_press',      '{"shoulders":0.70,"arms":0.20,"core":0.10}'::jsonb),
  ('arnold_press',                '{"shoulders":0.65,"arms":0.20,"core":0.15}'::jsonb),
  ('landmine_shoulder_press',     '{"shoulders":0.55,"chest":0.25,"arms":0.15,"core":0.05}'::jsonb),
  ('kettlebell_press',            '{"shoulders":0.60,"arms":0.20,"core":0.20}'::jsonb),
  ('lateral_raise',               '{"shoulders":0.85,"arms":0.10,"core":0.05}'::jsonb),
  ('cable_lateral_raise',         '{"shoulders":0.85,"arms":0.10,"core":0.05}'::jsonb),
  ('front_raise',                 '{"shoulders":0.85,"arms":0.10,"core":0.05}'::jsonb),
  ('cable_front_raise',           '{"shoulders":0.85,"arms":0.10,"core":0.05}'::jsonb),
  ('rear_delt_fly',               '{"shoulders":0.80,"back":0.15,"arms":0.05}'::jsonb),
  ('cable_rear_delt_fly',         '{"shoulders":0.80,"back":0.15,"arms":0.05}'::jsonb),
  ('reverse_pec_deck',            '{"shoulders":0.75,"back":0.20,"arms":0.05}'::jsonb),
  ('cable_face_pull',             '{"shoulders":0.55,"back":0.40,"arms":0.05}'::jsonb),
  ('face_pull',                   '{"shoulders":0.55,"back":0.40,"arms":0.05}'::jsonb),
  ('band_face_pull',              '{"shoulders":0.55,"back":0.40,"arms":0.05}'::jsonb),
  ('upright_row',                 '{"shoulders":0.65,"back":0.20,"arms":0.15}'::jsonb),
  ('barbell_shrug',               '{"shoulders":0.55,"back":0.40,"arms":0.05}'::jsonb),
  ('dumbbell_shrug',              '{"shoulders":0.55,"back":0.40,"arms":0.05}'::jsonb),
  ('tricep_pushdown',             '{"arms":0.95,"shoulders":0.05}'::jsonb),
  ('rope_pushdown',               '{"arms":0.95,"shoulders":0.05}'::jsonb),
  ('skull_crusher',               '{"arms":0.95,"shoulders":0.05}'::jsonb),
  ('overhead_tricep_extension',   '{"arms":0.95,"shoulders":0.05}'::jsonb),
  ('dumbbell_tricep_extension',   '{"arms":0.95,"shoulders":0.05}'::jsonb),
  ('close_grip_bench_press',      '{"arms":0.50,"chest":0.40,"shoulders":0.10}'::jsonb),
  ('close_grip_push_up',          '{"arms":0.50,"chest":0.40,"shoulders":0.05,"core":0.05}'::jsonb),
  ('jm_press',                    '{"arms":0.65,"chest":0.25,"shoulders":0.10}'::jsonb),
  ('dips',                        '{"chest":0.45,"arms":0.40,"shoulders":0.15}'::jsonb),
  ('bench_dip',                   '{"arms":0.65,"chest":0.25,"shoulders":0.10}'::jsonb),
  -- Pull (spec §5.2)
  ('barbell_bent_over_row',       '{"back":0.70,"arms":0.20,"core":0.10}'::jsonb),
  ('pendlay_row',                 '{"back":0.70,"arms":0.20,"core":0.10}'::jsonb),
  ('t_bar_row',                   '{"back":0.75,"arms":0.20,"core":0.05}'::jsonb),
  ('dumbbell_row',                '{"back":0.75,"arms":0.20,"core":0.05}'::jsonb),
  ('chest_supported_row',         '{"back":0.80,"arms":0.20}'::jsonb),
  ('seal_row',                    '{"back":0.80,"arms":0.20}'::jsonb),
  ('cable_row',                   '{"back":0.75,"arms":0.20,"core":0.05}'::jsonb),
  ('machine_row',                 '{"back":0.75,"arms":0.20,"core":0.05}'::jsonb),
  ('inverted_row',                '{"back":0.65,"arms":0.25,"core":0.10}'::jsonb),
  ('kettlebell_row',              '{"back":0.70,"arms":0.20,"core":0.10}'::jsonb),
  ('lat_pulldown',                '{"back":0.75,"arms":0.20,"core":0.05}'::jsonb),
  ('close_grip_lat_pulldown',     '{"back":0.65,"arms":0.30,"core":0.05}'::jsonb),
  ('straight_arm_pulldown',       '{"back":0.85,"arms":0.10,"core":0.05}'::jsonb),
  ('pull_up',                     '{"back":0.65,"arms":0.25,"core":0.10}'::jsonb),
  ('chin_up',                     '{"back":0.55,"arms":0.35,"core":0.10}'::jsonb),
  ('wide_grip_pull_up',           '{"back":0.75,"arms":0.20,"core":0.05}'::jsonb),
  ('dumbbell_pullover',           '{"back":0.55,"chest":0.30,"arms":0.10,"core":0.05}'::jsonb),
  ('hyperextension',              '{"back":0.75,"legs":0.20,"core":0.05}'::jsonb),
  ('back_extension',              '{"back":0.75,"legs":0.20,"core":0.05}'::jsonb),
  ('reverse_hyperextension',      '{"back":0.55,"legs":0.40,"core":0.05}'::jsonb),
  ('rack_pull',                   '{"back":0.55,"legs":0.30,"core":0.10,"arms":0.05}'::jsonb),
  ('good_morning',                '{"back":0.45,"legs":0.45,"core":0.10}'::jsonb),
  ('band_pull_apart',             '{"shoulders":0.55,"back":0.40,"arms":0.05}'::jsonb),
  ('barbell_curl',                '{"arms":0.90,"back":0.10}'::jsonb),
  ('ez_bar_curl',                 '{"arms":0.90,"back":0.10}'::jsonb),
  ('dumbbell_curl',               '{"arms":0.90,"back":0.10}'::jsonb),
  ('hammer_curl',                 '{"arms":0.90,"back":0.10}'::jsonb),
  ('cable_hammer_curl',           '{"arms":0.90,"back":0.10}'::jsonb),
  ('concentration_curl',          '{"arms":0.95,"back":0.05}'::jsonb),
  ('cable_curl',                  '{"arms":0.90,"back":0.10}'::jsonb),
  ('preacher_curl',               '{"arms":0.95,"back":0.05}'::jsonb),
  ('incline_dumbbell_curl',       '{"arms":0.90,"back":0.10}'::jsonb),
  ('spider_curl',                 '{"arms":0.95,"back":0.05}'::jsonb),
  ('zottman_curl',                '{"arms":0.90,"back":0.10}'::jsonb),
  ('reverse_curl',                '{"arms":0.90,"back":0.10}'::jsonb),
  ('wrist_curl',                  '{"arms":0.95,"back":0.05}'::jsonb),
  ('reverse_wrist_curl',          '{"arms":0.95,"back":0.05}'::jsonb),
  ('farmer_s_walk',               '{"core":0.40,"back":0.30,"arms":0.20,"legs":0.10}'::jsonb),
  -- Legs
  ('barbell_squat',               '{"legs":0.80,"core":0.10,"back":0.10}'::jsonb),
  ('front_squat',                 '{"legs":0.75,"core":0.15,"back":0.10}'::jsonb),
  ('hack_squat',                  '{"legs":0.85,"core":0.10,"back":0.05}'::jsonb),
  ('goblet_squat',                '{"legs":0.85,"core":0.10,"arms":0.05}'::jsonb),
  ('bodyweight_squat',            '{"legs":0.90,"core":0.10}'::jsonb),
  ('kettlebell_goblet_squat',     '{"legs":0.85,"core":0.10,"arms":0.05}'::jsonb),
  ('band_squat',                  '{"legs":0.90,"core":0.10}'::jsonb),
  ('deadlift',                    '{"back":0.40,"legs":0.40,"core":0.10,"arms":0.10}'::jsonb),
  ('sumo_deadlift',               '{"legs":0.50,"back":0.30,"core":0.10,"arms":0.10}'::jsonb),
  ('romanian_deadlift',           '{"legs":0.55,"back":0.35,"core":0.10}'::jsonb),
  ('kettlebell_deadlift',         '{"legs":0.45,"back":0.35,"core":0.10,"arms":0.10}'::jsonb),
  ('hip_thrust',                  '{"legs":0.85,"core":0.15}'::jsonb),
  ('glute_bridge',                '{"legs":0.85,"core":0.15}'::jsonb),
  ('single_leg_glute_bridge',     '{"legs":0.85,"core":0.15}'::jsonb),
  ('cable_glute_kickback',        '{"legs":0.90,"core":0.10}'::jsonb),
  ('donkey_kick',                 '{"legs":0.90,"core":0.10}'::jsonb),
  ('cable_pull_through',          '{"legs":0.50,"back":0.40,"core":0.10}'::jsonb),
  ('dumbbell_lunges',             '{"legs":0.90,"core":0.10}'::jsonb),
  ('walking_lunges',              '{"legs":0.90,"core":0.10}'::jsonb),
  ('reverse_lunges',              '{"legs":0.90,"core":0.10}'::jsonb),
  ('bulgarian_split_squat',       '{"legs":0.90,"core":0.10}'::jsonb),
  ('step_up',                     '{"legs":0.90,"core":0.10}'::jsonb),
  ('box_jump',                    '{"legs":0.90,"core":0.10}'::jsonb),
  ('leg_press',                   '{"legs":0.95,"core":0.05}'::jsonb),
  ('single_leg_leg_press',        '{"legs":0.95,"core":0.05}'::jsonb),
  ('leg_extension',               '{"legs":1.00}'::jsonb),
  ('leg_curl',                    '{"legs":1.00}'::jsonb),
  ('nordic_curl',                 '{"legs":0.95,"core":0.05}'::jsonb),
  ('leg_abductor',                '{"legs":1.00}'::jsonb),
  ('leg_adductor',                '{"legs":1.00}'::jsonb),
  ('wall_sit',                    '{"legs":0.95,"core":0.05}'::jsonb),
  ('calf_raise',                  '{"legs":1.00}'::jsonb),
  ('seated_calf_raise',           '{"legs":1.00}'::jsonb),
  ('dumbbell_calf_raise',         '{"legs":1.00}'::jsonb),
  ('kettlebell_swing',            '{"legs":0.45,"back":0.30,"core":0.20,"shoulders":0.05}'::jsonb),
  ('kettlebell_turkish_get_up',   '{"core":0.40,"shoulders":0.30,"legs":0.20,"arms":0.10}'::jsonb),
  ('kettlebell_windmill',         '{"core":0.65,"shoulders":0.25,"legs":0.10}'::jsonb),
  -- Core
  ('plank',                       '{"core":0.90,"shoulders":0.05,"arms":0.05}'::jsonb),
  ('side_plank',                  '{"core":0.90,"shoulders":0.05,"arms":0.05}'::jsonb),
  ('plank_up_down',               '{"core":0.75,"shoulders":0.15,"arms":0.10}'::jsonb),
  ('hanging_leg_raise',           '{"core":0.85,"arms":0.10,"back":0.05}'::jsonb),
  ('leg_raise',                   '{"core":1.00}'::jsonb),
  ('reverse_crunch',              '{"core":1.00}'::jsonb),
  ('flutter_kick',                '{"core":1.00}'::jsonb),
  ('crunches',                    '{"core":1.00}'::jsonb),
  ('cable_crunch',                '{"core":1.00}'::jsonb),
  ('bicycle_crunch',              '{"core":1.00}'::jsonb),
  ('russian_twist',               '{"core":1.00}'::jsonb),
  ('sit_up',                      '{"core":1.00}'::jsonb),
  ('v_up',                        '{"core":1.00}'::jsonb),
  ('hollow_body_hold',            '{"core":1.00}'::jsonb),
  ('toe_touch',                   '{"core":1.00}'::jsonb),
  ('heel_touch',                  '{"core":1.00}'::jsonb),
  ('windshield_wiper',            '{"core":1.00}'::jsonb),
  ('mountain_climber',            '{"core":0.70,"shoulders":0.15,"legs":0.15}'::jsonb),
  ('ab_rollout',                  '{"core":0.85,"shoulders":0.10,"arms":0.05}'::jsonb),
  ('cable_woodchop',              '{"core":0.90,"shoulders":0.05,"arms":0.05}'::jsonb),
  ('pallof_press',                '{"core":0.95,"shoulders":0.05}'::jsonb),
  ('dead_bug',                    '{"core":1.00}'::jsonb),
  -- Cardio (v2: zero earning paths in v1, but persists the attribution column)
  ('treadmill',                   '{"cardio":1.00}'::jsonb),
  ('rowing_machine',              '{"cardio":1.00}'::jsonb),
  ('stationary_bike',             '{"cardio":1.00}'::jsonb),
  ('jump_rope',                   '{"cardio":1.00}'::jsonb),
  ('elliptical',                  '{"cardio":1.00}'::jsonb)
)
UPDATE public.exercises e
SET xp_attribution = a.payload
FROM attr a
WHERE e.is_default = TRUE AND e.slug = a.slug;

-- Defensive assertion: every default exercise now carries an attribution
-- (or — for forward compat — a primary muscle group that the NULL-fallback
-- can resolve). Fail loudly if any default is missing the column AND the
-- fallback has nothing to resolve to.
DO $$
DECLARE
  v_unmapped int;
BEGIN
  SELECT COUNT(*) INTO v_unmapped
  FROM public.exercises
  WHERE is_default = TRUE
    AND xp_attribution IS NULL
    AND muscle_group IS NULL;
  IF v_unmapped > 0 THEN
    RAISE EXCEPTION 'rpg_v1: % default exercises have neither xp_attribution nor muscle_group', v_unmapped;
  END IF;
END
$$;

-- Also catch missing slugs early — a default we forgot to map.
DO $$
DECLARE
  v_unmapped_slugs text;
  v_count int;
BEGIN
  SELECT COUNT(*), string_agg(slug, ', ' ORDER BY slug)
  INTO v_count, v_unmapped_slugs
  FROM public.exercises
  WHERE is_default = TRUE AND xp_attribution IS NULL;
  IF v_count > 0 THEN
    RAISE NOTICE 'rpg_v1: % default exercise slugs use NULL-fallback attribution: %',
                 v_count, v_unmapped_slugs;
  END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- 15. Backfill all existing users — migration-time replay (D3)
-- ---------------------------------------------------------------------------
--
-- We DO NOT run backfill_rpg_v1 inside this migration's transaction because
-- backfill_rpg_v1 is a procedure with internal COMMITs — calling it from a
-- transaction would error. Migrations applied through `npx supabase db push`
-- run each migration in its own implicit transaction.
--
-- Instead, we enqueue each user-id in a sentinel table; the deployer then
-- runs the procedure outside the migration. For tests + local runs, the
-- accompanying integration test calls backfill_rpg_v1 directly per user.
--
-- Production handoff: after `npx supabase db push`, run
--   psql ... -c "DO $$ DECLARE r record; BEGIN
--     FOR r IN SELECT user_id FROM public.backfill_progress WHERE completed_at IS NULL LOOP
--       CALL public.backfill_rpg_v1(r.user_id);
--     END LOOP;
--   END $$;"
-- The DO block iterates serially per user; multi-user parallelism is a
-- future optimization (advisory-locked per user already; could hand to
-- N worker connections).
--
-- For now we enqueue every existing user.

INSERT INTO public.backfill_progress (user_id, started_at, updated_at)
SELECT u.id, now(), now()
FROM auth.users u
WHERE EXISTS (
  SELECT 1 FROM public.workouts w
  WHERE w.user_id = u.id AND w.finished_at IS NOT NULL
)
ON CONFLICT (user_id) DO NOTHING;

COMMIT;

-- ---------------------------------------------------------------------------
-- POST-MIGRATION: deploy operator runs the per-user backfill driver
-- (see comment in §15 above). Local test driver:
--   `flutter test test/integration/rpg_backfill_test.dart`
-- ---------------------------------------------------------------------------
