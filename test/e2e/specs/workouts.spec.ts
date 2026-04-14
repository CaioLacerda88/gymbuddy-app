/**
 * Workouts — consolidated E2E tests.
 *
 * Sources:
 *   - smoke/workout.smoke.spec.ts          (smokeWorkout, 5 tests)       -> @smoke
 *   - smoke/workout-restore.smoke.spec.ts  (smokeWorkoutRestore, 2 tests) -> @smoke
 *   - full/workout-logging.spec.ts         (fullWorkout, 14 tests)       -> untagged
 *   - full/history.spec.ts                 (fullHistory, 1 test)         -> untagged
 */

import { test, expect } from '@playwright/test';
import { waitForAppReady } from '../helpers/app';
import { login } from '../helpers/auth';
import { NAV, WORKOUT, HOME, PR, HOME_STATS, HISTORY } from '../helpers/selectors';
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

// =============================================================================
// SMOKE — Workout core journey (smokeWorkout user)
// =============================================================================

test.describe('Workouts', { tag: '@smoke' }, () => {
  test.beforeEach(async ({ page }) => {
    await login(
      page,
      TEST_USERS.smokeWorkout.email,
      TEST_USERS.smokeWorkout.password,
    );
  });

  test('should save workout successfully on completion and show celebration or home (QA-001)', async ({
    page,
  }) => {
    // Start an empty workout.
    await startEmptyWorkout(page);

    // The active workout screen should be reachable.
    await expect(page.locator(WORKOUT.finishButton)).toBeVisible({
      timeout: 15_000,
    });

    // Add Barbell Bench Press.
    await addExercise(page, SEED_EXERCISES.benchPress);

    // Wait for the exercise card with its set row.
    await expect(page.locator(WORKOUT.addSetButton)).toBeVisible({
      timeout: 10_000,
    });

    // Set weight and reps on the first set.
    await setWeight(page, '60');
    await setReps(page, '8');

    // Mark the set as done.
    await completeSet(page, 0);

    // Finish the workout — this triggers the save_workout RPC.
    await finishWorkout(page);

    // After finishing, either the PR celebration or the home screen must
    // appear. Both indicate a successful save. Neither should be a 404 error.
    const isCelebration = await page
      .locator('text=First Workout Complete!')
      .isVisible({ timeout: 15_000 })
      .catch(() => false);

    const isNewPR = await page
      .locator('text=NEW PR')
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    if (isCelebration || isNewPR) {
      // Dismiss the celebration screen.
      await page.click('text=Continue');
    }

    // We must end up on the Home screen — proves navigation completed.
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 20_000 });
  });

  test('should show home screen with start workout option after login', async ({
    page,
  }) => {
    // After login the home screen should be visible with the navigation bar
    // and a way to start a workout.
    await expect(page.locator(NAV.homeTab)).toBeVisible();
    await expect(page.locator(WORKOUT.startEmpty)).toBeVisible({
      timeout: 10_000,
    });
  });

  test('should complete full workout journey: start, add exercise, set weight/reps, complete set, finish', async ({
    page,
  }) => {
    // 1. Start an empty workout from the home screen.
    await startEmptyWorkout(page);

    // Active workout screen is visible — the finish button is in the bottom bar.
    await expect(page.locator(WORKOUT.finishButton)).toBeVisible();

    // 2. Add Barbell Bench Press from the exercise picker.
    await addExercise(page, SEED_EXERCISES.benchPress);

    // After adding, an exercise card with at least one set row should appear.
    // The add-set button confirms the exercise card is rendered.
    await expect(page.locator(WORKOUT.addSetButton)).toBeVisible({
      timeout: 10_000,
    });

    // 3. The first set row is pre-populated with "0" for weight and reps.
    //    Use the setWeight / setReps helpers which tap the value text,
    //    interact with the AlertDialog, and dismiss it.
    await setWeight(page, '60');
    await setReps(page, '8');

    // 4. Mark the set as done.
    await completeSet(page, 0);

    // 5. Finish the workout.
    await finishWorkout(page);

    // After finishing, the app navigates to the PR celebration screen (first
    // workout) or back to Home. Either way we wait for the celebration or
    // Home tab to become visible.
    const isPRScreen = await page
      .locator('text=First Workout Complete!')
      .isVisible({ timeout: 15_000 })
      .catch(() => false);

    if (isPRScreen) {
      await page.click('text=Continue');
    }

    // We should now be on the Home screen.
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  test('should update stat card on home screen after finishing workout', async ({
    page,
  }) => {
    // Complete a minimal workout — the Finish button is disabled until at
    // least one set is marked as done.
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);
    await setWeight(page, '50');
    await setReps(page, '5');
    await completeSet(page, 0);
    await finishWorkout(page);

    // Dismiss PR / celebration screen if shown (first workout or NEW PR).
    const isCelebration = await page
      .locator('text=First Workout Complete!')
      .isVisible({ timeout: 10_000 })
      .catch(() => false);

    const isNewPR = await page
      .locator('text=NEW PR')
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    if (isCelebration || isNewPR) {
      await page.click('text=Continue');
    }

    // Back on Home — the contextual stat cells should be visible.
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });

    // The home screen was redesigned in Step 12.2b: lifetime stat cards
    // ("Workouts", "Records") were removed in favour of contextual stat cells
    // ("Last session" + "Week's volume"). Assert the new contextual stat cell
    // labels are present — this confirms the home screen rendered after save.
    await expect(page.locator('text=Last session')).toBeVisible({
      timeout: 15_000,
    });
  });

  test('should return to home without saving when discarding a workout', async ({
    page,
  }) => {
    await startEmptyWorkout(page);

    // Click the Discard button (available in the AppBar or overflow menu).
    const discardButton = page.locator(WORKOUT.discardButton);
    const isDirectlyVisible = await discardButton
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    if (!isDirectlyVisible) {
      // Try the overflow / back action to expose discard.
      const overflowMenu = page.locator('role=button[name="More options"]');
      if (
        await overflowMenu.isVisible({ timeout: 3_000 }).catch(() => false)
      ) {
        await overflowMenu.click();
      }
    }

    await page.locator(WORKOUT.discardButton).click();

    // A confirmation dialog appears — confirm discard.
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();

    // Should navigate back to Home.
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });
});

// =============================================================================
// SMOKE — Workout restore (smokeWorkoutRestore user, BUG-001)
// =============================================================================

test.describe('Workout restore', { tag: '@smoke' }, () => {
  test.beforeEach(async ({ page }) => {
    await login(
      page,
      TEST_USERS.smokeWorkoutRestore.email,
      TEST_USERS.smokeWorkoutRestore.password,
    );
  });

  test('should preserve manually-added exercise name after page reload (BUG-001)', async ({
    page,
  }) => {
    // Start a manual (empty) workout and add Barbell Bench Press.
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);

    // Confirm the exercise card is visible before reload via its accessible name.
    // Flutter CanvasKit draws text to canvas so text= selectors fail for zero-dimension
    // flt-semantics elements. The _ExerciseCard Semantics label (via AOM) is reliable.
    await expect(
      page.locator(`role=group[name*="Exercise: ${SEED_EXERCISES.benchPress}. Tap for details"]`),
    ).toBeVisible({ timeout: 10_000 });

    // Simulate app restore by reloading (preserves IndexedDB/Hive state).
    await page.reload();

    // After a reload, Flutter must re-initialise its semantics tree.
    // waitForAppReady() enables accessibility and waits for auth to resolve.
    // document.body.innerText is empty in CanvasKit (text drawn to canvas),
    // so a plain waitForFunction on innerText would never fire.
    await waitForAppReady(page);

    // If the active workout screen was not re-entered automatically, navigate
    // back via the active workout banner or resume link.
    const finishVisible = await page
      .locator(WORKOUT.finishButton)
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    if (!finishVisible) {
      const activeBannerVisible = await page
        .locator(HOME.activeBanner)
        .isVisible({ timeout: 10_000 })
        .catch(() => false);

      if (activeBannerVisible) {
        await page.locator(HOME.activeBanner).click();
      } else {
        const resumeVisible = await page
          .locator('text=Resume')
          .isVisible({ timeout: 5_000 })
          .catch(() => false);
        if (resumeVisible) {
          await page.locator('text=Resume').click();
        }
      }

      await expect(page.locator(WORKOUT.finishButton)).toBeVisible({
        timeout: 15_000,
      });
    }

    // KEY ASSERTION FOR BUG-001:
    // The fallback name "Exercise: Exercise. Tap for details." must NOT
    // be present. That pattern only appears when exercise was null on restore.
    const fallbackLabel = page.locator(
      'role=group[name*="Exercise: Exercise. Tap for details"]',
    );
    await expect(fallbackLabel).not.toBeVisible({ timeout: 3_000 });

    // The real exercise name must be visible as the card heading via its
    // Semantics accessible name. text= selectors fail for CanvasKit zero-dimension
    // flt-semantics elements — the role=button[name=...] selector is reliable.
    await expect(
      page.locator(`role=group[name*="Exercise: ${SEED_EXERCISES.benchPress}. Tap for details"]`),
    ).toBeVisible({ timeout: 10_000 });

    // Clean up by discarding.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  test('should show correct names for multiple manually-added exercises after reload (BUG-001)', async ({
    page,
  }) => {
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);
    await addExercise(page, SEED_EXERCISES.squat);

    // Both exercise cards must be visible before reload via their Semantics accessible names.
    await expect(
      page.locator(`role=group[name*="Exercise: ${SEED_EXERCISES.benchPress}. Tap for details"]`),
    ).toBeVisible({ timeout: 10_000 });
    await expect(
      page.locator(`role=group[name*="Exercise: ${SEED_EXERCISES.squat}. Tap for details"]`),
    ).toBeVisible({ timeout: 10_000 });

    // Reload to simulate restore.
    await page.reload();

    // waitForAppReady re-enables semantics after reload and waits for auth.
    await waitForAppReady(page);

    const finishVisible = await page
      .locator(WORKOUT.finishButton)
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    if (!finishVisible) {
      const activeBannerVisible = await page
        .locator(HOME.activeBanner)
        .isVisible({ timeout: 10_000 })
        .catch(() => false);

      if (activeBannerVisible) {
        await page.locator(HOME.activeBanner).click();
      } else {
        const resumeVisible = await page
          .locator('text=Resume')
          .isVisible({ timeout: 5_000 })
          .catch(() => false);
        if (resumeVisible) {
          await page.locator('text=Resume').click();
        }
      }

      await expect(page.locator(WORKOUT.finishButton)).toBeVisible({
        timeout: 15_000,
      });
    }

    // Neither card should show the "Exercise" fallback accessible name.
    const fallbackLabel = page.locator(
      'role=group[name*="Exercise: Exercise. Tap for details"]',
    );
    await expect(fallbackLabel).not.toBeVisible({ timeout: 3_000 });

    // Both real names must still be visible via their Semantics accessible names.
    await expect(
      page.locator(`role=group[name*="Exercise: ${SEED_EXERCISES.benchPress}. Tap for details"]`),
    ).toBeVisible({ timeout: 10_000 });
    await expect(
      page.locator(`role=group[name*="Exercise: ${SEED_EXERCISES.squat}. Tap for details"]`),
    ).toBeVisible({ timeout: 10_000 });

    // Clean up.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });
});

// =============================================================================
// FULL — Workout logging (fullWorkout user)
// =============================================================================

test.describe('Workout logging', () => {
  test.beforeEach(async ({ page }) => {
    await login(
      page,
      TEST_USERS.fullWorkout.email,
      TEST_USERS.fullWorkout.password,
    );
  });

  test('should show Finish Workout and Add Exercise buttons after starting empty workout', async ({
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

  test('should show both exercise cards when adding multiple exercises', async ({
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
    // Flutter CanvasKit renders exercise names to canvas — no DOM text node.
    // The name only appears in the exercise card group's accessible name.
    await expect(
      page.locator(`role=group[name*="Exercise: ${SEED_EXERCISES.benchPress}"]`),
    ).toBeVisible({ timeout: 10_000 });
    await expect(
      page.locator(`role=group[name*="Exercise: ${SEED_EXERCISES.squat}"]`),
    ).toBeVisible({ timeout: 10_000 });

    // Discard to clean up.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();
  });

  test('should set weight and reps via dialog entry', async ({ page }) => {
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

  test('should add multiple sets to an exercise', async ({ page }) => {
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

  test('should complete individual sets via checkbox toggle', async ({ page }) => {
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

  test('should show incomplete sets warning dialog when finishing with incomplete sets', async ({
    page,
  }) => {
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);

    // Add a second set so we have 2 sets total.
    await page.click(WORKOUT.addSetButton);

    // Complete set 0 to enable the Finish button (onPressed requires _hasCompletedSet).
    await completeSet(page, 0);

    // Leave set 1 incomplete — tap Finish Workout.
    await page.click(WORKOUT.finishButton);

    // The dialog should warn about incomplete sets.
    // The warning text follows the pattern "You have N incomplete set(s)".
    // Flutter's showDialog + AlertDialog renders as role="alertdialog" via AOM.
    // Playwright's role= selector uses exact role matching — role=dialog does NOT
    // match alertdialog. Use role=alertdialog directly, with a fallback to check
    // for the dialog content text.
    const dialog = page.locator('role=alertdialog').or(page.locator('role=dialog'));
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

  test('should navigate away from workout screen after finishing with completed sets', async ({
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
    // Check both simultaneously to avoid sequential timeouts on CI.
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
  });

  test('should show confirmation dialog and return to home when discarding workout', async ({
    page,
  }) => {
    await startEmptyWorkout(page);

    // The Discard button may be directly visible or inside an overflow menu.
    const discardBtn = page.locator(WORKOUT.discardButton);
    const isVisible = await discardBtn
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    if (!isVisible) {
      const overflow = page.locator('role=button[name="More options"]');
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

  test('should auto-generate workout name with an em-dash date separator', async ({
    page,
  }) => {
    await startEmptyWorkout(page);

    // The AppBar title uses an em-dash (U+2014) separator: "Workout — Day Mon DD"
    const appBarTitle = page.locator('role=heading[name*="Workout \u2014"]');
    await expect(appBarTitle).toBeVisible({ timeout: 10_000 });

    // Discard to clean up.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();
  });

  test('should survive decimal weight 22.5 through full save and display round-trip (WK-023)', async ({
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

    // Navigate to history via the Last session stat cell (SPA navigation).
    // page.goto('/home/history') reloads the Flutter SPA and the router
    // doesn't preserve the deep link.
    await expect(page.locator(HOME_STATS.lastSessionCell)).toBeVisible({
      timeout: 10_000,
    });
    await page.click(HOME_STATS.lastSessionCell);

    // The history screen must be visible.
    await expect(page.locator(HISTORY.heading)).toBeVisible({ timeout: 15_000 });

    // Tap the most recent workout card to open its detail.
    const firstHistoryCard = page.locator('role=button[name*="Workout"]').first();
    await expect(firstHistoryCard).toBeVisible({ timeout: 10_000 });
    await firstHistoryCard.click();

    // The workout detail screen must display "22.5" as the logged weight.
    await expect(page.locator('text=22.5')).toBeVisible({ timeout: 10_000 });
  });

  test('should open detail bottom sheet when tapping exercise name during active workout (EX-DETAIL-001)', async ({
    page,
  }) => {
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);

    // The exercise name is wrapped in a tappable Semantics area with
    // label "Exercise: <name>. Tap for details. Long press to swap."
    const exerciseTap = page.locator(
      `role=group[name*="Exercise: ${SEED_EXERCISES.benchPress}. Tap for details"]`,
    );
    await expect(exerciseTap).toBeVisible({ timeout: 10_000 });
    await exerciseTap.click();

    // The bottom sheet must appear. The "ABOUT" section header only appears
    // in the detail sheet, confirming it's open. Using .nth(1) on the exercise
    // name fails because CanvasKit renders the card's name inside the group's
    // accessible name, not as a standalone text node.
    await expect(page.locator('text=ABOUT')).toBeVisible({ timeout: 10_000 });

    // Clean up — dismiss the sheet by pressing Escape, then discard the workout.
    await page.keyboard.press('Escape');
    await expect(page.locator(WORKOUT.finishButton)).toBeVisible({ timeout: 5_000 });

    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  test('should show exercise name and muscle group in detail bottom sheet (EX-DETAIL-002)', async ({
    page,
  }) => {
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);

    const exerciseTap = page.locator(
      `role=group[name*="Exercise: ${SEED_EXERCISES.benchPress}. Tap for details"]`,
    );
    await expect(exerciseTap).toBeVisible({ timeout: 10_000 });
    await exerciseTap.click();

    // The sheet must show the "ABOUT" section — confirms the sheet is open.
    await expect(page.locator('text=ABOUT')).toBeVisible({ timeout: 10_000 });

    // The muscle group chip must appear. Barbell Bench Press -> Chest.
    // Use .first() — CanvasKit renders "Chest" in the ABOUT text too.
    await expect(page.locator('text=Chest').first()).toBeVisible({ timeout: 5_000 });

    // Dismiss.
    await page.keyboard.press('Escape');
    await expect(page.locator(WORKOUT.finishButton)).toBeVisible({ timeout: 5_000 });

    // Discard workout.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  test('should return to workout with timer visible after dismissing exercise detail sheet (EX-DETAIL-003)', async ({
    page,
  }) => {
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.squat);

    // Note the workout is now in progress — the elapsed timer is in the AppBar.
    // Open the detail sheet.
    const exerciseTap = page.locator(
      `role=group[name*="Exercise: ${SEED_EXERCISES.squat}. Tap for details"]`,
    );
    await expect(exerciseTap).toBeVisible({ timeout: 10_000 });
    await exerciseTap.click();

    // Sheet is open — verify via the exercise name text in the sheet heading.
    // Squat doesn't have ABOUT/FORM TIPS sections, so check the name directly.
    // The card renders the name inside the group's accessible label (not standalone),
    // so `text=Barbell Squat` only matches the sheet heading.
    await expect(
      page.locator(`text=${SEED_EXERCISES.squat}`),
    ).toBeVisible({ timeout: 10_000 });

    // Dismiss the sheet by pressing Escape.
    await page.keyboard.press('Escape');

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

  test('should preserve workout set data after viewing exercise detail sheet (EX-DETAIL-004)', async ({
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
      `role=group[name*="Exercise: ${SEED_EXERCISES.benchPress}. Tap for details"]`,
    );
    await expect(exerciseTap).toBeVisible({ timeout: 10_000 });
    await exerciseTap.click();

    // Sheet is open — the "ABOUT" section confirms it.
    await expect(page.locator('text=ABOUT')).toBeVisible({ timeout: 10_000 });

    // Dismiss the sheet.
    await page.keyboard.press('Escape');
    await expect(page.locator(WORKOUT.finishButton)).toBeVisible({ timeout: 5_000 });

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

// =============================================================================
// FULL — Workout history (fullHistory user)
// =============================================================================

test.describe('Workout history', () => {
  test.beforeEach(async ({ page }) => {
    await login(
      page,
      TEST_USERS.fullHistory.email,
      TEST_USERS.fullHistory.password,
    );
  });

  test('should show empty state for a user with no completed workouts (HIST-005)', async ({
    page,
  }) => {
    // Navigate to the history screen. Since P8 hides the Last session stat
    // cell when lastSession == null && weekVolume == 0 (the new-user empty
    // state), we cannot tap that cell here. Navigate via SPA hash routing
    // instead — page.goto() would reload the Flutter SPA and lose state.
    await page.evaluate(() => {
      window.location.hash = '#/home/history';
    });

    // The history screen AppBar title confirms we are on the right screen.
    await expect(page.locator(HISTORY.heading)).toBeVisible({ timeout: 15_000 });

    // The empty state text must be visible.
    await expect(page.locator(HISTORY.emptyState)).toBeVisible({
      timeout: 10_000,
    });

    // The call-to-action button must accompany the empty state.
    await expect(page.locator(HISTORY.emptyStateCta)).toBeVisible({
      timeout: 5_000,
    });

    // The "Retry" error button must NOT be visible — this is an empty state,
    // not an error state.
    await expect(page.locator(HISTORY.retryButton)).not.toBeVisible();
  });
});
