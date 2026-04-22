-- =============================================================================
-- RepSaga Initial Schema
-- Migration: 00001_initial_schema
-- =============================================================================

-- =============================================================================
-- ENUMS
-- =============================================================================

CREATE TYPE muscle_group AS ENUM (
  'chest',
  'back',
  'legs',
  'shoulders',
  'arms',
  'core'
);

CREATE TYPE equipment_type AS ENUM (
  'barbell',
  'dumbbell',
  'cable',
  'machine',
  'bodyweight',
  'bands',
  'kettlebell'
);

CREATE TYPE fitness_level AS ENUM (
  'beginner',
  'intermediate',
  'advanced'
);

CREATE TYPE record_type AS ENUM (
  'max_weight',
  'max_reps',
  'max_volume'
);

-- =============================================================================
-- TABLES
-- =============================================================================

-- User profile, extended from auth.users
CREATE TABLE profiles (
  id             uuid        PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  username       text        UNIQUE,
  display_name   text,
  avatar_url     text,
  fitness_level  fitness_level NOT NULL DEFAULT 'beginner',
  created_at     timestamptz NOT NULL DEFAULT now()
);

-- Exercise library: default exercises (is_default = true) or user-created ones
CREATE TABLE exercises (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name           text        NOT NULL,
  muscle_group   muscle_group NOT NULL,
  equipment_type equipment_type NOT NULL,
  is_default     boolean     NOT NULL DEFAULT false,
  -- null for default exercises, set for custom exercises
  user_id        uuid        REFERENCES auth.users,
  deleted_at     timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now()
);

-- A single workout session
CREATE TABLE workouts (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid        NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  name             text        NOT NULL,
  started_at       timestamptz NOT NULL,
  finished_at      timestamptz,
  duration_seconds integer,
  is_active        boolean     NOT NULL DEFAULT false,
  notes            text,
  created_at       timestamptz NOT NULL DEFAULT now()
);

-- Exercises within a workout, ordered
CREATE TABLE workout_exercises (
  id          uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  workout_id  uuid    NOT NULL REFERENCES workouts ON DELETE CASCADE,
  exercise_id uuid    NOT NULL REFERENCES exercises,
  "order"     integer NOT NULL,
  rest_seconds integer,
  UNIQUE (workout_id, "order")
);

-- Individual sets within a workout exercise
CREATE TABLE sets (
  id                  uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  workout_exercise_id uuid    NOT NULL REFERENCES workout_exercises ON DELETE CASCADE,
  set_number          integer NOT NULL,
  reps                integer,
  weight              numeric(7, 2),
  rpe                 integer CHECK (rpe >= 1 AND rpe <= 10),
  notes               text,
  is_completed        boolean NOT NULL DEFAULT false,
  created_at          timestamptz NOT NULL DEFAULT now()
);

-- Personal records tracked per user and exercise
CREATE TABLE personal_records (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  exercise_id uuid        NOT NULL REFERENCES exercises,
  record_type record_type NOT NULL,
  value       numeric(10, 2) NOT NULL,
  achieved_at timestamptz NOT NULL,
  -- optional link to the set that triggered the record
  set_id      uuid        REFERENCES sets,
  -- one record per type per exercise per user (idempotent PR creation)
  UNIQUE (user_id, exercise_id, record_type)
);

-- Reusable workout templates (default or user-created)
CREATE TABLE workout_templates (
  id          uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  -- null user_id means it is a default template visible to all
  user_id     uuid    REFERENCES auth.users ON DELETE CASCADE,
  name        text    NOT NULL,
  is_default  boolean NOT NULL DEFAULT false,
  -- JSONB array: [{exercise_id, set_configs: [{target_reps, target_weight, rest_seconds}]}]
  exercises   jsonb   NOT NULL DEFAULT '[]',
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- =============================================================================
-- INDEXES
-- =============================================================================

-- Fast lookup of a user's workout history sorted by most recent
CREATE INDEX idx_workouts_user_finished
  ON workouts(user_id, finished_at DESC);

-- Fast lookup of exercises within a workout (ordered display)
CREATE INDEX idx_workout_exercises_workout
  ON workout_exercises(workout_id);

-- Fast lookup of sets within a workout exercise
CREATE INDEX idx_sets_workout_exercise
  ON sets(workout_exercise_id);

-- Fast lookup of a user's personal records per exercise
CREATE INDEX idx_personal_records_user_exercise
  ON personal_records(user_id, exercise_id);

-- Partial index: only active (non-deleted) user-created exercises
CREATE INDEX idx_exercises_user
  ON exercises(user_id)
  WHERE deleted_at IS NULL;

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercises         ENABLE ROW LEVEL SECURITY;
ALTER TABLE workouts          ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE sets              ENABLE ROW LEVEL SECURITY;
ALTER TABLE personal_records  ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_templates ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

-- A user can read their own profile
CREATE POLICY profiles_select_own
  ON profiles FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- Auto-insert on signup (handled by trigger), also allow explicit insert
CREATE POLICY profiles_insert_own
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (id = auth.uid());

-- A user can update their own profile
CREATE POLICY profiles_update_own
  ON profiles FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- ---------------------------------------------------------------------------
-- exercises
-- ---------------------------------------------------------------------------

-- All authenticated users can read default exercises
CREATE POLICY exercises_select_default
  ON exercises FOR SELECT
  TO authenticated
  USING (is_default = true AND deleted_at IS NULL);

-- Users can read their own custom exercises
CREATE POLICY exercises_select_own
  ON exercises FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() AND deleted_at IS NULL);

-- Users can insert their own custom exercises
CREATE POLICY exercises_insert_own
  ON exercises FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid() AND is_default = false);

-- Users can update their own custom exercises
CREATE POLICY exercises_update_own
  ON exercises FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid() AND is_default = false);

-- Allow reading soft-deleted exercises that appear in user's own workout history
CREATE POLICY exercises_select_in_own_workouts
  ON exercises FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM workout_exercises we
      JOIN workouts w ON w.id = we.workout_id
      WHERE we.exercise_id = exercises.id
        AND w.user_id = auth.uid()
    )
  );

-- Users can soft-delete their own custom exercises (set deleted_at)
CREATE POLICY exercises_delete_own
  ON exercises FOR DELETE
  TO authenticated
  USING (user_id = auth.uid() AND is_default = false);

-- ---------------------------------------------------------------------------
-- workouts
-- ---------------------------------------------------------------------------

CREATE POLICY workouts_select_own
  ON workouts FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY workouts_insert_own
  ON workouts FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY workouts_update_own
  ON workouts FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY workouts_delete_own
  ON workouts FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- workout_exercises (access scoped via workout ownership)
-- ---------------------------------------------------------------------------

CREATE POLICY workout_exercises_select_own
  ON workout_exercises FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM workouts w
      WHERE w.id = workout_exercises.workout_id
        AND w.user_id = auth.uid()
    )
  );

CREATE POLICY workout_exercises_insert_own
  ON workout_exercises FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM workouts w
      WHERE w.id = workout_exercises.workout_id
        AND w.user_id = auth.uid()
    )
  );

CREATE POLICY workout_exercises_update_own
  ON workout_exercises FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM workouts w
      WHERE w.id = workout_exercises.workout_id
        AND w.user_id = auth.uid()
    )
  );

CREATE POLICY workout_exercises_delete_own
  ON workout_exercises FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM workouts w
      WHERE w.id = workout_exercises.workout_id
        AND w.user_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- sets (access scoped via workout_exercises → workouts ownership chain)
-- ---------------------------------------------------------------------------

CREATE POLICY sets_select_own
  ON sets FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM workout_exercises we
      JOIN workouts w ON w.id = we.workout_id
      WHERE we.id = sets.workout_exercise_id
        AND w.user_id = auth.uid()
    )
  );

CREATE POLICY sets_insert_own
  ON sets FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM workout_exercises we
      JOIN workouts w ON w.id = we.workout_id
      WHERE we.id = sets.workout_exercise_id
        AND w.user_id = auth.uid()
    )
  );

CREATE POLICY sets_update_own
  ON sets FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM workout_exercises we
      JOIN workouts w ON w.id = we.workout_id
      WHERE we.id = sets.workout_exercise_id
        AND w.user_id = auth.uid()
    )
  );

CREATE POLICY sets_delete_own
  ON sets FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM workout_exercises we
      JOIN workouts w ON w.id = we.workout_id
      WHERE we.id = sets.workout_exercise_id
        AND w.user_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- personal_records
-- ---------------------------------------------------------------------------

CREATE POLICY personal_records_select_own
  ON personal_records FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY personal_records_insert_own
  ON personal_records FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY personal_records_update_own
  ON personal_records FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY personal_records_delete_own
  ON personal_records FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- workout_templates
-- ---------------------------------------------------------------------------

-- All authenticated users can read default templates
CREATE POLICY workout_templates_select_default
  ON workout_templates FOR SELECT
  TO authenticated
  USING (is_default = true);

-- Users can read their own templates
CREATE POLICY workout_templates_select_own
  ON workout_templates FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Users can insert their own templates (not default)
CREATE POLICY workout_templates_insert_own
  ON workout_templates FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid() AND is_default = false);

-- Users can update their own templates
CREATE POLICY workout_templates_update_own
  ON workout_templates FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid() AND is_default = false);

-- Users can delete their own templates
CREATE POLICY workout_templates_delete_own
  ON workout_templates FOR DELETE
  TO authenticated
  USING (user_id = auth.uid() AND is_default = false);

-- =============================================================================
-- TRIGGERS
-- =============================================================================

-- Auto-create a profile row when a new auth user is created
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, created_at)
  VALUES (NEW.id, now())
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();
