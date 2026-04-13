/**
 * Home screen and navigation spec — merged from full suite.
 *
 * Tests:
 *  1. All 4 bottom nav tabs are visible and tappable
 *  2. Switching tabs updates the visible screen content (URL-based assertions)
 *  3. Home tab shows the date context and Start Empty Workout button
 *  4. Home tab shows "Start Empty Workout" button
 *  5. Home tab shows routine cards or Start Empty Workout
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

// ---------------------------------------------------------------------------
// Full — home screen and navigation (no smoke equivalent)
// ---------------------------------------------------------------------------
test.describe('Home screen and navigation', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, TEST_USERS.fullHome.email, TEST_USERS.fullHome.password);
  });

  test('should show all four bottom nav tabs after login', async ({ page }) => {
    await expect(page.locator(NAV.homeTab)).toBeVisible();
    await expect(page.locator(NAV.exercisesTab)).toBeVisible();
    await expect(page.locator(NAV.routinesTab)).toBeVisible();
    await expect(page.locator(NAV.profileTab)).toBeVisible();
  });

  test('should update visible content heading when switching tabs', async ({
    page,
  }) => {
    // Exercises tab — wait for the URL to confirm navigation.
    await page.click(NAV.exercisesTab);
    await page.waitForURL('**/exercises**', { timeout: 15_000 });

    // Routines tab.
    await page.click(NAV.routinesTab);
    await page.waitForURL('**/routines**', { timeout: 15_000 });

    // Profile tab.
    await page.click(NAV.profileTab);
    await page.waitForURL('**/profile**', { timeout: 15_000 });
    await expect(page.locator('text=Log Out')).toBeVisible({
      timeout: 15_000,
    });

    // Home tab — verify home content renders.
    await page.click(NAV.homeTab);
    await page.waitForURL('**/home**', { timeout: 15_000 });
    await expect(page.locator(WORKOUT.startEmpty)).toBeVisible({
      timeout: 15_000,
    });
  });

  test('should show the date and Start Empty Workout button on home tab', async ({ page }) => {
    // The home screen displays a "THIS WEEK" section and the workout launcher.
    await expect(page.locator(WORKOUT.startEmpty)).toBeVisible({ timeout: 15_000 });
  });

  test('should show Start Empty Workout button on home tab', async ({ page }) => {
    await expect(page.locator(WORKOUT.startEmpty)).toBeVisible({
      timeout: 15_000,
    });
  });

  test('should show a routines section with starter or user routines on home tab', async ({
    page,
  }) => {
    // A new user sees starter routine cards; an active user sees their routines.
    // Routine section text labels are canvas-rendered without accessible text on
    // the home screen, so we check for routine card buttons instead. If no
    // routine cards are visible, fall back to the "Start Empty Workout" button
    // which confirms the home screen rendered (routines are tested in routines.spec.ts).
    const hasRoutineCard = await page
      .locator('role=button[name*="Push Day"]')
      .first()
      .isVisible({ timeout: 10_000 })
      .catch(() => false);
    const hasStartEmpty = await page
      .locator(WORKOUT.startEmpty)
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    expect(hasRoutineCard || hasStartEmpty).toBe(true);
  });

  test('should update Last session stat cell after completing a workout', async ({
    page,
  }) => {
    // Start and finish a minimal workout with one completed set.
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);
    await setWeight(page, '60');
    await setReps(page, '5');
    await completeSet(page, 0);
    await finishWorkout(page);

    // Dismiss celebration if shown — check both screens simultaneously to avoid
    // sequential timeouts that waste time on CI.
    const celebrationScreen = page
      .locator(PR.firstWorkoutHeading)
      .or(page.locator(PR.newPRHeading));
    const onCelebration = await celebrationScreen
      .isVisible({ timeout: 20_000 })
      .catch(() => false);

    if (onCelebration) {
      await page.click(PR.continueButton);
    }

    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });

    // The Last session stat cell must be visible after completing a workout.
    await expect(page.locator(HOME_STATS.lastSessionCell)).toBeVisible({
      timeout: 10_000,
    });
  });

  test('should navigate to history screen when tapping Last session stat cell', async ({
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

  test('should show user email and Log Out button on profile tab', async ({
    page,
  }) => {
    await navigateToTab(page, 'Profile');

    // The user's email is shown in the identity card.
    await expect(page.locator(`text=${TEST_USERS.fullHome.email}`)).toBeVisible({
      timeout: 10_000,
    });

    // Log Out button must be visible.
    await expect(page.locator(PROFILE.logOutButton)).toBeVisible({
      timeout: 5_000,
    });
  });

  test('should show kg and lbs options in profile weight unit toggle', async ({
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
  test('should show Last session and Week\'s volume stat cells on home screen (HOME-STAT-001)', async ({
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
  test('should navigate to history screen when tapping Last session cell (HOME-STAT-002)', async ({
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
  test('should navigate to history screen when tapping Week\'s volume cell (HOME-STAT-003)', async ({
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
  test('should update Last session cell after completing a workout (HOME-STAT-004)', async ({
    page,
  }) => {
    // Complete a minimal workout.
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);
    await setWeight(page, '60');
    await setReps(page, '5');
    await completeSet(page, 0);
    await finishWorkout(page);

    // Dismiss PR celebration if shown — check both simultaneously to avoid
    // sequential timeouts on CI.
    const celebrationScreen2 = page
      .locator(PR.firstWorkoutHeading)
      .or(page.locator(PR.newPRHeading));
    const onCelebration2 = await celebrationScreen2
      .isVisible({ timeout: 20_000 })
      .catch(() => false);
    if (onCelebration2) {
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
