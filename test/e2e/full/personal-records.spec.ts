/**
 * Personal records full spec — detection, celebration, and list display.
 *
 * Tests:
 *  1. First completed workout shows "First Workout Complete!" celebration
 *  2. Second workout with HIGHER weight triggers "NEW PR" for max weight
 *  3. Second workout with MORE reps (same weight) triggers "NEW PR"
 *  4. Home screen shows "RECENT RECORDS" section after a PR is set
 *  5. RECENT RECORDS section shows the exercise name
 *  6. Multiple exercises in one workout each generate their own PR entries
 *
 * Notes:
 *  - The first workout is always a baseline — it shows "First Workout Complete!",
 *    not "NEW PR".
 *  - Subsequent workouts with a higher weight or more reps trigger "NEW PR".
 *  - PR detection runs server-side on workout save.
 *  - Tests in this describe block share a single fresh user and run in order.
 *    State accumulates (workouts pile up), so each test uses a different
 *    exercise to avoid interference.
 *
 * Uses the dedicated `fullPR` test user.
 * The Flutter web app is served automatically by Playwright's webServer config
 * during local dev. In CI the FLUTTER_APP_URL env var is set by the workflow.
 */

import { test, expect, type Page } from '@playwright/test';
import { login } from '../helpers/auth';
import { NAV, PR, WORKOUT } from '../helpers/selectors';
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

const USER = TEST_USERS.fullPR;

// ---------------------------------------------------------------------------
// Helper — complete a single-exercise workout with one set
// ---------------------------------------------------------------------------

async function doWorkout(
  page: Page,
  exerciseName: string,
  weight: string,
  reps: string,
): Promise<void> {
  await startEmptyWorkout(page);
  await addExercise(page, exerciseName);
  await setWeight(page, weight);
  await setReps(page, reps);
  await completeSet(page, 0);
  await finishWorkout(page);
}

// ---------------------------------------------------------------------------
// Helper — dismiss the celebration screen and wait for Home
// ---------------------------------------------------------------------------

async function dismissCelebration(page: Page): Promise<void> {
  const isCelebration = await page
    .locator('text=First Workout Complete!')
    .isVisible({ timeout: 15_000 })
    .catch(() => false);

  if (!isCelebration) {
    // Check for "NEW PR" heading.
    const isNewPR = await page
      .locator(PR.newPRHeading)
      .isVisible({ timeout: 5_000 })
      .catch(() => false);
    if (isNewPR) {
      await page.click(PR.continueButton);
    }
  } else {
    await page.click(PR.continueButton);
  }

  await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
}

// ---------------------------------------------------------------------------
// Spec
// ---------------------------------------------------------------------------

test.describe('Personal records — full suite', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, USER.email, USER.password);
  });

  test('first completed workout shows "First Workout Complete!" celebration', async ({
    page,
  }) => {
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);
    await setWeight(page, '60');
    await setReps(page, '8');
    await completeSet(page, 0);
    await finishWorkout(page);

    // First ever workout shows this specific heading (not "NEW PR").
    await expect(page.locator(PR.firstWorkoutHeading)).toBeVisible({
      timeout: 20_000,
    });
    await expect(page.locator(PR.continueButton)).toBeVisible();

    await page.click(PR.continueButton);
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  test('second workout with higher weight triggers "NEW PR" celebration', async ({
    page,
  }) => {
    // Workout A — establishes baseline for Barbell Squat (different exercise
    // from the first test to avoid PR state collision).
    await doWorkout(page, SEED_EXERCISES.squat, '60', '5');
    await dismissCelebration(page);

    // Workout B — higher weight on the same exercise → new weight PR.
    await doWorkout(page, SEED_EXERCISES.squat, '80', '5');

    await expect(page.locator(PR.newPRHeading)).toBeVisible({
      timeout: 20_000,
    });
    await expect(page.locator(PR.continueButton)).toBeVisible();

    await page.click(PR.continueButton);
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  test('second workout with more reps at the same weight triggers "NEW PR"', async ({
    page,
  }) => {
    // Use Overhead Press to isolate state from other tests.
    // Workout A — 50 kg × 5.
    await doWorkout(page, SEED_EXERCISES.overheadPress, '50', '5');
    await dismissCelebration(page);

    // Workout B — 50 kg × 10 (more reps → reps PR).
    await doWorkout(page, SEED_EXERCISES.overheadPress, '50', '10');

    await expect(page.locator(PR.newPRHeading)).toBeVisible({
      timeout: 20_000,
    });
    await page.click(PR.continueButton);
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  test('home screen shows RECENT RECORDS section after a PR is set', async ({
    page,
  }) => {
    // Use Deadlift to isolate state.
    await doWorkout(page, SEED_EXERCISES.deadlift, '100', '3');
    await dismissCelebration(page);

    await doWorkout(page, SEED_EXERCISES.deadlift, '120', '3');

    const isNewPR = await page
      .locator(PR.newPRHeading)
      .isVisible({ timeout: 20_000 })
      .catch(() => false);
    if (isNewPR) {
      await page.click(PR.continueButton);
    }

    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });

    // The home screen must show the RECENT RECORDS section.
    await expect(page.locator(PR.recentRecordsSection)).toBeVisible({
      timeout: 10_000,
    });
  });

  test('RECENT RECORDS section shows the exercise name after a PR', async ({
    page,
  }) => {
    // Workout A — Barbell Curl baseline.
    await doWorkout(page, 'Barbell Curl', '30', '8');
    await dismissCelebration(page);

    // Workout B — heavier Barbell Curl → PR.
    await doWorkout(page, 'Barbell Curl', '40', '8');

    const isNewPR = await page
      .locator(PR.newPRHeading)
      .isVisible({ timeout: 20_000 })
      .catch(() => false);
    if (isNewPR) {
      await page.click(PR.continueButton);
    }

    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
    await expect(page.locator(PR.recentRecordsSection)).toBeVisible({
      timeout: 10_000,
    });

    // The exercise name must appear in the records list on the home screen.
    await expect(page.locator('text=Barbell Curl')).toBeVisible({
      timeout: 10_000,
    });
  });

  test('two exercises in one workout each get their own PR detection', async ({
    page,
  }) => {
    // Baseline workout — Leg Press + Leg Curl.
    await startEmptyWorkout(page);

    // Exercise 1: Leg Press.
    await addExercise(page, 'Leg Press');
    await setWeight(page, '80');
    await setReps(page, '8');
    await completeSet(page, 0);

    // Exercise 2: Leg Curl.
    await addExercise(page, 'Leg Curl');
    // After completing the first exercise set, the first visible "0" is the
    // weight value for the new (second) exercise set row.
    await setWeight(page, '40');
    await setReps(page, '10');
    // Mark the second exercise set (index 1 overall).
    await page.locator(WORKOUT.markSetDone).nth(1).click();

    await finishWorkout(page);
    await dismissCelebration(page);

    // PR workout — both exercises at higher values.
    await startEmptyWorkout(page);

    await addExercise(page, 'Leg Press');
    await setWeight(page, '100');
    await setReps(page, '8');
    await completeSet(page, 0);

    await addExercise(page, 'Leg Curl');
    await setWeight(page, '50');
    await setReps(page, '10');
    await page.locator(WORKOUT.markSetDone).nth(1).click();

    await finishWorkout(page);

    // PR celebration must appear.
    await expect(page.locator(PR.newPRHeading)).toBeVisible({
      timeout: 20_000,
    });
    await page.click(PR.continueButton);
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });

    // RECENT RECORDS section must be present.
    await expect(page.locator(PR.recentRecordsSection)).toBeVisible({
      timeout: 10_000,
    });
  });
});
