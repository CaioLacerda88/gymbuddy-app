-- Migration: pg_cron reconciliation job for subscriptions
-- Phase 16a — fallback poll loop that guards against missed RTDNs.
--
-- Pub/Sub is at-least-once-in-practice but not hard-guaranteed. If Google
-- ever drops or mis-routes a notification (topic misconfig, Pub/Sub outage,
-- push endpoint 5xx window), the `subscriptions` row goes stale and the
-- user's entitlement drifts from reality.
--
-- This job runs every 6 hours and re-invokes the `validate-purchase` Edge
-- Function for every subscription whose server expires_at falls inside a
-- 7-day window around `now()` (recently expired or imminently expiring).
-- The Edge Function re-polls the Play Developer API and UPSERTs the row —
-- same code path as a client-initiated validation, so behavior stays
-- identical.
--
-- NOTE: this migration requires the `pg_cron` and `pg_net` extensions,
-- which are available on Supabase Pro+. On hosted Supabase `pg_cron`
-- installs into the `cron` schema and `pg_net` installs its public API
-- functions into the `net` schema — regardless of the `WITH SCHEMA`
-- clause on CREATE EXTENSION, pg_net's `http_post` / `http_get` live at
-- `net.http_post` / `net.http_get`. Calling `extensions.http_post`
-- raises "function does not exist" at runtime, which in a cron context
-- fails silently forever. We use `net.http_post` with named parameters
-- to match the documented pg_net signature.
-- We guard with IF NOT EXISTS so the migration is idempotent.
--
-- The job POSTs to the Edge Function using the service role key as a
-- bearer token so the function can authenticate via its existing
-- JWT-verification path (the service role JWT is a valid Supabase JWT).
-- No end-user JWT is involved — this is a server-to-server reconcile.

CREATE EXTENSION IF NOT EXISTS pg_cron  WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_net   WITH SCHEMA extensions;

-- Helper: invoke validate-purchase for a single subscription row.
-- Kept as a separate function so we can unit-test the selection logic
-- independently of the HTTP side-effect and so operators can run a manual
-- reconcile for one user from the SQL editor:
--
--   SELECT public.reconcile_subscription('<user-uuid>');
CREATE OR REPLACE FUNCTION public.reconcile_subscription(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_product_id      text;
  v_purchase_token  text;
  v_function_url    text;
  v_service_key     text;
BEGIN
  SELECT product_id, purchase_token
    INTO v_product_id, v_purchase_token
    FROM public.subscriptions
   WHERE user_id = p_user_id;

  IF v_purchase_token IS NULL THEN
    RETURN;
  END IF;

  -- These are set as database-level configuration parameters. See the
  -- Phase 16a setup doc for the `ALTER DATABASE ... SET app.settings.*`
  -- commands that populate them. If unset, the call no-ops with a notice
  -- rather than raising — we do not want a misconfigured reconciler to
  -- poison the scheduler.
  v_function_url := current_setting('app.settings.edge_functions_url', true);
  v_service_key  := current_setting('app.settings.service_role_key',    true);

  IF v_function_url IS NULL OR v_service_key IS NULL THEN
    RAISE NOTICE 'reconcile_subscription: app.settings.edge_functions_url / service_role_key not configured; skipping';
    RETURN;
  END IF;

  -- pg_net exposes http_post in the `net` schema (not `extensions`).
  -- Named parameters; body is jsonb. timeout_milliseconds keeps the
  -- cron tick bounded if the Edge Function hangs.
  PERFORM net.http_post(
    url                := v_function_url || '/validate-purchase',
    headers            := jsonb_build_object(
                            'Content-Type',  'application/json',
                            'Authorization', 'Bearer ' || v_service_key
                          ),
    body               := jsonb_build_object(
                            'product_id',     v_product_id,
                            'purchase_token', v_purchase_token,
                            'user_id',        p_user_id,
                            'source',         'cron_reconcile'
                          ),
    timeout_milliseconds := 30000
  );
END;
$$;

-- Batch entrypoint: scan subs whose expires_at falls inside a ±7-day
-- window around now() (either about to expire or recently expired) and
-- fan out reconcile calls. The window is deliberately bounded on BOTH
-- sides so the batch size stays constant as the subscriber base grows —
-- we don't want to re-poll every active sub for the next decade on
-- every tick, only the ones where an RTDN miss could matter. Rows with
-- expires_at further in the future are handled by the next RTDN or the
-- next reconcile when they drift into the window.
-- Running as SECURITY DEFINER so the scheduler (which executes as the
-- cron superuser) can read the subscriptions table without needing RLS
-- bypass privileges on the caller.
CREATE OR REPLACE FUNCTION public.reconcile_subscriptions_batch()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row record;
BEGIN
  FOR v_row IN
    SELECT user_id
      FROM public.subscriptions
     WHERE expires_at IS NOT NULL
       AND expires_at > now() - interval '7 days'
       AND expires_at < now() + interval '7 days'
  LOOP
    PERFORM public.reconcile_subscription(v_row.user_id);
  END LOOP;
END;
$$;

-- Schedule: every 6 hours. If a schedule with the same name already
-- exists (re-running this migration on an environment that has it), we
-- unschedule it first so the cron expression stays in sync with the file.
DO $$
DECLARE
  v_existing int;
BEGIN
  SELECT jobid INTO v_existing
    FROM cron.job
   WHERE jobname = 'subscription_reconcile_6h';

  IF v_existing IS NOT NULL THEN
    PERFORM cron.unschedule(v_existing);
  END IF;

  PERFORM cron.schedule(
    'subscription_reconcile_6h',
    '0 */6 * * *',
    $cron$ SELECT public.reconcile_subscriptions_batch(); $cron$
  );
END;
$$;
