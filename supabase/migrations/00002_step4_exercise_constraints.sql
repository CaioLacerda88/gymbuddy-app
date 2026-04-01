-- =============================================================================
-- Step 4: Exercise Library Constraints & Missing Columns
-- Migration: 00002_step4_exercise_constraints
--
-- Adds columns and constraints required by Step 4 (Exercise Library) and
-- future steps that were defined in the schema design but not included
-- in the initial migration.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Add set_type column to sets table (needed for Step 5, defined in schema)
-- ---------------------------------------------------------------------------
ALTER TABLE sets
  ADD COLUMN set_type text NOT NULL DEFAULT 'working'
  CONSTRAINT valid_set_type CHECK (set_type IN ('working', 'warmup', 'dropset', 'failure'));

-- ---------------------------------------------------------------------------
-- 2. Add weight_unit column to profiles table
-- ---------------------------------------------------------------------------
ALTER TABLE profiles
  ADD COLUMN weight_unit text NOT NULL DEFAULT 'kg'
  CONSTRAINT valid_weight_unit CHECK (weight_unit IN ('kg', 'lbs'));

-- ---------------------------------------------------------------------------
-- 3. Unique exercise name per user (case-insensitive), scoped by muscle
--    group and equipment type, excluding soft-deleted exercises
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX idx_exercises_unique_name
  ON exercises(user_id, LOWER(name), muscle_group, equipment_type)
  WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- 4. Partial index for quickly finding a user's active workout
-- ---------------------------------------------------------------------------
CREATE INDEX idx_workouts_active
  ON workouts(user_id)
  WHERE is_active = true;

-- ---------------------------------------------------------------------------
-- 5. Ensure no duplicate set numbers within a workout exercise
-- ---------------------------------------------------------------------------
ALTER TABLE sets
  ADD CONSTRAINT unique_set_per_exercise
  UNIQUE (workout_exercise_id, set_number);

-- ---------------------------------------------------------------------------
-- 6. Ensure workout_templates.exercises is always a JSON array
-- ---------------------------------------------------------------------------
ALTER TABLE workout_templates
  ADD CONSTRAINT valid_exercises_json
  CHECK (jsonb_typeof(exercises) = 'array');
