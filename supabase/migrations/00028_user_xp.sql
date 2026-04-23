-- =============================================================================
-- Phase 17b — XP & Level data layer
-- Migration: 00028_user_xp
--
-- Introduces two tables and one RPC:
--
--   * public.user_xp     — one row per user, rolled-up totals (total_xp,
--                           current_level, rank). Read-only for owners;
--                           writes happen exclusively via award_xp().
--   * public.xp_events   — append-only ledger of every XP-awarding event
--                           (workout, pr, quest, comeback, milestone,
--                           retro). Owner-readable only.
--   * public.award_xp(...) RPC — SECURITY DEFINER entry point. Validates
--                           caller == p_user_id, inserts one xp_events row,
--                           rolls up user_xp in a single transaction.
--
-- The level curve and rank thresholds are NOT encoded in SQL — they are
-- client-side (XpCalculator, kRankThresholds) so later sub-phases can retune
-- without a migration. The RPC accepts pre-computed level + rank and
-- stores them as denormalized snapshots; a follow-up sub-phase (17d) can
-- re-derive on read if we ever change the curve.
--
-- Idempotency: this migration is safe to re-run by using IF NOT EXISTS
-- guards on every create. The RPC is replaced via CREATE OR REPLACE.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.user_xp (
  user_id           uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  total_xp          bigint      NOT NULL DEFAULT 0 CHECK (total_xp >= 0),
  current_level     integer     NOT NULL DEFAULT 1 CHECK (current_level >= 1),
  rank              text        NOT NULL DEFAULT 'rookie'
                                  CHECK (rank IN ('rookie','iron','copper','silver',
                                                  'gold','platinum','diamond')),
  last_xp_event_id  uuid,
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.xp_events (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  workout_id  uuid        REFERENCES public.workouts(id) ON DELETE CASCADE,
  amount      integer     NOT NULL CHECK (amount > 0),
  source      text        NOT NULL CHECK (source IN
                          ('workout','pr','quest','comeback','milestone','retro')),
  breakdown   jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Index for per-user chronological reads (character sheet timeline, 17d).
CREATE INDEX IF NOT EXISTS idx_xp_events_user_created
  ON public.xp_events (user_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

ALTER TABLE public.user_xp    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.xp_events  ENABLE ROW LEVEL SECURITY;

-- user_xp: owner SELECT only. No INSERT/UPDATE/DELETE policies — the
-- award_xp() function runs as SECURITY DEFINER and bypasses RLS for writes.
DROP POLICY IF EXISTS user_xp_select_own ON public.user_xp;
CREATE POLICY user_xp_select_own
  ON public.user_xp FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- xp_events: owner SELECT only. Inserts go through award_xp().
DROP POLICY IF EXISTS xp_events_select_own ON public.xp_events;
CREATE POLICY xp_events_select_own
  ON public.xp_events FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- award_xp RPC
-- ---------------------------------------------------------------------------
--
-- Signature:
--   award_xp(p_user_id uuid, p_workout_id uuid, p_amount int, p_source text,
--            p_breakdown jsonb)
--     → (total_xp bigint, current_level int, rank text)
--
-- Contract:
--   * caller must equal p_user_id (enforced against auth.uid())
--   * inserts one xp_events row
--   * upserts user_xp, adding p_amount to total_xp
--   * stores the passed current_level + rank as-is; the client has already
--     computed them from the new total via XpCalculator
--
-- The function does NOT compute the level curve server-side. Locating that
-- logic client-side keeps the curve tuneable without a migration.
-- p_breakdown is expected to carry pre-computed `level` and `rank` fields;
-- if absent, we fall back to the existing row (preserves idempotency of
-- same-amount retries).

CREATE OR REPLACE FUNCTION public.award_xp(
  p_user_id     uuid,
  p_workout_id  uuid,
  p_amount      integer,
  p_source      text,
  p_breakdown   jsonb
)
RETURNS TABLE (total_xp bigint, current_level integer, rank text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_id  uuid;
  v_level     integer;
  v_rank      text;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: award_xp caller does not match p_user_id'
      USING ERRCODE = '42501';
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'award_xp: p_amount must be > 0 (got %)', p_amount
      USING ERRCODE = '22023';
  END IF;

  IF p_source NOT IN ('workout','pr','quest','comeback','milestone','retro') THEN
    RAISE EXCEPTION 'award_xp: unknown source %', p_source
      USING ERRCODE = '22023';
  END IF;

  -- Client-computed snapshot values. When the client forgot to send them
  -- (defensive default) fall back to existing row so we never demote.
  v_level := COALESCE((p_breakdown ->> 'level')::integer, 1);
  v_rank  := COALESCE(p_breakdown ->> 'rank', 'rookie');

  INSERT INTO public.xp_events (user_id, workout_id, amount, source, breakdown)
  VALUES (p_user_id, p_workout_id, p_amount, p_source, p_breakdown)
  RETURNING id INTO v_event_id;

  INSERT INTO public.user_xp (user_id, total_xp, current_level, rank,
                              last_xp_event_id, updated_at)
  VALUES (p_user_id, p_amount, v_level, v_rank, v_event_id, now())
  ON CONFLICT (user_id) DO UPDATE
     SET total_xp         = public.user_xp.total_xp + EXCLUDED.total_xp,
         -- GREATEST: never demote level/rank on a retroactive insert that
         -- carries a stale client snapshot. This keeps the roll-up
         -- monotonic w.r.t. the highest level ever awarded.
         current_level    = GREATEST(public.user_xp.current_level,
                                     EXCLUDED.current_level),
         rank             = CASE
                              WHEN public.user_xp.current_level >=
                                   EXCLUDED.current_level THEN public.user_xp.rank
                              ELSE EXCLUDED.rank
                            END,
         last_xp_event_id = EXCLUDED.last_xp_event_id,
         updated_at       = now();

  RETURN QUERY
    SELECT u.total_xp, u.current_level, u.rank
      FROM public.user_xp u
     WHERE u.user_id = p_user_id;
END;
$$;

-- Tight grant: only authenticated users may even ATTEMPT the call; the
-- auth.uid() check inside enforces that they can only award XP to themselves.
REVOKE EXECUTE ON FUNCTION public.award_xp(uuid, uuid, integer, text, jsonb)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.award_xp(uuid, uuid, integer, text, jsonb)
  TO authenticated;
