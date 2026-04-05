/**
 * Home screen and navigation full spec.
 *
 * Tests:
 *  1. All 4 bottom nav tabs are visible and tappable
 *  2. Switching tabs updates the visible screen content
 *  3. Home tab shows the GymBuddy title and today's date context
 *  4. Home tab shows "Start Empty Workout" button
 *  5. Home tab shows STARTER ROUTINES or MY ROUTINES section
 *  6. After completing a workout, the RECENT section appears
 *  7. "View All" link navigates to the workout history screen
 *  8. Profile tab shows the user's email and Log Out button
 *  9. Profile weight unit toggle shows kg and lbs options
 *
 * Uses the dedicated `fullHome` test user.
 * The Flutter web app must be served at localhost:8080 before running.
 */

import { test, expect } from '@playwright/test';
import { navigateToTab } from '../helpers/app';
import { login } from '../helpers/auth';
import {
  NAV,
  HOME,
  WORKOUT,
  PR,
  HISTORY,
  PROFILE,
  ROUTINE,
} from '../helpers/selectors';
import {
  startEmptyWorkout,
  addExercise,
  completeSet,
  finishWorkout,
} from '../helpers/workout';
import { TEST_USERS } from '../fixtures/test-users';
import { SEED_EXERCISES } from '../fixtures/test-exercises';

const USER = TEST_USERS.fullHome;

test.describe('Home screen and navigation — full suite', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, USER.email, USER.password);
  });

  test('all four bottom nav tabs are visible after login', async ({ page }) => {
    await expect(page.locator(NAV.homeTab)).toBeVisible();
    await expect(page.locator(NAV.exercisesTab)).toBeVisible();
    await expect(page.locator(NAV.routinesTab)).toBeVisible();
    await expect(page.locator(NAV.profileTab)).toBeVisible();
  });

  test('switching tabs updates the visible content heading', async ({
    page,
  }) => {
    // Exercises tab.
    await page.click(NAV.exercisesTab);
    await expect(page.locator('text=Exercises')).toBeVisible({
      timeout: 15_000,
    });

    // Routines tab.
    await page.click(NAV.routinesTab);
    await expect(page.locator('text=Routines')).toBeVisible({
      timeout: 15_000,
    });

    // Profile tab.
    await page.click(NAV.profileTab);
    await expect(page.locator('text=Log Out')).toBeVisible({
      timeout: 15_000,
    });

    // Home tab.
    await page.click(NAV.homeTab);
    await expect(page.locator('text=GymBuddy')).toBeVisible({
      timeout: 15_000,
    });
  });

  test('home tab shows GymBuddy title', async ({ page }) => {
    await expect(page.locator('text=GymBuddy')).toBeVisible({ timeout: 15_000 });
  });

  test('home tab shows "Start Empty Workout" button', async ({ page }) => {
    await expect(page.locator(WORKOUT.startEmpty)).toBeVisible({
      timeout: 15_000,
    });
  });

  test('home tab shows a routines section (STARTER or MY ROUTINES)', async ({
    page,
  }) => {
    // A new user sees STARTER ROUTINES; a user who created routines sees MY ROUTINES.
    // Either heading must be present.
    const hasStarter = await page
      .locator(ROUTINE.starterRoutinesSection)
      .isVisible({ timeout: 10_000 })
      .catch(() => false);
    const hasMy = await page
      .locator(ROUTINE.myRoutinesSection)
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    expect(hasStarter || hasMy).toBe(true);
  });

  test('completing a workout makes RECENT section appear on the home screen', async ({
    page,
  }) => {
    // Start and finish a minimal workout.
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);

    await page.locator('text=0').first().click();
    const wInput = page.locator('input').last();
    await wInput.clear();
    await wInput.fill('60');
    await page.locator('text=OK').click();

    await page.locator('text=0').first().click();
    const rInput = page.locator('input').last();
    await rInput.clear();
    await rInput.fill('5');
    await page.locator('text=OK').click();

    await completeSet(page, 0);
    await finishWorkout(page);

    // Dismiss celebration if shown.
    const isCelebration = await page
      .locator(PR.firstWorkoutHeading)
      .isVisible({ timeout: 15_000 })
      .catch(() => false);
    const isNewPR = await page
      .locator(PR.newPRHeading)
      .isVisible({ timeout: isCelebration ? 0 : 3_000 })
      .catch(() => false);

    if (isCelebration || isNewPR) {
      await page.click(PR.continueButton);
    }

    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });

    // The RECENT section must appear after at least one finished workout.
    await expect(page.locator(HOME.recentSection)).toBeVisible({
      timeout: 10_000,
    });
  });

  test('"View All" link on home screen navigates to the history screen', async ({
    page,
  }) => {
    // The "View All" link is only shown when there is at least one workout.
    // Check if it is already visible (from prior test state in this user account).
    const viewAllVisible = await page
      .locator(HOME.viewAllHistory)
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    if (!viewAllVisible) {
      // Complete a workout first to surface the link.
      await startEmptyWorkout(page);
      await finishWorkout(page);

      const isCelebration = await page
        .locator(PR.firstWorkoutHeading)
        .isVisible({ timeout: 15_000 })
        .catch(() => false);
      if (isCelebration) {
        await page.click(PR.continueButton);
      }

      await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
    }

    // "View All" must now be visible.
    await expect(page.locator(HOME.viewAllHistory)).toBeVisible({
      timeout: 10_000,
    });

    await page.click(HOME.viewAllHistory);

    // History screen heading must appear.
    await expect(page.locator(HISTORY.heading)).toBeVisible({
      timeout: 15_000,
    });
  });

  test('profile tab shows the user email and Log Out button', async ({
    page,
  }) => {
    await navigateToTab(page, 'Profile');

    // The user's email is shown in the identity card.
    await expect(page.locator(`text=${USER.email}`)).toBeVisible({
      timeout: 10_000,
    });

    // Log Out button must be visible.
    await expect(page.locator(PROFILE.logOutButton)).toBeVisible({
      timeout: 5_000,
    });
  });

  test('profile weight unit toggle shows kg and lbs options', async ({
    page,
  }) => {
    await navigateToTab(page, 'Profile');

    await expect(page.locator(PROFILE.kgOption)).toBeVisible({
      timeout: 10_000,
    });
    await expect(page.locator(PROFILE.lbsOption)).toBeVisible({
      timeout: 5_000,
    });

    // Tapping lbs must not crash the app; the option remains visible.
    await page.click(PROFILE.lbsOption);
    await expect(page.locator(PROFILE.lbsOption)).toBeVisible({
      timeout: 5_000,
    });
    await expect(page.locator(PROFILE.kgOption)).toBeVisible();
  });
});
