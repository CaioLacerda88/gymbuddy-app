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
 * 10. HOME-STAT-001 — Workouts and Records stat cards are visible
 * 11. HOME-STAT-002 — Tapping the Workouts stat card navigates to history
 * 12. HOME-STAT-003 — Tapping the Records stat card navigates to PR list
 * 13. HOME-STAT-004 — Workouts card count updates after completing a workout
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
  HOME,
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

  // ---------------------------------------------------------------------------
  // HOME-STAT-001 — Workouts and Records stat cards are visible on the home screen
  //
  // _StatCardsRow renders two _StatCard widgets. Each has a Semantics button
  // whose label includes "tap to view workouts" / "tap to view records" once the
  // count has loaded from the server.
  // ---------------------------------------------------------------------------
  test('HOME-STAT-001: Workouts and Records stat cards are visible on the home screen', async ({
    page,
  }) => {
    // The stat cards are at the top of the home screen, below the date line.
    // We wait for the data-loaded state (label includes "tap to view").
    await expect(page.locator(HOME_STATS.workoutsCard)).toBeVisible({
      timeout: 15_000,
    });
    await expect(page.locator(HOME_STATS.recordsCard)).toBeVisible({
      timeout: 10_000,
    });
  });

  // ---------------------------------------------------------------------------
  // HOME-STAT-002 — Tapping the Workouts stat card navigates to workout history
  //
  // _StatCard for "Workouts" calls context.go('/home/history') on tap.
  // After navigation the WorkoutHistoryScreen AppBar title "History" must appear.
  // ---------------------------------------------------------------------------
  test('HOME-STAT-002: tapping the Workouts stat card navigates to the history screen', async ({
    page,
  }) => {
    // Wait for the card to be in data state (count loaded from server).
    await expect(page.locator(HOME_STATS.workoutsCard)).toBeVisible({
      timeout: 15_000,
    });

    await page.click(HOME_STATS.workoutsCard);

    await expect(page.locator(HISTORY.heading)).toBeVisible({ timeout: 15_000 });
  });

  // ---------------------------------------------------------------------------
  // HOME-STAT-003 — Tapping the Records stat card navigates to the PR list
  //
  // _StatCard for "Records" calls context.go('/records') on tap.
  // After navigation the PRListScreen AppBar title "Personal Records" must appear.
  // ---------------------------------------------------------------------------
  test('HOME-STAT-003: tapping the Records stat card navigates to the Personal Records screen', async ({
    page,
  }) => {
    await expect(page.locator(HOME_STATS.recordsCard)).toBeVisible({
      timeout: 15_000,
    });

    await page.click(HOME_STATS.recordsCard);

    await expect(page.locator('text=Personal Records')).toBeVisible({
      timeout: 15_000,
    });
  });

  // ---------------------------------------------------------------------------
  // HOME-STAT-004 — Workouts card count increments after finishing a workout
  //
  // Reads the aria-label before and after completing a workout to confirm the
  // count changed. The Semantics label encodes the count: "$n Workouts, tap…"
  // so we can extract it from the attribute.
  // ---------------------------------------------------------------------------
  test('HOME-STAT-004: Workouts card count increments after completing a workout', async ({
    page,
  }) => {
    // Read the current count from the aria-label before starting a workout.
    await expect(page.locator(HOME_STATS.workoutsCard)).toBeVisible({
      timeout: 15_000,
    });

    const labelBefore = await page
      .locator(HOME_STATS.workoutsCard)
      .getAttribute('aria-label');

    // Extract the integer at the start of the label: "3 Workouts, tap to view…"
    const countBefore = parseInt(
      (labelBefore ?? '').match(/^(\d+)/)?.[1] ?? '0',
      10,
    );

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

    // After returning to Home the provider is invalidated and the card reloads.
    // Wait for the card to show the new count (greater than before).
    await expect(async () => {
      const labelAfter = await page
        .locator(HOME_STATS.workoutsCard)
        .getAttribute('aria-label');
      const countAfter = parseInt(
        (labelAfter ?? '').match(/^(\d+)/)?.[1] ?? '0',
        10,
      );
      expect(countAfter).toBeGreaterThan(countBefore);
    }).toPass({ timeout: 15_000 });
  });
});
