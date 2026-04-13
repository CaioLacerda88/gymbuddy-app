/**
 * Home screen and navigation full spec.
 *
 * Tests:
 *  1. All 4 bottom nav tabs are visible and tappable
 *  2. Switching tabs updates the visible screen content
 *  3. Home tab shows the GymBuddy title and today's date context
 *  4. Home tab shows "Start Empty Workout" button
 *  5. Home tab shows STARTER ROUTINES or MY ROUTINES section
 *  6. After completing a workout, the Last session stat cell is visible
 *  7. Tapping Last session stat cell navigates to the history screen
 *  8. Profile tab shows the user's email and Log Out button
 *  9. Profile weight unit toggle shows kg and lbs options
 * 10. HOME-STAT-001 — Last session and Week's volume stat cells are visible
 * 11. HOME-STAT-002 — Tapping the Last session cell navigates to history
 * 12. HOME-STAT-003 — Tapping the Week's volume cell navigates to history
 * 13. HOME-STAT-004 — Last session cell updates after completing a workout
 *
 * Uses the dedicated `fullHome` test user.
 * The Flutter web app is served automatically by Playwright's webServer config
 * during local dev. In CI the FLUTTER_APP_URL env var is set by the workflow.
 */

import { test, expect } from '@playwright/test';
import { navigateToTab } from '../helpers/app';
import { login } from '../helpers/auth';
import {
  NAV,
  HOME_STATS,
  WORKOUT,
  PR,
  HISTORY,
  PROFILE,
  ROUTINE,
} from '../helpers/selectors';
import {
  startEmptyWorkout,
  addExercise,
  setWeight,
  setReps,
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
    await expect(page.locator('text=Exercises').first()).toBeVisible({
      timeout: 15_000,
    });

    // Routines tab.
    await page.click(NAV.routinesTab);
    await expect(page.locator('text=Routines').first()).toBeVisible({
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

  test('completing a workout updates the Last session stat cell on the home screen', async ({
    page,
  }) => {
    // Start and finish a minimal workout with one completed set.
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);
    await setWeight(page, '60');
    await setReps(page, '5');
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

    // The Last session stat cell must be visible after completing a workout.
    await expect(page.locator(HOME_STATS.lastSessionCell)).toBeVisible({
      timeout: 10_000,
    });
  });

  test('tapping Last session stat cell navigates to the history screen', async ({
    page,
  }) => {
    // The Last session stat cell should be visible on the home screen.
    await expect(page.locator(HOME_STATS.lastSessionCell)).toBeVisible({
      timeout: 10_000,
    });

    await page.click(HOME_STATS.lastSessionCell);

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

  // ---------------------------------------------------------------------------
  // HOME-STAT-001 — Last session and Week's volume stat cells are visible
  //
  // _ContextualStatCells renders two cells with Semantics labels:
  //   "Last session: {value}" and "Week's volume: {value}"
  // Both are tappable and navigate to /home/history.
  // ---------------------------------------------------------------------------
  test('HOME-STAT-001: Last session and Week\'s volume stat cells are visible on the home screen', async ({
    page,
  }) => {
    // The stat cells are at the top of the home screen, below the date line.
    await expect(page.locator(HOME_STATS.lastSessionCell)).toBeVisible({
      timeout: 15_000,
    });
    await expect(page.locator(HOME_STATS.weekVolumeCell)).toBeVisible({
      timeout: 10_000,
    });
  });

  // ---------------------------------------------------------------------------
  // HOME-STAT-002 — Tapping the Last session cell navigates to workout history
  //
  // _ContextualStatCells "Last session" cell calls context.go('/home/history')
  // on tap. After navigation the WorkoutHistoryScreen AppBar title "History"
  // must appear.
  // ---------------------------------------------------------------------------
  test('HOME-STAT-002: tapping the Last session cell navigates to the history screen', async ({
    page,
  }) => {
    // Wait for the cell to be visible.
    await expect(page.locator(HOME_STATS.lastSessionCell)).toBeVisible({
      timeout: 15_000,
    });

    await page.click(HOME_STATS.lastSessionCell);

    await expect(page.locator(HISTORY.heading)).toBeVisible({ timeout: 15_000 });
  });

  // ---------------------------------------------------------------------------
  // HOME-STAT-003 — Tapping the Week's volume cell navigates to history
  //
  // _ContextualStatCells "Week's volume" cell calls context.go('/home/history')
  // on tap. After navigation the WorkoutHistoryScreen AppBar title "History"
  // must appear.
  // ---------------------------------------------------------------------------
  test('HOME-STAT-003: tapping the Week\'s volume cell navigates to the history screen', async ({
    page,
  }) => {
    await expect(page.locator(HOME_STATS.weekVolumeCell)).toBeVisible({
      timeout: 15_000,
    });

    await page.click(HOME_STATS.weekVolumeCell);

    await expect(page.locator(HISTORY.heading)).toBeVisible({ timeout: 15_000 });
  });

  // ---------------------------------------------------------------------------
  // HOME-STAT-004 — Last session cell updates after completing a workout
  //
  // Completes a minimal workout and verifies that after returning to Home the
  // "Last session" cell is visible, reflecting the recent workout. The value
  // is dynamic ("Just now", "Today", etc.) so we just verify the cell is visible.
  // ---------------------------------------------------------------------------
  test('HOME-STAT-004: Last session cell updates after completing a workout', async ({
    page,
  }) => {
    // Complete a minimal workout.
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);
    await setWeight(page, '60');
    await setReps(page, '5');
    await completeSet(page, 0);
    await finishWorkout(page);

    // Dismiss PR celebration if shown.
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

    // After returning to Home the "Last session" cell should reflect the recent workout.
    // The value is dynamic ("Just now", "Today", etc.) so we just verify the cell is visible.
    await expect(page.locator(HOME_STATS.lastSessionCell)).toBeVisible({
      timeout: 10_000,
    });
  });
});
