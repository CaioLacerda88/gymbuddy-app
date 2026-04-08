/**
 * Routines full spec — starter routines and quick-start workflow.
 *
 * Tests:
 *  1. Routines tab shows the STARTER ROUTINES section
 *  2. Starter routines are present in the list (seed data: Push Day, Pull Day, Leg Day, Full Body)
 *  3. Start a workout from a starter routine — navigates to active workout with pre-filled exercises
 *  4. Discard the routine-started workout returns to home
 *  5. Routines tab loads without crashing (navigation smoke)
 *
 * Uses the dedicated `fullRoutines` test user.
 * The Flutter web app is served automatically by Playwright's webServer config
 * during local dev. In CI the FLUTTER_APP_URL env var is set by the workflow.
 */

import { test, expect } from '@playwright/test';
import { navigateToTab } from '../helpers/app';
import { login } from '../helpers/auth';
import { NAV, ROUTINE, WORKOUT } from '../helpers/selectors';
import { TEST_USERS } from '../fixtures/test-users';

const USER = TEST_USERS.fullRoutines;

// Starter routine names as inserted by supabase/seed.sql.
const STARTER_ROUTINES = ['Push Day', 'Pull Day', 'Leg Day', 'Full Body'];

test.describe('Routines — full suite', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, USER.email, USER.password);
    await navigateToTab(page, 'Routines');
  });

  test('routines tab shows the STARTER ROUTINES section heading', async ({
    page,
  }) => {
    await expect(page.locator(ROUTINE.heading)).toBeVisible({ timeout: 15_000 });
    await expect(page.locator(ROUTINE.starterRoutinesSection)).toBeVisible({
      timeout: 10_000,
    });
  });

  test('all four starter routines from seed data are visible', async ({
    page,
  }) => {
    await expect(page.locator(ROUTINE.starterRoutinesSection)).toBeVisible({
      timeout: 10_000,
    });

    for (const name of STARTER_ROUTINES) {
      await expect(page.locator(ROUTINE.routineName(name))).toBeVisible({
        timeout: 10_000,
      });
    }
  });

  test('tapping a starter routine card navigates to the active workout screen', async ({
    page,
  }) => {
    await expect(page.locator(ROUTINE.starterRoutinesSection)).toBeVisible({
      timeout: 10_000,
    });

    // Tap "Push Day" — the first starter routine in seed order.
    await page.click(ROUTINE.routineName('Push Day'));

    // The active workout screen identifies itself by the Finish Workout button.
    await expect(page.locator(WORKOUT.finishButton)).toBeVisible({
      timeout: 20_000,
    });

    // The routine pre-fills exercises. At least one Add Set button must appear,
    // confirming exercise cards were rendered.
    await expect(page.locator(WORKOUT.addSetButton)).toBeVisible({
      timeout: 10_000,
    });

    // Push Day contains "Barbell Bench Press" per seed.sql.
    await expect(page.locator('text=Barbell Bench Press')).toBeVisible({
      timeout: 10_000,
    });
  });

  test('discard a routine-started workout returns to home', async ({ page }) => {
    await expect(page.locator(ROUTINE.starterRoutinesSection)).toBeVisible({
      timeout: 10_000,
    });

    await page.click(ROUTINE.routineName('Push Day'));
    await expect(page.locator(WORKOUT.finishButton)).toBeVisible({
      timeout: 20_000,
    });

    // Discard the workout.
    const discardBtn = page.locator(WORKOUT.discardButton);
    const isVisible = await discardBtn
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    if (!isVisible) {
      const overflow = page.locator('[aria-label="More options"]');
      if (await overflow.isVisible({ timeout: 3_000 }).catch(() => false)) {
        await overflow.click();
      }
    }

    await page.locator(WORKOUT.discardButton).click();

    // Confirm the discard dialog.
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();

    // Must return to home.
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  test('routines tab is accessible from all other tabs without crashing', async ({
    page,
  }) => {
    // Navigate away to Exercises and back to Routines.
    await page.click(NAV.exercisesTab);
    await expect(page.locator('text=Exercises')).toBeVisible({ timeout: 15_000 });

    await page.click(NAV.routinesTab);
    await expect(page.locator(ROUTINE.heading)).toBeVisible({ timeout: 15_000 });
    await expect(page.locator(ROUTINE.starterRoutinesSection)).toBeVisible({
      timeout: 10_000,
    });

    // Navigate from Home tab.
    await page.click(NAV.homeTab);
    await expect(page.locator('text=GymBuddy')).toBeVisible({ timeout: 15_000 });

    await page.click(NAV.routinesTab);
    await expect(page.locator(ROUTINE.heading)).toBeVisible({ timeout: 15_000 });
  });
});
