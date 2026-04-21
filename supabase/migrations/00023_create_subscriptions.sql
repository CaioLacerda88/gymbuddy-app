-- Migration: create subscriptions table
-- Phase 16a — subscription monetization backend foundation.
--
-- One row per user, UPSERTed by the `validate-purchase` and `rtdn-webhook`
-- Edge Functions using the service role. The UNIQUE(user_id) constraint
-- enforces the one-row-per-user invariant required by the UPSERT pattern.
--
-- Clients (authenticated users) may SELECT their own row via the
-- `entitlements` view (see 00025). No client INSERT / UPDATE / DELETE is
-- permitted — the absence of write policies enforces this.
--
-- Lifecycle fields mirror the Google Play Developer API
-- `purchases.subscriptionsv2.get` response surface we care about:
--   - state: rolled-up string for entitlement derivation
--   - auto_renewing, in_grace_period, acknowledgement_state: raw flags
--   - linked_purchase_token: set on upgrade/downgrade/resignup to supersede
--     the previous token
--   - started_at / expires_at: server-trusted window

CREATE TABLE IF NOT EXISTS public.subscriptions (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                uuid NOT NULL UNIQUE
                               REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id             text NOT NULL,
  purchase_token         text NOT NULL,
  linked_purchase_token  text,
  state                  text NOT NULL
                               CHECK (state IN (
                                 'active',
                                 'canceled',
                                 'expired',
                                 'on_hold',
                                 'paused',
                                 'revoked'
                               )),
  auto_renewing          boolean NOT NULL DEFAULT false,
  in_grace_period        boolean NOT NULL DEFAULT false,
  acknowledgement_state  text NOT NULL DEFAULT 'pending'
                               CHECK (acknowledgement_state IN (
                                 'pending',
                                 'acknowledged'
                               )),
  started_at             timestamptz,
  expires_at             timestamptz,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_user
  ON public.subscriptions (user_id);

-- Reconciliation cron (00026) scans subs whose server expiry is within the
-- last 7 days to re-poll Play in case a Pub/Sub notification was lost. A
-- partial index on expires_at keeps that scan cheap.
CREATE INDEX IF NOT EXISTS idx_subscriptions_expires_at
  ON public.subscriptions (expires_at)
  WHERE expires_at IS NOT NULL;

-- Keep updated_at fresh on every row change. Declared as a reusable public
-- function so future tables (subscription_events deliberately does NOT use
-- it — it's append-only) can share the same trigger body.
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER subscriptions_set_updated_at
  BEFORE UPDATE ON public.subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- SELECT own row only. Users read their entitlement through the
-- `entitlements` view (00025) which applies the same predicate, but having
-- the policy on the base table lets the view remain a thin projection.
CREATE POLICY subscriptions_select_own
  ON public.subscriptions
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Intentionally NO INSERT / UPDATE / DELETE policies: all writes go through
-- Edge Functions using the service role, which bypasses RLS. Client writes
-- are rejected with PGRST/RLS errors.
