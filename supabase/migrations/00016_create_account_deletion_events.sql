-- Migration: create account_deletion_events table
-- Phase 13a Sprint A, PR 5 — account deletion audit stream.
--
-- This table is SEPARATE from analytics_events for a reason: an
-- account_deleted row must survive the very delete it records. The
-- analytics_events table is `ON DELETE CASCADE` on `auth.users`, so any
-- row tied to the user being deleted is wiped at the same moment the
-- user is. To preserve churn metrics, we write to this table instead —
-- it has no FK to auth.users, and rows are fully anonymous (no user_id,
-- only aggregate props like workout_count / days_since_signup).
--
-- Inserts happen exclusively via the `delete-user` Edge Function using
-- the service role (bypasses RLS). Users cannot read, insert, update or
-- delete rows from this table directly.

CREATE TABLE IF NOT EXISTS public.account_deletion_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  props       jsonb NOT NULL DEFAULT '{}'::jsonb,
  platform    text,
  app_version text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_account_deletion_events_created
  ON public.account_deletion_events (created_at DESC);

ALTER TABLE public.account_deletion_events ENABLE ROW LEVEL SECURITY;

-- Intentionally NO policies: all access is service-role only.
