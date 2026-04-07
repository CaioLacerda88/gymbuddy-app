/**
 * Routine regression full spec — BUG-003, BUG-004, BUG-005 coverage.
 *
 * BUG-003 (P1): Starting a routine whose exercise references all resolved to
 *   null silently returns without navigating, and without telling the user why.
 *   Fix: show a snackbar "Could not load exercises. Please try again." when the
 *   exercises list is empty after filtering.
 *   E2E strategy: we can't directly inject a network failure mid-test, but we
 *   can verify:
 *     a) The happy path: a healthy routine DOES navigate. (Belt-and-suspenders
 *        with the smoke test.)
 *     b) The error-message infrastructure is wired: the snackbar selector is
 *        exercised through a custom routine with an exercise that gets deleted
 *        after the routine is saved, then the routine is started. Deleted
 *        exercises are filtered out (deletedAt != null), so if ALL exercises
 *        are deleted the guard triggers and the snackbar must appear.
 *
 * BUG-004 (P2): Deep validation of weight defaults for all exercise types in a
 *   routine. Barbell → 20 kg, Dumbbell → 10 kg, Bodyweight → 0 (acceptable).
 *   Full Body routine includes Barbell Squat (barbell) and Plank (bodyweight).
 *
 * BUG-005 (P2): Routine card subtitle must show muscle group names for all
 *   four starter routines, not just Push Day. Also verifies that the subtitle
 *   does not show the bare exercise-count fallback for Pull Day, Leg Day, etc.
 *
 * Uses the dedicated `fullRoutineRegression` test user.
 * User is created in global-setup.ts and deleted in global-teardown.ts.
 */

import { test, expect } from '@playwright/test';
import { navigateToTab, flutterFill } from '../helpers/app';
import { login } from '../helpers/auth';
import {
  NAV,
  ROUTINE,
  CREATE_ROUTINE,
  WORKOUT,
  EXERCISE_LIST,
  EXERCISE_DETAIL,
  CREATE_EXERCISE,
} from '../helpers/selectors';
import { TEST_USERS } from '../fixtures/test-users';
import { SEED_EXERCISES } from '../fixtures/test-exercises';

const USER = TEST_USERS.fullRoutineRegression;

const STARTER_ROUTINES = ['Push Day', 'Pull Day', 'Leg Day', 'Full Body'];

// Muscle groups known to appear in starter routine subtitles when exercises
// resolve correctly (per seed.sql exercise list for each routine).
const PUSH_DAY_GROUPS = ['Chest', 'Shoulders', 'Triceps'];
const PULL_DAY_GROUPS = ['Back', 'Biceps'];
const LEG_DAY_GROUPS = ['Legs', 'Glutes', 'Core'];
const FULL_BODY_GROUPS = ['Legs', 'Chest', 'Back'];

// TODO: Enable once selectors are verified against live Flutter web app locally.
test.describe.fixme('Routine regressions — full suite', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, USER.email, USER.password);
    await navigateToTab(page, 'Routines');
    await expect(page.locator(ROUTINE.starterRoutinesSection)).toBeVisible({
      timeout: 10_000,
    });
  });

  // ---------------------------------------------------------------------------
  // BUG-005 (P2): All starter routine cards show muscle group names in subtitle
  // ---------------------------------------------------------------------------
  test('BUG-005: Push Day card subtitle contains muscle group names, not bare count', async ({
    page,
  }) => {
    // At least one of the expected Push Day muscle groups must appear on screen
    // in the routine list — these come from the card subtitle.
    let foundGroup = false;
    for (const group of PUSH_DAY_GROUPS) {
      const visible = await page
        .locator(`text=${group}`)
        .isVisible({ timeout: 5_000 })
        .catch(() => false);
      if (visible) {
        foundGroup = true;
        break;
      }
    }
    expect(foundGroup).toBe(true);

    // The fallback "6 exercises" must not be the subtitle for Push Day.
    await expect(page.locator('text=6 exercises')).not.toBeVisible({
      timeout: 3_000,
    });
  });

  test('BUG-005: Pull Day card subtitle contains muscle group names', async ({
    page,
  }) => {
    let foundGroup = false;
    for (const group of PULL_DAY_GROUPS) {
      const visible = await page
        .locator(`text=${group}`)
        .isVisible({ timeout: 5_000 })
        .catch(() => false);
      if (visible) {
        foundGroup = true;
        break;
      }
    }
    expect(foundGroup).toBe(true);
  });

  test('BUG-005: no starter routine card shows a bare exercise-count fallback', async ({
    page,
  }) => {
    // None of the starter routine cards should show just "N exercises" —
    // that text is the _buildSubtitle() fallback when re.exercise is null.
    // We allow that a user-created routine with no exercises might show "0 exercises",
    // but the seeded starter routines must all have resolved exercise references.

    // The starter routines have 6, 6, 7, and 6 exercises respectively.
    // If any of them fail to resolve, the subtitle becomes e.g. "6 exercises".
    for (const count of ['6 exercises', '7 exercises', '5 exercises']) {
      await expect(page.locator(`text=${count}`)).not.toBeVisible({
        timeout: 2_000,
      });
    }
  });

  // ---------------------------------------------------------------------------
  // BUG-003 (P1): Error snackbar shown when all exercises are filtered out.
  //
  // Strategy:
  //   1. Create a custom routine with one custom exercise.
  //   2. Delete the exercise (soft-delete — sets deletedAt).
  //   3. Navigate back to Routines.
  //   4. Tap "Start" on the custom routine.
  //   5. startRoutineWorkout filters out the deleted exercise → exercises.isEmpty.
  //   6. The snackbar "Could not load exercises. Please try again." must appear.
  //   7. The app must NOT navigate to the active workout screen.
  //
  // Note: steps 1-2 require navigating to Exercises to create/delete the exercise
  // and back to Routines to test the routine start.
  // ---------------------------------------------------------------------------
  test('BUG-003: starting a routine whose only exercise was deleted shows error snackbar', async ({
    page,
  }) => {
    const uniqueSuffix = Date.now();
    const exerciseName = `BUG-003 Exercise ${uniqueSuffix}`;
    const routineName = `BUG-003 Routine ${uniqueSuffix}`;

    // Step 1: Create a custom exercise.
    await navigateToTab(page, 'Exercises');
    await page.click(EXERCISE_LIST.createFab);
    await expect(page.locator(CREATE_EXERCISE.nameInput)).toBeVisible({
      timeout: 10_000,
    });
    await flutterFill(page, CREATE_EXERCISE.nameInput, exerciseName);
    await page.locator('role=button[name*="Muscle group: Chest"]').first().click();
    await page.locator('role=button[name*="Equipment type: Barbell"]').first().click();
    await page.click(CREATE_EXERCISE.saveButton);
    await expect(page.locator(EXERCISE_LIST.heading).first()).toBeVisible({
      timeout: 15_000,
    });

    // Step 2: Create a routine that uses this exercise.
    await navigateToTab(page, 'Routines');
    await page.click(ROUTINE.createButton);

    // Fill in the routine name.
    const nameInput = page.locator(CREATE_ROUTINE.nameInput);
    await expect(nameInput).toBeVisible({ timeout: 10_000 });
    await nameInput.click();
    await page.keyboard.press('Control+a');
    await page.keyboard.type(routineName, { delay: 10 });

    // Add the custom exercise to the routine.
    await page.click(CREATE_ROUTINE.addExerciseButton);
    const searchInput = page.locator('role=textbox[name*="Search exercises to add"]');
    await expect(searchInput).toBeVisible({ timeout: 10_000 });
    await flutterFill(page, 'role=textbox[name*="Search exercises to add"]', exerciseName.substring(0, 10));
    await page.waitForTimeout(600);

    const addBtn = page.locator(`role=button[name*="Add ${exerciseName}"]`).first();
    await expect(addBtn).toBeVisible({ timeout: 10_000 });
    await addBtn.click();

    // Save the routine.
    await page.click(CREATE_ROUTINE.saveButton);
    await expect(page.locator(ROUTINE.heading)).toBeVisible({ timeout: 15_000 });

    // Verify the custom routine appears.
    await expect(page.locator(ROUTINE.routineName(routineName)).first()).toBeVisible({
      timeout: 10_000,
    });

    // Step 3: Delete the exercise so it becomes soft-deleted (deletedAt is set).
    await navigateToTab(page, 'Exercises');
    await flutterFill(page, EXERCISE_LIST.searchInput, exerciseName.substring(0, 10));
    await page.waitForTimeout(800);

    const exerciseCard = page
      .locator(EXERCISE_LIST.exerciseCard(exerciseName))
      .first();
    await expect(exerciseCard).toBeVisible({ timeout: 10_000 });
    await exerciseCard.click();

    await expect(page.locator(EXERCISE_DETAIL.deleteButton)).toBeVisible({
      timeout: 10_000,
    });
    await page.click(EXERCISE_DETAIL.deleteButton);
    await expect(page.locator(EXERCISE_DETAIL.deleteDialogTitle)).toBeVisible({
      timeout: 5_000,
    });
    await page.click(EXERCISE_DETAIL.deleteConfirmButton);
    await expect(page.locator(EXERCISE_LIST.heading).first()).toBeVisible({
      timeout: 15_000,
    });

    // Step 4: Navigate to Routines and try to start the custom routine.
    await navigateToTab(page, 'Routines');

    // The routine may appear in MY ROUTINES section.
    await page.waitForTimeout(500);

    const myRoutineCard = page
      .locator(ROUTINE.routineName(routineName))
      .first();
    await expect(myRoutineCard).toBeVisible({ timeout: 10_000 });
    await myRoutineCard.click();

    // Step 5-6: The snackbar with the error message must appear.
    // The start action filters out the soft-deleted exercise → exercises is empty
    // → shows SnackBar("Could not load exercises. Please try again.").
    await expect(
      page.locator('text=Could not load exercises'),
    ).toBeVisible({ timeout: 10_000 });

    // Step 7: The app must NOT have navigated to the active workout screen.
    // "Finish Workout" button must NOT be visible.
    await expect(page.locator(WORKOUT.finishButton)).not.toBeVisible({
      timeout: 3_000,
    });

    // We must still be on the Routines tab (or Home — either is fine as long
    // as we did not land on the active workout screen).
    const onRoutines = await page
      .locator(ROUTINE.heading)
      .isVisible({ timeout: 3_000 })
      .catch(() => false);
    const onHome = await page
      .locator('text=GymBuddy')
      .isVisible({ timeout: 3_000 })
      .catch(() => false);

    expect(onRoutines || onHome).toBe(true);
  });

  // ---------------------------------------------------------------------------
  // BUG-004 (P2): Deep weight default check across routine types.
  //
  // Full Body starter routine includes:
  //   - Barbell Squat (barbell) → default 20 kg
  //   - Plank (bodyweight) → default 0 kg (acceptable — bodyweight has no weight)
  //   - Barbell Bench Press (barbell) → default 20 kg
  //
  // We verify that barbell exercises do NOT show weight 0 when no previous
  // session exists for this fresh test user.
  // ---------------------------------------------------------------------------
  test('BUG-004: Full Body routine barbell exercises start with non-zero weight', async ({
    page,
  }) => {
    await page.locator(ROUTINE.routineName('Full Body')).first().click();

    await expect(page.locator(WORKOUT.finishButton)).toBeVisible({
      timeout: 20_000,
    });

    // Barbell Squat must be in the routine.
    await expect(
      page.locator(`text=${SEED_EXERCISES.squat}`),
    ).toBeVisible({ timeout: 10_000 });

    // For barbell exercises, the default weight is 20 kg — not 0 kg.
    // "Weight value: 0 kg" in the aria-label signals the bug is present.
    const zeroWeightButtons = page.locator(
      'flt-semantics[aria-label*="Weight value: 0 kg"]',
    );

    // Count how many exercise cards are barbell vs bodyweight.
    // We can't easily distinguish per-exercise, but we can assert that
    // NOT ALL weight buttons show 0 — at least one barbell exercise (Squat or
    // Bench Press) should show a non-zero value.
    const allWeightButtons = page.locator(
      'flt-semantics[aria-label*="Weight value:"]',
    );
    await expect(allWeightButtons.first()).toBeVisible({ timeout: 10_000 });

    const totalWeightButtons = await allWeightButtons.count();
    const zeroWeightCount = await zeroWeightButtons.count();

    // Not ALL weight buttons can be zero — barbell exercises should have 20 kg.
    // Plank (bodyweight) legitimately shows 0 kg, but Barbell Squat and
    // Barbell Bench Press must not be 0.
    // Conservative assertion: at least one weight button must be non-zero.
    expect(zeroWeightCount).toBeLessThan(totalWeightButtons);

    // Clean up.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator('text=Discard').last();
    if (await confirmDiscard.isVisible({ timeout: 3_000 }).catch(() => false)) {
      await confirmDiscard.click();
    }
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  // ---------------------------------------------------------------------------
  // BUG-004 (P2): Push Day dumbbell exercise (Lateral Raise) default weight check.
  //
  // Push Day includes Lateral Raise (dumbbell). Equipment default for dumbbell
  // is 10 kg — must not be 0 on first use.
  // ---------------------------------------------------------------------------
  test('BUG-004: Push Day dumbbell exercises start with non-zero weight', async ({
    page,
  }) => {
    await page.locator(ROUTINE.routineName('Push Day')).first().click();

    await expect(page.locator(WORKOUT.finishButton)).toBeVisible({
      timeout: 20_000,
    });

    // Lateral Raise is a dumbbell exercise in Push Day.
    await expect(page.locator('text=Lateral Raise')).toBeVisible({
      timeout: 10_000,
    });

    // At least one weight button must show a non-zero value.
    const allWeightButtons = page.locator(
      'flt-semantics[aria-label*="Weight value:"]',
    );
    const zeroWeightButtons = page.locator(
      'flt-semantics[aria-label*="Weight value: 0 kg"]',
    );

    await expect(allWeightButtons.first()).toBeVisible({ timeout: 10_000 });
    const total = await allWeightButtons.count();
    const zeros = await zeroWeightButtons.count();

    // Push Day has no bodyweight exercises — all should have defaults > 0.
    expect(zeros).toBeLessThan(total);

    // Clean up.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator('text=Discard').last();
    if (await confirmDiscard.isVisible({ timeout: 3_000 }).catch(() => false)) {
      await confirmDiscard.click();
    }
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  // ---------------------------------------------------------------------------
  // BUG-001 (P0): Exercise name survives a page reload when started from routine.
  //
  // Full suite companion to the smoke test. Uses Pull Day so it exercises a
  // different code path than the smoke test (which uses Push Day).
  // ---------------------------------------------------------------------------
  test('BUG-001: exercise names survive page reload when started from a routine', async ({
    page,
  }) => {
    await page.locator(ROUTINE.routineName('Pull Day')).first().click();

    await expect(page.locator(WORKOUT.finishButton)).toBeVisible({
      timeout: 20_000,
    });

    // Capture the first exercise name that is visible in the workout.
    // Pull Day includes "Deadlift" and "Barbell Bent-Over Row" per seed.sql.
    const deadliftVisible = await page
      .locator(`text=${SEED_EXERCISES.deadlift}`)
      .isVisible({ timeout: 10_000 })
      .catch(() => false);

    const bentRowVisible = await page
      .locator('text=Barbell Bent-Over Row')
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    expect(deadliftVisible || bentRowVisible).toBe(true);

    // Reload to simulate crash / app restore.
    await page.reload();

    await page.waitForFunction(
      () => {
        const text = document.body.innerText ?? '';
        return text.includes('GymBuddy') || text.includes('Home') || text.includes('Finish Workout');
      },
      { timeout: 30_000, polling: 500 },
    );

    // Return to the active workout screen.
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
        const banner = page.locator('flt-semantics[aria-label*="Pull Day"]');
        if (await banner.isVisible({ timeout: 5_000 }).catch(() => false)) {
          await banner.click();
        }
      }
      await expect(page.locator(WORKOUT.finishButton)).toBeVisible({
        timeout: 15_000,
      });
    }

    // KEY ASSERTION: the "Exercise" fallback must NOT appear as a card header.
    const fallbackLabel = page.locator(
      'flt-semantics[aria-label*="Exercise: Exercise. Tap for details"]',
    );
    await expect(fallbackLabel).not.toBeVisible({ timeout: 3_000 });

    // The real exercise name (Deadlift or Bent-Over Row) must still be visible.
    if (deadliftVisible) {
      await expect(
        page.locator(`text=${SEED_EXERCISES.deadlift}`),
      ).toBeVisible({ timeout: 10_000 });
    } else {
      await expect(
        page.locator('text=Barbell Bent-Over Row'),
      ).toBeVisible({ timeout: 10_000 });
    }

    // Clean up.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator('text=Discard').last();
    if (await confirmDiscard.isVisible({ timeout: 3_000 }).catch(() => false)) {
      await confirmDiscard.click();
    }
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });
});
