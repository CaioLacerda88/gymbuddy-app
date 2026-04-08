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
 * 10. WK-023 (P1) — Decimal weight (22.5 kg) round-trip
 * 11. EX-DETAIL-001 — Tapping exercise name during active workout opens bottom sheet
 * 12. EX-DETAIL-002 — Bottom sheet shows exercise name and muscle group
 * 13. EX-DETAIL-003 — Dismissing bottom sheet returns to workout with timer running
 * 14. EX-DETAIL-004 — Workout state preserved after viewing exercise detail
 *
 * Uses the dedicated `fullWorkout` test user.
 * The Flutter web app is served automatically by Playwright's webServer config
 * during local dev. In CI the FLUTTER_APP_URL env var is set by the workflow.
 */

import { test, expect } from '@playwright/test';
import { login } from '../helpers/auth';
import { NAV, WORKOUT, PR, HOME_STATS, HISTORY } from '../helpers/selectors';
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
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();
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
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();
  });

  test('set weight and reps via dialog entry', async ({ page }) => {
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);

    // Set weight to 100 kg via the dialog helper.
    await setWeight(page, '100');

    // The dialog must dismiss and the weight value must update to 100 in the set row.
    await expect(page.locator('text=100')).toBeVisible({ timeout: 5_000 });

    // Set reps to 5 via the dialog helper.
    await setReps(page, '5');

    // Discard.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();
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
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();
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
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();
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
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();
  });

  test('finish workout with completed sets navigates away from the workout screen', async ({
    page,
  }) => {
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);

    // Set weight and reps using the helpers.
    await setWeight(page, '60');
    await setReps(page, '8');

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
    await page.locator(WORKOUT.discardConfirmButton).click();

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
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();
  });

  // ---------------------------------------------------------------------------
  // WK-023 (P1) — Decimal weight round-trip
  // Sets weight to 22.5, completes the set, finishes the workout, then checks
  // that "22.5" appears in the recent workouts section on the home screen.
  // This verifies that decimal values survive the save → reload → display cycle.
  // ---------------------------------------------------------------------------
  test('WK-023: decimal weight 22.5 survives the full save and display round-trip', async ({
    page,
  }) => {
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);

    // Enter the decimal weight via the dialog helper.
    await setWeight(page, '22.5');

    // Confirm the decimal value is visible in the set row immediately after entry.
    await expect(page.locator('text=22.5')).toBeVisible({ timeout: 5_000 });

    await setReps(page, '10');
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

    // Navigate to the history screen to verify the saved value.
    // Tap the Workouts stat card, or fall back to direct navigation.
    const statsVisible = await page
      .locator(HOME_STATS.workoutsCard)
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    if (statsVisible) {
      await page.click(HOME_STATS.workoutsCard);
    } else {
      await page.goto('/home/history');
    }

    // The history screen must be visible.
    await expect(page.locator(HISTORY.heading)).toBeVisible({ timeout: 15_000 });

    // Tap the most recent workout card to open its detail.
    const firstHistoryCard = page.locator('[aria-label*="Workout"]').first();
    await expect(firstHistoryCard).toBeVisible({ timeout: 10_000 });
    await firstHistoryCard.click();

    // The workout detail screen must display "22.5" as the logged weight.
    await expect(page.locator('text=22.5')).toBeVisible({ timeout: 10_000 });
  });

  // ---------------------------------------------------------------------------
  // EX-DETAIL-001 — Tapping exercise name during active workout opens bottom sheet
  //
  // _ExerciseCard wraps the exercise name in a Semantics + InkWell. Tapping
  // calls _showExerciseDetail which opens a DraggableScrollableSheet via
  // showModalBottomSheet. The sheet contains the exercise name as headlineMedium.
  // ---------------------------------------------------------------------------
  test('EX-DETAIL-001: tapping exercise name during active workout opens the detail bottom sheet', async ({
    page,
  }) => {
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);

    // The exercise name is wrapped in a tappable Semantics area with
    // label "Exercise: <name>. Tap for details. Long press to swap."
    const exerciseTap = page.locator(
      `flt-semantics[aria-label*="Exercise: ${SEED_EXERCISES.benchPress}. Tap for details"]`,
    );
    await expect(exerciseTap).toBeVisible({ timeout: 10_000 });
    await exerciseTap.click();

    // The bottom sheet must appear. The exercise name is the first text rendered
    // inside the sheet at headlineMedium size.
    // We wait for a second instance of the exercise name (the card heading is
    // always visible; the sheet adds a second one).
    await expect(
      page.locator(`text=${SEED_EXERCISES.benchPress}`).nth(1),
    ).toBeVisible({ timeout: 10_000 });

    // Clean up — dismiss the sheet by pressing Escape, then discard the workout.
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);

    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  // ---------------------------------------------------------------------------
  // EX-DETAIL-002 — Bottom sheet shows exercise name and muscle group chip
  //
  // _ExerciseDetailSheet renders the exercise name as headlineMedium text and
  // muscle group as a _SheetChip with the muscle group's displayName.
  // Barbell Bench Press belongs to the "Chest" muscle group.
  // ---------------------------------------------------------------------------
  test('EX-DETAIL-002: exercise detail bottom sheet shows exercise name and muscle group', async ({
    page,
  }) => {
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);

    const exerciseTap = page.locator(
      `flt-semantics[aria-label*="Exercise: ${SEED_EXERCISES.benchPress}. Tap for details"]`,
    );
    await expect(exerciseTap).toBeVisible({ timeout: 10_000 });
    await exerciseTap.click();

    // The sheet must show the exercise name (second occurrence — first is the card).
    await expect(
      page.locator(`text=${SEED_EXERCISES.benchPress}`).nth(1),
    ).toBeVisible({ timeout: 10_000 });

    // The muscle group chip must appear. Barbell Bench Press → Chest.
    // _SheetChip renders the muscle group's displayName as a Text widget.
    await expect(page.locator('text=Chest')).toBeVisible({ timeout: 5_000 });

    // Dismiss.
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);

    // Discard workout.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  // ---------------------------------------------------------------------------
  // EX-DETAIL-003 — Dismissing the bottom sheet returns to the workout screen
  //
  // After closing the detail sheet the active workout screen must still be
  // visible (Finish Workout button present) and the elapsed timer must still
  // be running (timer text is visible in the AppBar).
  // ---------------------------------------------------------------------------
  test('EX-DETAIL-003: dismissing exercise detail sheet returns to workout with timer visible', async ({
    page,
  }) => {
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.squat);

    // Note the workout is now in progress — the elapsed timer is in the AppBar.
    // Open the detail sheet.
    const exerciseTap = page.locator(
      `flt-semantics[aria-label*="Exercise: ${SEED_EXERCISES.squat}. Tap for details"]`,
    );
    await expect(exerciseTap).toBeVisible({ timeout: 10_000 });
    await exerciseTap.click();

    // Sheet is open — exercise name appears a second time.
    await expect(
      page.locator(`text=${SEED_EXERCISES.squat}`).nth(1),
    ).toBeVisible({ timeout: 10_000 });

    // Dismiss the sheet by pressing Escape.
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);

    // The workout screen must still be active.
    await expect(page.locator(WORKOUT.finishButton)).toBeVisible({
      timeout: 10_000,
    });

    // The elapsed timer format is MM:SS or H:MM:SS. We match on a colon digit
    // pattern to verify it is still displayed in the AppBar.
    // The AppBar title area contains the workout name + timer as a Column.
    // The timer text is produced by _ElapsedTimer which renders e.g. "01:23".
    await expect(page.locator('text=/\\d+:\\d+/')).toBeVisible({
      timeout: 5_000,
    });

    // Discard.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  // ---------------------------------------------------------------------------
  // EX-DETAIL-004 — Workout state preserved after viewing exercise detail
  //
  // Verifies that sets logged before opening the detail sheet are still present
  // after it is dismissed. The sheet is read-only and must not affect state.
  // ---------------------------------------------------------------------------
  test('EX-DETAIL-004: workout set data is preserved after viewing exercise detail sheet', async ({
    page,
  }) => {
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);

    // Enter weight and reps, then mark the set done.
    await setWeight(page, '80');
    await setReps(page, '10');
    await completeSet(page, 0);

    // The set is now completed — verify the checkbox state before opening sheet.
    await expect(page.locator(WORKOUT.setCompleted).nth(0)).toBeVisible({
      timeout: 5_000,
    });

    // Open the exercise detail sheet.
    const exerciseTap = page.locator(
      `flt-semantics[aria-label*="Exercise: ${SEED_EXERCISES.benchPress}. Tap for details"]`,
    );
    await expect(exerciseTap).toBeVisible({ timeout: 10_000 });
    await exerciseTap.click();

    await expect(
      page.locator(`text=${SEED_EXERCISES.benchPress}`).nth(1),
    ).toBeVisible({ timeout: 10_000 });

    // Dismiss the sheet.
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);

    // The completed set checkbox must still be in the completed state.
    await expect(page.locator(WORKOUT.setCompleted).nth(0)).toBeVisible({
      timeout: 5_000,
    });

    // The weight value must still be visible.
    await expect(page.locator('text=80')).toBeVisible({ timeout: 5_000 });

    // Discard.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });
});
