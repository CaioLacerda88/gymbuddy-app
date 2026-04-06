/**
 * Workout action helpers for E2E tests.
 *
 * These helpers drive the active-workout screen interactions. Each helper
 * isolates a single UI action so smoke specs remain readable.
 *
 * Assumes the user is already logged in before calling these helpers.
 *
 * CanvasKit renderer notes
 * ------------------------
 * Flutter web (CanvasKit) does not render standard HTML elements for most
 * widgets — it draws to <canvas>. However, text fields are an exception:
 * Flutter injects a hidden <input> overlay into the DOM when a TextField
 * receives focus so that the OS keyboard and clipboard work. Playwright can
 * interact with this overlay using the generic 'input' selector.
 *
 * The weight and reps entry dialogs work as follows:
 *   1. Tap the large value text in the set row (initially "0" for both).
 *      WeightStepper / RepsStepper open an AlertDialog with a TextField.
 *   2. The AlertDialog title ("Enter weight" / "Enter reps") confirms focus.
 *   3. Flutter renders a hidden <input> overlay for the focused TextField.
 *      Using `page.locator('input').last()` targets this overlay.
 *   4. Clear and fill the input, then click "OK" to confirm.
 */

import { Page, expect } from '@playwright/test';
import { flutterFill } from './app';
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

  await flutterFill(page, EXERCISE_PICKER.searchInput, exerciseName);

  // Wait for the debounce / filter to apply, then select the exercise.
  // Flutter CanvasKit renders duplicate semantics nodes for each exercise card,
  // so we use .first() to avoid strict-mode violations.
  const addButton = page.locator(EXERCISE_PICKER.addExerciseButton(exerciseName)).first();
  await expect(addButton).toBeVisible({ timeout: 10_000 });
  await addButton.click();

  // Wait for the picker to dismiss and the exercise to appear in the workout.
  await expect(page.locator(EXERCISE_PICKER.searchInput)).not.toBeVisible({
    timeout: 10_000,
  });

  // The exercise starts with zero sets (ActiveWorkoutNotifier.addExercise
  // creates with `sets: const []`). Click "Add Set" to create the first set
  // row so that weight/reps buttons are available for subsequent interactions.
  await expect(page.locator(WORKOUT.addSetButton)).toBeVisible({
    timeout: 10_000,
  });
  await page.locator(WORKOUT.addSetButton).first().click();

  // Wait for the set row to render — the weight button confirms it.
  await expect(
    page.locator('role=button[name*="Weight value"]').first(),
  ).toBeVisible({ timeout: 10_000 });
}

/**
 * Set the weight for the next uncompleted set by tapping its value.
 *
 * Taps the first visible weight value text to open the "Enter weight" dialog,
 * clears the existing value, types the new value, and confirms with "OK".
 *
 * Implementation note: WeightStepper shows the current value as large text
 * (e.g. "0") inside a GestureDetector. Tapping it opens an AlertDialog.
 * Flutter renders a hidden <input> overlay for the focused TextField inside
 * the dialog, which Playwright can target with `page.locator('input').last()`.
 */
export async function setWeight(page: Page, value: string): Promise<void> {
  // The weight value has a Semantics label like "Weight value: 0 kg. Tap to enter weight."
  // Click the first matching weight button to open the "Enter weight" dialog.
  await page.locator('role=button[name*="Weight value"]').first().click();

  // Wait for the dialog title to confirm the correct dialog opened.
  await expect(page.locator('text=Enter weight')).toBeVisible({ timeout: 5_000 });

  // The dialog TextField focuses automatically. Select all existing content
  // and type the new value using real keyboard events.
  await page.waitForTimeout(300);
  await page.keyboard.press('Control+a');
  await page.keyboard.type(value, { delay: 10 });

  await page.click('text=OK');

  // Wait for the dialog to dismiss before returning.
  await expect(page.locator('text=Enter weight')).not.toBeVisible({
    timeout: 5_000,
  });
}

/**
 * Set the reps for the next uncompleted set by tapping its value.
 *
 * Taps the first visible reps value text to open the "Enter reps" dialog,
 * clears the existing value, types the new value, and confirms with "OK".
 *
 * Implementation note: After setting weight, the weight cell shows the new
 * value (no longer "0"), so the first "0" text visible is now the reps value.
 */
export async function setReps(page: Page, value: string): Promise<void> {
  // The reps value has a Semantics label like "Reps value: 0. Tap to enter reps."
  // Click the first matching reps button to open the "Enter reps" dialog.
  await page.locator('role=button[name*="Reps value"]').first().click();

  // Wait for the dialog title to confirm the correct dialog opened.
  await expect(page.locator('text=Enter reps')).toBeVisible({ timeout: 5_000 });

  // The dialog TextField focuses automatically. Select all existing content
  // and type the new value using real keyboard events.
  await page.waitForTimeout(300);
  await page.keyboard.press('Control+a');
  await page.keyboard.type(value, { delay: 10 });

  await page.click('text=OK');

  // Wait for the dialog to dismiss before returning.
  await expect(page.locator('text=Enter reps')).not.toBeVisible({
    timeout: 5_000,
  });
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
