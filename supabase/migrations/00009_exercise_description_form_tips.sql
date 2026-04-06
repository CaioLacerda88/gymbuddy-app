-- =============================================================================
-- Add description and form_tips columns to exercises
-- Migration: 00009_exercise_description_form_tips
--
-- Two new optional TEXT columns for exercise context:
--   - description: 1-2 sentence explanation of the exercise
--   - form_tips: newline-separated bullet points for safe execution
--
-- No NOT NULL constraint — custom exercises may omit these.
-- Default exercises are populated in the next migration (00010).
-- =============================================================================

ALTER TABLE exercises ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS form_tips TEXT;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
