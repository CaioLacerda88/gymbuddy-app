/**
 * Workout logging full spec — comprehensive workout lifecycle tests.
 *
 * Tests:
 *  1. Start empty workout shows Finish and Add Exercise buttons
 *  2. Add multiple exercises — both appear as exercise cards
 *  3. Set weight and reps via dialog entry
 *  4. Add multiple sets to an exercise
 *  5. Complete individual sets via checkbox
 *  6. Finish with incomplete sets shows warning dialog
 *  7. Finish workout with completed sets → PR celebration or home
 *  8. Discard workout — confirm dialog, returns to home without saving
 *  9. Workout name is auto-generated with date (contains em-dash separator)
 *
 * Uses the dedicated `fullWorkout` test user.
 * The Flutter web app must be served at localhost:8080 before running.
 */

import { test, expect } from '@playwright/test';
import { login } from '../helpers/auth';
import { NAV, WORKOUT, PR } from '../helpers/selectors';
import {
  startEmptyWorkout,
  addExercise,
  completeSet,
  finishWorkout,
} from '../helpers/workout';
import { TEST_USERS } from '../fixtures/test-users';
import { SEED_EXERCISES } from '../fixtures/test-exercises';

const USER = TEST_USERS.fullWorkout;

test.describe('Workout logging — full suite', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, USER.email, USER.password);
  });

  test('start empty workout shows Finish Workout and Add Exercise buttons', async ({
    page,
  }) => {
    await startEmptyWorkout(page);

    await expect(page.locator(WORKOUT.finishButton)).toBeVisible();
    await expect(page.locator(WORKOUT.addExerciseFab)).toBeVisible();

    // Clean up by discarding.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator('text=Discard').last();
    if (
      await confirmDiscard.isVisible({ timeout: 3_000 }).catch(() => false)
    ) {
      await confirmDiscard.click();
    }
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  test('add multiple exercises — both appear as exercise cards', async ({
    page,
  }) => {
    await startEmptyWorkout(page);

    // Add Barbell Bench Press.
    await addExercise(page, SEED_EXERCISES.benchPress);
    await expect(page.locator(WORKOUT.addSetButton)).toBeVisible({
      timeout: 10_000,
    });

    // Add Barbell Squat.
    await addExercise(page, SEED_EXERCISES.squat);

    // Both exercise names must appear as card headings.
    await expect(
      page.locator(`text=${SEED_EXERCISES.benchPress}`),
    ).toBeVisible({ timeout: 10_000 });
    await expect(page.locator(`text=${SEED_EXERCISES.squat}`)).toBeVisible({
      timeout: 10_000,
    });

    // Discard to clean up.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator('text=Discard').last();
    if (
      await confirmDiscard.isVisible({ timeout: 3_000 }).catch(() => false)
    ) {
      await confirmDiscard.click();
    }
  });

  test('set weight and reps via dialog entry', async ({ page }) => {
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);

    // The default value for both weight and reps is "0".
    // Tap the first "0" to open the weight entry dialog.
    const firstZero = page.locator('text=0').first();
    await firstZero.click();

    // Dialog title confirms we are entering weight.
    await expect(page.locator('text=Enter weight')).toBeVisible({
      timeout: 5_000,
    });

    const weightInput = page.locator('input').last();
    await weightInput.clear();
    await weightInput.fill('100');
    await page.locator('text=OK').click();

    // The dialog must dismiss.
    await expect(page.locator('text=Enter weight')).not.toBeVisible({
      timeout: 5_000,
    });

    // The weight value must update to 100 in the set row.
    await expect(page.locator('text=100')).toBeVisible({ timeout: 5_000 });

    // Tap reps "0" to open the reps dialog.
    const repsZero = page.locator('text=0').first();
    await repsZero.click();

    await expect(page.locator('text=Enter reps')).toBeVisible({
      timeout: 5_000,
    });

    const repsInput = page.locator('input').last();
    await repsInput.clear();
    await repsInput.fill('5');
    await page.locator('text=OK').click();

    await expect(page.locator('text=Enter reps')).not.toBeVisible({
      timeout: 5_000,
    });

    // Discard.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator('text=Discard').last();
    if (
      await confirmDiscard.isVisible({ timeout: 3_000 }).catch(() => false)
    ) {
      await confirmDiscard.click();
    }
  });

  test('add multiple sets to an exercise', async ({ page }) => {
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);

    // Each exercise card starts with one set row. The Add Set button adds more.
    const initialSets = await page
      .locator(WORKOUT.markSetDone)
      .count();

    await page.click(WORKOUT.addSetButton);
    await page.waitForTimeout(300);

    const setsAfterFirst = await page.locator(WORKOUT.markSetDone).count();
    expect(setsAfterFirst).toBeGreaterThan(initialSets);

    await page.click(WORKOUT.addSetButton);
    await page.waitForTimeout(300);

    const setsAfterSecond = await page.locator(WORKOUT.markSetDone).count();
    expect(setsAfterSecond).toBeGreaterThan(setsAfterFirst);

    // Discard.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator('text=Discard').last();
    if (
      await confirmDiscard.isVisible({ timeout: 3_000 }).catch(() => false)
    ) {
      await confirmDiscard.click();
    }
  });

  test('complete individual sets via checkbox toggle', async ({ page }) => {
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);

    // Add a second set so we can check independence.
    await page.click(WORKOUT.addSetButton);

    // Mark the first set as done.
    await completeSet(page, 0);

    // The first checkbox is now in the completed state.
    await expect(page.locator(WORKOUT.setCompleted).nth(0)).toBeVisible({
      timeout: 5_000,
    });

    // The second set must still be in the uncompleted state.
    await expect(page.locator(WORKOUT.markSetDone).nth(0)).toBeVisible({
      timeout: 5_000,
    });

    // Discard.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator('text=Discard').last();
    if (
      await confirmDiscard.isVisible({ timeout: 3_000 }).catch(() => false)
    ) {
      await confirmDiscard.click();
    }
  });

  test('finish with incomplete sets shows "incomplete sets" warning dialog', async ({
    page,
  }) => {
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);

    // Do NOT complete any sets — tap Finish Workout directly.
    await page.click(WORKOUT.finishButton);

    // The dialog should warn about incomplete sets.
    // The warning text follows the pattern "You have N incomplete set(s)".
    const dialog = page.locator('[role="dialog"]');
    await expect(dialog).toBeVisible({ timeout: 8_000 });

    const hasIncompleteWarning =
      (await page
        .locator('text=incomplete')
        .isVisible({ timeout: 5_000 })
        .catch(() => false)) ||
      (await page
        .locator("text=You have")
        .isVisible({ timeout: 2_000 })
        .catch(() => false));

    expect(hasIncompleteWarning).toBe(true);

    // "Keep Going" closes the dialog and returns to the workout.
    await page.click(WORKOUT.keepGoingButton);
    await expect(page.locator(WORKOUT.finishButton)).toBeVisible({
      timeout: 5_000,
    });

    // Discard.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator('text=Discard').last();
    if (
      await confirmDiscard.isVisible({ timeout: 3_000 }).catch(() => false)
    ) {
      await confirmDiscard.click();
    }
  });

  test('finish workout with completed sets navigates away from the workout screen', async ({
    page,
  }) => {
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);

    // Set weight and reps.
    const weightZero = page.locator('text=0').first();
    await weightZero.click();
    const wInput = page.locator('input').last();
    await wInput.clear();
    await wInput.fill('60');
    await page.locator('text=OK').click();

    const repsZero = page.locator('text=0').first();
    await repsZero.click();
    const rInput = page.locator('input').last();
    await rInput.clear();
    await rInput.fill('8');
    await page.locator('text=OK').click();

    await completeSet(page, 0);
    await finishWorkout(page);

    // App must navigate to either the PR celebration screen or home.
    const isCelebration = await page
      .locator(PR.firstWorkoutHeading)
      .isVisible({ timeout: 15_000 })
      .catch(() => false);
    const isNewPR = await page
      .locator(PR.newPRHeading)
      .isVisible({ timeout: 3_000 })
      .catch(() => false);

    if (isCelebration || isNewPR) {
      await page.click(PR.continueButton);
    }

    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  test('discard workout shows confirmation dialog and returns to home', async ({
    page,
  }) => {
    await startEmptyWorkout(page);

    // The Discard button may be directly visible or inside an overflow menu.
    const discardBtn = page.locator(WORKOUT.discardButton);
    const isVisible = await discardBtn
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    if (!isVisible) {
      const overflow = page.locator('[aria-label="More options"]');
      if (
        await overflow.isVisible({ timeout: 3_000 }).catch(() => false)
      ) {
        await overflow.click();
      }
    }

    await page.locator(WORKOUT.discardButton).click();

    // Confirmation dialog must appear.
    await expect(page.locator('text=Discard Workout?')).toBeVisible({
      timeout: 5_000,
    });

    // Confirm discard.
    await page.locator('text=Discard').last().click();

    // Must return to home without saving the workout.
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  test('workout name is auto-generated with an em-dash date separator', async ({
    page,
  }) => {
    await startEmptyWorkout(page);

    // The AppBar title uses an em-dash (U+2014) separator: "Workout — Day Mon DD"
    const appBarTitle = page.locator('flt-semantics[aria-label*="Workout \u2014"]');
    await expect(appBarTitle).toBeVisible({ timeout: 10_000 });

    // Discard to clean up.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator('text=Discard').last();
    if (
      await confirmDiscard.isVisible({ timeout: 3_000 }).catch(() => false)
    ) {
      await confirmDiscard.click();
    }
  });
});
