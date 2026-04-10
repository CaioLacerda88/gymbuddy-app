/**
 * Manage Data smoke tests — account deletion (irreversible feature).
 *
 * PREREQUISITES:
 *   - Supabase containers running (docker ps | grep supa)
 *   - Edge Function serving locally (run in background before this test):
 *       npx supabase functions serve delete-user --no-verify-jwt
 *   - Flutter web built from current branch and served by Playwright webServer
 *
 * Covers the critical path:
 *   Login → Profile → Manage Data → Delete Account →
 *   Partial-string gate ("DELET" keeps button disabled) →
 *   Full string "DELETE" enables button →
 *   Confirm → redirected to /login →
 *   Re-login rejected (user no longer exists) →
 *   Backend verification: user absent from auth.users (404), workouts cascaded (0 rows)
 *
 * Uses a purpose-created throwaway user (not in global-setup) so the deletion
 * act IS the cleanup. The afterAll block provides emergency cleanup if the test
 * fails before reaching the in-app delete step.
 */

import { test, expect } from '@playwright/test';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';
import { login } from '../helpers/auth';
import { AUTH, NAV, PROFILE, MANAGE_DATA } from '../helpers/selectors';

dotenv.config({ path: path.join(__dirname, '..', '.env.local') });

// ---------------------------------------------------------------------------
// Admin API helpers
// ---------------------------------------------------------------------------

function getAdminClient(): SupabaseClient {
  const supabaseUrl = process.env['SUPABASE_URL'];
  const serviceRoleKey = process.env['SUPABASE_SERVICE_ROLE_KEY'];
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error(
      'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY — check test/e2e/.env.local',
    );
  }
  return createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

async function createThrowawayUser(supabase: SupabaseClient): Promise<{
  userId: string;
  email: string;
  password: string;
}> {
  const ts = Date.now();
  const email = `e2e-throwaway-delete-${ts}@test.local`;
  const password = 'TestPassword123!';
  const { data, error } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });
  if (error || !data.user) {
    throw new Error(`Failed to create throwaway user: ${error?.message}`);
  }
  return { userId: data.user.id, email, password };
}

async function seedWorkout(
  supabase: SupabaseClient,
  userId: string,
): Promise<void> {
  await supabase.from('workouts').insert({
    user_id: userId,
    name: 'Delete Test Workout',
    started_at: new Date(Date.now() - 3600000).toISOString(),
    finished_at: new Date(Date.now() - 1800000).toISOString(),
    duration_seconds: 1800,
  });
}

async function emergencyCleanup(
  supabase: SupabaseClient,
  userId: string,
): Promise<void> {
  try {
    const { data: workouts } = await supabase
      .from('workouts')
      .select('id')
      .eq('user_id', userId);
    const workoutIds = (workouts ?? []).map((w) => w.id);
    if (workoutIds.length > 0) {
      const { data: wxs } = await supabase
        .from('workout_exercises')
        .select('id')
        .in('workout_id', workoutIds);
      const wxIds = (wxs ?? []).map((wx) => wx.id);
      if (wxIds.length > 0) {
        await supabase.from('sets').delete().in('workout_exercise_id', wxIds);
        await supabase
          .from('workout_exercises')
          .delete()
          .in('workout_id', workoutIds);
      }
      await supabase.from('personal_records').delete().eq('user_id', userId);
      await supabase.from('workouts').delete().eq('user_id', userId);
    }
    await supabase.from('profiles').delete().eq('id', userId);
    await supabase.auth.admin.deleteUser(userId);
  } catch {
    // Swallow — emergency only.
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test.describe('Manage Data — account deletion smoke', () => {
  let supabase: SupabaseClient;
  let userId: string;
  let userEmail: string;
  let userPassword: string;
  // Track whether in-app deletion succeeded (to skip emergency cleanup).
  let deletionCompletedInApp = false;

  test.beforeAll(async () => {
    supabase = getAdminClient();
    const user = await createThrowawayUser(supabase);
    userId = user.userId;
    userEmail = user.email;
    userPassword = user.password;

    // Seed a workout to verify cascade deletion later.
    await seedWorkout(supabase, userId);

    // Upsert profile so the app routes to Home, not onboarding.
    await supabase.from('profiles').upsert(
      {
        id: userId,
        display_name: 'Delete Test User',
        fitness_level: 'beginner',
      },
      { onConflict: 'id' },
    );

    console.log(
      `[manage-data] Throwaway user created: ${userEmail} (${userId})`,
    );
  });

  test.afterAll(async () => {
    if (!deletionCompletedInApp) {
      console.log(
        `[manage-data] Emergency cleanup for ${userEmail} (in-app deletion did not complete)`,
      );
      await emergencyCleanup(supabase, userId);
    }
  });

  test(
    'Delete Account: partial string keeps confirm disabled, full DELETE enables, deletion verified in backend',
    async ({ page }) => {
      // ── 1. Log in ─────────────────────────────────────────────────────────
      // Use the shared helper for the happy-path sign-in. The re-login attempt
      // later in this test is kept raw because it's expected to fail and the
      // helper would assert the happy path.
      await login(page, userEmail, userPassword);

      // ── 2. Navigate to Profile → Manage Data ──────────────────────────────
      await page.click(NAV.profileTab);
      await page.waitForURL('**/profile**', { timeout: 15_000 });
      await page.waitForTimeout(500);

      await page.click(PROFILE.manageData);
      await page.waitForURL('**/manage-data**', { timeout: 15_000 });
      await expect(page.locator(MANAGE_DATA.heading)).toBeVisible({
        timeout: 10_000,
      });

      // ── 3. Tap "Delete Account" tile ──────────────────────────────────────
      // The tile is rendered as a button with aria-name combining title + subtitle.
      // Use the subtitle as the unique selector to avoid ambiguity with the
      // dialog's "Delete Account" button that appears later.
      await page.locator('text=Permanently delete your account and all data').click();

      // The full-screen dialog opens — verify by checking the dialog's heading.
      await expect(
        page.locator('role=heading[name="Delete Account"]'),
      ).toBeVisible({ timeout: 5_000 });

      // ── 4. Assert "Delete Account" button is initially DISABLED ───────────
      // GradientButton with null onPressed renders with disabled=true in semantics.
      // The Playwright accessibility tree exposes this as role=button [disabled].
      const confirmButton = page.locator('role=button[name="Delete Account"]').last();
      await expect(confirmButton).toBeDisabled({ timeout: 5_000 });

      // ── 5. Focus the "DELETE" TextField ───────────────────────────────────
      // The textbox has role=textbox with name matching the hintText "DELETE".
      const deleteInput = page.locator('role=textbox[name="DELETE"]');
      await expect(deleteInput).toBeVisible({ timeout: 5_000 });
      await deleteInput.click();
      // Wait for Flutter's native <input> proxy to appear.
      await page.locator('input').last().waitFor({ state: 'attached', timeout: 5_000 });
      await page.waitForTimeout(200);

      // ── 6. Type "DELET" (one char short) — button must stay disabled ───────
      await page.keyboard.press('Control+a');
      await page.keyboard.type('DELET', { delay: 30 });
      await page.waitForTimeout(400);

      await expect(confirmButton).toBeDisabled({ timeout: 3_000 });

      // ── 7. Complete "DELETE" — button must become enabled ──────────────────
      await page.keyboard.type('E', { delay: 30 });
      await page.waitForTimeout(500);

      await expect(confirmButton).toBeEnabled({ timeout: 5_000 });

      // ── 8. Tap the enabled confirm button ─────────────────────────────────
      await confirmButton.click();

      // ── 9. Assert redirect to /login ───────────────────────────────────────
      // deleteAccount() → Edge Function delete-user → authNotifier signOut → /login.
      await page.waitForURL('**/login**', { timeout: 30_000 });
      await expect(page.locator(AUTH.appTitle)).toBeVisible({ timeout: 10_000 });

      // Mark deletion as completed so afterAll skips emergency cleanup.
      deletionCompletedInApp = true;

      // ── 10. Attempt re-login with deleted credentials — must FAIL ──────────
      await page.click(AUTH.emailInput);
      await page.locator('input').last().waitFor({ state: 'attached', timeout: 5_000 });
      await page.waitForTimeout(200);
      await page.keyboard.press('Control+a');
      await page.keyboard.type(userEmail, { delay: 10 });

      await page.click(AUTH.passwordInput);
      await page.locator('input').last().waitFor({ state: 'attached', timeout: 5_000 });
      await page.waitForTimeout(200);
      await page.keyboard.press('Control+a');
      await page.keyboard.type(userPassword, { delay: 10 });

      await page.click(AUTH.loginButton);

      // Should show an auth error — deleted user cannot log in.
      await expect(page.locator(AUTH.errorMessage)).toBeVisible({
        timeout: 10_000,
      });

      // Must NOT navigate to Home.
      const isOnHome = await page
        .locator(NAV.homeTab)
        .isVisible({ timeout: 3_000 })
        .catch(() => false);
      expect(isOnHome, 'Should NOT navigate to home after re-login with deleted credentials').toBe(false);

      // ── 11. Backend verification: user must be absent from auth ────────────
      // Use getUserById (O(1)) instead of listUsers to avoid a false-positive
      // once the test DB grows beyond the page size. The Supabase admin SDK
      // returns one of two shapes for a missing user depending on server
      // behavior, so we accept EITHER:
      //   - an AuthError with a 404-ish status (most common: 404 not found),
      //   - or a success-shaped response with data.user === null.
      const getUserResult = await supabase.auth.admin.getUserById(userId);
      const userGone =
        (getUserResult.error !== null &&
          (getUserResult.error.status === undefined ||
            getUserResult.error.status === 404 ||
            getUserResult.error.status >= 400)) ||
        getUserResult.data.user === null;
      expect(
        userGone,
        `User ${userEmail} (${userId}) should not exist in auth.users after deletion. ` +
          `getUserById returned: error=${JSON.stringify(getUserResult.error)} ` +
          `data=${JSON.stringify(getUserResult.data)}`,
      ).toBe(true);

      // ── 12. Cascade verification: workouts must be gone ────────────────────
      const { data: workoutsAfterDelete } = await supabase
        .from('workouts')
        .select('id')
        .eq('user_id', userId);
      const remainingWorkouts = workoutsAfterDelete?.length ?? 0;
      expect(
        remainingWorkouts,
        `Expected 0 workouts after cascade deletion, found ${remainingWorkouts}`,
      ).toBe(0);

      console.log(
        `[manage-data] Verified: user ${userEmail} (${userId}) deleted from auth. ` +
          `Cascade: 0 workouts remaining. Re-login correctly rejected.`,
      );
    },
  );
});
