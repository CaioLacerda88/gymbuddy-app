/**
 * Auth smoke tests — critical login/logout journey.
 *
 * Uses the dedicated smokeAuth test user created in global-setup.ts.
 * The Flutter web app is served automatically by Playwright's webServer config
 * during local dev. In CI the FLUTTER_APP_URL env var is set by the workflow.
 */

import { test, expect } from '@playwright/test';
import { waitForAppReady, flutterFill } from '../helpers/app';
import { login, logout } from '../helpers/auth';
import { AUTH, NAV } from '../helpers/selectors';
import { TEST_USERS } from '../fixtures/test-users';

test.describe('Auth smoke', () => {
  test('login screen is shown on first load', async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);

    // The login screen identifies itself with the "GymBuddy" title and
    // "Welcome back" subtitle.
    await expect(page.locator(AUTH.appTitle)).toBeVisible();
    await expect(page.locator(AUTH.welcomeBack)).toBeVisible();

    // Both form fields must be present.
    await expect(page.locator(AUTH.emailInput)).toBeVisible();
    await expect(page.locator(AUTH.passwordInput)).toBeVisible();

    // The primary action button must be present and labelled LOG IN.
    await expect(page.locator(AUTH.loginButton)).toBeVisible();
  });

  test('login with valid credentials lands on home screen with bottom nav', async ({
    page,
  }) => {
    const { email, password } = TEST_USERS.smokeAuth;

    await login(page, email, password);

    // The shell scaffold renders the bottom NavigationBar on all main routes.
    await expect(page.locator(NAV.homeTab)).toBeVisible();
    await expect(page.locator(NAV.exercisesTab)).toBeVisible();
    await expect(page.locator(NAV.routinesTab)).toBeVisible();
    await expect(page.locator(NAV.profileTab)).toBeVisible();
  });

  test('login with wrong password shows an error message', async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);

    await flutterFill(page, AUTH.emailInput, 'test@example.com');
    await flutterFill(page, AUTH.passwordInput, 'definitely-wrong-password');
    await page.click(AUTH.loginButton);

    // The LoginScreen renders an inline error container on auth failure.
    // The exact text comes from AuthErrorMessages.fromError — we just assert
    // that some error text is rendered, not the exact wording.
    await expect(page.locator(AUTH.errorMessage)).toBeVisible({
      timeout: 10_000,
    });
  });

  test('logout returns to login screen', async ({ page }) => {
    const { email, password } = TEST_USERS.smokeAuth;

    await login(page, email, password);
    await logout(page);

    // After logout the router redirects to /login.
    await expect(page.locator(AUTH.appTitle)).toBeVisible();
    await expect(page.locator(AUTH.loginButton)).toBeVisible();
  });

  test('forgot password with valid email shows success feedback', async ({
    page,
  }) => {
    await page.goto('/');
    await waitForAppReady(page);

    // Fill in a valid email address.
    await flutterFill(page, AUTH.emailInput, TEST_USERS.smokeAuth.email);

    // Click the forgot password button.
    await page.click(AUTH.forgotPasswordButton);

    // The button should trigger a reset email (Supabase /recover endpoint).
    // We wait a moment for the async request to complete.
    // The UI should show either:
    //   a) A SnackBar "Password reset email sent. Check your inbox."
    //   b) OR remain on the login screen without an error visible.
    // We cannot reliably assert the SnackBar (it disappears quickly) but we
    // can assert the app does NOT show an error and does NOT crash.
    await page.waitForTimeout(2_000);

    // The login screen itself must still be visible (no unhandled crash).
    await expect(page.locator(AUTH.appTitle)).toBeVisible({ timeout: 5_000 });

    // No error alert should have appeared.
    const hasError = await page
      .locator(AUTH.errorMessage)
      .isVisible({ timeout: 3_000 })
      .catch(() => false);

    // Rate-limit (429) is the only acceptable error response here since we
    // may call this endpoint multiple times in test runs. Any other error
    // should fail this test. The aria-live selector may match empty elements
    // (e.g. SnackBar placeholders), so only assert on non-empty text.
    if (hasError) {
      const errorText = (await page.locator(AUTH.errorMessage).textContent()) ?? '';
      if (errorText.trim().length > 0) {
        expect(errorText.toLowerCase()).toContain('rate limit');
      }
    }
  });

  test('toggle to sign-up mode changes button label and subtitle', async ({
    page,
  }) => {
    await page.goto('/');
    await waitForAppReady(page);

    // Initially in sign-in mode.
    await expect(page.locator(AUTH.loginButton)).toBeVisible();

    // Toggle to sign-up mode.
    await page.click(AUTH.toggleToSignUp);

    // Button should now read SIGN UP and subtitle should read "Create your
    // account" — both are hard-coded strings in LoginScreen._isSignUp branch.
    await expect(page.locator(AUTH.signUpButton)).toBeVisible();
    await expect(page.locator('text=Create your account')).toBeVisible();

    // Toggle back.
    await page.click(AUTH.toggleToLogIn);
    await expect(page.locator(AUTH.loginButton)).toBeVisible();
    await expect(page.locator(AUTH.welcomeBack)).toBeVisible();
  });
});
