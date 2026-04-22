-- Migration: switch reconcile_subscription() to read secrets from Supabase Vault
-- Phase 16a follow-up — supersedes the `current_setting('app.settings.*')`
-- lookup introduced in 00026.
--
-- Why this exists
-- ---------------
-- The original 00026 version of `public.reconcile_subscription` read its
-- Edge Function URL and service-role JWT from session/database-level GUCs:
--
--   current_setting('app.settings.edge_functions_url', true)
--   current_setting('app.settings.service_role_key',   true)
--
-- The corresponding Phase 16a setup doc told operators to populate those
-- with `ALTER DATABASE postgres SET app.settings.* = '...'`. On hosted
-- Supabase that statement is rejected with
--
--   ERROR: 42501: permission denied to set parameter
--
-- at *every* level we have access to: the Management API, `ALTER ROLE
-- postgres SET app.settings.*`, and the Studio SQL editor (which executes
-- as a restricted `postgres` role, not the real superuser). There is no
-- supported path for a project owner to set custom `app.settings.*` GUCs
-- on a hosted project, so Stage 2 of the setup checklist was blocked.
--
-- The sanctioned workaround is Supabase Vault. The Vault extension
-- (pgsodium-backed) exposes a `vault.decrypted_secrets` view which
-- transparently decrypts secrets that were registered via the Studio
-- Vault UI (Project Settings → Vault → New secret). Any authenticated
-- dashboard user can add secrets through the UI — no superuser SQL
-- required — and `SECURITY DEFINER` functions running as the table owner
-- can read them via `SELECT decrypted_secret FROM vault.decrypted_secrets
-- WHERE name = '...'`. This is the pattern Supabase documents for
-- exactly our use case (pg_cron + pg_net + Edge Functions).
--
-- Operator action required after this migration is applied
-- --------------------------------------------------------
-- Studio → Project Settings → Vault → New secret, add:
--   * name: `edge_functions_url`  value: https://<ref>.supabase.co/functions/v1
--   * name: `service_role_key`    value: <project service_role JWT>
-- See `docs/phase-16a-setup.md` Section 2 for the step-by-step.
--
-- Scope of this migration
-- -----------------------
-- Only `public.reconcile_subscription(uuid)` changes. The batch entrypoint
-- `public.reconcile_subscriptions_batch()` and the `cron.schedule(...)`
-- block from 00026 are untouched — they call `reconcile_subscription` and
-- do not care where the secrets come from. The function signature,
-- `SECURITY DEFINER`, `SET search_path = public`, and the `net.http_post`
-- call-shape are preserved bit-for-bit. The only behavior change is where
-- the two secret values are sourced from.
--
-- Graceful degradation is preserved: if either secret is missing from the
-- Vault (fresh environment, forgotten setup step), the function emits a
-- `RAISE NOTICE` and returns without error. A misconfigured reconciler
-- must not poison the scheduler — same reasoning as the 00026 header.
--
-- Extensions (pg_cron / pg_net) are already guaranteed present by 00026
-- and are not re-declared here. The Vault extension is installed by
-- Supabase on every hosted project by default; we rely on
-- `vault.decrypted_secrets` existing without re-creating it.

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

  -- Source the Edge Function base URL and service-role JWT from Vault.
  -- `vault.decrypted_secrets` is a view that transparently decrypts each
  -- row via pgsodium using the project-level encryption key, so we read
  -- plaintext here and never have to handle keys in SQL. The two secret
  -- names are a contract with the operator setup doc — renaming either
  -- requires a paired doc update.
  --
  -- Single query (not two sequential SELECTs): both values come from the
  -- same snapshot of the view, and pgsodium decrypts only the matching
  -- rows in one scan rather than two. `MAX(...) FILTER` returns NULL
  -- when no row matches, so the downstream missing-secret guard still
  -- triggers cleanly if either name is absent from the Vault.
  SELECT
    MAX(decrypted_secret) FILTER (WHERE name = 'edge_functions_url'),
    MAX(decrypted_secret) FILTER (WHERE name = 'service_role_key')
    INTO v_function_url, v_service_key
    FROM vault.decrypted_secrets
   WHERE name IN ('edge_functions_url', 'service_role_key');

  -- Graceful no-op when secrets are missing. We do NOT raise — a cron job
  -- that raises on every tick floods the Postgres log and, depending on
  -- pg_cron configuration, can disable the schedule entirely. A NOTICE is
  -- enough for an operator tailing logs to spot the misconfiguration.
  IF v_function_url IS NULL OR v_service_key IS NULL THEN
    RAISE NOTICE 'reconcile_subscription: vault secrets edge_functions_url or service_role_key not configured; skipping';
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
