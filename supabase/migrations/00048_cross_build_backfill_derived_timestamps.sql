-- =============================================================================
-- Cluster 7 — DB integrity (BUG-034)
-- Migration: 00048_cross_build_backfill_derived_timestamps
--
-- Problem: 00043 backfilled cross-build distinction titles with
--          `earned_at = now()`, so every backfilled user shares an identical
--          timestamp for each cross-build slug. "Recently earned" UIs
--          surface the entire backfilled cohort as a single uniform spike,
--          which reads as an obvious data event rather than organic
--          progression.
--
-- Fix: For each cross-build row whose `earned_at` originated from the 00043
--      backfill, replace it with a per-user derived timestamp:
--          MAX(earned_at) of the user's existing per-body-part / non-cross-
--          build titles, plus 1ms.
--      That places the cross-build unlock just after the most recent
--      qualifying per-body-part title — temporally plausible, since by
--      definition the cross-build predicate fires only once a user has
--      accumulated enough body-part rank to satisfy it.
--
-- Cross-build slugs (mirrored from CrossBuildTitleEvaluator):
--   pillar_walker, broad_shouldered, even_handed, iron_bound, saga_forged
--
-- Idempotency strategy:
--   This is a one-shot data correction, not an incremental backfill. We
--   record a single sentinel row in `public.migration_checkpoints` after
--   the UPDATE runs. Re-runs check the sentinel and short-circuit. Two
--   safeguards together:
--     1. `pg_advisory_xact_lock(hashtext('00048_cross_build_backfill_ts'))`
--        serializes concurrent applies (defensive — `db push` is single-
--        threaded in practice, but cheap insurance against parallel CLI
--        runs from CI + a developer machine).
--     2. The sentinel row in `migration_checkpoints` makes the migration
--        a no-op on the second invocation. Without it, a re-run would
--        shift each cross-build row by another +1ms.
--
-- A separate `migration_checkpoints` table is intentional: previous one-shot
-- fixes (notably the RPG backfill in 00040) used a similar pattern, but with
-- per-feature checkpoint tables. Centralizing future one-shot data fixes on
-- a single small table keeps the migration footprint clean.
--
-- NOTE: Supabase CLI wraps each migration in an implicit transaction; the
-- advisory lock is automatically released at COMMIT.
-- =============================================================================

-- Checkpoint table for one-shot data-correction migrations.
-- Each row pins a (key, applied_at) pair. Future one-shot data fixes can
-- reuse this table by inserting their own key.
CREATE TABLE IF NOT EXISTS public.migration_checkpoints (
  key        text        PRIMARY KEY,
  applied_at timestamptz NOT NULL DEFAULT now(),
  notes      text
);

-- Lock service-role-only — this table is never read or written from
-- application code; it exists solely for migration bookkeeping.
ALTER TABLE public.migration_checkpoints ENABLE ROW LEVEL SECURITY;
-- (No policies = no rows visible to authenticated/anon clients. Service
-- role bypasses RLS by default.)

DO $$
DECLARE
  _already_applied boolean;
BEGIN
  -- Serialize concurrent attempts (defensive).
  PERFORM pg_advisory_xact_lock(hashtext('00048_cross_build_backfill_ts'));

  -- Sentinel guard — short-circuit on re-run.
  SELECT EXISTS (
    SELECT 1 FROM public.migration_checkpoints
    WHERE key = '00048_cross_build_backfill_ts'
  ) INTO _already_applied;

  IF _already_applied THEN
    RAISE NOTICE
      'Migration 00048 already applied; skipping derived-timestamp backfill.';
    RETURN;
  END IF;

  -- Replace cross-build earned_at with a per-user derived timestamp.
  -- COALESCE keeps the original timestamp for users who have no other
  -- earned titles (in which case there's nothing more plausible to use).
  UPDATE public.earned_titles et
  SET earned_at = COALESCE(
    (
      SELECT MAX(et2.earned_at) + INTERVAL '1 millisecond'
      FROM public.earned_titles et2
      WHERE et2.user_id = et.user_id
        AND et2.title_id NOT IN (
          'pillar_walker',
          'broad_shouldered',
          'even_handed',
          'iron_bound',
          'saga_forged'
        )
    ),
    et.earned_at
  )
  WHERE et.title_id IN (
    'pillar_walker',
    'broad_shouldered',
    'even_handed',
    'iron_bound',
    'saga_forged'
  );

  -- Record the checkpoint so future runs no-op.
  INSERT INTO public.migration_checkpoints (key, notes)
  VALUES (
    '00048_cross_build_backfill_ts',
    'Derived per-user earned_at for cross-build distinction titles seeded by 00043.'
  );
END;
$$;
