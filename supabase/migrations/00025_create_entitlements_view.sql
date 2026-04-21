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
--   premium        — sub is active and not yet expired (the only paid state)
--   grace_period   — Google flagged in_grace_period AND we are within 3d of
--                    server expires_at (Play's own grace). Clients extend
--                    this by another 7d of offline cache (Hive) — the
--                    server-side grace advertised here is the "can still
--                    use the app because Play is retrying payment" window.
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
    WHEN s.state = 'active' AND s.expires_at > now()
      THEN 'premium'
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
