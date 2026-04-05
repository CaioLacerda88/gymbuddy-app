/**
 * Playwright global teardown — deletes E2E test users via Supabase Admin Auth API.
 *
 * Runs once after all tests complete. Identifies test users by the "e2e-"
 * prefix in their email addresses and deletes them.
 *
 * Errors during individual user deletion are logged but do not fail teardown
 * so that all users are attempted even if one fails.
 */

import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.join(__dirname, '.env.local') });

async function globalTeardown(): Promise<void> {
  const supabaseUrl = process.env['SUPABASE_URL'];
  const serviceRoleKey = process.env['SUPABASE_SERVICE_ROLE_KEY'];

  if (!supabaseUrl || !serviceRoleKey) {
    console.warn(
      '[global-teardown] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY — ' +
        'skipping test user cleanup.',
    );
    return;
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  console.log('[global-teardown] Listing users to find E2E test accounts...');

  // List all users — local Supabase typically has few users so one page is enough.
  const { data: listData, error: listError } =
    await supabase.auth.admin.listUsers({ perPage: 1000 });

  if (listError) {
    console.error(
      `[global-teardown] Failed to list users: ${listError.message}`,
    );
    return;
  }

  const testUsers = listData.users.filter((u) =>
    u.email?.startsWith('e2e-'),
  );

  if (testUsers.length === 0) {
    console.log('[global-teardown] No E2E test users found — nothing to clean up.');
    return;
  }

  console.log(
    `[global-teardown] Deleting ${testUsers.length} E2E test user(s)...`,
  );

  for (const user of testUsers) {
    const { error } = await supabase.auth.admin.deleteUser(user.id);

    if (error) {
      // Log but do not throw — attempt to clean up remaining users.
      console.error(
        `[global-teardown] Failed to delete user ${user.email} (${user.id}): ${error.message}`,
      );
    } else {
      console.log(`[global-teardown] Deleted user: ${user.email}`);
    }
  }

  console.log('[global-teardown] Done.');
}

export default globalTeardown;
