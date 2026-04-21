-- Migration: create subscription_events table
-- Phase 16a — immutable audit log for every subscription state transition.
--
-- Rows are inserted (never updated) by the `validate-purchase` and
-- `rtdn-webhook` Edge Functions using the service role. The
-- UNIQUE(purchase_token, notification_type, event_time) constraint is the
-- idempotency boundary: Pub/Sub redelivers aggressively, so duplicate
-- RTDNs MUST collapse into a single row. The webhook catches the unique
-- violation and returns 200 without re-processing.
--
-- `notification_type` is stored as text (not an enum) because Google may
-- introduce new RTDN types at any time. We validate known values at the
-- application layer and persist unknown ones as-is for forensics.
--
-- Client access: SELECT own events only — used by the in-app receipt
-- history UI (future). No client writes.

CREATE TABLE IF NOT EXISTS public.subscription_events (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  purchase_token     text NOT NULL,
  notification_type  text NOT NULL,
  event_time         timestamptz NOT NULL,
  raw_payload        jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at         timestamptz NOT NULL DEFAULT now(),

  -- Idempotency boundary. Pub/Sub redelivers at-least-once; the webhook
  -- relies on this constraint raising a unique_violation to short-circuit
  -- duplicate processing with a 200 response.
  CONSTRAINT subscription_events_dedupe
    UNIQUE (purchase_token, notification_type, event_time)
);

CREATE INDEX IF NOT EXISTS idx_subscription_events_user_created
  ON public.subscription_events (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_subscription_events_token_created
  ON public.subscription_events (purchase_token, created_at DESC);

ALTER TABLE public.subscription_events ENABLE ROW LEVEL SECURITY;

-- SELECT own only. Users can inspect their own audit trail but never write
-- to it. A future "Subscription history" UI surface can read through this
-- policy directly without another view layer.
CREATE POLICY subscription_events_select_own
  ON public.subscription_events
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Intentionally NO INSERT / UPDATE / DELETE policies. All writes come from
-- Edge Functions using the service role. The audit log is append-only by
-- convention — we do not even define an UPDATE policy for the service role
-- because there is no legitimate reason to mutate past events.
