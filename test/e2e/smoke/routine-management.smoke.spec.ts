/**
 * Routine management smoke test — create / edit / delete.
 *
 * Covers the MY ROUTINES CRUD flow:
 *   - Create a new routine with a name and at least one exercise.
 *   - Verify it appears in the MY ROUTINES list.
 *   - Edit the routine name via the action sheet.
 *   - Verify the updated name is shown.
 *   - Delete the routine via the action sheet.
 *   - Verify it is gone.
 *
 * Uses the dedicated `smokeRoutineManagement` user for state isolation.
 * The Barbell Bench Press exercise is seeded by seed.sql.
 */

import { test, expect } from '@playwright/test';
import { login } from '../helpers/auth';
import { navigateToTab, flutterFill, flutterFillByInput, flutterLongPress } from '../helpers/app';
import { ROUTINE, CREATE_ROUTINE, EXERCISE_PICKER, ROUTINE_MANAGEMENT } from '../helpers/selectors';
import { TEST_USERS } from '../fixtures/test-users';

const USER = TEST_USERS.smokeRoutineManagement;

const ROUTINE_NAME = 'Smoke Test Routine';
const ROUTINE_NAME_EDITED = 'Smoke Test Routine Edited';
// A seeded exercise that always exists.
const EXERCISE_NAME = 'Barbell Bench Press';

test.describe('Smoke: Routine Management', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, USER.email, USER.password);
    await navigateToTab(page, 'Routines');
  });

  // ---------------------------------------------------------------------------
  // Test 1: Create a new routine.
  //
  // Taps the + icon in the AppBar → lands on CreateRoutineScreen.
  // Fills name, adds an exercise, taps Save. Verifies the routine appears
  // under MY ROUTINES.
  // ---------------------------------------------------------------------------
  test('creates a new routine and it appears in MY ROUTINES list', async ({
    page,
  }) => {
    // Tap the + AppBar action to open CreateRoutineScreen.
    await expect(page.locator(ROUTINE.heading).first()).toBeVisible({ timeout: 10_000 });
    await page.locator(ROUTINE_MANAGEMENT.createIconButton).click();

    // CreateRoutineScreen: title is "Create Routine".
    await expect(page.locator(ROUTINE_MANAGEMENT.createRoutineScreenTitle)).toBeVisible({
      timeout: 10_000,
    });

    // Fill routine name.
    await flutterFill(page, CREATE_ROUTINE.nameInput, ROUTINE_NAME);

    // Add an exercise — tap "Add Exercise" button.
    await page.locator(CREATE_ROUTINE.addExerciseButton).click();

    // ExercisePickerSheet appears. Search for the exercise.
    await expect(page.locator(EXERCISE_PICKER.searchInput)).toBeVisible({
      timeout: 10_000,
    });
    await flutterFillByInput(page, 'Search exercises', EXERCISE_NAME);

    // Tap the "Add Barbell Bench Press" tile (use .first() in case of duplicates).
    const addTile = page.locator(EXERCISE_PICKER.addExerciseButton(EXERCISE_NAME)).first();
    await expect(addTile).toBeVisible({ timeout: 10_000 });
    await addTile.click();

    // Back on CreateRoutineScreen — exercise card should now appear.
    await expect(page.locator(`text=${EXERCISE_NAME}`).first()).toBeVisible({
      timeout: 10_000,
    });

    // Save — the Save TextButton in the AppBar.
    await page.locator(CREATE_ROUTINE.saveButton).click();

    // After save, pop back to RoutineListScreen.
    await expect(page.locator(ROUTINE.myRoutinesSection)).toBeVisible({
      timeout: 15_000,
    });

    // The new routine must appear in MY ROUTINES.
    await expect(page.locator(ROUTINE.routineName(ROUTINE_NAME)).first()).toBeVisible({
      timeout: 10_000,
    });
  });

  // ---------------------------------------------------------------------------
  // Test 2: Edit a routine name.
  //
  // Long-press the routine card → action sheet → Edit → rename → Save.
  // Verifies the updated name appears and the old name is gone.
  // ---------------------------------------------------------------------------
  test('edits a routine name via the action sheet', async ({ page }) => {
    // Ensure the routine exists first (create if missing).
    await expect(page.locator(ROUTINE.myRoutinesSection)).toBeVisible({
      timeout: 10_000,
    });

    const routineCard = page.locator(ROUTINE.routineName(ROUTINE_NAME)).first();
    const exists = await routineCard.isVisible({ timeout: 5_000 }).catch(() => false);

    if (!exists) {
      // Create it.
      await page.locator(ROUTINE_MANAGEMENT.createIconButton).click();
      await expect(page.locator(ROUTINE_MANAGEMENT.createRoutineScreenTitle)).toBeVisible({
        timeout: 10_000,
      });
      await flutterFill(page, CREATE_ROUTINE.nameInput, ROUTINE_NAME);
      await page.locator(CREATE_ROUTINE.addExerciseButton).click();
      await expect(page.locator(EXERCISE_PICKER.searchInput)).toBeVisible({
        timeout: 10_000,
      });
      await flutterFillByInput(page, 'Search exercises', EXERCISE_NAME);
      await page.locator(EXERCISE_PICKER.addExerciseButton(EXERCISE_NAME)).first().click();
      await page.locator(CREATE_ROUTINE.saveButton).click();
      await expect(page.locator(ROUTINE.myRoutinesSection)).toBeVisible({
        timeout: 15_000,
      });
    }

    // Long-press the routine card to open the action sheet.
    await flutterLongPress(page, ROUTINE.routineName(ROUTINE_NAME));

    // Action sheet: tap Edit.
    await expect(page.locator(ROUTINE.editOption)).toBeVisible({ timeout: 10_000 });
    await page.locator(ROUTINE.editOption).click();

    // CreateRoutineScreen in edit mode — title is "Edit Routine".
    await expect(page.locator(ROUTINE_MANAGEMENT.editRoutineScreenTitle)).toBeVisible({
      timeout: 10_000,
    });

    // Clear existing name and type new name.
    await flutterFill(page, CREATE_ROUTINE.nameInput, ROUTINE_NAME_EDITED);

    // Save.
    await page.locator(CREATE_ROUTINE.saveButton).click();

    // Back on list — edited name must appear.
    await expect(page.locator(ROUTINE.routineName(ROUTINE_NAME_EDITED)).first()).toBeVisible({
      timeout: 15_000,
    });

    // Old name must be gone — use exact text match to avoid matching the
    // edited name "Smoke Test Routine Edited" which contains the old name.
    await expect(page.getByText(ROUTINE_NAME, { exact: true })).not.toBeVisible({
      timeout: 5_000,
    });
  });

  // ---------------------------------------------------------------------------
  // Test 3: Delete a routine.
  //
  // Long-press the (edited) routine card → action sheet → Delete → confirm.
  // Verifies the routine is gone from the list.
  // ---------------------------------------------------------------------------
  test('deletes a routine and it disappears from the list', async ({ page }) => {
    await expect(page.locator(ROUTINE.myRoutinesSection)).toBeVisible({
      timeout: 10_000,
    });

    // Find a deletable routine — either the edited or original name.
    const nameToDelete = await page
      .locator(ROUTINE.routineName(ROUTINE_NAME_EDITED))
      .first()
      .isVisible({ timeout: 3_000 })
      .catch(() => false)
      ? ROUTINE_NAME_EDITED
      : ROUTINE_NAME;

    const routineExists = await page
      .locator(ROUTINE.routineName(nameToDelete))
      .first()
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    if (!routineExists) {
      // Create it fresh so we have something to delete.
      await page.locator(ROUTINE_MANAGEMENT.createIconButton).click();
      await expect(page.locator(ROUTINE_MANAGEMENT.createRoutineScreenTitle)).toBeVisible({
        timeout: 10_000,
      });
      await flutterFill(page, CREATE_ROUTINE.nameInput, ROUTINE_NAME);
      await page.locator(CREATE_ROUTINE.addExerciseButton).click();
      await expect(page.locator(EXERCISE_PICKER.searchInput)).toBeVisible({
        timeout: 10_000,
      });
      await flutterFillByInput(page, 'Search exercises', EXERCISE_NAME);
      await page.locator(EXERCISE_PICKER.addExerciseButton(EXERCISE_NAME)).first().click();
      await page.locator(CREATE_ROUTINE.saveButton).click();
      await expect(page.locator(ROUTINE.myRoutinesSection)).toBeVisible({
        timeout: 15_000,
      });
    }

    const targetName = routineExists ? nameToDelete : ROUTINE_NAME;

    // Long-press to open action sheet.
    await flutterLongPress(page, ROUTINE.routineName(targetName));

    await expect(page.locator(ROUTINE.deleteOption)).toBeVisible({ timeout: 10_000 });
    await page.locator(ROUTINE.deleteOption).click();

    // Delete confirmation dialog.
    await expect(page.locator(ROUTINE.deleteDialogTitle)).toBeVisible({
      timeout: 5_000,
    });
    await page.locator(ROUTINE.deleteConfirmButton).click();

    // The routine must no longer appear in the list.
    await expect(
      page.locator(ROUTINE.routineName(targetName)),
    ).not.toBeVisible({ timeout: 10_000 });
  });
});
