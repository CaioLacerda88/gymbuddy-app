// Supabase Edge Function: delete-user
//
// Permanently deletes the calling user's auth record. All user-owned rows in
// public tables cascade via FK (ON DELETE CASCADE), so this single call
// removes the account and every piece of data tied to it.
//
// Before the delete runs, the function writes a row to
// `account_deletion_events` — an anonymous audit stream used for churn
// metrics. The row has no user_id (intentional: GDPR-clean) and carries
// only aggregate props: workout_count and days_since_signup. This happens
// inside the function because a client-side insert would be wiped by the
// CASCADE a few milliseconds later.
//
// The function is invoked from the Flutter app via
// `supabase.functions.invoke('delete-user')`. Supabase-js automatically
// attaches the caller's JWT as `Authorization: Bearer <jwt>` — we verify that
// token with a user-scoped client, then switch to a service-role client to
// perform the admin delete (auth.admin.deleteUser requires elevated perms).
//
// Optional POST body: `{ "platform": "android", "app_version": "1.2.3" }`
// Both fields are stored as-is in the deletion event; missing fields become
// NULL columns. The function tolerates an empty body.
//
// Required environment variables (set automatically by Supabase for every
// Edge Function):
//   - SUPABASE_URL
//   - SUPABASE_ANON_KEY
//   - SUPABASE_SERVICE_ROLE_KEY

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req) => {
  // Preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return json({ error: 'Missing Authorization header' }, 401);
    }
    const jwt = authHeader.replace('Bearer ', '');

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ error: 'Server misconfigured' }, 500);
    }

    // Parse optional POST body for platform / app_version. A missing or
    // malformed body is tolerated — we just write NULLs for those columns.
    let platform: string | null = null;
    let appVersion: string | null = null;
    try {
      if (req.headers.get('content-type')?.includes('application/json')) {
        const body = await req.json();
        if (typeof body?.platform === 'string') platform = body.platform;
        if (typeof body?.app_version === 'string') appVersion = body.app_version;
      }
    } catch (_) {
      // Ignore parse errors — body is optional.
    }

    // Verify the caller's JWT by reading their user record.
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });
    const {
      data: { user },
      error: getUserError,
    } = await userClient.auth.getUser(jwt);
    if (getUserError || !user) {
      return json({ error: 'Invalid or expired token' }, 401);
    }

    // Switch to service-role client for the audit insert and the delete.
    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // --- 1. Record the deletion event BEFORE deleting the user ---
    //
    // Best-effort: if anything fails here we still proceed with the delete.
    // The audit row is valuable but not worth blocking the user's explicit
    // erasure request.
    try {
      // Finished workout count for this user.
      const { count: workoutCount } = await adminClient
        .from('workouts')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .not('finished_at', 'is', null);

      // Days since signup, floored.
      const createdAtIso = user.created_at;
      let daysSinceSignup = 0;
      if (createdAtIso) {
        const createdAt = new Date(createdAtIso);
        if (!Number.isNaN(createdAt.getTime())) {
          daysSinceSignup = Math.floor(
            (Date.now() - createdAt.getTime()) / (1000 * 60 * 60 * 24),
          );
        }
      }

      await adminClient.from('account_deletion_events').insert({
        props: {
          workout_count: workoutCount ?? 0,
          days_since_signup: daysSinceSignup,
        },
        platform,
        app_version: appVersion,
      });
    } catch (_) {
      // Swallow and continue to the delete.
    }

    // --- 2. Delete the user ---
    //
    // All user data in public.* tables cascades via FK constraints.
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(
      user.id,
    );
    if (deleteError) {
      return json({ error: deleteError.message }, 500);
    }

    return json({ success: true }, 200);
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : 'Unknown error' }, 500);
  }
});

function json(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
