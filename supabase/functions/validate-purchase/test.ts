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

// A throwaway RSA-2048 PKCS#8 key used ONLY to satisfy
// `crypto.subtle.importKey` during signing. The signature is never
// verified (we mock the token endpoint to return success regardless).
const FAKE_PRIVATE_KEY = `-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7VJTUt9Us8cKj
MzEfYyjiWA4R4/M2bS1GB4t7NXp98C3SC6dVMvDuictGeurT8jNbvJZHtCSuYEvu
NMoSfm76oqFvAp8Gy0iz5sxjZmSnXyCdPEovGhLa0VzMaQ8s+CLOyS56YyCFGeJZ
qgtzJ6GR3eqoYSW9b9UMvkBpZODSctWSNGj3P7jRFDO5VoTwCQAWbFnOjDfH5Ulg
p2PKSQnSJP3AJLQNFNe7br1XbrhV//eO+t51mIpGSDCUv3E0DDFcWDTH9cXDTTlR
ZVEiR2BwpZOOkE/Z0/BVnhZYL71oZV34bKfWjQIt6V/isSMahdsAASACp4ZTGtwi
VuNd9tybAgMBAAECggEBAKTmjaS6tkK8BlPXClTQ2vpz/N6uxDeS35mXpqasqskV
laAidgg/sWqpjXDbXr93otIMLlWsM+X0CqMDgSXKejLS2jx4GDjI1ZTXg++0AMJ8
sJ74pWzVDOfmCEQ/7wXs3+cbnXhKriO8Z036q92Qc1+N87SI38nkGa0ABH9CN83H
mQqt4fB7UdHzuIRe/me2PGhIq5ZBzj6h3BpoPGzEP+x3l9YmK8t/1cN0pqI+dQwY
dgfGjackLu/2qH80MCF7IyQaseZUOJyKrCLtSD/Iixv/hzDEUPfOCjFDgTpzf3cw
ta8+oE4wHCo1iI1/4TlPkwmXx4qSXtmw4aQPz7IDQvECgYEA8KNThCO2gsC2I9PQ
DM/8Cw0O983WCDY+oi+7JPiNAJwv5DYBqEZB1QYdj06YD16XlC/HAZMsMku1na2T
N0driwenQQWzoev3g2S7gRDoS/FCJSI3jJ+kjgtaA7Qmzlgk1TxODN+G1H91HW7t
0l7VnL27IWyYo2qRRK3jzxqUiPUCgYEAx0oQs2reBQGMVZnApD1jeq7n4MvNLcPv
t8b/eU9iUv6Y4Mj0Suo/AU8lYZXm8ubbqAlwz2VSVunD2tOplHyMUrtCtObAfVDU
AhCndKaA9gApgfb3xw1IKbuQ1u4IF1FJl3VtumfQn//LiH1B3rXhcdyo3/vIttEk
48RakUKClU8CgYEAzV7W3COOlDDcQd935DdtKBFRAPRPAlspQUnzMi5eSHMD/ISL
DY5IiQHbIH83D4bvXq0X7qQoSBSNP7Dvv3HYuqMhf0DaegrlBuJllFVVq9qPVRnK
xt1Il2HgxOBvbhOT+9in1BzA+YJ99UzC85O0Qz06A+CmtHEy4aZ2kj5hHjECgYEA
mNS4+A8Fkss8Js1RieK2LniBxMgmYml3pfVLKGnzmng7H2+cwPLhPIzIuwytXywh
2bzbsYEfYx3EoEVgMEpPhoarQnYPukrJO4gwE2o5Te6T5mJSZGlQJQj9q4ZB2Dfz
et6INsK0oG8XVGXSpQvQh3RUYekCZQkBBFcpqWpbIEsCgYAnM3DQf3FJoSnXaMhr
VBIovic5l0xFkEHskAjFTevO86Fsz1C2aSeRKSqGFoOQ0tmJzBEs1R6KqnHInicD
TQrKhArgLXX4v3CddjfTRJkFWDbE/CkvKZNOrcf1nhaGCPspRJj2KUkj1Fhl9Cnc
dn/RsYEONbwQSjIfMPkvxF+8HQ==
-----END PRIVATE KEY-----
`;

const FAKE_SERVICE_ACCOUNT: ServiceAccountJson = {
  client_email: 'test@example.iam.gserviceaccount.com',
  private_key: FAKE_PRIVATE_KEY,
  token_uri: 'https://oauth2.googleapis.com/token',
};

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

function baseInput(
  client: unknown,
  overrides: Partial<Parameters<typeof validatePurchase>[0]> = {},
): Parameters<typeof validatePurchase>[0] {
  return {
    userId: FAKE_USER_ID,
    productId: 'gymbuddy_premium:monthly',
    purchaseToken: 'tok_1',
    source: 'client',
    serviceAccount: FAKE_SERVICE_ACCOUNT,
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

  const result = await validatePurchase(baseInput(client), { fetchFn });

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
    baseInput(client, { purchaseToken: 'tok_ack' }),
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
    baseInput(client, { purchaseToken: 'tok_mismatch' }),
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
    baseInput(client, { purchaseToken: 'tok_noacct' }),
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
    baseInput(client, { purchaseToken: 'tok_expired' }),
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
    baseInput(client, { purchaseToken: 'tok_500' }),
    { fetchFn },
  );
  assertEquals(result.status, 502);
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
    baseInput(client, { purchaseToken: 'tok_ackfail' }),
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
    baseInput(client, { purchaseToken: 'tok_dup' }),
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
    baseInput(client, { purchaseToken: 'tok_evterr' }),
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
    baseInput(client, { purchaseToken: 'tok_upfail' }),
    { fetchFn },
  );
  assertEquals(result.status, 500);
  assertStringIncludes(result.body.error as string, 'UPSERT failed');
  assertEquals(calls.filter((c) => c.op === 'insert').length, 0);
});
