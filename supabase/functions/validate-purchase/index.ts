// Supabase Edge Function: validate-purchase
//
// Called from the Flutter client after a successful
// `in_app_purchase` flow to server-validate the purchase token against
// the Google Play Developer API and grant entitlement only if Play
// confirms it.
//
// Contract (POST JSON):
//   {
//     "product_id":     "gymbuddy_premium:monthly",
//     "purchase_token": "eyjk...",
//     "user_id":        "<uuid>",       // optional; defaults to JWT sub
//     "source":         "client" | "cron_reconcile"  // optional, audit only
//   }
//
// Behavior:
//   1. Verify the caller's JWT (anon client) or accept service-role JWTs
//      from the internal reconciliation cron.
//   2. Ensure the JWT user_id matches `obfuscatedExternalAccountId` in
//      the Play response — prevents token hijacking across Supabase users.
//   3. UPSERT the `subscriptions` row through the service-role client.
//   4. Write an audit row to `subscription_events` (type = source).
//   5. If the subscription needs acknowledgement, call the Play
//      acknowledge endpoint. On acknowledgement failure we return 500
//      WITHOUT leaving the UPSERT in a "granted" state on a pending
//      subscription — we deliberately keep the row but force
//      `acknowledgement_state='pending'` so a retry is clean. The
//      entitlements view only reports `premium` if state='active' AND
//      expires_at > now(); it does NOT consult acknowledgement_state
//      directly, so this is enforced at the UI layer by a follow-up
//      check (16b will expose `acknowledgement_state` through the client
//      to gate access until ack succeeds). For 16a the contract is:
//      non-2xx ack → function returns 500 and the client is responsible
//      for retrying.
//
// Env vars (Supabase sets the first three automatically):
//   SUPABASE_URL
//   SUPABASE_ANON_KEY
//   SUPABASE_SERVICE_ROLE_KEY
//   GOOGLE_PLAY_SERVICE_ACCOUNT_JSON  (service account credentials)
//   GOOGLE_PLAY_PACKAGE_NAME          (e.g. "com.gymbuddy.app")

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  acknowledgePlaySubscription,
  baseProductIdFromPlay,
  fetchPlaySubscriptionV2,
  getPlayAccessToken,
  normalizePlaySubscription,
  type ServiceAccountJson,
} from '../_shared/google_play.ts';

const allowedOrigin = Deno.env.get('SUPABASE_URL') ?? '';
const corsHeaders = {
  'Access-Control-Allow-Origin': allowedOrigin,
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  Vary: 'Origin',
};

function json(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// --- Core handler, extracted so unit tests can drive it without HTTP ------

export interface ValidatePurchaseDeps {
  fetchFn?: typeof fetch;
  now?: () => Date;
}

export interface ValidatePurchaseInput {
  userId: string;
  productId: string;
  purchaseToken: string;
  source: string;
  serviceAccount: ServiceAccountJson;
  packageName: string;
  client: SupabaseClient;
}

export interface ValidatePurchaseResult {
  status: number;
  body: Record<string, unknown>;
}

export async function validatePurchase(
  input: ValidatePurchaseInput,
  deps: ValidatePurchaseDeps = {},
): Promise<ValidatePurchaseResult> {
  const fetchFn = deps.fetchFn ?? fetch;

  // 1. OAuth2 exchange for an androidpublisher access token.
  let accessToken: string;
  try {
    accessToken = await getPlayAccessToken(input.serviceAccount, fetchFn);
  } catch (e) {
    return {
      status: 500,
      body: { error: 'Failed to obtain Play access token', detail: String(e) },
    };
  }

  // 2. purchases.subscriptionsv2.get
  const play = await fetchPlaySubscriptionV2({
    packageName: input.packageName,
    token: input.purchaseToken,
    accessToken,
    fetchFn,
  });

  if (play.status >= 400) {
    // 4xx/5xx from Play — relay status class so client can decide to
    // retry (5xx) vs surface as user error (4xx).
    return {
      status: play.status >= 500 ? 502 : 400,
      body: { error: 'Play API error', status: play.status, detail: play.body },
    };
  }

  const playBody = play.body as Parameters<typeof normalizePlaySubscription>[0]['playResponse'];

  // 3. Enforce obfuscatedAccountId binding — the client is supposed to
  // set this to the Supabase user_id at purchase time. If Play says the
  // token belongs to a different user, refuse the grant.
  const boundUserId =
    playBody.externalAccountIdentifiers?.obfuscatedExternalAccountId;
  if (!boundUserId) {
    return {
      status: 400,
      body: {
        error: 'Purchase token is not bound to a Supabase user '
             + '(obfuscatedAccountId missing)',
      },
    };
  }
  if (boundUserId !== input.userId) {
    return {
      status: 403,
      body: {
        error: 'Purchase token user mismatch',
        expected: input.userId,
        actual: boundUserId,
      },
    };
  }

  // 4. Normalize + UPSERT the subscription row via the service role.
  const adminClient = input.client;

  const normalized = normalizePlaySubscription({
    purchaseToken: input.purchaseToken,
    playResponse: playBody,
  });

  const { error: upsertError } = await adminClient
    .from('subscriptions')
    .upsert(
      {
        user_id: input.userId,
        product_id: normalized.product_id || input.productId,
        purchase_token: normalized.purchase_token,
        linked_purchase_token: normalized.linked_purchase_token,
        state: normalized.state,
        auto_renewing: normalized.auto_renewing,
        in_grace_period: normalized.in_grace_period,
        acknowledgement_state: normalized.acknowledgement_state,
        started_at: normalized.started_at,
        expires_at: normalized.expires_at,
      },
      { onConflict: 'user_id' },
    );
  if (upsertError) {
    return {
      status: 500,
      body: { error: 'Subscriptions UPSERT failed', detail: upsertError.message },
    };
  }

  // 5. Audit row. Duplicate RTDNs are collapsed elsewhere; this
  // validation source is always fresh so we use `now` as event_time.
  const eventTime = (deps.now ? deps.now() : new Date()).toISOString();
  const { error: evErr } = await adminClient
    .from('subscription_events')
    .insert({
      user_id: input.userId,
      purchase_token: input.purchaseToken,
      notification_type: `validate:${input.source}`,
      event_time: eventTime,
      raw_payload: playBody as unknown as Record<string, unknown>,
    });
  if (evErr && !isUniqueViolation(evErr)) {
    // Non-dedupe insert failure is a real error — but do NOT undo the
    // UPSERT: the subscriptions row already reflects Play truth.
    return {
      status: 500,
      body: { error: 'subscription_events insert failed', detail: evErr.message },
    };
  }

  // 6. Acknowledge within 3d. If it fails, we return 500 WITHOUT marking
  // acknowledgement_state='acknowledged'. Entitlement derivation doesn't
  // require acknowledged state at the DB level, but the client contract
  // is: a 200 means "use the app"; 500 means "do not grant yet, retry".
  if (normalized.acknowledgement_state === 'pending') {
    const baseProduct = baseProductIdFromPlay(playBody) ?? '';
    if (!baseProduct) {
      return {
        status: 500,
        body: { error: 'Cannot acknowledge: no product id in Play response' },
      };
    }
    const ack = await acknowledgePlaySubscription({
      packageName: input.packageName,
      subscriptionId: baseProduct,
      token: input.purchaseToken,
      accessToken,
      fetchFn,
    });
    if (!ack.ok) {
      return {
        status: 500,
        body: {
          error: 'Acknowledgement failed; entitlement not granted',
          detail: ack.body,
          status: ack.status,
        },
      };
    }
    // Best-effort: update acknowledgement_state. If this write fails
    // we still return 200 because Play itself has been acknowledged —
    // the reconcile cron will pick up the truth on its next run.
    await adminClient
      .from('subscriptions')
      .update({ acknowledgement_state: 'acknowledged' })
      .eq('user_id', input.userId);
  }

  return {
    status: 200,
    body: {
      success: true,
      entitlement_state: deriveEntitlement(normalized, deps.now ? deps.now() : new Date()),
      expires_at: normalized.expires_at,
    },
  };
}

function isUniqueViolation(err: { code?: string; message?: string }): boolean {
  return err.code === '23505' || /duplicate key/i.test(err.message ?? '');
}

function deriveEntitlement(
  n: { state: string; in_grace_period: boolean; expires_at: string | null },
  now: Date,
): string {
  if (!n.expires_at) return 'free';
  const exp = new Date(n.expires_at).getTime();
  if (n.state === 'active' && exp > now.getTime()) return 'premium';
  if (n.in_grace_period && exp > now.getTime() - 3 * 24 * 60 * 60 * 1000) {
    return 'grace_period';
  }
  if (n.state === 'on_hold') return 'on_hold';
  return 'free';
}

// --- HTTP boundary --------------------------------------------------------

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return json({ error: 'Missing Authorization header' }, 401);
    const jwt = authHeader.replace('Bearer ', '');

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const saJson = Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON');
    const packageName = Deno.env.get('GOOGLE_PLAY_PACKAGE_NAME');
    if (!supabaseUrl || !anonKey || !serviceRoleKey || !saJson || !packageName) {
      return json({ error: 'Server misconfigured' }, 500);
    }

    // Parse body first so we can fall back on explicit user_id when the
    // cron invokes us with a service-role JWT (which has no Supabase auth
    // user attached to it).
    let body: {
      product_id?: unknown;
      purchase_token?: unknown;
      user_id?: unknown;
      source?: unknown;
    } = {};
    try {
      body = await req.json();
    } catch (_) {
      return json({ error: 'Invalid JSON body' }, 400);
    }

    const productId = typeof body.product_id === 'string' ? body.product_id : '';
    const purchaseToken =
      typeof body.purchase_token === 'string' ? body.purchase_token : '';
    const source = typeof body.source === 'string' ? body.source : 'client';
    if (!productId || !purchaseToken) {
      return json({ error: 'product_id and purchase_token required' }, 400);
    }

    // Resolve caller user_id. Service-role callers (cron) supply it
    // explicitly in the body. Authenticated users are identified from
    // their JWT and MUST match any user_id they pass (prevents a
    // user acting on another user's purchase via a forged body).
    let userId: string;
    if (jwt === serviceRoleKey) {
      if (typeof body.user_id !== 'string' || !body.user_id) {
        return json({ error: 'user_id required for service-role calls' }, 400);
      }
      userId = body.user_id;
    } else {
      const userClient = createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: `Bearer ${jwt}` } },
      });
      const { data: { user }, error: uerr } = await userClient.auth.getUser(jwt);
      if (uerr || !user) return json({ error: 'Invalid or expired token' }, 401);
      if (
        typeof body.user_id === 'string'
        && body.user_id
        && body.user_id !== user.id
      ) {
        return json({ error: 'user_id does not match JWT' }, 403);
      }
      userId = user.id;
    }

    let serviceAccount: ServiceAccountJson;
    try {
      serviceAccount = JSON.parse(saJson);
    } catch (_) {
      return json({ error: 'Invalid GOOGLE_PLAY_SERVICE_ACCOUNT_JSON' }, 500);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const result = await validatePurchase({
      userId,
      productId,
      purchaseToken,
      source,
      serviceAccount,
      packageName,
      client: adminClient,
    });
    return json(result.body, result.status);
  } catch (e) {
    return json(
      { error: e instanceof Error ? e.message : 'Unknown error' },
      500,
    );
  }
});
