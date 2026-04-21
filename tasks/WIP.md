# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 16a — Subscription backend foundation

**Branch:** `feature/phase16a-subscription-backend`
**Reference:** PLAN.md Phase 16 → sub-phase 16a
**Owner:** tech-lead

### Goal

Ship Supabase schema + two Edge Functions + Google Cloud service account + Pub/Sub + Play Console draft subscription product. Backend-only — no Flutter code yet. Testable via `curl` / `supabase functions invoke`. No merchant account required for this sub-phase.

### Checklist

**Migrations (`supabase/migrations/`):**
- [x] `00023_create_subscriptions.sql` — table + RLS (SELECT own, no client writes)
- [x] `00024_create_subscription_events.sql` — audit log with `UNIQUE(purchase_token, notification_type, event_time)`
- [x] `00025_create_entitlements_view.sql` — computed view (`entitlement_state` from subscriptions row, per CASE logic in PLAN.md Phase 16 Schema section)
- [x] `00026_subscription_cron_reconciliation.sql` — pg_cron fallback job every 6h for subs with `expires_at > now() - interval '7 days'`

**Edge Functions (`supabase/functions/`):**
- [x] `validate-purchase/index.ts` — JWT verify → Play API `purchases.subscriptionsv2.get` → DB upsert → acknowledge within 3d
  - Service account JSON from Supabase secret `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`
  - OAuth2 exchange for short-lived access token (scope: `androidpublisher`)
  - Validate `obfuscatedAccountId` in Play response matches JWT user_id
  - If acknowledgement fails → DO NOT grant entitlement, return 500
- [x] `rtdn-webhook/index.ts` — Pub/Sub JWT verify → state transitions for all 10 RTDN types
  - Verify Pub/Sub JWT against Google's public keys (`https://www.googleapis.com/oauth2/v3/certs`)
  - Idempotency via UNIQUE constraint on `subscription_events`; return 200 on duplicate
  - Handle: PURCHASED, RENEWED, RECOVERED, CANCELED, EXPIRED, REVOKED, ON_HOLD, IN_GRACE_PERIOD, PAUSED, DEFERRED

**External setup (manual — document steps in PR description, not automated):**
All steps documented in `docs/phase-16a-setup.md` for the user to follow.
- [x] Google Cloud service account with `androidpublisher` scope → JSON key → Supabase secret `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`
- [x] Pub/Sub topic `gymbuddy-rtdn` + push subscription → rtdn-webhook URL
- [x] Play Console: draft subscription `gymbuddy_premium`, base plans `:monthly` + `:annual`, 14-day free trial offer on both
- [x] Explicit prices: BRL R$19,90 / R$119,90 · USD $3,99 / $23,99 · EUR €3,99 / €23,99
- [x] PPP-aware auto-conversion enabled for other countries (Play's suggested-pricing tool)

**Tests:**
- [x] Unit tests for `validate-purchase` with mocked Play API: success, already-acknowledged, expired token, user_id mismatch
- [x] Unit tests for `rtdn-webhook`: all 10 notification types, duplicate handling, invalid JWT
- [x] Unit test for `validate-purchase` pending-ack + no-product-id branch (500, no :acknowledge call) — QA gate
- [x] Unit tests for shared helpers: OAuth token cache hit, JWK cache hit, SUBSCRIPTION_STATE_PENDING normalizer — QA gate
- [x] Document `curl` invocation examples for manual end-to-end testing (in `docs/phase-16a-setup.md`)

**QA gate fixes (Apr 21):**
- [x] Important #1 — added `idx_subscriptions_purchase_token` on `public.subscriptions(purchase_token)` for RTDN lookup hot path
- [x] Important #2 — regression test for "pending ack + empty lineItems" → 500, no ack call, no row mark
- [x] Nit #1 — corrected stale `tests_shared.test.ts` reference in `rtdn-webhook/test.ts` comment
- [x] Nit #2 — added OAuth access-token and JWK cache-hit tests to `_shared/google_play.test.ts`
- [x] Nit #3 — added `SUBSCRIPTION_STATE_PENDING → 'active'` normalizer test
- [x] Drive-by (uncovered by local Deno 2.7 run): `validate-purchase/test.ts` was unrunnable because `FAKE_PRIVATE_KEY` failed `crypto.subtle.importKey` on Deno 2.x — replaced with runtime-generated RSA-2048 PKCS#8 PEM
- [x] Drive-by: tampered-signature JWT test was intermittently flaky (flipping last base64 char of a 256-byte RSA sig can hit padding-only bits) — now flips first char (always mutates data bits)
- [x] Verified: 46/46 Deno tests pass on two consecutive runs (containerized Deno 2.7.12)

### Files to read before starting

- `PLAN.md` Phase 16 section (full spec — Business Model, Architecture, Schema, Sub-phases)
- `supabase/migrations/00001_initial_schema.sql` (RLS pattern reference)
- `supabase/migrations/00015_create_analytics_events.sql` (recent migration pattern + audit-log style)
- `supabase/functions/delete-user/index.ts` (Edge Function pattern — JWT verify, service-role client, CORS, error handling)
- `CLAUDE.md` (project conventions, commit format, migration rules)

### Notes

- **No Flutter code this phase.** `pubspec.yaml` untouched. 16b adds `in_app_purchase`.
- **Merchant account NOT required for 16a** — only for 16d production go-live.
- Service-role writes only on `subscriptions` / `subscription_events`; RLS blocks all client writes.
- Pub/Sub JWT is the auth mechanism for `rtdn-webhook` (no user JWT on that inbound path — it's a webhook).
- Manual Play Console + Google Cloud setup steps cannot be automated — document clearly in PR description so the user can reproduce/verify.
