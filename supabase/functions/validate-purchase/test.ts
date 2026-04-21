// Unit tests for validate-purchase Edge Function.
//
// These tests exercise the pure `validatePurchase()` core with a mocked
// fetch (Play OAuth + Play API) and a fake SupabaseClient stub. No real
// network, no Play API, no DB.
//
// Run with:  deno test --allow-net --allow-env supabase/functions/
//
// We do NOT test the HTTP boundary here — JWT resolution + body parsing
// live in the `serve()` wrapper and are thin enough that repeated
// coverage adds little value.

import {
  assert,
  assertEquals,
  assertStringIncludes,
} from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { validatePurchase } from './index.ts';
import {
  _resetPlayTokenCacheForTests,
  type ServiceAccountJson,
} from '../_shared/google_play.ts';

// --- Fixtures --------------------------------------------------------------

// `signAssertion()` in the shared helper calls `crypto.subtle.importKey`
// with the PEM private_key, so we need a PEM that is actually importable.
// We generate a throwaway RSA-2048 keypair at test-suite start and export
// its PKCS#8 body as PEM. The signature is never verified upstream in
// tests (we mock the OAuth token endpoint to succeed regardless), so the
// key just needs to be valid enough to import + sign.
async function generateFakeServiceAccount(): Promise<ServiceAccountJson> {
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
  let bin = '';
  for (const b of pkcs8) bin += String.fromCharCode(b);
  const b64 = btoa(bin);
  const lines = b64.match(/.{1,64}/g) ?? [b64];
  const pem = `-----BEGIN PRIVATE KEY-----\n${lines.join('\n')}\n-----END PRIVATE KEY-----\n`;
  return {
    client_email: 'test@example.iam.gserviceaccount.com',
    private_key: pem,
    token_uri: 'https://oauth2.googleapis.com/token',
  };
}

// Cache a single generated service account for the whole test run —
// generating 2048-bit RSA keys is slow (~100ms) and we don't need
// per-test isolation of the key material (the OAuth endpoint is mocked).
let _cachedFakeSa: ServiceAccountJson | null = null;
async function getFakeServiceAccount(): Promise<ServiceAccountJson> {
  if (!_cachedFakeSa) _cachedFakeSa = await generateFakeServiceAccount();
  return _cachedFakeSa;
}

const FAKE_USER_ID = '11111111-1111-1111-1111-111111111111';

// --- Fetch mock ------------------------------------------------------------
//
// Drives only the Play HTTP endpoints: oauth2 token exchange, subscriptionsv2
// get, and :acknowledge. Supabase DB calls are served by the client stub
// below, never by fetch.

interface FetchMockEntry {
  url: string | RegExp;
  response: {
    status?: number;
    body: unknown;
    ok?: boolean;
  };
}

function buildFetchMock(entries: FetchMockEntry[]): typeof fetch {
  return (input, _init) => {
    const url = typeof input === 'string' ? input : (input as Request).url;
    for (const e of entries) {
      const matches = typeof e.url === 'string' ? url.includes(e.url) : e.url.test(url);
      if (matches) {
        const status = e.response.status ?? 200;
        return Promise.resolve(new Response(JSON.stringify(e.response.body), {
          status,
          headers: { 'Content-Type': 'application/json' },
        }));
      }
    }
    return Promise.reject(new Error(`fetch mock: no match for ${url}`));
  };
}

// --- Supabase client stub --------------------------------------------------
//
// handleRtdn-style: records calls, returns configured errors.
// The Edge Function calls:
//   client.from('subscriptions').upsert(row, { onConflict })
//   client.from('subscription_events').insert(row)
//   client.from('subscriptions').update(patch).eq('user_id', x)

interface DbCall {
  table: string;
  op: 'upsert' | 'insert' | 'update';
  payload?: unknown;
}

function makeClient(opts: {
  upsertError?: { code?: string; message: string };
  insertError?: { code?: string; message: string };
  updateError?: { code?: string; message: string };
} = {}): { client: unknown; calls: DbCall[] } {
  const calls: DbCall[] = [];
  const client = {
    from(table: string) {
      return {
        upsert(row: unknown, _opts?: unknown) {
          calls.push({ table, op: 'upsert', payload: row });
          return Promise.resolve(
            opts.upsertError
              ? { data: null, error: opts.upsertError }
              : { data: row, error: null },
          );
        },
        insert(row: unknown) {
          calls.push({ table, op: 'insert', payload: row });
          return Promise.resolve(
            opts.insertError
              ? { data: null, error: opts.insertError }
              : { data: row, error: null },
          );
        },
        update(patch: unknown) {
          calls.push({ table, op: 'update', payload: patch });
          return {
            eq(_k: string, _v: unknown) {
              return Promise.resolve(
                opts.updateError
                  ? { data: null, error: opts.updateError }
                  : { data: patch, error: null },
              );
            },
          };
        },
      };
    },
  };
  return { client, calls };
}

// --- Play response fixtures ------------------------------------------------

function playOk(opts: {
  ackState?: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED' | 'ACKNOWLEDGEMENT_STATE_PENDING';
  subState?: string;
  boundUserId?: string;
  expiresInMs?: number;
} = {}): Record<string, unknown> {
  return {
    kind: 'androidpublisher#subscriptionPurchaseV2',
    subscriptionState: opts.subState ?? 'SUBSCRIPTION_STATE_ACTIVE',
    startTime: new Date(Date.now() - 60_000).toISOString(),
    latestOrderId: 'GPA.1234-5678-9012-34567',
    lineItems: [{
      productId: 'gymbuddy_premium',
      expiryTime: new Date(Date.now() + (opts.expiresInMs ?? 30 * 24 * 60 * 60 * 1000)).toISOString(),
      autoRenewingPlan: { autoRenewEnabled: true },
      offerDetails: { basePlanId: 'monthly' },
    }],
    acknowledgementState: opts.ackState ?? 'ACKNOWLEDGEMENT_STATE_PENDING',
    externalAccountIdentifiers: {
      obfuscatedExternalAccountId: opts.boundUserId ?? FAKE_USER_ID,
    },
  };
}

const OAUTH_TOKEN_OK: FetchMockEntry = {
  url: 'oauth2.googleapis.com/token',
  response: { body: { access_token: 'ya29.test', expires_in: 3600 } },
};

// --- Tests -----------------------------------------------------------------

async function baseInput(
  client: unknown,
  overrides: Partial<Parameters<typeof validatePurchase>[0]> = {},
): Promise<Parameters<typeof validatePurchase>[0]> {
  return {
    userId: FAKE_USER_ID,
    productId: 'gymbuddy_premium:monthly',
    purchaseToken: 'tok_1',
    source: 'client',
    serviceAccount: await getFakeServiceAccount(),
    packageName: 'com.gymbuddy.app',
    // deno-lint-ignore no-explicit-any
    client: client as any,
    ...overrides,
  };
}

Deno.test('happy path: active sub + pending ack → acknowledges + 200', async () => {
  _resetPlayTokenCacheForTests();
  const { client, calls } = makeClient();
  const fetchFn = buildFetchMock([
    OAUTH_TOKEN_OK,
    { url: 'subscriptionsv2/tokens/tok_1', response: { body: playOk() } },
    { url: ':acknowledge', response: { body: {} } },
  ]);

  const result = await validatePurchase(await baseInput(client), { fetchFn });

  assertEquals(result.status, 200);
  assertEquals(result.body.success, true);
  assertEquals(result.body.entitlement_state, 'premium');

  // Order matters: UPSERT → event → (Play ack) → mark-acknowledged.
  // We must NOT mark acknowledged before Play confirms.
  const ops = calls.map((c) => `${c.table}.${c.op}`);
  assertEquals(ops[0], 'subscriptions.upsert');
  assertEquals(ops[1], 'subscription_events.insert');
  assertEquals(ops[2], 'subscriptions.update');
});

Deno.test('already-acknowledged sub does NOT call :acknowledge', async () => {
  _resetPlayTokenCacheForTests();
  const { client, calls } = makeClient();
  let ackCalled = false;
  const base = buildFetchMock([
    OAUTH_TOKEN_OK,
    {
      url: 'subscriptionsv2/tokens/tok_ack',
      response: { body: playOk({ ackState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED' }) },
    },
  ]);
  const fetchFn: typeof fetch = (input, init) => {
    const url = typeof input === 'string' ? input : (input as Request).url;
    if (url.includes(':acknowledge')) ackCalled = true;
    return base(input, init);
  };

  const result = await validatePurchase(
    await baseInput(client, { purchaseToken: 'tok_ack' }),
    { fetchFn },
  );

  assertEquals(result.status, 200);
  assertEquals(ackCalled, false);
  // No post-ack update — the row was already acknowledged.
  assertEquals(calls.filter((c) => c.op === 'update').length, 0);
});

Deno.test('user_id mismatch → 403, no DB writes', async () => {
  _resetPlayTokenCacheForTests();
  const { client, calls } = makeClient();
  const fetchFn = buildFetchMock([
    OAUTH_TOKEN_OK,
    {
      url: 'subscriptionsv2/tokens/tok_mismatch',
      response: { body: playOk({ boundUserId: '22222222-2222-2222-2222-222222222222' }) },
    },
  ]);

  const result = await validatePurchase(
    await baseInput(client, { purchaseToken: 'tok_mismatch' }),
    { fetchFn },
  );

  assertEquals(result.status, 403);
  assertStringIncludes(result.body.error as string, 'user mismatch');
  assertEquals(calls.length, 0);
});

Deno.test('missing obfuscatedAccountId → 400', async () => {
  _resetPlayTokenCacheForTests();
  const { client, calls } = makeClient();
  const playBody = playOk();
  delete (playBody as Record<string, unknown>).externalAccountIdentifiers;
  const fetchFn = buildFetchMock([
    OAUTH_TOKEN_OK,
    { url: 'subscriptionsv2', response: { body: playBody } },
  ]);
  const result = await validatePurchase(
    await baseInput(client, { purchaseToken: 'tok_noacct' }),
    { fetchFn },
  );
  assertEquals(result.status, 400);
  assertStringIncludes(result.body.error as string, 'obfuscatedAccountId');
  assertEquals(calls.length, 0);
});

Deno.test('Play API 410 (expired/invalid token) → 400 relay', async () => {
  _resetPlayTokenCacheForTests();
  const { client } = makeClient();
  const fetchFn = buildFetchMock([
    OAUTH_TOKEN_OK,
    {
      url: 'subscriptionsv2/tokens/tok_expired',
      response: { status: 410, body: { error: { code: 410, message: 'token expired' } } },
    },
  ]);
  const result = await validatePurchase(
    await baseInput(client, { purchaseToken: 'tok_expired' }),
    { fetchFn },
  );
  assertEquals(result.status, 400);
  assertEquals(result.body.error, 'Play API error');
});

Deno.test('Play API 500 → 502 relay', async () => {
  _resetPlayTokenCacheForTests();
  const { client } = makeClient();
  const fetchFn = buildFetchMock([
    OAUTH_TOKEN_OK,
    { url: 'subscriptionsv2', response: { status: 500, body: { error: 'boom' } } },
  ]);
  const result = await validatePurchase(
    await baseInput(client, { purchaseToken: 'tok_500' }),
    { fetchFn },
  );
  assertEquals(result.status, 502);
});

Deno.test('pending ack + no product id in Play response → 500, no :acknowledge call', async () => {
  _resetPlayTokenCacheForTests();
  const { client, calls } = makeClient();

  // Play returns a PENDING ack with zero lineItems — the function cannot
  // build the `:acknowledge` URL without a base product id, so it must
  // bail with 500 BEFORE marking the row acknowledged.
  const playBody: Record<string, unknown> = {
    kind: 'androidpublisher#subscriptionPurchaseV2',
    subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
    startTime: new Date(Date.now() - 60_000).toISOString(),
    latestOrderId: 'GPA.no-line-items',
    lineItems: [],
    acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
    externalAccountIdentifiers: { obfuscatedExternalAccountId: FAKE_USER_ID },
  };

  let ackCalled = false;
  const base = buildFetchMock([
    OAUTH_TOKEN_OK,
    { url: 'subscriptionsv2/tokens/tok_nolineitem', response: { body: playBody } },
  ]);
  const fetchFn: typeof fetch = (input, init) => {
    const url = typeof input === 'string' ? input : (input as Request).url;
    if (url.includes(':acknowledge')) ackCalled = true;
    return base(input, init);
  };

  const result = await validatePurchase(
    await baseInput(client, { purchaseToken: 'tok_nolineitem' }),
    { fetchFn },
  );

  assertEquals(result.status, 500);
  assertEquals(
    result.body.error,
    'Cannot acknowledge: no product id in Play response',
  );
  // Critical: we must NOT have issued a Play :acknowledge call, and we
  // must NOT have PATCHed the row to acknowledged.
  assertEquals(ackCalled, false, ':acknowledge must not be called');
  assertEquals(
    calls.filter((c) => c.op === 'update').length,
    0,
    'no UPDATE should run when we cannot acknowledge',
  );
  // UPSERT + audit insert still ran (state is known, audit is best-effort).
  assert(calls.some((c) => c.table === 'subscriptions' && c.op === 'upsert'));
});

Deno.test('acknowledgement failure → 500, subscriptions row NOT marked acknowledged', async () => {
  _resetPlayTokenCacheForTests();
  const { client, calls } = makeClient();
  const fetchFn = buildFetchMock([
    OAUTH_TOKEN_OK,
    { url: 'subscriptionsv2/tokens/tok_ackfail', response: { body: playOk() } },
    { url: ':acknowledge', response: { status: 500, body: { error: 'ack service down' } } },
  ]);

  const result = await validatePurchase(
    await baseInput(client, { purchaseToken: 'tok_ackfail' }),
    { fetchFn },
  );

  assertEquals(result.status, 500);
  assertStringIncludes(result.body.error as string, 'Acknowledgement failed');

  // Critical: UPSERT must have fired (state is now known), but we must
  // NOT have subsequently PATCHed to mark acknowledgement_state =
  // 'acknowledged'. Only UPSERT + audit insert, no UPDATE.
  const updateCalls = calls.filter((c) => c.op === 'update');
  assertEquals(updateCalls.length, 0, 'no UPDATE should run on ack failure');
  assert(calls.some((c) => c.op === 'upsert'));
});

Deno.test('duplicate audit insert (unique violation) is tolerated', async () => {
  _resetPlayTokenCacheForTests();
  const { client, calls } = makeClient({
    insertError: { code: '23505', message: 'duplicate key value' },
  });
  const fetchFn = buildFetchMock([
    OAUTH_TOKEN_OK,
    { url: 'subscriptionsv2/tokens/tok_dup', response: { body: playOk() } },
    { url: ':acknowledge', response: { body: {} } },
  ]);

  const result = await validatePurchase(
    await baseInput(client, { purchaseToken: 'tok_dup' }),
    { fetchFn },
  );

  assertEquals(result.status, 200);
  assert(result.body.success);
  // Despite the duplicate event, we still UPSERTed and still acknowledged.
  assert(calls.some((c) => c.table === 'subscriptions' && c.op === 'upsert'));
  assert(calls.some((c) => c.table === 'subscriptions' && c.op === 'update'));
});

Deno.test('non-dedupe audit insert failure → 500', async () => {
  _resetPlayTokenCacheForTests();
  const { client } = makeClient({
    insertError: { message: 'connection refused' },
  });
  const fetchFn = buildFetchMock([
    OAUTH_TOKEN_OK,
    { url: 'subscriptionsv2/tokens/tok_evterr', response: { body: playOk() } },
  ]);
  const result = await validatePurchase(
    await baseInput(client, { purchaseToken: 'tok_evterr' }),
    { fetchFn },
  );
  assertEquals(result.status, 500);
  assertStringIncludes(result.body.error as string, 'subscription_events');
});

Deno.test('UPSERT failure → 500, no audit insert', async () => {
  _resetPlayTokenCacheForTests();
  const { client, calls } = makeClient({
    upsertError: { message: 'constraint violation' },
  });
  const fetchFn = buildFetchMock([
    OAUTH_TOKEN_OK,
    { url: 'subscriptionsv2/tokens/tok_upfail', response: { body: playOk() } },
  ]);
  const result = await validatePurchase(
    await baseInput(client, { purchaseToken: 'tok_upfail' }),
    { fetchFn },
  );
  assertEquals(result.status, 500);
  assertStringIncludes(result.body.error as string, 'UPSERT failed');
  assertEquals(calls.filter((c) => c.op === 'insert').length, 0);
});
