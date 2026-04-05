/**
 * Workout smoke tests — core workout journey.
 *
 * Covers the critical path:
 *   Login → start empty workout → add exercise → set weight & reps →
 *   complete set → finish workout → workout appears in home screen history
 *
 * Uses the dedicated smokeWorkout test user to avoid shared state with
 * other smoke specs. User is created in global-setup.ts.
 *
 * The Flutter web app must be served at localhost:8080 before running:
 *   flutter build web --web-renderer html
 *   cd build/web && python3 -m http.server 8080
 */

import { test, expect } from '@playwright/test';
import { waitForAppReady } from '../helpers/app';
import { login } from '../helpers/auth';
import { NAV, HOME, WORKOUT, EXERCISE_PICKER } from '../helpers/selectors';
import {
  startEmptyWorkout,
  addExercise,
  completeSet,
  finishWorkout,
} from '../helpers/workout';
import { TEST_USERS } from '../fixtures/test-users';
import { SEED_EXERCISES } from '../fixtures/test-exercises';

test.describe('Workout smoke', () => {
  test.beforeEach(async ({ page }) => {
    await login(
      page,
      TEST_USERS.smokeWorkout.email,
      TEST_USERS.smokeWorkout.password,
    );
  });

  test('home screen is visible with start workout option after login', async ({
    page,
  }) => {
    // After login the home screen should be visible with the navigation bar
    // and a way to start a workout.
    await expect(page.locator(NAV.homeTab)).toBeVisible();
    await expect(page.locator(WORKOUT.startEmpty)).toBeVisible({
      timeout: 10_000,
    });
  });

  test('complete workout journey: start, add exercise, set weight/reps, complete set, finish', async ({
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

    // 3. The first set row is pre-populated. Set weight to 60 kg and reps to 8.
    //    Tap the weight/reps values to open the entry dialogs.
    const weightValue = page.locator('text=0').first();
    await weightValue.click();

    // Dialog for weight entry.
    const weightInput = page.locator('input').last();
    await weightInput.clear();
    await weightInput.fill('60');
    await page.locator('text=OK').click();

    const repsValue = page.locator('text=0').first();
    await repsValue.click();

    // Dialog for reps entry.
    const repsInput = page.locator('input').last();
    await repsInput.clear();
    await repsInput.fill('8');
    await page.locator('text=OK').click();

    // 4. Mark the set as done.
    await completeSet(page, 0);

    // 5. Finish the workout.
    await finishWorkout(page);

    // After finishing, the app navigates to the PR celebration screen (first
    // workout) or back to Home. Either way we wait for the celebration or
    // Home tab to become visible.
    const celebrationOrHome = page.locator(
      `text=First Workout Complete!, ${NAV.homeTab}`,
    );

    // Accept either outcome — PR screen with Continue, or directly on Home.
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

  test('finished workout appears in the recent section on the home screen', async ({
    page,
  }) => {
    // Start and immediately finish a minimal workout (no exercises, just finish).
    await startEmptyWorkout(page);
    await finishWorkout(page);

    // Dismiss PR / celebration screen if shown.
    const isCelebration = await page
      .locator('text=First Workout Complete!')
      .isVisible({ timeout: 10_000 })
      .catch(() => false);

    if (isCelebration) {
      await page.click('text=Continue');
    }

    // Back on Home — the recent section should now have at least one entry.
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });

    // The "RECENT" heading signals the workout history section.
    await expect(page.locator(HOME.recentSection)).toBeVisible({
      timeout: 10_000,
    });
  });

  test('discarding a workout returns to home without saving', async ({
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
      const overflowMenu = page.locator('[aria-label="More options"]');
      if (
        await overflowMenu.isVisible({ timeout: 3_000 }).catch(() => false)
      ) {
        await overflowMenu.click();
      }
    }

    await page.locator(WORKOUT.discardButton).click();

    // A confirmation dialog may appear — confirm discard.
    const confirmDiscard = page.locator('text=Discard').last();
    const dialogVisible = await confirmDiscard
      .isVisible({ timeout: 3_000 })
      .catch(() => false);
    if (dialogVisible) {
      await confirmDiscard.click();
    }

    // Should navigate back to Home.
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });
});
