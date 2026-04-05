/**
 * Playwright global setup — creates E2E test users via Supabase Admin Auth API.
 *
 * Runs once before all tests. Creates each test user with email_confirm: true
 * so they can log in immediately without email verification.
 *
 * Uses the Service Role key (admin privileges) — never expose this key to the
 * client-side app. It is only used here in the test setup process.
 *
 * If a user already exists (e.g., from a previous interrupted run), the error
 * is swallowed and setup continues so reruns are idempotent.
 */

import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.join(__dirname, '.env.local') });

const TEST_USERS = [
  // Smoke suite users
  'e2e-smoke-auth@test.local',
  'e2e-smoke-workout@test.local',
  'e2e-smoke-pr@test.local',
  // Full suite users (one per spec file)
  'e2e-full-auth@test.local',
  'e2e-full-exercises@test.local',
  'e2e-full-workout@test.local',
  'e2e-full-routines@test.local',
  'e2e-full-pr@test.local',
  'e2e-full-home@test.local',
  'e2e-full-crash@test.local',
];

async function globalSetup(): Promise<void> {
  const supabaseUrl = process.env['SUPABASE_URL'];
  const serviceRoleKey = process.env['SUPABASE_SERVICE_ROLE_KEY'];
  const password = process.env['TEST_USER_PASSWORD'];

  if (!supabaseUrl || !serviceRoleKey || !password) {
    throw new Error(
      'Missing required environment variables: SUPABASE_URL, ' +
        'SUPABASE_SERVICE_ROLE_KEY, TEST_USER_PASSWORD. ' +
        'Ensure test/e2e/.env.local is present.',
    );
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  console.log('[global-setup] Creating E2E test users...');

  for (const email of TEST_USERS) {
    const { data, error } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (error) {
      // 422 "User already registered" — idempotent, skip.
      // Different Supabase versions return slightly different status codes and
      // messages for duplicate users, so we match on message content.
      if (
        error.message.toLowerCase().includes('already') ||
        error.message.toLowerCase().includes('registered') ||
        error.message.toLowerCase().includes('exists')
      ) {
        console.log(`[global-setup] User already exists, skipping: ${email}`);
        continue;
      }

      // Any other error is unexpected — fail setup.
      throw new Error(
        `[global-setup] Failed to create user ${email}: ${error.message}`,
      );
    }

    console.log(
      `[global-setup] Created user: ${email} (id: ${data.user?.id})`,
    );
  }

  console.log('[global-setup] Done.');
}

export default globalSetup;
