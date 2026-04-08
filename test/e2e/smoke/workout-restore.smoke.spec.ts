/**
 * Workout restore smoke tests — BUG-001 regression for manually-started workouts.
 *
 * BUG-001 (P0): Exercise names show as "Exercise" after app restore.
 *
 * The smoke/routine-start.smoke.spec.ts covers the restore path when a workout
 * was started from a routine. This file covers the OTHER code path: a workout
 * started manually via "Start Empty Workout" + "Add Exercise".
 *
 * Both paths serialize WorkoutExercise to Hive, and both paths hit the same
 * @JsonKey(includeToJson: false) bug. A fix must pass both test files.
 *
 * Strategy: start an empty workout, add an exercise manually, reload the page
 * (preserves IndexedDB/Hive), resume the workout, and assert the exercise name
 * is the real name — NOT the "Exercise" fallback.
 *
 * Uses the dedicated `smokeWorkoutRestore` test user to avoid shared state with
 * other smoke specs.
 */

import { test, expect } from '@playwright/test';
import { login } from '../helpers/auth';
import { waitForAppReady } from '../helpers/app';
import { NAV, WORKOUT } from '../helpers/selectors';
import { startEmptyWorkout, addExercise } from '../helpers/workout';
import { TEST_USERS } from '../fixtures/test-users';
import { SEED_EXERCISES } from '../fixtures/test-exercises';

const USER = TEST_USERS.smokeWorkoutRestore;

test.describe('Workout restore smoke — manual workout (BUG-001)', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, USER.email, USER.password);
  });

  // ---------------------------------------------------------------------------
  // BUG-001 (P0): Exercise name is preserved after page reload for a manually
  // started workout.
  //
  // Before the fix: WorkoutExercise.exercise was @JsonKey(includeToJson: false),
  // so the exercise object was never written to Hive. On restore, exercise was
  // null and the UI fell back to rendering "Exercise" as the card header.
  //
  // After the fix: the exercise object is included in the serialised JSON, so
  // restore reads it back correctly and the card shows the real name.
  //
  // This is the SMOKE (P0) counterpart to the crash-recovery full spec, which
  // tests persistence but does not explicitly assert the BUG-001 name fallback.
  // ---------------------------------------------------------------------------
  test('BUG-001: manually-added exercise name is preserved after page reload', async ({
    page,
  }) => {
    // Start a manual (empty) workout and add Barbell Bench Press.
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);

    // Confirm the exercise card is visible before reload via its Semantics aria-label.
    // Flutter CanvasKit draws text to canvas so text= selectors fail for zero-dimension
    // flt-semantics elements. The _ExerciseCard Semantics label is unique and reliable.
    await expect(
      page.locator(`flt-semantics[aria-label*="Exercise: ${SEED_EXERCISES.benchPress}. Tap for details"]`),
    ).toBeVisible({ timeout: 10_000 });

    // Simulate app restore by reloading (preserves IndexedDB/Hive state).
    await page.reload();

    // After a reload, Flutter must re-initialise its semantics tree.
    // waitForAppReady() enables accessibility and waits for auth to resolve.
    // document.body.innerText is empty in CanvasKit (text drawn to canvas),
    // so a plain waitForFunction on innerText would never fire.
    await waitForAppReady(page);

    // If the active workout screen was not re-entered automatically, navigate
    // back via the resume banner.
    const finishVisible = await page
      .locator(WORKOUT.finishButton)
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    if (!finishVisible) {
      const resumeVisible = await page
        .locator('text=Resume')
        .isVisible({ timeout: 10_000 })
        .catch(() => false);

      if (resumeVisible) {
        await page.locator('text=Resume').click();
      } else {
        // Fall back to tapping the active workout banner if present.
        const bannerVisible = await page
          .locator('flt-semantics[aria-label*="Workout"]')
          .isVisible({ timeout: 5_000 })
          .catch(() => false);
        if (bannerVisible) {
          await page.locator('flt-semantics[aria-label*="Workout"]').first().click();
        }
      }

      await expect(page.locator(WORKOUT.finishButton)).toBeVisible({
        timeout: 15_000,
      });
    }

    // KEY ASSERTION FOR BUG-001:
    // The fallback aria-label "Exercise: Exercise. Tap for details." must NOT
    // be present. That pattern only appears when exercise was null on restore.
    const fallbackLabel = page.locator(
      'flt-semantics[aria-label*="Exercise: Exercise. Tap for details"]',
    );
    await expect(fallbackLabel).not.toBeVisible({ timeout: 3_000 });

    // The real exercise name must be visible as the card heading via its
    // Semantics aria-label. text= selectors fail for CanvasKit zero-dimension
    // flt-semantics elements — the aria-label selector is reliable.
    await expect(
      page.locator(`flt-semantics[aria-label*="Exercise: ${SEED_EXERCISES.benchPress}. Tap for details"]`),
    ).toBeVisible({ timeout: 10_000 });

    // Clean up by discarding.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  // ---------------------------------------------------------------------------
  // BUG-001 (P0): Multiple manually-added exercises all preserve their names.
  //
  // The bug affects every WorkoutExercise in the serialised list, not just the
  // first one. This test adds two different exercises and asserts that BOTH
  // show their real names after a reload.
  // ---------------------------------------------------------------------------
  test('BUG-001: multiple manually-added exercises all show correct names after reload', async ({
    page,
  }) => {
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);
    await addExercise(page, SEED_EXERCISES.squat);

    // Both exercise cards must be visible before reload via their Semantics aria-labels.
    await expect(
      page.locator(`flt-semantics[aria-label*="Exercise: ${SEED_EXERCISES.benchPress}. Tap for details"]`),
    ).toBeVisible({ timeout: 10_000 });
    await expect(
      page.locator(`flt-semantics[aria-label*="Exercise: ${SEED_EXERCISES.squat}. Tap for details"]`),
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
      const resumeVisible = await page
        .locator('text=Resume')
        .isVisible({ timeout: 10_000 })
        .catch(() => false);

      if (resumeVisible) {
        await page.locator('text=Resume').click();
      } else {
        const bannerVisible = await page
          .locator('flt-semantics[aria-label*="Workout"]')
          .isVisible({ timeout: 5_000 })
          .catch(() => false);
        if (bannerVisible) {
          await page.locator('flt-semantics[aria-label*="Workout"]').first().click();
        }
      }

      await expect(page.locator(WORKOUT.finishButton)).toBeVisible({
        timeout: 15_000,
      });
    }

    // Neither card should show the "Exercise" fallback aria-label.
    const fallbackLabel = page.locator(
      'flt-semantics[aria-label*="Exercise: Exercise. Tap for details"]',
    );
    await expect(fallbackLabel).not.toBeVisible({ timeout: 3_000 });

    // Both real names must still be visible via their Semantics aria-labels.
    await expect(
      page.locator(`flt-semantics[aria-label*="Exercise: ${SEED_EXERCISES.benchPress}. Tap for details"]`),
    ).toBeVisible({ timeout: 10_000 });
    await expect(
      page.locator(`flt-semantics[aria-label*="Exercise: ${SEED_EXERCISES.squat}. Tap for details"]`),
    ).toBeVisible({ timeout: 10_000 });

    // Clean up.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
    await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
    await confirmDiscard.click();
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });
});
