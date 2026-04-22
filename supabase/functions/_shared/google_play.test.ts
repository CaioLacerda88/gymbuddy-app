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
  _resetPlayTokenCacheForTests,
  baseProductIdFromPlay,
  getPlayAccessToken,
  normalizePlaySubscription,
  playStateToDbState,
  type ServiceAccountJson,
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
        productId: 'repsaga_premium',
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
  assertEquals(n.product_id, 'repsaga_premium:monthly');
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
      lineItems: [{ productId: 'repsaga_premium', autoRenewingPlan: { autoRenewEnabled: true } }],
    },
  });
  assertEquals(n.state, 'active');
  assertEquals(n.in_grace_period, true);
  assertEquals(n.acknowledgement_state, 'acknowledged');
});

Deno.test('baseProductIdFromPlay extracts top-level product', () => {
  assertEquals(
    baseProductIdFromPlay({
      lineItems: [{ productId: 'repsaga_premium', offerDetails: { basePlanId: 'annual' } }],
    }),
    'repsaga_premium',
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
  // Flip the FIRST byte of the signature. Flipping the last base64 char
  // is risky because for a 256-byte RSA signature the last base64 char
  // only carries 2 data bits + 4 padding bits — a flip that happens to
  // land in the padding bits produces a signature that decodes to the
  // same bytes, and the test would pass a valid signature and fail to
  // verify its tampered premise. The first char always encodes 6 real
  // data bits of byte 0, so flipping it always mutates the signature.
  const parts = jwt.split('.');
  parts[2] = (parts[2].startsWith('A') ? 'B' : 'A') + parts[2].slice(1);
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

// --- JWK cache hit --------------------------------------------------------
//
// Google's JWKs barely change; our verifier caches the imported keys for
// 1h. Locking that in so a regression that refetches on every call (e.g.
// accidentally clearing the cache) surfaces immediately.

Deno.test('verifyPubSubJwt: second call reuses cached JWKs (no refetch)', async () => {
  _resetJwkCacheForTests();
  const { privateKey, jwksBody } = await makeKeypairAndJwks('kid_cache');
  const now = Math.floor(Date.now() / 1000);

  let certsFetches = 0;
  const countingFetch: typeof fetch = (input, _init) => {
    const url = typeof input === 'string' ? input : (input as Request).url;
    if (url.includes('/oauth2/v3/certs')) {
      certsFetches += 1;
      return Promise.resolve(new Response(JSON.stringify(jwksBody), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }));
    }
    return Promise.reject(new Error(`unexpected fetch: ${url}`));
  };

  const mkJwt = () => signJwt({
    privateKey,
    header: { alg: 'RS256', kid: 'kid_cache', typ: 'JWT' },
    payload: {
      iss: 'https://accounts.google.com',
      aud: 'aud',
      exp: now + 3600,
      iat: now,
    },
  });

  await verifyPubSubJwt({
    token: await mkJwt(),
    expectedAudience: 'aud',
    fetchFn: countingFetch,
  });
  await verifyPubSubJwt({
    token: await mkJwt(),
    expectedAudience: 'aud',
    fetchFn: countingFetch,
  });

  assertEquals(certsFetches, 1, 'JWKs should be fetched once and reused');
});

// --- OAuth access-token cache hit -----------------------------------------
//
// `getPlayAccessToken` caches the access_token for its stated lifetime
// (minus a 60s safety margin). Calling twice in quick succession must hit
// the token endpoint exactly once — otherwise every Play API call re-signs
// a JWT + roundtrips to Google, which would burn cold-start budget.

async function generatePkcs8PemKeypair(): Promise<ServiceAccountJson> {
  const { privateKey } = await crypto.subtle.generateKey(
    {
      name: 'RSASSA-PKCS1-v1_5',
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: 'SHA-256',
    },
    true,
    ['sign', 'verify'],
  );
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey('pkcs8', privateKey));
  // Chunk base64 into PEM-standard 64-char lines.
  let bin = '';
  for (const b of pkcs8) bin += String.fromCharCode(b);
  const b64 = btoa(bin);
  const lines = b64.match(/.{1,64}/g) ?? [b64];
  const pem = `-----BEGIN PRIVATE KEY-----\n${lines.join('\n')}\n-----END PRIVATE KEY-----\n`;
  return {
    client_email: 'cachetest@example.iam.gserviceaccount.com',
    private_key: pem,
    token_uri: 'https://oauth2.googleapis.com/token',
  };
}

Deno.test('getPlayAccessToken: second call served from cache (no refetch)', async () => {
  _resetPlayTokenCacheForTests();
  const sa = await generatePkcs8PemKeypair();

  let tokenFetches = 0;
  const countingFetch: typeof fetch = (input, _init) => {
    const url = typeof input === 'string' ? input : (input as Request).url;
    if (url.includes('oauth2.googleapis.com/token')) {
      tokenFetches += 1;
      return Promise.resolve(new Response(JSON.stringify({
        access_token: 'ya29.cached',
        expires_in: 3600,
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }));
    }
    return Promise.reject(new Error(`unexpected fetch: ${url}`));
  };

  const t1 = await getPlayAccessToken(sa, countingFetch);
  const t2 = await getPlayAccessToken(sa, countingFetch);

  assertEquals(t1, 'ya29.cached');
  assertEquals(t2, 'ya29.cached');
  assertEquals(tokenFetches, 1, 'token endpoint should be hit exactly once');
});

// --- SUBSCRIPTION_STATE_PENDING normalization -----------------------------
//
// Play returns SUBSCRIPTION_STATE_PENDING when a purchase hasn't finished
// settling (e.g. slow payment method). Our mapping deliberately surfaces
// this as `active` at the DB level — the entitlement derivation in
// `deriveEntitlement` gates on expires_at, so a pending-but-unexpired sub
// still grants premium (matches Play's own "grant entitlement optimistically,
// revoke if payment fails" guidance). Locking this in so a future
// refactor doesn't silently downgrade PENDING to expired/free.

Deno.test('normalizePlaySubscription: SUBSCRIPTION_STATE_PENDING → active', () => {
  const n = normalizePlaySubscription({
    purchaseToken: 'tok_pending',
    playResponse: {
      subscriptionState: 'SUBSCRIPTION_STATE_PENDING',
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
      lineItems: [{
        productId: 'repsaga_premium',
        expiryTime: '2030-01-01T00:00:00Z',
        autoRenewingPlan: { autoRenewEnabled: true },
        offerDetails: { basePlanId: 'monthly' },
      }],
    },
  });
  assertEquals(n.state, 'active');
  assertEquals(n.in_grace_period, false);
  assertEquals(n.acknowledgement_state, 'pending');
});
