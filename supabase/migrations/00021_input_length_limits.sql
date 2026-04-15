-- =============================================================================
-- Input length ceilings — defense in depth (Phase 13 Sprint C, W3b)
-- Migration: 00021_input_length_limits
--
-- UI-side `maxLength` on TextField widgets blocks casual over-entry; these DB
-- CHECK constraints block API-level abuse (anyone writing directly to
-- Supabase via PostgREST / edge functions / SQL with a service-role key).
--
-- Ceilings are intentionally generous upper bounds (prevent 10MB strings) —
-- NOT ergonomic UI limits, which live client-side and are tighter. The gap
-- between UI and DB limits leaves headroom for legacy rows entered before
-- this change, so subsequent updates don't fail.
--
-- All columns affected are nullable — standard SQL CHECK semantics allow NULL
-- through, so no explicit `IS NULL OR` clause is needed. We include it
-- anyway for readability on nullable columns.
--
-- `char_length()` is used (not `length()`) because it counts characters, not
-- bytes — multi-byte-safe for users typing emoji or non-Latin characters.
--
-- Hosted-max vs. ceiling (measured before this migration):
--   Column                    | Hosted max | Ceiling
--   --------------------------+-----------:+--------:
--   profiles.username         |          0 |      50
--   profiles.display_name     |          4 |     100
--   exercises.name            |         27 |     100
--   exercises.description     |        128 |     500
--   exercises.form_tips       |        246 |    2000
--   workouts.name             |         19 |     100
--   workouts.notes            |          4 |    2000
--   workout_templates.name    |         19 |     100
--   sets.notes                |          0 |    1000
--
-- Constraint naming: `valid_<table>_<col>_length`.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
ALTER TABLE profiles
  ADD CONSTRAINT valid_profiles_username_length
  CHECK (username IS NULL OR char_length(username) <= 50);

ALTER TABLE profiles
  ADD CONSTRAINT valid_profiles_display_name_length
  CHECK (display_name IS NULL OR char_length(display_name) <= 100);

-- ---------------------------------------------------------------------------
-- exercises
-- ---------------------------------------------------------------------------
ALTER TABLE exercises
  ADD CONSTRAINT valid_exercises_name_length
  CHECK (char_length(name) <= 100);

ALTER TABLE exercises
  ADD CONSTRAINT valid_exercises_description_length
  CHECK (description IS NULL OR char_length(description) <= 500);

ALTER TABLE exercises
  ADD CONSTRAINT valid_exercises_form_tips_length
  CHECK (form_tips IS NULL OR char_length(form_tips) <= 2000);

-- ---------------------------------------------------------------------------
-- workouts
-- ---------------------------------------------------------------------------
ALTER TABLE workouts
  ADD CONSTRAINT valid_workouts_name_length
  CHECK (char_length(name) <= 100);

ALTER TABLE workouts
  ADD CONSTRAINT valid_workouts_notes_length
  CHECK (notes IS NULL OR char_length(notes) <= 2000);

-- ---------------------------------------------------------------------------
-- workout_templates
-- ---------------------------------------------------------------------------
ALTER TABLE workout_templates
  ADD CONSTRAINT valid_workout_templates_name_length
  CHECK (char_length(name) <= 100);

-- ---------------------------------------------------------------------------
-- sets (no UI input today, but DB-level guard against direct writes)
-- ---------------------------------------------------------------------------
ALTER TABLE sets
  ADD CONSTRAINT valid_sets_notes_length
  CHECK (notes IS NULL OR char_length(notes) <= 1000);
