-- =============================================================================
-- Cluster 7 — DB integrity (BUG-033)
-- Migration: 00047_personal_records_exercise_id_on_delete
--
-- Problem: `personal_records.exercise_id` was created at 00001:108 as
--          `NOT NULL REFERENCES exercises` with no explicit ON DELETE
--          behaviour, defaulting to NO ACTION. A hard DELETE FROM exercises
--          would fail with an FK violation — and even soft-delete patterns
--          that include an eventual purge phase have no graceful path.
--
-- Fix: Mirror the pattern from 00008 (which fixed the analogous issue on
--      personal_records.set_id):
--        1. ALTER COLUMN exercise_id DROP NOT NULL — required so SET NULL
--           can fire on parent delete without a CHECK violation.
--        2. Drop the existing FK constraint (auto-named by Postgres because
--           it was declared inline in 00001).
--        3. Re-add the FK with `ON DELETE SET NULL` and the canonical name
--           `personal_records_exercise_id_fkey`.
--
-- Rationale for SET NULL (not CASCADE): a personal record is a historical
-- claim about a value the user achieved. The exercise being deleted (e.g.,
-- a custom exercise the user removed from their library) does not
-- invalidate the PR value — the achievement still happened. SET NULL
-- preserves the record while severing the dangling reference. UI surfaces
-- already cope with `exercise_id IS NULL` for the analogous `set_id`
-- nullification path introduced by 00008.
--
-- Idempotency: the DO-block constraint lookup mirrors 00008. ALTER COLUMN
-- DROP NOT NULL is idempotent (no-op if already nullable). Re-runs converge.
--
-- NOTE: Supabase CLI wraps each migration in an implicit transaction; we do
-- not add explicit BEGIN/COMMIT here.
-- =============================================================================

-- Step 1: allow exercise_id to be NULL so SET NULL doesn't violate NOT NULL.
ALTER TABLE public.personal_records
  ALTER COLUMN exercise_id DROP NOT NULL;

-- Step 2: drop the existing FK constraint (auto-named by Postgres in 00001).
DO $$
DECLARE
  _constraint_name text;
BEGIN
  SELECT tc.constraint_name INTO _constraint_name
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
  WHERE tc.table_schema = 'public'
    AND tc.table_name = 'personal_records'
    AND tc.constraint_type = 'FOREIGN KEY'
    AND kcu.column_name = 'exercise_id';

  IF _constraint_name IS NOT NULL THEN
    EXECUTE format(
      'ALTER TABLE public.personal_records DROP CONSTRAINT %I',
      _constraint_name
    );
  END IF;
END;
$$;

-- Step 3: re-add the FK with ON DELETE SET NULL and a canonical name.
ALTER TABLE public.personal_records
  ADD CONSTRAINT personal_records_exercise_id_fkey
  FOREIGN KEY (exercise_id) REFERENCES public.exercises(id) ON DELETE SET NULL;

-- Reload PostgREST schema cache (mirrors 00008).
NOTIFY pgrst, 'reload schema';
