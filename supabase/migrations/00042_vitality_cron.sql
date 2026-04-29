-- =============================================================================
-- Phase 18d Stage 1 — Vitality nightly EWMA recompute (cron + idempotency table)
-- Migration: 00042_vitality_cron
--
-- This migration sets up the Postgres-side scaffolding for the nightly
-- Vitality EWMA recompute. The actual computation lives in the
-- `vitality-nightly` Edge Function (TypeScript) — Postgres just owns
--   1. The idempotency dedup table (`vitality_runs`).
--   2. The pg_cron schedule that POSTs to the Edge Function once per UTC day.
--
-- Why an Edge Function and not a SQL procedure? The EWMA math (asymmetric
-- α with `exp(-Δt/τ)`) and the per-user fan-out are both more readable in
-- TypeScript, and the Edge Function can be invoked manually for ad-hoc
-- recomputes (integration tests, support escalations) without granting
-- SQL EXECUTE on a SECURITY DEFINER function. Postgres still enforces the
-- idempotency contract via `vitality_runs` PRIMARY KEY.
--
-- Spec references:
--   §8 Vitality formula (asymmetric EWMA)
--   §12.2 Vitality update cadence rationale (daily, not per-set)
--   §12.3 Performance budget (10min for 100k users)
--
-- Dependencies:
--   * pg_cron + pg_net extensions guaranteed installed by 00026.
--   * Vault secrets `edge_functions_url` and `service_role_key` set per the
--     pattern documented in 00027 (operator action). Same secrets are
--     reused — no new operator action required if 00027 has been run.
--
-- Forward-only: this migration creates new objects only. It does not drop
-- anything from earlier migrations.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. vitality_runs — idempotency dedup table
-- ---------------------------------------------------------------------------
--
-- One row per (user_id, run_date) — `run_date` is the UTC calendar day the
-- nightly job processed the user on. The Edge Function INSERTs into this
-- table FIRST, before computing anything; a duplicate (PRIMARY KEY conflict)
-- short-circuits the worker without touching `body_part_progress`.
--
-- We do not auto-prune old rows: at our user count + cardinality this table
-- adds ~365 rows/user/year, trivial to retain and useful for forensics
-- ("did the nightly job run for user X on day Y?"). A future migration can
-- add a retention policy if needed.

CREATE TABLE IF NOT EXISTS public.vitality_runs (
  user_id      uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  run_date     date        NOT NULL,
  inserted_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, run_date)
);

-- Index for "did we run this user today?" lookups by run_date alone (the
-- Edge Function paginates users; PRIMARY KEY already covers the common
-- (user_id, run_date) probe).
CREATE INDEX IF NOT EXISTS vitality_runs_run_date_idx
  ON public.vitality_runs(run_date);

-- RLS: owner SELECT only. Writes come from the Edge Function via service-role
-- so they bypass RLS — the policy below is purely so a user can introspect
-- their own run history if a debug surface is ever added.
ALTER TABLE public.vitality_runs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS vitality_runs_select_own ON public.vitality_runs;
CREATE POLICY vitality_runs_select_own
  ON public.vitality_runs FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 1b. Partial index on body_part_progress for the nightly active-pool query
-- ---------------------------------------------------------------------------
--
-- The Edge Function's UNION active-pool query filters rows on
-- `vitality_ewma > 0` to find users still carrying conditioning that needs
-- decay. Without an index, that's a sequential scan over body_part_progress
-- every nightly run — at the §12.3 budget target (100k users × 6 body parts
-- = 600k rows) the seq scan blows the 10-min budget silently.
--
-- The partial WHERE clause keeps this index narrow: only rows with
-- vitality_ewma > 0 are indexed, so the index size scales with the active
-- conditioning population, not the full table. Day-0 users (peak == 0,
-- ewma == 0) and fully-decayed body parts contribute zero rows here.
--
-- Indexed column is `user_id` because the Edge Function pages users into
-- chunks by user_id; the planner uses this as both a filter (WHERE
-- vitality_ewma > 0, satisfied by the partial predicate) and an index-only
-- scan source for the user_id list.
--
-- Idempotent (CREATE INDEX IF NOT EXISTS) — safe to re-apply against a DB
-- that already has the index from a previous push.
CREATE INDEX IF NOT EXISTS body_part_progress_vitality_ewma_nonzero_idx
  ON public.body_part_progress (user_id)
  WHERE vitality_ewma > 0;

-- ---------------------------------------------------------------------------
-- 2. invoke_vitality_nightly() — server-side cron entrypoint
-- ---------------------------------------------------------------------------
--
-- Mirrors the pattern from 00027: SECURITY DEFINER, secrets sourced from
-- `vault.decrypted_secrets`, graceful no-op (RAISE NOTICE, not RAISE
-- EXCEPTION) when secrets are missing so a misconfigured environment does
-- not flood the Postgres log or trigger pg_cron's auto-disable.
--
-- The Edge Function ignores any user-supplied JWT and authenticates strictly
-- on the service-role key in the Authorization header. The `chunk` body
-- parameter is OPTIONAL — leaving it absent processes all users in one pass.
-- We invoke without `chunk` here; chunking is wired in the Edge Function
-- and can be enabled later by replacing this single PERFORM with ten
-- parallel calls (one per chunk_id 0..9).

CREATE OR REPLACE FUNCTION public.invoke_vitality_nightly()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_function_url text;
  v_service_key  text;
BEGIN
  -- Source the same vault secrets registered by 00027. Renaming either name
  -- requires a paired update in this function and the operator setup doc.
  SELECT
    MAX(decrypted_secret) FILTER (WHERE name = 'edge_functions_url'),
    MAX(decrypted_secret) FILTER (WHERE name = 'service_role_key')
    INTO v_function_url, v_service_key
    FROM vault.decrypted_secrets
   WHERE name IN ('edge_functions_url', 'service_role_key');

  IF v_function_url IS NULL OR v_service_key IS NULL THEN
    RAISE NOTICE 'invoke_vitality_nightly: vault secrets edge_functions_url or service_role_key not configured; skipping';
    RETURN;
  END IF;

  -- Fire-and-forget POST. pg_net runs HTTP calls asynchronously off the
  -- session, so the cron tick returns immediately. The Edge Function's
  -- own logging is the source of truth for run outcomes; we record the
  -- per-user (user_id, run_date) row inside the function itself.
  --
  -- timeout_milliseconds is the *per-request* socket timeout, not the
  -- full processing budget — at 100k users the Edge Function streams
  -- per-user updates back to Postgres via the supabase-js client and
  -- the HTTP response itself is small. 60s is generous for the initial
  -- handshake + body upload.
  PERFORM net.http_post(
    url                  := v_function_url || '/vitality-nightly',
    headers              := jsonb_build_object(
                              'Content-Type',  'application/json',
                              'Authorization', 'Bearer ' || v_service_key
                            ),
    body                 := jsonb_build_object(
                              'source', 'cron_nightly'
                            ),
    timeout_milliseconds := 60000
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.invoke_vitality_nightly() FROM PUBLIC, anon, authenticated;
-- pg_cron runs schedule entries as the cron superuser; no GRANT needed for
-- the scheduler itself. Keeping the function un-granted to authenticated
-- prevents any client from triggering a fire-and-forget POST loop.

-- ---------------------------------------------------------------------------
-- 3. pg_cron schedule — 03:00 UTC daily
-- ---------------------------------------------------------------------------
--
-- 03:00 UTC = midnight America/Sao_Paulo (BRT, our largest cohort window).
-- Most active users are asleep and the system load is at its trough — by
-- the time they wake up to log a workout, the previous day's vitality has
-- been recomputed.
--
-- Idempotency at the schedule level: if pg_cron retries (it doesn't by
-- default, but operator could re-trigger manually), the per-user
-- `vitality_runs` PRIMARY KEY conflict makes the worker a no-op for users
-- already processed today.

DO $$
DECLARE
  v_existing int;
BEGIN
  SELECT jobid INTO v_existing
    FROM cron.job
   WHERE jobname = 'vitality_nightly_03utc';

  IF v_existing IS NOT NULL THEN
    PERFORM cron.unschedule(v_existing);
  END IF;

  PERFORM cron.schedule(
    'vitality_nightly_03utc',
    '0 3 * * *',
    $cron$ SELECT public.invoke_vitality_nightly(); $cron$
  );
END;
$$;

COMMIT;
