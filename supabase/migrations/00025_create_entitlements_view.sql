-- Migration: create entitlements view
-- Phase 16a — derived read model for "is this user currently entitled?".
--
-- The client reads this view (never the raw subscriptions table) to learn
-- its current access state. Centralising the CASE here means clients cannot
-- disagree on what "premium" means — the rule is evaluated by Postgres
-- against the server clock.
--
-- State rules (from PLAN.md Phase 16 Schema):
--
--   premium        — sub is active and not yet expired (the only paid
--                    state). This branch INTENTIONALLY covers BOTH regular
--                    active subs and subs currently in Play's grace period,
--                    because our RTDN mapping translates
--                    SUBSCRIPTION_IN_GRACE_PERIOD to `state='active' +
--                    in_grace_period=true` (playStateToDbState in
--                    _shared/google_play.ts). A user whose card has just
--                    failed and whom Play is retrying over the next ~7 days
--                    still has state='active' and expires_at in the future,
--                    so they correctly see `premium` here — which matches
--                    Play's "grant entitlement while we retry billing"
--                    product guidance.
--
--   grace_period   — Our OWN grace window: expires_at has just passed,
--                    but we give 3 days of tolerance before yanking
--                    access. This is the "Play's retry window ended,
--                    but we want to avoid a hard denial flicker while
--                    the user fixes their payment or an RTDN catches
--                    up" band. Clients extend this by another 7d of
--                    offline cache (Hive) — the server-side grace
--                    advertised here is the soft tail after Play has
--                    given up retrying.
--
--                    Branch ordering note: `active AND expires_at > now()`
--                    fires BEFORE this branch by design. While Play is
--                    still retrying, the user is `premium`; only once
--                    expires_at slips into the past does this branch
--                    engage. Do not reorder.
--
--   on_hold        — payment failed past grace; treat as free until
--                    recovered (RECOVERED RTDN or user fixes payment).
--   free           — everything else (canceled past expires_at, expired,
--                    revoked, paused, no row at all via LEFT-JOIN semantics
--                    handled client-side).
--
-- RLS is inherited from the underlying `subscriptions` table — views in
-- Postgres honor the base table's policies when `security_invoker` is true,
-- which is the default for views created by the owner running this
-- migration. We also explicitly set it to make intent clear and to avoid
-- surprises if Postgres ever changes the default.

CREATE OR REPLACE VIEW public.entitlements
WITH (security_invoker = true) AS
SELECT
  s.user_id,
  s.product_id,
  s.state,
  s.auto_renewing,
  s.in_grace_period,
  s.started_at,
  s.expires_at,
  CASE
    -- Active AND not yet expired. Covers regular active subs AND Play's
    -- own grace-period retry window (state stays 'active' during retry).
    WHEN s.state = 'active' AND s.expires_at > now()
      THEN 'premium'
    -- Our soft tail: expires_at has passed but we give 3d leeway.
    -- in_grace_period gates this so we only extend to users Play was
    -- actively retrying at expiry — not users who simply canceled.
    WHEN s.in_grace_period
         AND s.expires_at > now() - interval '3 days'
      THEN 'grace_period'
    WHEN s.state = 'on_hold'
      THEN 'on_hold'
    ELSE 'free'
  END AS entitlement_state,
  s.updated_at
FROM public.subscriptions s;

-- Grant SELECT explicitly. The base table's RLS policy (SELECT own only)
-- still applies via security_invoker, so a user can only ever read their
-- own row through this view.
GRANT SELECT ON public.entitlements TO authenticated;
