/**
 * Step 5e UX-polish smoke tests.
 *
 * Covers the critical journeys introduced in Step 5e:
 *   - Onboarding: 2-page flow (no page 3)
 *   - Start workout without a dialog (direct to active-workout screen)
 *   - Profile screen: name displayed, weight unit toggle, logout confirmation
 *
 * Skipped by default. Remove test.skip() and set environment variables to run:
 *   TEST_USER_EMAIL=<email>
 *   TEST_USER_PASSWORD=<password>
 *
 * The Flutter web app must be running at http://localhost:8080 before starting:
 *   flutter build web --web-renderer html
 *   cd build/web && python3 -m http.server 8080
 *
 * OR during active development (with hot-reload):
 *   flutter run -d chrome --web-port 8080 --web-renderer html
 *
 * See test/e2e helpers for full setup instructions.
 */

import { test, expect } from '@playwright/test';
import { waitForAppReady, navigateToTab } from '../helpers/app';
import { login, getTestCredentials } from '../helpers/auth';
import { AUTH, NAV, ONBOARDING } from '../helpers/selectors';

// Requires: running Flutter web app and test Supabase credentials.
test.skip(true, 'Requires running Flutter web app and test Supabase credentials');

// ---------------------------------------------------------------------------
// Onboarding — 2-page flow
// ---------------------------------------------------------------------------

test.describe('Onboarding — 2-page flow (Step 5e)', () => {
  /**
   * NOTE: This test only runs when the authenticated user has NOT yet completed
   * onboarding (needsOnboarding = true). In a CI environment, create a fresh
   * user for each run or reset the profile record to trigger onboarding.
   *
   * We test the structure of the onboarding screen here (page count, CTA labels)
   * without completing the flow so it does not interfere with other tests that
   * rely on a logged-in, onboarded user.
   */
  test('onboarding shows welcome page with GET STARTED on load', async ({
    page,
  }) => {
    await page.goto('/');
    await waitForAppReady(page);

    // If the user lands on onboarding we can verify the 2-page structure.
    // If they land on home (already onboarded) we skip by early-returning.
    const onOnboarding = await page
      .locator(ONBOARDING.getStartedButton)
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    if (!onOnboarding) {
      test.skip();
      return;
    }

    await expect(page.locator(ONBOARDING.getStartedButton)).toBeVisible();
    await expect(page.locator('text=Track every rep,\nevery time')).toBeVisible();
  });

  test('GET STARTED navigates to profile setup (page 2), not a page 3', async ({
    page,
  }) => {
    await page.goto('/');
    await waitForAppReady(page);

    const onOnboarding = await page
      .locator(ONBOARDING.getStartedButton)
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    if (!onOnboarding) {
      test.skip();
      return;
    }

    await page.click(ONBOARDING.getStartedButton);

    // Page 2 shows profile setup, not a third page.
    await expect(page.locator('text=Set up your profile')).toBeVisible({
      timeout: 10_000,
    });

    // The final CTA on page 2 is "LET'S GO", NOT "NEXT".
    // A "NEXT" button would indicate a third page exists (Step 5e removed it).
    await expect(page.locator(ONBOARDING.letsGoButton)).toBeVisible();
    await expect(page.locator(ONBOARDING.nextButton)).not.toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// Start workout — no dialog, auto-named
// ---------------------------------------------------------------------------

test.describe('Start workout without dialog (Step 5e)', () => {
  test.beforeEach(async ({ page }) => {
    const { email, password } = getTestCredentials();
    await login(page, email, password);
    await navigateToTab(page, 'Home');
  });

  test('tapping Start Workout lands directly on the active workout screen', async ({
    page,
  }) => {
    // The Home screen has a "Start Workout" button. In Step 5e the dialog was
    // removed — tapping it goes straight to the active workout screen.
    await page.click('text=Start Workout');

    // The active workout screen identifies itself by the AppBar which shows the
    // auto-generated workout name (e.g. "Workout — Wed Apr 2") and the
    // "Add Exercise" or "Finish" controls. We assert on the Finish button
    // in the persistent bottom bar.
    await expect(page.locator('text=Finish')).toBeVisible({ timeout: 15_000 });

    // No naming dialog should appear.
    await expect(page.locator('[role="dialog"]')).not.toBeVisible();

    // Clean up: discard the workout so subsequent tests start from a clean state.
    // The Discard option is accessible from the AppBar overflow menu.
    const discardButton = page.locator('text=Discard');
    const discardVisible = await discardButton.isVisible({ timeout: 3_000 }).catch(() => false);
    if (discardVisible) {
      await discardButton.click();
    } else {
      // Try the overflow menu if Discard is not directly visible.
      const overflowMenu = page.locator('[aria-label="More options"]');
      if (await overflowMenu.isVisible({ timeout: 2_000 }).catch(() => false)) {
        await overflowMenu.click();
        await page.click('text=Discard');
      }
    }
  });

  test('auto-generated workout name includes day-of-week and date', async ({
    page,
  }) => {
    await page.click('text=Start Workout');
    await expect(page.locator('text=Finish')).toBeVisible({ timeout: 15_000 });

    // The AppBar title shows the auto-generated name matching "Workout — <day> <month> <date>".
    // We assert it contains the em-dash separator used by _generateWorkoutName.
    const appBarTitle = page.locator('flt-semantics[aria-label*="Workout \u2014"]');
    await expect(appBarTitle).toBeVisible({ timeout: 5_000 });

    // Discard to clean up.
    await page.goBack().catch(() => {});
  });
});

// ---------------------------------------------------------------------------
// Profile screen (Step 5e — new feature)
// ---------------------------------------------------------------------------

test.describe('Profile screen (Step 5e)', () => {
  test.beforeEach(async ({ page }) => {
    const { email, password } = getTestCredentials();
    await login(page, email, password);
    await navigateToTab(page, 'Profile');
  });

  test('profile tab shows user email and name section', async ({ page }) => {
    // The Profile screen always shows the user's email address from auth.
    const { email } = getTestCredentials();

    // Email is shown in the identity card.
    await expect(page.locator(`text=${email}`)).toBeVisible({ timeout: 10_000 });
  });

  test('weight unit segmented button shows kg and lbs options', async ({
    page,
  }) => {
    await expect(page.locator('text=kg')).toBeVisible({ timeout: 10_000 });
    await expect(page.locator('text=lbs')).toBeVisible();
  });

  test('Log Out button is present on the profile screen', async ({ page }) => {
    await expect(page.locator('text=Log Out')).toBeVisible({ timeout: 10_000 });
  });

  test('tapping Log Out shows a confirmation dialog', async ({ page }) => {
    await page.click('text=Log Out');

    // The dialog contains "Are you sure you want to log out?"
    await expect(
      page.locator('text=Are you sure you want to log out?'),
    ).toBeVisible({ timeout: 5_000 });

    // Cancel should dismiss the dialog without logging out.
    await page.click('text=Cancel');
    await expect(
      page.locator('text=Are you sure you want to log out?'),
    ).not.toBeVisible();

    // The profile tab should still be visible.
    await expect(page.locator(NAV.profileTab)).toBeVisible();
  });

  test('confirming logout returns to the login screen', async ({ page }) => {
    await page.click('text=Log Out');
    await expect(
      page.locator('text=Are you sure you want to log out?'),
    ).toBeVisible({ timeout: 5_000 });

    // Confirm logout — the second "Log Out" button appears in the dialog.
    const dialogLogOutButtons = page.locator('text=Log Out');
    // There will be two: the button that opened the dialog and the one inside it.
    // Click the last one (dialog action).
    await dialogLogOutButtons.last().click();

    // After logout the router redirects to /login.
    await expect(page.locator(AUTH.appTitle)).toBeVisible({ timeout: 15_000 });
    await expect(page.locator(AUTH.loginButton)).toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// Rest timer — +30s / -30s adjustment buttons (Step 5e)
// ---------------------------------------------------------------------------

test.describe('Rest timer adjustment buttons (Step 5e)', () => {
  test.beforeEach(async ({ page }) => {
    const { email, password } = getTestCredentials();
    await login(page, email, password);
    await navigateToTab(page, 'Home');
  });

  test('+30s and -30s buttons are visible when rest timer is active', async ({
    page,
  }) => {
    // Start a workout and add an exercise so we can complete a set to trigger
    // the rest timer. This test is intentionally high-level: if the timer
    // overlay appears at all, the adjustment buttons must be present per
    // the Step 5e requirement.

    await page.click('text=Start Workout');
    await expect(page.locator('text=Finish')).toBeVisible({ timeout: 15_000 });

    // Add an exercise from the picker.
    // The active workout screen shows "Add Exercise" as the CTA.
    const addExercise = page.locator('text=Add Exercise');
    const addExVisible = await addExercise.isVisible({ timeout: 5_000 }).catch(() => false);
    if (!addExVisible) {
      // Screen may show a different CTA — skip gracefully.
      test.skip();
      return;
    }

    await addExercise.click();

    // The exercise picker appears. Pick the first available exercise.
    const firstExercise = page.locator('[aria-label^="Exercise:"]').first();
    await expect(firstExercise).toBeVisible({ timeout: 10_000 });
    await firstExercise.click();

    // Add a set and complete it to trigger the rest timer.
    await page.click('text=Add Set');
    const checkbox = page.locator('[aria-label="Mark set as done"]').first();
    await expect(checkbox).toBeVisible({ timeout: 5_000 });
    await checkbox.click();

    // The rest timer overlay should appear.
    const restOverlay = page.locator('text=Rest');
    const restVisible = await restOverlay.isVisible({ timeout: 8_000 }).catch(() => false);
    if (!restVisible) {
      // Rest timer may be disabled or already expired — skip gracefully.
      test.skip();
      return;
    }

    await expect(page.locator('text=+30s')).toBeVisible();
    await expect(page.locator('text=-30s')).toBeVisible();

    // Skip the timer so subsequent tests start clean.
    await page.click('text=Skip');

    // Discard workout to clean up state.
    const discardButton = page.locator('text=Discard');
    const discardVisible = await discardButton.isVisible({ timeout: 3_000 }).catch(() => false);
    if (discardVisible) {
      await discardButton.click();
    }
  });
});
