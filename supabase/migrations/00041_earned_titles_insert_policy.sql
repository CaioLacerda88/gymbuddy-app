-- =============================================================================
-- Phase 18c — earned_titles INSERT policy + equipTitle UPSERT enablement
-- Migration: 00041_earned_titles_insert_policy
--
-- The Phase 18a plan called for server-side title insertion inside
-- `record_set_xp` / `record_session_xp_batch`, but that code path was never
-- implemented. As a result, `earned_titles` has SELECT + UPDATE policies but
-- no INSERT policy, meaning `equipTitle` (which only did UPDATEs) was a no-op
-- for a user's first equip of a title that was never inserted.
--
-- This migration:
--   1. Adds an INSERT RLS policy for `earned_titles` so authenticated users
--      can insert their own rows.
--   2. No changes to the batch/set XP functions — title rows are created
--      client-side when the user equips from the celebration overlay or the
--      titles screen (see TitlesRepository.equipTitle which is now an UPSERT).
--
-- Why client-side INSERT is safe here:
--   * The UNIQUE INDEX on (user_id) WHERE is_active = TRUE still enforces the
--     at-most-one-active invariant.
--   * The PRIMARY KEY (user_id, title_id) prevents duplicate unlock rows.
--   * The RLS WITH CHECK (user_id = auth.uid()) prevents inserting rows for
--     other users.
--   * Title unlock detection is driven by rank deltas computed client-side —
--     the server already wrote body_part_progress; the client reads the delta
--     and records the unlock via equip.
-- =============================================================================

BEGIN;

-- Add INSERT policy for authenticated users to insert their own rows.
-- The WITH CHECK ensures they can only insert rows where user_id matches
-- the calling user's auth.uid().
DROP POLICY IF EXISTS earned_titles_insert_own ON public.earned_titles;
CREATE POLICY earned_titles_insert_own
  ON public.earned_titles FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

COMMIT;
