/**
 * Auth helpers: login and logout flows.
 *
 * These helpers interact with the real Supabase backend. Test users must exist
 * before running tests. Create them once in the Supabase dashboard or via the
 * signup flow, then store their credentials in environment variables:
 *
 *   TEST_USER_EMAIL=e2e-test@example.com
 *   TEST_USER_PASSWORD=TestPassword123!
 *
 * Set these in a .env file at test/e2e/.env (never commit this file) or
 * export them in the shell before running tests.
 *
 * The test/e2e/.env file should be listed in .gitignore — verify before
 * committing.
 *
 * Recommended test user setup:
 *   1. Sign up through the app's own flow so the user record exists in both
 *      Supabase Auth and the profiles table.
 *   2. Confirm the email address (or disable email confirmation in Supabase
 *      Auth settings for the test project).
 *   3. Export TEST_USER_EMAIL and TEST_USER_PASSWORD.
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
 * Log out by navigating to the Profile tab and tapping the logout option.
 *
 * Note: The Profile tab is currently a placeholder screen (no logout button
 * implemented in Steps 1-4). This helper is a stub — update it once the
 * profile feature (Step 6) adds a real logout action.
 *
 * When profile is implemented, the expected selector for logout will be
 * something like: '[aria-label="Log out"]' or 'text=Log out'
 */
export async function logout(page: Page): Promise<void> {
  await page.click(NAV.profileTab);

  // TODO: update selector when profile screen implements logout (Step 6).
  // For now we click a "Log out" text button as a placeholder expectation.
  await page.click('text=Log out');

  // After logout, the router redirects to /login.
  await expect(page.locator(AUTH.appTitle)).toBeVisible({ timeout: 15_000 });
}

/**
 * Read test credentials from environment variables.
 *
 * Throws a descriptive error if the variables are not set, so tests fail
 * clearly rather than attempting to log in with empty strings.
 */
export function getTestCredentials(): { email: string; password: string } {
  const email = process.env['TEST_USER_EMAIL'];
  const password = process.env['TEST_USER_PASSWORD'];

  if (!email || !password) {
    throw new Error(
      'Missing test credentials. Set TEST_USER_EMAIL and TEST_USER_PASSWORD ' +
        'environment variables before running e2e tests. ' +
        'See test/e2e/README.md for setup instructions.',
    );
  }

  return { email, password };
}
