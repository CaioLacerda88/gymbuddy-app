# Phase 16a — External setup checklist

The subscription backend (migrations + Edge Functions) is in code. The
pieces below can only be created through Google's and Supabase's UIs.
Follow this once, in order. Re-running any step is idempotent unless
noted.

Everything here is pre-launch infrastructure. **You do not need a
Brazilian merchant account for 16a.** Merchant setup is the 16d gate.

---

## 1. Google Cloud — service account for the Play Developer API

The `validate-purchase` Edge Function calls `purchases.subscriptionsv2.get`
and `purchases.subscriptions.acknowledge` using a service account. Play
Console requires the service account to be linked to the Play app.

### 1.1 Create the service account

1. Google Cloud Console → pick (or create) the GCP project you want for
   this app's server-side work.
2. IAM & Admin → Service Accounts → **Create service account**.
   * Name: `gymbuddy-play-api`
   * ID: leave auto-generated
   * Description: `Server-to-server calls to Play Developer API (validate, acknowledge, reconcile).`
3. Grant no project-level roles. Continue. Done.
4. Open the new service account → **Keys** tab → **Add Key** → Create
   new key → JSON → Download.
5. Store the JSON file somewhere you won't lose it (password manager /
   1Password / git-crypt secret). **Never commit it.**

### 1.2 Enable the API

GCP Console → APIs & Services → Library → search "Google Play Android
Developer API" → **Enable** for the project.

### 1.3 Link the service account to Play Console

1. Play Console → Setup → API access.
2. Find the GCP project you used above; click **Link**.
3. Under "Service accounts", find `gymbuddy-play-api@…iam.gserviceaccount.com`
   → **Grant access**.
4. Permissions: minimum set for Phase 16a —
   * **Account permissions**: (none needed)
   * **App permissions**: pick the GymBuddy app
   * Permissions: **View financial data**, **Manage orders and
     subscriptions**, **View app information**. Leave everything else
     off.
5. Invite user. Wait ~1 minute for the grant to propagate before the
   first API call.

---

## 2. Supabase — secrets

The Edge Functions read two project-level secrets. Set them with the
Supabase CLI:

```bash
# Paste the full JSON key file contents as one secret value.
supabase secrets set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON="$(cat ~/Downloads/gymbuddy-play-api-xxxxx.json)"

# The package name that appears in Play Console for the Android build.
supabase secrets set GOOGLE_PLAY_PACKAGE_NAME="com.gymbuddy.app"

# The audience that Pub/Sub will set on its push-delivery JWT. Must
# match exactly what you configure in step 3 below.
supabase secrets set RTDN_PUBSUB_AUDIENCE="https://<your-project-ref>.supabase.co/functions/v1/rtdn-webhook"
```

The reconciliation cron (migration 00026) also needs two database-level
settings so it knows which URL to POST to and which JWT to use:

```sql
-- Supabase SQL editor, connected as the postgres superuser:
ALTER DATABASE postgres SET app.settings.edge_functions_url =
  'https://<your-project-ref>.supabase.co/functions/v1';
ALTER DATABASE postgres SET app.settings.service_role_key =
  '<paste service role key from Supabase project settings>';
```

Verify from the SQL editor:

```sql
SELECT current_setting('app.settings.edge_functions_url', true);
SELECT current_setting('app.settings.service_role_key',    true) IS NOT NULL;
```

---

## 3. Google Cloud Pub/Sub — RTDN topic + push subscription

### 3.1 Topic

GCP Console → Pub/Sub → Topics → **Create topic**.
* Name: `gymbuddy-rtdn`
* Default encryption. Leave schema off.

### 3.2 Grant Play the right to publish

The "Google Play" service account (pre-existing, identified as
`google-play-developer-notifications@system.gserviceaccount.com`) must
be granted **Pub/Sub Publisher** on this topic:

Topic → Permissions → **Add principal** →
`google-play-developer-notifications@system.gserviceaccount.com` → role
`Pub/Sub Publisher` → Save.

### 3.3 Push subscription → Edge Function

Topic → Create subscription.
* Name: `gymbuddy-rtdn-push`
* Delivery type: **Push**
* Endpoint URL: `https://<your-project-ref>.supabase.co/functions/v1/rtdn-webhook`
* Enable authentication: **Yes**
  * Service account: create or pick one (any GCP service account in
    this project; our verifier trusts Google's OIDC as long as aud
    matches).
  * Audience: **exactly** the URL you set as `RTDN_PUBSUB_AUDIENCE` in
    step 2. Usually the Edge Function URL.
* Acknowledgement deadline: 10 seconds (default). Retry policy:
  exponential backoff, default. Dead-letter topic: optional; for 16a
  leave it off and revisit in 16d.

### 3.4 Tell Play about the topic

Play Console → Monetize → Subscriptions → **Monetization setup** →
Real-time developer notifications (RTDN) → Topic name:
`projects/<gcp-project-id>/topics/gymbuddy-rtdn` → **Send test
notification** → confirm you see a 200 in Pub/Sub metrics for the
subscription.

---

## 4. Play Console — draft subscription product

This is the gymbuddy_premium draft. It does NOT require a merchant
account, but the subscription cannot be published to production until
the merchant is live.

### 4.1 Product

Play Console → Monetize → Subscriptions → **Create subscription**.
* Product ID: `gymbuddy_premium`
* Name: `GymBuddy Premium`
* Description: (2-3 sentences, Play Store policy: must be benefits-first,
  not feature-first).

### 4.2 Base plans

Two base plans on the single product:

| ID        | Billing period | Renewal     |
| --------- | -------------- | ----------- |
| `monthly` | Monthly        | Auto-renewing |
| `annual`  | Yearly         | Auto-renewing |

### 4.3 Explicit prices

Set these for both base plans:

| Market | Monthly (`:monthly`) | Annual (`:annual`) |
| ------ | -------------------- | ------------------ |
| Brazil (BRL)   | R$19,90 | R$119,90 |
| United States (USD) | $3,99 | $23,99 |
| Eurozone (EUR) | €3,99 | €23,99 |

For every other market: enable **Use suggested prices for all other
countries** (Play's PPP-aware auto-conversion tool). Spot-check the
generated prices for: UK, DE, FR, ES, PT, MX, AR, CA, AU.

### 4.4 Trial offer

Both base plans get a **free trial offer**:
* Offer ID: `trial-14d`
* Eligibility: New customer (one-per-Google-account, Play-enforced)
* Free trial length: 14 days
* No introductory price after trial — falls through to the base plan
  price.

### 4.5 Save as draft

Do NOT activate yet. The draft is enough for 16a testing via internal
testing + license-tester accounts.

---

## 5. Verify end-to-end (without merchant)

### 5.1 Migrations applied

```bash
supabase db push
# Or, if linked:
supabase link --project-ref <ref> && supabase db push
```

Verify:
```sql
SELECT COUNT(*) FROM pg_policies WHERE tablename = 'subscriptions';   -- 1 (SELECT own)
SELECT COUNT(*) FROM pg_policies WHERE tablename = 'subscription_events'; -- 1
SELECT COUNT(*) FROM cron.job WHERE jobname = 'subscription_reconcile_6h'; -- 1
```

### 5.2 Edge Functions deployed

```bash
supabase functions deploy validate-purchase
supabase functions deploy rtdn-webhook
```

### 5.3 RTDN webhook smoke test

From Play Console → Monetize → Subscriptions → Monetization setup →
RTDN → **Send test notification**. You should get:
* Pub/Sub metric: 1 delivery, 200 response.
* Supabase Edge Function logs: `{ "success": true, "test": true }`.

### 5.4 validate-purchase smoke test (requires license tester)

Build the app (16b will wire this up) or use `curl` with a purchase
token obtained from an internal-testing license-tester account:

```bash
curl -X POST \
  -H "Authorization: Bearer <user-jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "product_id": "gymbuddy_premium:monthly",
    "purchase_token": "<token from Play>",
    "source": "client"
  }' \
  https://<your-project-ref>.supabase.co/functions/v1/validate-purchase
```

Expected: `{"success":true,"entitlement_state":"premium","expires_at":"..."}`
and a new row in `public.subscriptions` for the calling user.

---

## 6. What's next (not in 16a)

* 16b: add `in_app_purchase ^3.2.x` to the Flutter app, wire paywall UI,
  onboarding → paywall route rewrite.
* 16c: hard gate enforcement, router guard, E2E refactor.
* 16d: analytics, Sentry breadcrumbs, Brazilian merchant account setup,
  launch-readiness checklist.

If any step above blocks you (API access invite expiring, Pub/Sub IAM
drift, Play product draft rejected), write the exact error and
credential state into `tasks/WIP.md` before retrying — it's easier to
debug permission chains with a diff than from memory.
