// Tests for the shared Google Play helpers. Focused on the small pure
// pieces that are easy to verify without network: the Play → DB state
// mapping, and Pub/Sub JWT verification (we sign our own JWT with a
// throwaway key, serve that key back via a mocked JWKs endpoint, and
// watch the verifier accept / reject across valid + tampered inputs).
//
// Run with: deno test --allow-net --allow-env supabase/functions/

import {
  assert,
  assertEquals,
  assertRejects,
} from 'https://deno.land/std@0.224.0/assert/mod.ts';
import {
  _resetJwkCacheForTests,
  baseProductIdFromPlay,
  normalizePlaySubscription,
  playStateToDbState,
  verifyPubSubJwt,
} from './google_play.ts';

// --- playStateToDbState ---------------------------------------------------

Deno.test('playStateToDbState maps all v2 states', () => {
  assertEquals(playStateToDbState('SUBSCRIPTION_STATE_ACTIVE'),          'active');
  assertEquals(playStateToDbState('SUBSCRIPTION_STATE_CANCELED'),        'canceled');
  assertEquals(playStateToDbState('SUBSCRIPTION_STATE_EXPIRED'),         'expired');
  assertEquals(playStateToDbState('SUBSCRIPTION_STATE_ON_HOLD'),         'on_hold');
  assertEquals(playStateToDbState('SUBSCRIPTION_STATE_IN_GRACE_PERIOD'), 'active');
  assertEquals(playStateToDbState('SUBSCRIPTION_STATE_PAUSED'),          'paused');
  assertEquals(playStateToDbState('SUBSCRIPTION_STATE_PENDING'),         'active');
  // Unknown / missing → expired (safe default, denies entitlement).
  assertEquals(playStateToDbState(undefined),                            'expired');
  assertEquals(playStateToDbState('SOMETHING_NEW'),                      'expired');
});

// --- normalizePlaySubscription -------------------------------------------

Deno.test('normalizePlaySubscription: active + pending ack', () => {
  const n = normalizePlaySubscription({
    purchaseToken: 'tok',
    playResponse: {
      subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
      startTime: '2024-01-01T00:00:00Z',
      linkedPurchaseToken: 'prev_tok',
      lineItems: [{
        productId: 'gymbuddy_premium',
        expiryTime: '2025-01-01T00:00:00Z',
        autoRenewingPlan: { autoRenewEnabled: true },
        offerDetails: { basePlanId: 'monthly' },
      }],
    },
  });
  assertEquals(n.state, 'active');
  assertEquals(n.acknowledgement_state, 'pending');
  assertEquals(n.auto_renewing, true);
  assertEquals(n.in_grace_period, false);
  assertEquals(n.product_id, 'gymbuddy_premium:monthly');
  assertEquals(n.linked_purchase_token, 'prev_tok');
  assertEquals(n.started_at, '2024-01-01T00:00:00Z');
  assertEquals(n.expires_at, '2025-01-01T00:00:00Z');
});

Deno.test('normalizePlaySubscription: in_grace_period', () => {
  const n = normalizePlaySubscription({
    purchaseToken: 'tok',
    playResponse: {
      subscriptionState: 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
      lineItems: [{ productId: 'gymbuddy_premium', autoRenewingPlan: { autoRenewEnabled: true } }],
    },
  });
  assertEquals(n.state, 'active');
  assertEquals(n.in_grace_period, true);
  assertEquals(n.acknowledgement_state, 'acknowledged');
});

Deno.test('baseProductIdFromPlay extracts top-level product', () => {
  assertEquals(
    baseProductIdFromPlay({
      lineItems: [{ productId: 'gymbuddy_premium', offerDetails: { basePlanId: 'annual' } }],
    }),
    'gymbuddy_premium',
  );
  assertEquals(baseProductIdFromPlay({}), null);
  assertEquals(baseProductIdFromPlay({ lineItems: [] }), null);
});

// --- verifyPubSubJwt ------------------------------------------------------
//
// Generate a real RSA keypair at test start, sign a JWT with the private
// key, serve the public key from a mocked JWKs endpoint, and verify.

function base64UrlEncode(bytes: Uint8Array): string {
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function encodeJson(v: unknown): string {
  return base64UrlEncode(new TextEncoder().encode(JSON.stringify(v)));
}

async function signJwt(args: {
  privateKey: CryptoKey;
  header: Record<string, unknown>;
  payload: Record<string, unknown>;
}): Promise<string> {
  const signingInput = `${encodeJson(args.header)}.${encodeJson(args.payload)}`;
  const sig = new Uint8Array(
    await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5',
      args.privateKey,
      new TextEncoder().encode(signingInput),
    ),
  );
  return `${signingInput}.${base64UrlEncode(sig)}`;
}

async function makeKeypairAndJwks(kid: string): Promise<{
  privateKey: CryptoKey;
  jwksBody: { keys: unknown[] };
}> {
  const { privateKey, publicKey } = await crypto.subtle.generateKey(
    {
      name: 'RSASSA-PKCS1-v1_5',
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: 'SHA-256',
    },
    true,
    ['sign', 'verify'],
  );
  const jwk = await crypto.subtle.exportKey('jwk', publicKey) as Record<string, unknown>;
  jwk.kid = kid;
  jwk.alg = 'RS256';
  jwk.use = 'sig';
  return { privateKey, jwksBody: { keys: [jwk] } };
}

function fetchMockFor(jwksBody: unknown): typeof fetch {
  return (input, _init) => {
    const url = typeof input === 'string' ? input : (input as Request).url;
    if (url.includes('/oauth2/v3/certs')) {
      return Promise.resolve(new Response(JSON.stringify(jwksBody), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }));
    }
    return Promise.reject(new Error(`unexpected fetch: ${url}`));
  };
}

Deno.test('verifyPubSubJwt: valid JWT passes', async () => {
  _resetJwkCacheForTests();
  const { privateKey, jwksBody } = await makeKeypairAndJwks('kid_valid');
  const now = Math.floor(Date.now() / 1000);
  const jwt = await signJwt({
    privateKey,
    header: { alg: 'RS256', kid: 'kid_valid', typ: 'JWT' },
    payload: {
      iss: 'https://accounts.google.com',
      aud: 'https://project.supabase.co/functions/v1/rtdn-webhook',
      exp: now + 3600,
      iat: now,
    },
  });

  const claims = await verifyPubSubJwt({
    token: jwt,
    expectedAudience: 'https://project.supabase.co/functions/v1/rtdn-webhook',
    fetchFn: fetchMockFor(jwksBody),
  });
  assertEquals(claims.aud, 'https://project.supabase.co/functions/v1/rtdn-webhook');
});

Deno.test('verifyPubSubJwt: wrong audience rejected', async () => {
  _resetJwkCacheForTests();
  const { privateKey, jwksBody } = await makeKeypairAndJwks('kid_aud');
  const now = Math.floor(Date.now() / 1000);
  const jwt = await signJwt({
    privateKey,
    header: { alg: 'RS256', kid: 'kid_aud', typ: 'JWT' },
    payload: {
      iss: 'https://accounts.google.com',
      aud: 'https://evil.example.com',
      exp: now + 3600,
      iat: now,
    },
  });
  await assertRejects(
    () => verifyPubSubJwt({
      token: jwt,
      expectedAudience: 'https://correct.example.com',
      fetchFn: fetchMockFor(jwksBody),
    }),
    Error,
    'Unexpected JWT aud',
  );
});

Deno.test('verifyPubSubJwt: expired JWT rejected', async () => {
  _resetJwkCacheForTests();
  const { privateKey, jwksBody } = await makeKeypairAndJwks('kid_exp');
  const now = Math.floor(Date.now() / 1000);
  const jwt = await signJwt({
    privateKey,
    header: { alg: 'RS256', kid: 'kid_exp', typ: 'JWT' },
    payload: {
      iss: 'https://accounts.google.com',
      aud: 'aud',
      exp: now - 60,
      iat: now - 3600,
    },
  });
  await assertRejects(
    () => verifyPubSubJwt({
      token: jwt,
      expectedAudience: 'aud',
      fetchFn: fetchMockFor(jwksBody),
    }),
    Error,
    'JWT expired',
  );
});

Deno.test('verifyPubSubJwt: wrong issuer rejected', async () => {
  _resetJwkCacheForTests();
  const { privateKey, jwksBody } = await makeKeypairAndJwks('kid_iss');
  const now = Math.floor(Date.now() / 1000);
  const jwt = await signJwt({
    privateKey,
    header: { alg: 'RS256', kid: 'kid_iss', typ: 'JWT' },
    payload: {
      iss: 'https://evil.example.com',
      aud: 'aud',
      exp: now + 3600,
      iat: now,
    },
  });
  await assertRejects(
    () => verifyPubSubJwt({
      token: jwt,
      expectedAudience: 'aud',
      fetchFn: fetchMockFor(jwksBody),
    }),
    Error,
    'Unexpected JWT iss',
  );
});

Deno.test('verifyPubSubJwt: unknown kid rejected', async () => {
  _resetJwkCacheForTests();
  const { privateKey, jwksBody } = await makeKeypairAndJwks('kid_real');
  const now = Math.floor(Date.now() / 1000);
  // Sign with real key but claim a different kid in the header — verifier
  // will fetch JWKs, fail to find the claimed kid, and reject.
  const jwt = await signJwt({
    privateKey,
    header: { alg: 'RS256', kid: 'kid_forged', typ: 'JWT' },
    payload: {
      iss: 'https://accounts.google.com',
      aud: 'aud',
      exp: now + 3600,
      iat: now,
    },
  });
  await assertRejects(
    () => verifyPubSubJwt({
      token: jwt,
      expectedAudience: 'aud',
      fetchFn: fetchMockFor(jwksBody),
    }),
    Error,
    'Unknown JWT kid',
  );
});

Deno.test('verifyPubSubJwt: malformed token rejected', async () => {
  _resetJwkCacheForTests();
  await assertRejects(
    () => verifyPubSubJwt({
      token: 'not.a.jwt.at.all',
      expectedAudience: 'aud',
      fetchFn: fetchMockFor({ keys: [] }),
    }),
    Error,
  );
});

Deno.test('verifyPubSubJwt: tampered signature rejected', async () => {
  _resetJwkCacheForTests();
  const { privateKey, jwksBody } = await makeKeypairAndJwks('kid_tamper');
  const now = Math.floor(Date.now() / 1000);
  const jwt = await signJwt({
    privateKey,
    header: { alg: 'RS256', kid: 'kid_tamper', typ: 'JWT' },
    payload: {
      iss: 'https://accounts.google.com',
      aud: 'aud',
      exp: now + 3600,
      iat: now,
    },
  });
  // Flip the last byte of the signature.
  const parts = jwt.split('.');
  parts[2] = parts[2].slice(0, -1) + (parts[2].endsWith('A') ? 'B' : 'A');
  const tampered = parts.join('.');

  await assertRejects(
    () => verifyPubSubJwt({
      token: tampered,
      expectedAudience: 'aud',
      fetchFn: fetchMockFor(jwksBody),
    }),
    Error,
    'signature',
  );
});
