/**
 * Workout action helpers for E2E tests.
 *
 * These helpers drive the active-workout screen interactions. Each helper
 * isolates a single UI action so smoke specs remain readable.
 *
 * Assumes the user is already logged in before calling these helpers.
 */

import { Page, expect } from '@playwright/test';
import { WORKOUT, EXERCISE_PICKER } from './selectors';

/**
 * Start an empty workout from the Home screen.
 *
 * Clicks the "Start Empty Workout" button and waits until the active workout
 * screen is visible (identified by the Finish Workout button in the bottom bar).
 */
export async function startEmptyWorkout(page: Page): Promise<void> {
  await page.click(WORKOUT.startEmpty);
  await expect(page.locator(WORKOUT.finishButton)).toBeVisible({
    timeout: 15_000,
  });
}

/**
 * Add an exercise to the active workout via the exercise picker bottom sheet.
 *
 * Clicks the "Add Exercise" FAB, types the exercise name into the search field,
 * then taps the matching "Add <name>" tile to add it.
 */
export async function addExercise(
  page: Page,
  exerciseName: string,
): Promise<void> {
  await page.click(WORKOUT.addExerciseFab);

  // The picker opens as a bottom sheet with a search field.
  await expect(page.locator(EXERCISE_PICKER.searchInput)).toBeVisible({
    timeout: 10_000,
  });

  await page.fill(EXERCISE_PICKER.searchInput, exerciseName);

  // Wait for the debounce / filter to apply, then select the exercise.
  const addButton = page.locator(EXERCISE_PICKER.addExerciseButton(exerciseName));
  await expect(addButton).toBeVisible({ timeout: 10_000 });
  await addButton.click();

  // Wait for the picker to dismiss and the exercise to appear in the workout.
  await expect(page.locator(EXERCISE_PICKER.searchInput)).not.toBeVisible({
    timeout: 10_000,
  });
}

/**
 * Set the weight for the most recent set by opening the weight dialog.
 *
 * Taps the weight value text to open an AlertDialog, clears the field,
 * types the new value, and confirms with "OK".
 */
export async function setWeight(page: Page, value: string): Promise<void> {
  await page.click(WORKOUT.enterWeightDialog);

  // The dialog contains a TextField. Clear it and type the value.
  const input = page.locator('input[type="number"], input[type="text"]').last();
  await input.clear();
  await input.fill(value);

  await page.click('text=OK');
}

/**
 * Set the reps for the most recent set by opening the reps dialog.
 *
 * Taps the reps value text to open an AlertDialog, clears the field,
 * types the new value, and confirms with "OK".
 */
export async function setReps(page: Page, value: string): Promise<void> {
  await page.click(WORKOUT.enterRepsDialog);

  const input = page.locator('input[type="number"], input[type="text"]').last();
  await input.clear();
  await input.fill(value);

  await page.click('text=OK');
}

/**
 * Mark a set as completed by clicking its checkbox.
 *
 * @param page - Playwright page.
 * @param setIndex - Zero-based index of the set row (defaults to 0, the first set).
 */
export async function completeSet(
  page: Page,
  setIndex: number = 0,
): Promise<void> {
  const checkboxes = page.locator(WORKOUT.markSetDone);
  await expect(checkboxes.nth(setIndex)).toBeVisible({ timeout: 5_000 });
  await checkboxes.nth(setIndex).click();

  // Wait for the checkbox to reflect the completed state.
  await expect(page.locator(WORKOUT.setCompleted).nth(setIndex)).toBeVisible({
    timeout: 5_000,
  });
}

/**
 * Finish the active workout.
 *
 * Clicks "Finish Workout" in the bottom bar, then clicks the "Finish Workout"
 * button inside the confirmation dialog. After this the app navigates away
 * from the active workout screen (to the PR celebration or Home).
 */
export async function finishWorkout(page: Page): Promise<void> {
  await page.click(WORKOUT.finishButton);

  // Confirmation dialog appears — click the dialog action button.
  // The dialog has a "Keep Going" cancel and a "Finish Workout" confirm.
  const dialogFinish = page.locator(WORKOUT.finishButton).last();
  await expect(dialogFinish).toBeVisible({ timeout: 5_000 });
  await dialogFinish.click();
}
