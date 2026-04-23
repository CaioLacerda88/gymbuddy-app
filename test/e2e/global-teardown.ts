/**
 * Playwright global teardown — deletes E2E test users via Supabase Admin Auth API.
 *
 * Runs once after all tests complete. Identifies test users by the "e2e-"
 * prefix in their email addresses and deletes them.
 *
 * Before deleting each user from auth, all user-owned data is deleted from
 * dependent tables in the correct FK order to avoid constraint violations.
 *
 * Errors during individual user deletion are logged but do not fail teardown
 * so that all users are attempted even if one fails.
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.join(__dirname, '.env.local') });

/**
 * Delete all user-owned data from dependent tables before deleting the auth user.
 *
 * The deletion order respects FK constraints:
 *   1. sets (via workout_exercises -> workouts)
 *   2. workout_exercises (via workouts)
 *   3. personal_records
 *   4. workouts
 *   5. weekly_plans
 *   6. workout_templates (user-created only)
 *   7. exercises (user-created only, is_default = false)
 *   8. profiles
 *
 * Uses the service-role key which bypasses RLS.
 */
async function deleteUserData(
  supabase: SupabaseClient,
  userId: string,
): Promise<void> {
  try {
    // 1. Get user's workout IDs
    const { data: workouts } = await supabase
      .from('workouts')
      .select('id')
      .eq('user_id', userId);
    const workoutIds = workouts?.map((w) => w.id) ?? [];

    if (workoutIds.length > 0) {
      // 2. Get workout_exercise IDs for this user's workouts
      const { data: wxs } = await supabase
        .from('workout_exercises')
        .select('id')
        .in('workout_id', workoutIds);
      const wxIds = wxs?.map((wx) => wx.id) ?? [];

      // 3. Delete sets belonging to those workout_exercises
      if (wxIds.length > 0) {
        await supabase.from('sets').delete().in('workout_exercise_id', wxIds);
      }

      // 4. Delete workout_exercises
      await supabase
        .from('workout_exercises')
        .delete()
        .in('workout_id', workoutIds);
    }

    // 5. Delete personal_records
    await supabase.from('personal_records').delete().eq('user_id', userId);

    // 6. Delete workouts
    await supabase.from('workouts').delete().eq('user_id', userId);

    // 7. Delete weekly_plans
    await supabase.from('weekly_plans').delete().eq('user_id', userId);

    // 8. Delete workout_templates (user-created only)
    await supabase.from('workout_templates').delete().eq('user_id', userId);

    // 9. Delete user-created exercises (is_default = false)
    await supabase
      .from('exercises')
      .delete()
      .eq('user_id', userId)
      .eq('is_default', false);

    // 10. Delete XP ledger (Phase 17b)
    await supabase.from('xp_events').delete().eq('user_id', userId);
    await supabase.from('user_xp').delete().eq('user_id', userId);

    // 11. Delete profile
    await supabase.from('profiles').delete().eq('id', userId);
  } catch (err) {
    console.error(
      `[global-teardown] Error deleting data for user ${userId}: ${err}`,
    );
  }
}

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
    // Delete all user-owned data first to avoid FK constraint violations.
    await deleteUserData(supabase, user.id);

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
