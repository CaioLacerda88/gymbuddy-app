/**
 * Personal Records (PR) smoke tests — detection and celebration journey.
 *
 * Covers the critical path:
 *   Login → Workout A (Barbell Bench Press, 60 kg × 8) → finish →
 *   Workout B (Barbell Bench Press, 80 kg × 5) → finish →
 *   PR celebration screen shows "NEW PR" → Continue → PR list shows the record
 *
 * Uses the dedicated smokePR test user so state is isolated from other specs.
 * User is created in global-setup.ts.
 *
 * Notes:
 *   - The first workout triggers "First Workout Complete!" (not "NEW PR").
 *   - The second workout with a higher weight triggers "NEW PR".
 *   - PR detection runs on workout completion, comparing the best prior set.
 *
 * The Flutter web app is served automatically by Playwright's webServer config
 * during local dev. In CI the FLUTTER_APP_URL env var is set by the workflow.
 */

import { test, expect, type Page } from '@playwright/test';
import { login } from '../helpers/auth';
import { NAV, PR } from '../helpers/selectors';
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

test.describe('PR detection smoke', () => {
  test.beforeEach(async ({ page }) => {
    await login(
      page,
      TEST_USERS.smokePR.email,
      TEST_USERS.smokePR.password,
    );
  });

  test('first workout shows "First Workout Complete!" celebration', async ({
    page,
  }) => {
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);

    // Set 60 kg × 8 using the dialog helpers.
    await setWeight(page, '60');
    await setReps(page, '8');

    await completeSet(page, 0);
    await finishWorkout(page);

    // After the first-ever workout the app shows the "First Workout Complete!"
    // celebration screen (not "NEW PR" which requires a prior baseline).
    await expect(page.locator(PR.firstWorkoutHeading)).toBeVisible({
      timeout: 15_000,
    });

    // A "Continue" button dismisses the screen.
    await expect(page.locator(PR.continueButton)).toBeVisible();
    await page.click(PR.continueButton);

    // Dismissing returns to the home screen.
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  test('second workout with higher weight triggers "NEW PR" celebration', async ({
    page,
  }) => {
    // Workout A — 60 kg × 8 (establishes baseline).
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);
    await setWeight(page, '60');
    await setReps(page, '8');
    await completeSet(page, 0);
    await finishWorkout(page);

    // Dismiss the first-workout celebration screen (if shown).
    const isFirstCelebration = await page
      .locator(PR.firstWorkoutHeading)
      .isVisible({ timeout: 15_000 })
      .catch(() => false);

    if (isFirstCelebration) {
      await page.click(PR.continueButton);
    }

    // Wait for Home to stabilise before starting the second workout.
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });

    // Workout B — 80 kg × 5 (new weight PR).
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);
    await setWeight(page, '80');
    await setReps(page, '5');
    await completeSet(page, 0);
    await finishWorkout(page);

    // After the second workout the PR detection should fire and show "NEW PR".
    await expect(page.locator(PR.newPRHeading)).toBeVisible({
      timeout: 20_000,
    });

    // The Continue button dismisses the celebration.
    await expect(page.locator(PR.continueButton)).toBeVisible();
    await page.click(PR.continueButton);

    // Dismissing returns to the home screen.
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  test('PR list shows the record after a PR is set', async ({ page }) => {
    // Complete Workout A (baseline) then Workout B (PR).

    // Workout A — 60 kg × 8.
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);
    await setWeight(page, '60');
    await setReps(page, '8');
    await completeSet(page, 0);
    await finishWorkout(page);

    const isFirst = await page
      .locator(PR.firstWorkoutHeading)
      .isVisible({ timeout: 15_000 })
      .catch(() => false);
    if (isFirst) await page.click(PR.continueButton);

    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });

    // Workout B — heavier weight.
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);
    await setWeight(page, '80');
    await setReps(page, '5');
    await completeSet(page, 0);
    await finishWorkout(page);

    await expect(page.locator(PR.newPRHeading)).toBeVisible({
      timeout: 20_000,
    });
    await page.click(PR.continueButton);

    // Now navigate to the progress/records section to verify the PR appears.
    // The "RECENT RECORDS" section should be visible on the home screen
    // after a PR has been set.
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
    await expect(page.locator(PR.recentRecordsSection)).toBeVisible({
      timeout: 10_000,
    });

    // The record for Barbell Bench Press should appear in the list.
    await expect(
      page.locator(`text=${SEED_EXERCISES.benchPress}`),
    ).toBeVisible({ timeout: 10_000 });
  });
});
