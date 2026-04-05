/**
 * Auth helpers: login and logout flows.
 *
 * Test users are created by global-setup.ts using the Supabase Admin Auth API
 * and credentials in test/e2e/.env.local. No manual setup is required.
 *
 * Import specific user credentials from fixtures/test-users.ts rather than
 * using getTestCredentials() for new tests.
 */

import { Page, expect } from '@playwright/test';
import { AUTH, NAV } from './selectors';
import { waitForAppReady } from './app';

/**
 * Log in with email and password.
 *
 * Navigates to the base URL, waits for the login screen, fills credentials,
 * submits, then waits until the home shell (bottom nav) is visible.
 */
export async function login(
  page: Page,
  email: string,
  password: string,
): Promise<void> {
  await page.goto('/');
  await waitForAppReady(page);

  // Confirm we are on the login screen.
  await expect(page.locator(AUTH.appTitle)).toBeVisible({ timeout: 10_000 });

  await page.fill(AUTH.emailInput, email);
  await page.fill(AUTH.passwordInput, password);
  await page.click(AUTH.loginButton);

  // After successful login, the router redirects to /home and the shell nav
  // becomes visible. We wait for any bottom nav tab as confirmation.
  await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 20_000 });
}

/**
 * Log out by navigating to the Profile tab and confirming in the dialog.
 *
 * Flow: Profile tab → "Log Out" button → confirmation dialog → "Log Out" (last).
 * After logout the router redirects to /login.
 */
export async function logout(page: Page): Promise<void> {
  await page.click(NAV.profileTab);

  // Click the "Log Out" button on the profile screen.
  await page.click('text=Log Out');

  // A confirmation dialog appears. Click the "Log Out" button inside the dialog
  // (the last occurrence — the first is the button that opened the dialog).
  const logOutButtons = page.locator('text=Log Out');
  await expect(logOutButtons.last()).toBeVisible({ timeout: 5_000 });
  await logOutButtons.last().click();

  // After logout, the router redirects to /login.
  await expect(page.locator(AUTH.appTitle)).toBeVisible({ timeout: 15_000 });
}

/**
 * Read test credentials from environment variables.
 *
 * Prefers TEST_USER_EMAIL / TEST_USER_PASSWORD environment variables for
 * backward compatibility. Falls back to the smokeAuth user from fixtures if
 * the env vars are not set.
 *
 * For new tests, import TEST_USERS from fixtures/test-users.ts directly
 * instead of calling this function.
 */
export function getTestCredentials(): { email: string; password: string } {
  const email = process.env['TEST_USER_EMAIL'];
  const password =
    process.env['TEST_USER_PASSWORD'] ?? 'TestPassword123!';

  if (email) {
    return { email, password };
  }

  // Fall back to the smoke auth test user so older tests remain runnable
  // after the fixture-based setup is in place.
  return {
    email: 'e2e-smoke-auth@test.local',
    password,
  };
}
