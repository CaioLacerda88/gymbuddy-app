-- =============================================================================
-- Fix QA-003 and QA-004: Missing columns and tightened RLS policy
-- Migration: 00006_fix_qa003_qa004
--
-- QA-004: Migration 00002 was registered in schema_migrations but its DDL
--         did not land on production. The weight_unit column (profiles) and
--         set_type column (sets) are missing. Re-apply them idempotently.
--
-- QA-003: The exercises_update_own WITH CHECK contains `is_default = false`
--         but the USING clause does not. This mismatch allows a row to pass
--         USING yet fail WITH CHECK (e.g. data-corrupted row where a default
--         exercise has a user_id set). Tighten the USING clause to also
--         require `is_default = false` so the policy is internally consistent
--         and the WITH CHECK can never fire for a row that passed USING.
--         Also reload the PostgREST schema cache to clear any stale state.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- QA-004 fix: add missing columns from 00002 if they do not exist
-- ---------------------------------------------------------------------------

-- weight_unit on profiles
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'profiles'
      AND column_name  = 'weight_unit'
  ) THEN
    ALTER TABLE profiles
      ADD COLUMN weight_unit text NOT NULL DEFAULT 'kg'
      CONSTRAINT valid_weight_unit CHECK (weight_unit IN ('kg', 'lbs'));
  END IF;
END;
$$;

-- set_type on sets
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'sets'
      AND column_name  = 'set_type'
  ) THEN
    ALTER TABLE sets
      ADD COLUMN set_type text NOT NULL DEFAULT 'working'
      CONSTRAINT valid_set_type CHECK (set_type IN ('working', 'warmup', 'dropset', 'failure'));
  END IF;
END;
$$;

-- Unique exercise name index (idempotent via IF NOT EXISTS)
CREATE UNIQUE INDEX IF NOT EXISTS idx_exercises_unique_name
  ON exercises(user_id, LOWER(name), muscle_group, equipment_type)
  WHERE deleted_at IS NULL;

-- Active workout partial index (idempotent via IF NOT EXISTS)
CREATE INDEX IF NOT EXISTS idx_workouts_active
  ON workouts(user_id)
  WHERE is_active = true;

-- Unique set number per workout_exercise constraint (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE table_schema = 'public'
      AND table_name   = 'sets'
      AND constraint_name = 'unique_set_per_exercise'
  ) THEN
    ALTER TABLE sets
      ADD CONSTRAINT unique_set_per_exercise
      UNIQUE (workout_exercise_id, set_number);
  END IF;
END;
$$;

-- valid_exercises_json constraint on workout_templates (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE table_schema = 'public'
      AND table_name   = 'workout_templates'
      AND constraint_name = 'valid_exercises_json'
  ) THEN
    ALTER TABLE workout_templates
      ADD CONSTRAINT valid_exercises_json
      CHECK (jsonb_typeof(exercises) = 'array');
  END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- QA-003 fix: tighten exercises_update_own USING clause to match WITH CHECK
--
-- Before: USING (user_id = auth.uid())
-- After:  USING (user_id = auth.uid() AND is_default = false)
--
-- This ensures a row that passes USING will always pass WITH CHECK, making
-- it impossible for a WITH CHECK violation (403) to fire for a valid custom
-- exercise soft-delete. Any row where is_default = true is now invisible to
-- the UPDATE policy, so PostgREST returns 0 rows (no-op) instead of a 403.
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS exercises_update_own ON exercises;

CREATE POLICY exercises_update_own
  ON exercises FOR UPDATE
  TO authenticated
  USING  (user_id = auth.uid() AND is_default = false)
  WITH CHECK (user_id = auth.uid() AND is_default = false);

-- ---------------------------------------------------------------------------
-- Reload PostgREST schema cache to clear any stale policy or column metadata
-- ---------------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';
