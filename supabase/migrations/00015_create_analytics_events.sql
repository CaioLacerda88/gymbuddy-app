-- Migration: create analytics_events table
-- Phase 13a Sprint A, PR 5 — first-party product analytics.
-- Events are inserted by authenticated users only (RLS), never read back
-- by users. Querying is done via the Supabase SQL editor with the service
-- role for retention/funnel analysis.

CREATE TABLE IF NOT EXISTS public.analytics_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        text NOT NULL,
  props       jsonb NOT NULL DEFAULT '{}'::jsonb,
  platform    text,
  app_version text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_analytics_events_user_created
  ON public.analytics_events (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_analytics_events_name_created
  ON public.analytics_events (name, created_at DESC);

ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_insert_own_events"
  ON public.analytics_events
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Intentionally NO SELECT/UPDATE/DELETE policies: users cannot read their
-- own events back. Querying happens via the service role in the dashboard.
