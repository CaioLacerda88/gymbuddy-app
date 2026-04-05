/**
 * Auth smoke tests — critical login/logout journey.
 *
 * Uses the dedicated smokeAuth test user created in global-setup.ts.
 * The Flutter web app is served automatically by Playwright's webServer config
 * during local dev. In CI the FLUTTER_APP_URL env var is set by the workflow.
 */

import { test, expect } from '@playwright/test';
import { waitForAppReady } from '../helpers/app';
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

    await page.fill(AUTH.emailInput, 'test@example.com');
    await page.fill(AUTH.passwordInput, 'definitely-wrong-password');
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
