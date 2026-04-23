-- =============================================================================
-- Phase 17b — Retroactive XP backfill
-- Migration: 00029_retroactive_xp
--
-- Introduces `retro_backfill_xp(p_user_id uuid)` — a one-shot, idempotent
-- procedure that walks every completed workout a user already has and
-- synthesises an `xp_events (source='retro')` row + user_xp roll-up, so
-- existing lifters arrive at Phase 17b with a non-zero LVL that reflects
-- their real training history.
--
-- Why this is a one-call procedure and not a trigger: retro is a
-- historical snapshot. Future workouts award XP via `award_xp()` from
-- the client, driven by the same breakdown the celebration overlay
-- shows. Retro is only ever invoked once per user (first launch after
-- the 17b update) and is safe to re-run.
--
-- Idempotency guard
-- -----------------
-- The guard is: skip any workout that already has a matching
-- xp_events (user_id, workout_id, source='retro') row. We keep this
-- as a query-time check rather than a DB-level UNIQUE index because
-- the xp_events table supports multi-source writes (a single workout
-- can later generate a 'workout' + 'pr' + 'comeback' row), and a
-- naive UNIQUE on (user_id, workout_id, source) would be fine for
-- retro but over-restrictive if we ever want to allow idempotent
-- re-issues for the other sources. Keeping guards per source in
-- application code (SQL here, Dart later) gives more flexibility
-- and the same correctness guarantee for this specific function.
--
-- Formula (mirrors XpCalculator.compute on the client, sans comeback
-- which by definition does not apply to retroactive inserts):
--
--   base      = 50 per workout
--   volume    = floor(sum(weight * reps for completed working sets) / 500)
--   intensity = sum((rpe - 5) * 10) for completed working sets where rpe > 5
--   pr        = 100 for each first-time weight PR at time-of-workout
--             + 50 for each first-time rep PR at time-of-workout
--   quest     = 0 (no retroactive quest detection)
--   comeback  = 0 (retro users have no comeback context)
--
-- total = base + volume + intensity + pr
--
-- PR detection walks workouts in chronological order so `time-of-workout`
-- comparisons can be done with a running max per exercise.
--
-- The entire user's backfill runs in a single transaction implicitly
-- because SECURITY DEFINER plpgsql functions inherit the caller's
-- transaction (Supabase wraps each RPC in one).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.retro_backfill_xp(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_workout     record;
  v_base        integer;
  v_volume      integer;
  v_intensity   integer;
  v_pr_points   integer;
  v_total_kg    numeric;
  v_amount      integer;
  v_breakdown   jsonb;
  v_event_id    uuid;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: retro_backfill_xp caller does not match p_user_id'
      USING ERRCODE = '42501';
  END IF;

  -- Running-max table for per-exercise PR detection. We materialise it as
  -- a temporary table (session-scoped) so complex joins stay readable.
  CREATE TEMP TABLE IF NOT EXISTS _retro_pr_state (
    exercise_id uuid PRIMARY KEY,
    max_weight  numeric NOT NULL DEFAULT 0,
    max_reps    integer NOT NULL DEFAULT 0
  ) ON COMMIT DROP;

  -- Defensive truncation in case this session already ran once
  -- (connection pooler may reuse a session that had this temp table).
  -- TRUNCATE is used instead of DELETE (no WHERE clause) to avoid the
  -- PostgREST db-disallow-unsafe-deletes safety check.
  TRUNCATE _retro_pr_state;

  FOR v_workout IN
    SELECT w.id           AS workout_id,
           w.finished_at
      FROM public.workouts w
     WHERE w.user_id = p_user_id
       AND w.is_active = false
       AND w.finished_at IS NOT NULL
       AND NOT EXISTS (
             SELECT 1 FROM public.xp_events e
              WHERE e.user_id    = p_user_id
                AND e.workout_id = w.id
                AND e.source     = 'retro'
           )
     ORDER BY w.finished_at ASC
  LOOP
    -- Volume component: sum of completed working sets' weight * reps.
    SELECT COALESCE(SUM(s.weight * s.reps), 0)
      INTO v_total_kg
      FROM public.sets s
      JOIN public.workout_exercises we ON we.id = s.workout_exercise_id
     WHERE we.workout_id = v_workout.workout_id
       AND s.is_completed = true
       AND s.set_type = 'working'
       AND s.weight IS NOT NULL
       AND s.reps   IS NOT NULL;

    v_base      := 50;
    v_volume    := FLOOR(COALESCE(v_total_kg, 0) / 500.0)::integer;

    -- Intensity: sum((rpe - 5) * 10) for rpe > 5, completed working sets.
    SELECT COALESCE(SUM((s.rpe - 5) * 10), 0)
      INTO v_intensity
      FROM public.sets s
      JOIN public.workout_exercises we ON we.id = s.workout_exercise_id
     WHERE we.workout_id = v_workout.workout_id
       AND s.is_completed = true
       AND s.set_type = 'working'
       AND s.rpe IS NOT NULL
       AND s.rpe > 5;

    -- PR detection against the running max per exercise. We count
    -- first-time weight PRs (+100) and first-time rep PRs (+50) at
    -- time-of-workout. "First-time" here means "exceeds the running
    -- max built from every prior workout in this loop" — i.e. the
    -- same semantics the live PR detector uses, just rolled forward
    -- over history.
    v_pr_points := 0;

    -- For each exercise touched in this workout, compare its best
    -- completed working-set weight/reps against _retro_pr_state.
    WITH best_per_exercise AS (
      SELECT we.exercise_id,
             MAX(s.weight) FILTER (
               WHERE s.is_completed AND s.set_type = 'working'
                 AND s.weight IS NOT NULL
             ) AS w_max,
             MAX(s.reps) FILTER (
               WHERE s.is_completed AND s.set_type = 'working'
                 AND s.reps IS NOT NULL
             ) AS r_max
        FROM public.workout_exercises we
        JOIN public.sets s ON s.workout_exercise_id = we.id
       WHERE we.workout_id = v_workout.workout_id
       GROUP BY we.exercise_id
    ),
    prs AS (
      SELECT bpe.exercise_id,
             bpe.w_max,
             bpe.r_max,
             COALESCE(st.max_weight, 0) AS prev_w,
             COALESCE(st.max_reps,   0) AS prev_r
        FROM best_per_exercise bpe
        LEFT JOIN _retro_pr_state st ON st.exercise_id = bpe.exercise_id
    )
    SELECT COALESCE(SUM(
             CASE WHEN w_max IS NOT NULL AND w_max > prev_w THEN 100 ELSE 0 END
             +
             CASE WHEN r_max IS NOT NULL AND r_max > prev_r THEN 50  ELSE 0 END
           ), 0)::integer
      INTO v_pr_points
      FROM prs;

    -- Roll running-max forward for next iteration's comparisons.
    INSERT INTO _retro_pr_state (exercise_id, max_weight, max_reps)
    SELECT bpe.exercise_id,
           GREATEST(COALESCE((SELECT max_weight FROM _retro_pr_state s
                              WHERE s.exercise_id = bpe.exercise_id), 0),
                    COALESCE(bpe.w_max, 0)),
           GREATEST(COALESCE((SELECT max_reps   FROM _retro_pr_state s
                              WHERE s.exercise_id = bpe.exercise_id), 0),
                    COALESCE(bpe.r_max, 0))
      FROM (
        SELECT we.exercise_id,
               MAX(s.weight) FILTER (
                 WHERE s.is_completed AND s.set_type = 'working'
                   AND s.weight IS NOT NULL
               ) AS w_max,
               MAX(s.reps) FILTER (
                 WHERE s.is_completed AND s.set_type = 'working'
                   AND s.reps IS NOT NULL
               ) AS r_max
          FROM public.workout_exercises we
          JOIN public.sets s ON s.workout_exercise_id = we.id
         WHERE we.workout_id = v_workout.workout_id
         GROUP BY we.exercise_id
      ) bpe
    ON CONFLICT (exercise_id) DO UPDATE
      SET max_weight = GREATEST(_retro_pr_state.max_weight,
                                EXCLUDED.max_weight),
          max_reps   = GREATEST(_retro_pr_state.max_reps,
                                EXCLUDED.max_reps);

    v_amount := v_base + v_volume + v_intensity + v_pr_points;

    -- Skip workouts that produce zero XP. An `amount > 0` CHECK on
    -- xp_events would otherwise reject the insert. This only fires
    -- for empty workouts (no completed working sets) and keeps the
    -- ledger meaningful.
    IF v_amount <= 0 THEN
      CONTINUE;
    END IF;

    v_breakdown := jsonb_build_object(
      'base',      v_base,
      'volume',    v_volume,
      'intensity', v_intensity,
      'pr',        v_pr_points,
      'quest',     0,
      'comeback',  0,
      'total',     v_amount,
      'retro',     true
    );

    INSERT INTO public.xp_events (user_id, workout_id, amount, source, breakdown,
                                  created_at)
    VALUES (p_user_id, v_workout.workout_id, v_amount, 'retro', v_breakdown,
            v_workout.finished_at)
    RETURNING id INTO v_event_id;
  END LOOP;

  -- Roll up the user_xp row from the ledger. We recompute total_xp from
  -- scratch rather than incrementing so the retro portion is idempotent:
  -- re-running this function against an already-seeded user never
  -- double-counts historical workouts. (Live xp_events accrued since the
  -- first run remain in the sum, so total_xp after a re-run = retro XP +
  -- any post-retro events, which is the intended behavior.)
  --
  -- Level and rank are NOT recomputed server-side; the client reads
  -- total_xp and derives them via XpCalculator/kRankThresholds. A
  -- newly-backfilled user gets their level/rank the next time they open
  -- the app and xpProvider emits. For the stored snapshot we fall back
  -- to 1/rookie, which the client will overwrite on first summary read.
  INSERT INTO public.user_xp (user_id, total_xp, current_level, rank, updated_at)
  SELECT p_user_id,
         COALESCE(SUM(amount), 0),
         1,
         'rookie',
         now()
    FROM public.xp_events
   WHERE user_id = p_user_id
  ON CONFLICT (user_id) DO UPDATE
    SET total_xp   = EXCLUDED.total_xp,
        updated_at = now();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.retro_backfill_xp(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.retro_backfill_xp(uuid) TO authenticated;
