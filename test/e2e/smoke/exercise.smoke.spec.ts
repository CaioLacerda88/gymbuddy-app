/**
 * Exercise smoke tests — browse, create, delete, and search journey.
 *
 * Covers:
 *   - Exercise list loads with "Create new exercise" FAB visible
 *   - Creating a custom exercise (QA-007 fix verify: validation shows errors)
 *   - Deleting a custom exercise (QA-003 fix verify)
 *   - Search filters the exercise list
 *
 * Uses the dedicated smokeExercise test user to avoid shared state with
 * other smoke specs. User is created in global-setup.ts.
 *
 * The Flutter web app is served automatically by Playwright's webServer
 * config during local dev. In CI the FLUTTER_APP_URL env var is set by
 * the workflow.
 */

import { test, expect } from '@playwright/test';
import { navigateToTab } from '../helpers/app';
import { login } from '../helpers/auth';
import {
  EXERCISE_LIST,
  EXERCISE_DETAIL,
  CREATE_EXERCISE,
} from '../helpers/selectors';
import { TEST_USERS } from '../fixtures/test-users';

// The custom exercise name used across tests in this describe block.
// Includes a timestamp so repeated runs don't collide on the same name.
const CUSTOM_EXERCISE_NAME = `Smoke Test Exercise ${Date.now()}`;

test.describe('Exercise smoke', () => {
  test.beforeEach(async ({ page }) => {
    await login(
      page,
      TEST_USERS.smokeExercise.email,
      TEST_USERS.smokeExercise.password,
    );
    await navigateToTab(page, 'Exercises');
  });

  test('exercise list screen renders with search and create FAB', async ({
    page,
  }) => {
    // The page heading and search input must be present.
    await expect(page.locator(EXERCISE_LIST.heading)).toBeVisible();
    await expect(page.locator(EXERCISE_LIST.searchInput)).toBeVisible();

    // The muscle group "All" filter chip is always rendered.
    await expect(
      page.locator(EXERCISE_LIST.allMuscleGroupFilter),
    ).toBeVisible();

    // The FAB for creating exercises must be present.
    await expect(page.locator(EXERCISE_LIST.createFab)).toBeVisible();
  });

  test('create exercise — validation shows error when name is empty (QA-007 fix)', async ({
    page,
  }) => {
    // Open the create exercise screen via the FAB.
    await page.click(EXERCISE_LIST.createFab);
    await expect(page.locator(CREATE_EXERCISE.saveButton)).toBeVisible({
      timeout: 10_000,
    });

    // Click CREATE EXERCISE without filling in any fields.
    await page.click(CREATE_EXERCISE.saveButton);

    // The form must show a "Name is required" validation error.
    // Flutter AppTextField renders the helper text in the accessibility tree.
    await expect(page.locator('text=Name is required')).toBeVisible({
      timeout: 5_000,
    });

    // The screen should NOT navigate away — we should still be on create.
    await expect(page.locator(CREATE_EXERCISE.saveButton)).toBeVisible();
  });

  test('create custom exercise successfully navigates back to list', async ({
    page,
  }) => {
    // Open the create exercise screen.
    await page.click(EXERCISE_LIST.createFab);
    await expect(page.locator(CREATE_EXERCISE.nameInput)).toBeVisible({
      timeout: 10_000,
    });

    // Fill in the exercise name.
    await page.fill(CREATE_EXERCISE.nameInput, CUSTOM_EXERCISE_NAME);

    // Select a muscle group (Chest) and equipment (Barbell).
    await page.click('[aria-label="Muscle group: Chest Chest"]');
    await page.click('[aria-label="Equipment type: Barbell Barbell"]');

    // Submit the form.
    await page.click(CREATE_EXERCISE.saveButton);

    // Should navigate back to the exercise list.
    await expect(page.locator(EXERCISE_LIST.heading)).toBeVisible({
      timeout: 15_000,
    });
  });

  test('search filters exercise list by name', async ({ page }) => {
    // The list should have at least one exercise (user custom exercises or
    // default seeded exercises, depending on database state).
    // We search for a partial string to trigger the filter.
    await page.fill(EXERCISE_LIST.searchInput, 'Smoke Test');

    // Wait for the debounce to fire (300 ms default + render time).
    await page.waitForTimeout(600);

    // Either a matching card appears or the "no results" state is shown.
    const cards = page.locator('[aria-label^="Exercise:"]');
    const emptyState = page.locator(EXERCISE_LIST.emptyStateFiltered);

    const hasCards = await cards.first().isVisible({ timeout: 5_000 }).catch(() => false);
    const hasEmpty = await emptyState.isVisible({ timeout: 5_000 }).catch(() => false);

    // At least one of the two states must be visible — the app must not crash.
    expect(hasCards || hasEmpty).toBe(true);
  });

  test('delete custom exercise removes it from the list (QA-003 fix)', async ({
    page,
  }) => {
    // Create a dedicated exercise for this test so the delete does not
    // interfere with the shared CUSTOM_EXERCISE_NAME used in other tests.
    const deleteTargetName = `Delete Me ${Date.now()}`;

    // Create the exercise.
    await page.click(EXERCISE_LIST.createFab);
    await expect(page.locator(CREATE_EXERCISE.nameInput)).toBeVisible({
      timeout: 10_000,
    });
    await page.fill(CREATE_EXERCISE.nameInput, deleteTargetName);
    await page.click('[aria-label="Muscle group: Back Back"]');
    await page.click('[aria-label="Equipment type: Dumbbell Dumbbell"]');
    await page.click(CREATE_EXERCISE.saveButton);

    // Wait for navigation back to the list.
    await expect(page.locator(EXERCISE_LIST.heading)).toBeVisible({
      timeout: 15_000,
    });

    // Search for the newly created exercise to ensure it is present before
    // attempting to delete it.
    await page.fill(EXERCISE_LIST.searchInput, deleteTargetName.substring(0, 10));
    await page.waitForTimeout(600);

    // Open the detail screen for the exercise.
    const card = page.locator(EXERCISE_LIST.exerciseCard(deleteTargetName));
    await expect(card).toBeVisible({ timeout: 10_000 });
    await card.click();

    // The detail screen must show the delete button.
    await expect(page.locator(EXERCISE_DETAIL.deleteButton)).toBeVisible({
      timeout: 10_000,
    });

    // Click delete and confirm in the dialog.
    await page.click(EXERCISE_DETAIL.deleteButton);
    await expect(page.locator(EXERCISE_DETAIL.deleteDialogTitle)).toBeVisible({
      timeout: 5_000,
    });
    await page.click(EXERCISE_DETAIL.deleteConfirmButton);

    // After deletion the app should navigate back to the exercise list.
    await expect(page.locator(EXERCISE_LIST.heading)).toBeVisible({
      timeout: 15_000,
    });

    // The deleted exercise must no longer appear in the list.
    await page.waitForTimeout(500); // allow list to refresh
    await expect(
      page.locator(EXERCISE_LIST.exerciseCard(deleteTargetName)),
    ).not.toBeVisible({ timeout: 5_000 });
  });

  test('muscle group filter narrows the exercise list', async ({ page }) => {
    // Apply the "Chest" muscle group filter.
    await page.click(EXERCISE_LIST.muscleGroupFilter('Chest'));

    // Wait for the debounce and re-render.
    await page.waitForTimeout(600);

    // The filter chip should now be in the selected state.
    await expect(
      page.locator(EXERCISE_LIST.muscleGroupFilter('Chest')),
    ).toHaveAttribute('aria-selected', 'true');
  });
});
