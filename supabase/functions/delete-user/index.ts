// Supabase Edge Function: delete-user
//
// Permanently deletes the calling user's auth record. All user-owned rows in
// public tables cascade via FK (ON DELETE CASCADE), so this single call
// removes the account and every piece of data tied to it.
//
// The function is invoked from the Flutter app via
// `supabase.functions.invoke('delete-user')`. Supabase-js automatically
// attaches the caller's JWT as `Authorization: Bearer <jwt>` — we verify that
// token with a user-scoped client, then switch to a service-role client to
// perform the admin delete (auth.admin.deleteUser requires elevated perms).
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

    // Switch to service-role client and delete the user. All user data
    // cascades via FK constraints on public.* tables.
    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
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
