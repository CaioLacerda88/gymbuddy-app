/**
 * Auth full spec — edge cases beyond the happy-path smoke tests.
 *
 * Tests: wrong password, non-existent email, empty field validation,
 * mode toggle, duplicate signup, and full login → all tabs → logout journey.
 *
 * Uses the dedicated `fullAuth` test user (created in global-setup.ts).
 * The Flutter web app must be served at localhost:8080 before running.
 */

import { test, expect } from '@playwright/test';
import { waitForAppReady } from '../helpers/app';
import { login, logout } from '../helpers/auth';
import { AUTH, NAV } from '../helpers/selectors';
import { TEST_USERS } from '../fixtures/test-users';

const USER = TEST_USERS.fullAuth;

test.describe('Auth — edge cases', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
  });

  test('wrong password shows an error message', async ({ page }) => {
    await page.fill(AUTH.emailInput, USER.email);
    await page.fill(AUTH.passwordInput, 'definitely-wrong-password');
    await page.click(AUTH.loginButton);

    // The LoginScreen renders an inline error container on auth failure.
    await expect(page.locator(AUTH.errorMessage)).toBeVisible({
      timeout: 15_000,
    });

    // The error must not navigate away from the login screen.
    await expect(page.locator(AUTH.appTitle)).toBeVisible();
  });

  test('login with non-existent email shows an error message', async ({
    page,
  }) => {
    await page.fill(AUTH.emailInput, 'no-such-user-xyz@test.local');
    await page.fill(AUTH.passwordInput, 'AnyPassword123!');
    await page.click(AUTH.loginButton);

    await expect(page.locator(AUTH.errorMessage)).toBeVisible({
      timeout: 15_000,
    });

    // Still on the login screen.
    await expect(page.locator(AUTH.loginButton)).toBeVisible();
  });

  test('submitting with empty email and password shows an error', async ({
    page,
  }) => {
    // Leave both fields blank and submit.
    await page.click(AUTH.loginButton);

    // Either inline validation text or the error alert must appear.
    const hasError =
      (await page
        .locator(AUTH.errorMessage)
        .isVisible({ timeout: 8_000 })
        .catch(() => false)) ||
      (await page
        .locator('text=Email is required')
        .isVisible({ timeout: 2_000 })
        .catch(() => false)) ||
      (await page
        .locator('text=required')
        .isVisible({ timeout: 2_000 })
        .catch(() => false));

    expect(hasError).toBe(true);
    // Must remain on the login screen.
    await expect(page.locator(AUTH.appTitle)).toBeVisible();
  });

  test('toggle to sign-up mode and back to login mode', async ({ page }) => {
    // Initially in login mode.
    await expect(page.locator(AUTH.loginButton)).toBeVisible();
    await expect(page.locator(AUTH.welcomeBack)).toBeVisible();

    // Toggle to sign-up mode.
    await page.click(AUTH.toggleToSignUp);

    // Sign-up mode: SIGN UP button visible, "Create your account" subtitle.
    await expect(page.locator(AUTH.signUpButton)).toBeVisible({
      timeout: 5_000,
    });
    await expect(page.locator('text=Create your account')).toBeVisible();

    // Toggle back to login mode.
    await page.click(AUTH.toggleToLogIn);

    await expect(page.locator(AUTH.loginButton)).toBeVisible({ timeout: 5_000 });
    await expect(page.locator(AUTH.welcomeBack)).toBeVisible();
  });

  test('signing up with an already-registered email shows an error', async ({
    page,
  }) => {
    // Switch to sign-up mode.
    await page.click(AUTH.toggleToSignUp);
    await expect(page.locator(AUTH.signUpButton)).toBeVisible({ timeout: 5_000 });

    // Attempt to create an account with an email that already exists.
    await page.fill(AUTH.emailInput, USER.email);
    await page.fill(AUTH.passwordInput, USER.password);
    await page.click(AUTH.signUpButton);

    // Supabase returns a "User already registered" error that surfaces as an
    // inline error message in LoginScreen.
    await expect(page.locator(AUTH.errorMessage)).toBeVisible({
      timeout: 15_000,
    });
  });

  test('full journey: login → navigate all tabs → logout → back on login', async ({
    page,
  }) => {
    await login(page, USER.email, USER.password);

    // All four bottom nav tabs must be visible after login.
    await expect(page.locator(NAV.homeTab)).toBeVisible();
    await expect(page.locator(NAV.exercisesTab)).toBeVisible();
    await expect(page.locator(NAV.routinesTab)).toBeVisible();
    await expect(page.locator(NAV.profileTab)).toBeVisible();

    // Navigate through each tab and verify the heading/content loads.
    await page.click(NAV.exercisesTab);
    await expect(page.locator('text=Exercises')).toBeVisible({ timeout: 15_000 });

    await page.click(NAV.routinesTab);
    await expect(page.locator('text=Routines')).toBeVisible({ timeout: 15_000 });

    await page.click(NAV.profileTab);
    await expect(page.locator('text=Log Out')).toBeVisible({ timeout: 15_000 });

    await page.click(NAV.homeTab);
    await expect(page.locator('text=GymBuddy')).toBeVisible({ timeout: 15_000 });

    // Logout returns to the login screen.
    await logout(page);

    await expect(page.locator(AUTH.appTitle)).toBeVisible({ timeout: 15_000 });
    await expect(page.locator(AUTH.loginButton)).toBeVisible();

    // Bottom nav must not be visible after logout.
    await expect(page.locator(NAV.homeTab)).not.toBeVisible();
  });
});
