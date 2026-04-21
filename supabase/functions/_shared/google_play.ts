// Shared Google Play Developer API helpers for the `validate-purchase` and
// `rtdn-webhook` Edge Functions.
//
// Exposes:
//   - getPlayAccessToken(): cached, signs a JWT with the service account
//     private key and exchanges it for a short-lived androidpublisher
//     access token at the Google OAuth2 token endpoint.
//   - fetchPlaySubscriptionV2(): calls purchases.subscriptionsv2.get.
//   - acknowledgePlaySubscription(): calls purchases.subscriptions.acknowledge.
//   - verifyPubSubJwt(): validates the Google-signed Pub/Sub push JWT
//     against Google's public JWK set.
//   - normalizePlaySubscription(): flattens a Play API response into the
//     shape our `subscriptions` table stores.
//
// Design notes:
// * The token cache lives at module scope. Deno Edge Function isolates
//   are reused across invocations on warm containers, so a 1-hour token
//   is honored across many requests. The cache is a plain object (no
//   locking) because worst-case concurrent refreshes just re-sign — the
//   token endpoint is idempotent.
// * All network calls go through `fetch`. No third-party deps (keeps
//   Edge Function bundle small and cold-start fast).
// * Everything here is testable: consumers pass in an optional `fetchFn`
//   so unit tests can substitute a mock without monkey-patching globals.

export type FetchFn = typeof fetch;

export interface ServiceAccountJson {
  client_email: string;
  private_key: string;
  token_uri?: string;
}

export interface PlayAccessToken {
  access_token: string;
  expires_at: number; // epoch ms
}

// --- OAuth2 token exchange -------------------------------------------------

const ANDROIDPUBLISHER_SCOPE = 'https://www.googleapis.com/auth/androidpublisher';
const DEFAULT_TOKEN_URI = 'https://oauth2.googleapis.com/token';

let cachedToken: PlayAccessToken | null = null;

// Test-only: lets a unit test drop the cache between cases. Not exported
// in a way that production code should rely on.
export function _resetPlayTokenCacheForTests(): void {
  cachedToken = null;
}

function base64UrlEncode(bytes: Uint8Array): string {
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function base64UrlEncodeString(s: string): string {
  return base64UrlEncode(new TextEncoder().encode(s));
}

// Decode a PEM-encoded PKCS#8 private key into raw bytes suitable for
// `crypto.subtle.importKey`. Google issues PKCS#8 keys in JSON service
// account files.
function pemToPkcs8(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN [^-]+-----/g, '')
    .replace(/-----END [^-]+-----/g, '')
    .replace(/\s+/g, '');
  const raw = atob(body);
  const buf = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) buf[i] = raw.charCodeAt(i);
  return buf;
}

// Build and sign the JWT assertion that proves we own the service
// account. Google exchanges this for an access_token.
async function signAssertion(sa: ServiceAccountJson): Promise<string> {
  const header = { alg: 'RS256', typ: 'JWT' };
  const nowSec = Math.floor(Date.now() / 1000);
  const claims = {
    iss: sa.client_email,
    scope: ANDROIDPUBLISHER_SCOPE,
    aud: sa.token_uri ?? DEFAULT_TOKEN_URI,
    exp: nowSec + 3600,
    iat: nowSec,
  };
  const signingInput =
    `${base64UrlEncodeString(JSON.stringify(header))}.${base64UrlEncodeString(JSON.stringify(claims))}`;

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToPkcs8(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = new Uint8Array(
    await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5',
      key,
      new TextEncoder().encode(signingInput),
    ),
  );
  return `${signingInput}.${base64UrlEncode(sig)}`;
}

export async function getPlayAccessToken(
  sa: ServiceAccountJson,
  fetchFn: FetchFn = fetch,
): Promise<string> {
  // 60s safety margin so a token that's about to expire during a slow
  // downstream call doesn't get rejected mid-flight.
  if (cachedToken && cachedToken.expires_at > Date.now() + 60_000) {
    return cachedToken.access_token;
  }

  const assertion = await signAssertion(sa);
  const form = new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion,
  });

  const res = await fetchFn(sa.token_uri ?? DEFAULT_TOKEN_URI, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: form.toString(),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Google OAuth token exchange failed: ${res.status} ${text}`);
  }
  const json = await res.json() as { access_token: string; expires_in: number };
  cachedToken = {
    access_token: json.access_token,
    expires_at: Date.now() + (json.expires_in ?? 3600) * 1000,
  };
  return cachedToken.access_token;
}

// --- Play Developer API v2 -------------------------------------------------

export interface PlaySubscriptionV2Response {
  kind?: string;
  regionCode?: string;
  lineItems?: Array<{
    productId?: string;
    expiryTime?: string; // RFC3339
    autoRenewingPlan?: { autoRenewEnabled?: boolean };
    offerDetails?: {
      offerId?: string;
      basePlanId?: string;
    };
  }>;
  startTime?: string;
  subscriptionState?: string; // e.g. SUBSCRIPTION_STATE_ACTIVE
  latestOrderId?: string;
  linkedPurchaseToken?: string;
  acknowledgementState?: string; // ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED / PENDING
  externalAccountIdentifiers?: {
    obfuscatedExternalAccountId?: string;
    obfuscatedExternalProfileId?: string;
  };
  pausedStateContext?: unknown;
  canceledStateContext?: unknown;
  testPurchase?: unknown;
}

export async function fetchPlaySubscriptionV2(args: {
  packageName: string;
  token: string;
  accessToken: string;
  fetchFn?: FetchFn;
}): Promise<{ status: number; body: PlaySubscriptionV2Response | { error?: unknown } }> {
  const f = args.fetchFn ?? fetch;
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v1/applications/${encodeURIComponent(args.packageName)}/purchases/subscriptionsv2/tokens/${encodeURIComponent(args.token)}`;
  const res = await f(url, {
    headers: { Authorization: `Bearer ${args.accessToken}` },
  });
  const body = await res.json().catch(() => ({}));
  return { status: res.status, body };
}

export async function acknowledgePlaySubscription(args: {
  packageName: string;
  subscriptionId: string;
  token: string;
  accessToken: string;
  fetchFn?: FetchFn;
}): Promise<{ ok: boolean; status: number; body: unknown }> {
  const f = args.fetchFn ?? fetch;
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(args.packageName)}/purchases/subscriptions/${encodeURIComponent(args.subscriptionId)}/tokens/${encodeURIComponent(args.token)}:acknowledge`;
  const res = await f(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${args.accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({}),
  });
  const body = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, body };
}

// --- Pub/Sub JWT verification ---------------------------------------------

// Google's Pub/Sub push delivery signs requests with a short-lived OIDC
// JWT. We verify: (a) valid RSA signature against Google's published JWKs,
// (b) issuer is `https://accounts.google.com`, (c) `exp` not passed,
// (d) audience matches the expected value (the push subscription's
// configured audience — typically the Edge Function URL).
//
// This is a minimal verifier: we do not validate `email` /
// `email_verified` because the push subscription's service account is
// already restricted via IAM in Google Cloud.

const GOOGLE_CERTS_URL = 'https://www.googleapis.com/oauth2/v3/certs';

interface Jwk {
  kid: string;
  kty: string;
  n: string;
  e: string;
  alg?: string;
}

interface JwkCache {
  keys: Record<string, CryptoKey>;
  expires_at: number;
}

let jwkCache: JwkCache | null = null;

export function _resetJwkCacheForTests(): void {
  jwkCache = null;
}

function base64UrlDecode(s: string): Uint8Array {
  const pad = s.length % 4 === 0 ? '' : '='.repeat(4 - (s.length % 4));
  const b64 = (s + pad).replace(/-/g, '+').replace(/_/g, '/');
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

async function loadGoogleJwks(fetchFn: FetchFn): Promise<Record<string, CryptoKey>> {
  if (jwkCache && jwkCache.expires_at > Date.now()) return jwkCache.keys;

  const res = await fetchFn(GOOGLE_CERTS_URL);
  if (!res.ok) {
    throw new Error(`Failed to load Google JWKs: ${res.status}`);
  }
  const json = await res.json() as { keys: Jwk[] };
  const keys: Record<string, CryptoKey> = {};
  for (const jwk of json.keys) {
    // Only import RSA keys used with RS256 — Google uses RS256 for its
    // OIDC tokens today. Other algs would be a signal the token is forged
    // or spec changed.
    if (jwk.kty !== 'RSA') continue;
    keys[jwk.kid] = await crypto.subtle.importKey(
      'jwk',
      jwk as JsonWebKey,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['verify'],
    );
  }
  // Cache for the remainder of the current hour. Google's cert rotation
  // happens roughly daily and announces Cache-Control, but a 1h cap is
  // simple and safe.
  jwkCache = { keys, expires_at: Date.now() + 60 * 60 * 1000 };
  return keys;
}

export interface PubSubClaims {
  iss: string;
  aud: string;
  exp: number;
  iat: number;
  email?: string;
  email_verified?: boolean;
  sub?: string;
}

export async function verifyPubSubJwt(args: {
  token: string;
  expectedAudience: string;
  fetchFn?: FetchFn;
  nowMs?: number;
}): Promise<PubSubClaims> {
  const fetchFn = args.fetchFn ?? fetch;
  const now = args.nowMs ?? Date.now();

  const parts = args.token.split('.');
  if (parts.length !== 3) throw new Error('Malformed JWT');
  const [h, p, s] = parts;

  const header = JSON.parse(new TextDecoder().decode(base64UrlDecode(h))) as
    { alg: string; kid: string };
  if (header.alg !== 'RS256') {
    throw new Error(`Unsupported JWT alg: ${header.alg}`);
  }

  const jwks = await loadGoogleJwks(fetchFn);
  const key = jwks[header.kid];
  if (!key) throw new Error(`Unknown JWT kid: ${header.kid}`);

  const signingInput = new TextEncoder().encode(`${h}.${p}`);
  const sig = base64UrlDecode(s);
  const ok = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    sig,
    signingInput,
  );
  if (!ok) throw new Error('JWT signature invalid');

  const claims = JSON.parse(new TextDecoder().decode(base64UrlDecode(p))) as PubSubClaims;
  if (claims.iss !== 'https://accounts.google.com' && claims.iss !== 'accounts.google.com') {
    throw new Error(`Unexpected JWT iss: ${claims.iss}`);
  }
  if (claims.aud !== args.expectedAudience) {
    throw new Error(`Unexpected JWT aud: ${claims.aud}`);
  }
  if (typeof claims.exp !== 'number' || claims.exp * 1000 <= now) {
    throw new Error('JWT expired');
  }
  return claims;
}

// --- Play → DB row normalization ------------------------------------------

// Canonical rolled-up state used by the `subscriptions.state` column.
// Maps Play's v2 SUBSCRIPTION_STATE_* enum to our five-value set.
// We keep this in one place so both validate-purchase (pull) and
// rtdn-webhook (push) agree on state derivation.
export function playStateToDbState(playState: string | undefined): string {
  switch (playState) {
    case 'SUBSCRIPTION_STATE_ACTIVE':
      return 'active';
    case 'SUBSCRIPTION_STATE_CANCELED':
      return 'canceled';
    case 'SUBSCRIPTION_STATE_EXPIRED':
      return 'expired';
    case 'SUBSCRIPTION_STATE_ON_HOLD':
      return 'on_hold';
    case 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD':
      // "active" entitlement-wise; grace flag tracked separately below.
      return 'active';
    case 'SUBSCRIPTION_STATE_PAUSED':
      return 'paused';
    case 'SUBSCRIPTION_STATE_PENDING':
      return 'active';
    default:
      return 'expired';
  }
}

export interface NormalizedSubscription {
  product_id: string;
  purchase_token: string;
  linked_purchase_token: string | null;
  state: string;
  auto_renewing: boolean;
  in_grace_period: boolean;
  acknowledgement_state: 'pending' | 'acknowledged';
  started_at: string | null;
  expires_at: string | null;
}

export function normalizePlaySubscription(args: {
  purchaseToken: string;
  playResponse: PlaySubscriptionV2Response;
}): NormalizedSubscription {
  const line = args.playResponse.lineItems?.[0];
  const productId =
    line?.offerDetails?.basePlanId
      ? `${line.productId ?? ''}:${line.offerDetails.basePlanId}`.replace(/^:/, '')
      : (line?.productId ?? '');

  const ackState =
    args.playResponse.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'
      ? 'acknowledged'
      : 'pending';

  return {
    product_id: productId,
    purchase_token: args.purchaseToken,
    linked_purchase_token: args.playResponse.linkedPurchaseToken ?? null,
    state: playStateToDbState(args.playResponse.subscriptionState),
    auto_renewing: line?.autoRenewingPlan?.autoRenewEnabled ?? false,
    in_grace_period:
      args.playResponse.subscriptionState === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
    acknowledgement_state: ackState,
    started_at: args.playResponse.startTime ?? null,
    expires_at: line?.expiryTime ?? null,
  };
}

// Top-level product id extraction for the acknowledge call, which wants
// just the base product id (not `product:baseplan`).
export function baseProductIdFromPlay(
  playResponse: PlaySubscriptionV2Response,
): string | null {
  return playResponse.lineItems?.[0]?.productId ?? null;
}
