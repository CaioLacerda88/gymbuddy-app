-- =============================================================================
-- Fix personal_records.set_id FK to allow cascade-deleting sets
-- Migration: 00008_fix_personal_records_set_id_fk
--
-- Problem: personal_records.set_id references sets(id) with the default
--          ON DELETE RESTRICT behaviour. When a user deletes workout history,
--          the cascade (workouts -> workout_exercises -> sets) fails because
--          personal_records still references the sets being deleted.
--
-- Fix: Change the FK to ON DELETE SET NULL so that deleting a set simply
--      nulls out the link in personal_records rather than blocking the delete.
--      The personal record itself is preserved (the PR value is still valid;
--      it just loses the reference to the specific set that achieved it).
-- =============================================================================

-- Drop the existing FK constraint and re-create with ON DELETE SET NULL.
-- The original constraint was created inline without a name, so Postgres
-- auto-named it. We look it up dynamically.

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
    AND kcu.column_name = 'set_id';

  IF _constraint_name IS NOT NULL THEN
    EXECUTE format(
      'ALTER TABLE personal_records DROP CONSTRAINT %I',
      _constraint_name
    );
  END IF;
END;
$$;

ALTER TABLE personal_records
  ADD CONSTRAINT personal_records_set_id_fkey
  FOREIGN KEY (set_id) REFERENCES sets(id) ON DELETE SET NULL;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
