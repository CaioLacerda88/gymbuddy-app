-- =============================================================================
-- Fix exercise soft-delete RLS violation
-- Migration: 00017_fix_exercise_soft_delete_rls
--
-- Root cause: PostgreSQL RLS requires that the *updated* row (after UPDATE)
-- is visible through at least one SELECT policy. The existing SELECT policies
-- on exercises all require `deleted_at IS NULL`, so setting `deleted_at`
-- causes the new row version to be invisible, triggering error 42501:
-- "new row violates row-level security policy".
--
-- The fix adds a SELECT policy allowing users to read their own soft-deleted
-- custom exercises. This makes the post-UPDATE row visible to RLS, allowing
-- the soft-delete UPDATE to succeed.
--
-- Exercises used in workout history were unaffected because the
-- `exercises_select_in_own_workouts` policy (which has no deleted_at filter)
-- provided visibility. Only exercises *never used in a workout* hit this bug.
-- =============================================================================

-- Allow users to SELECT their own soft-deleted custom exercises.
-- This is required so that the UPDATE setting deleted_at produces a row
-- still visible to the user, satisfying PostgreSQL's RLS post-UPDATE check.
CREATE POLICY exercises_select_own_deleted
  ON exercises FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() AND deleted_at IS NOT NULL);
