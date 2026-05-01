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
-- Fix:     Drop the auto-named FK from 00001 and re-add it with
--          `ON DELETE CASCADE` and the canonical name
--          `personal_records_exercise_id_fkey`.
--
-- Rationale for CASCADE (not SET NULL): a personal record without its
-- parent exercise is meaningless — the PR value is contextless once the
-- exercise it was achieved on is gone. CASCADE keeps the data graph
-- coherent. The Dart model declares `required String exerciseId` (non-
-- nullable), so SET NULL would have produced rows the model cannot
-- deserialize without a coupled model migration. CASCADE keeps schema and
-- model in sync without that coupling.
--
-- Note on the analogous 00008 (`personal_records.set_id` → SET NULL):
-- the precedent there made sense because (a) `set_id` was already nullable
-- in 00001 and (b) the model declared `String? setId`. The same reasoning
-- does not apply here.
--
-- Idempotency:
--   * Step 1 (drop) — DO block looks up the FK name dynamically; no-op when
--     no FK on `exercise_id` exists.
--   * Step 2 (add)  — guarded by an existence check on the canonical
--     constraint name so partial-replay scenarios (e.g., manual
--     post-failure recovery) do not raise "constraint already exists".
--
-- NOTE: Supabase CLI wraps each migration in an implicit transaction; we do
-- not add explicit BEGIN/COMMIT here.
-- =============================================================================

-- Step 1: drop the existing FK constraint (auto-named by Postgres in 00001).
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

-- Step 2: re-add the FK with ON DELETE CASCADE and a canonical name.
-- Wrapped in an existence guard so partial replay does not raise
-- "constraint already exists" — closes the idempotency gap reviewer flagged.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE table_schema = 'public'
      AND table_name = 'personal_records'
      AND constraint_name = 'personal_records_exercise_id_fkey'
      AND constraint_type = 'FOREIGN KEY'
  ) THEN
    ALTER TABLE public.personal_records
      ADD CONSTRAINT personal_records_exercise_id_fkey
      FOREIGN KEY (exercise_id) REFERENCES public.exercises(id) ON DELETE CASCADE;
  END IF;
END;
$$;

-- Reload PostgREST schema cache (mirrors 00008).
NOTIFY pgrst, 'reload schema';
