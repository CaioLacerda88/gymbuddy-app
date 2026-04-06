/**
 * Exercise library full spec — browse, filter, search, create, and delete.
 *
 * Tests:
 *  1. List loads with seeded exercises
 *  2. Search filters by partial name ("bench")
 *  3. Muscle group filter (Chest)
 *  4. Equipment filter (Barbell)
 *  5. Combined filters (muscle group + search)
 *  6. Clear filters resets the list
 *  7. Tap exercise card opens detail screen with name visible
 *  8. Create custom exercise, verify it appears in the list
 *  9. Delete custom exercise, verify it is gone from list [EX-008]
 * 10. Back navigation from detail returns to the list
 * 11. Soft-deleted exercise is excluded from search results [EX-003 — P0]
 * 12. Filter combination with zero results shows empty state [EX-005 — P1]
 * 13. Duplicate exercise name shows validation error [EX-007 — P1]
 *
 * Uses the dedicated `fullExercises` test user.
 * The Flutter web app is served automatically by Playwright's webServer config
 * during local dev. In CI the FLUTTER_APP_URL env var is set by the workflow.
 */

import { test, expect } from '@playwright/test';
import { navigateToTab } from '../helpers/app';
import { login } from '../helpers/auth';
import {
  EXERCISE_LIST,
  EXERCISE_DETAIL,
  CREATE_EXERCISE,
  NAV,
} from '../helpers/selectors';
import { TEST_USERS } from '../fixtures/test-users';

const USER = TEST_USERS.fullExercises;

test.describe('Exercise library — full suite', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, USER.email, USER.password);
    await navigateToTab(page, 'Exercises');
  });

  test('exercise list loads with seeded exercises', async ({ page }) => {
    // The heading and filter controls must be present.
    await expect(page.locator(EXERCISE_LIST.heading)).toBeVisible();
    await expect(page.locator(EXERCISE_LIST.searchInput)).toBeVisible();
    await expect(page.locator(EXERCISE_LIST.allMuscleGroupFilter)).toBeVisible();
    await expect(page.locator(EXERCISE_LIST.createFab)).toBeVisible();

    // At least one exercise card from seed data must be visible.
    const cards = page.locator('[aria-label^="Exercise:"]');
    await expect(cards.first()).toBeVisible({ timeout: 10_000 });
    const count = await cards.count();
    expect(count).toBeGreaterThan(5);
  });

  test('search for "bench" narrows results to bench-related exercises', async ({
    page,
  }) => {
    const allCards = page.locator('[aria-label^="Exercise:"]');
    await expect(allCards.first()).toBeVisible({ timeout: 10_000 });
    const totalBefore = await allCards.count();

    await page.fill(EXERCISE_LIST.searchInput, 'bench');
    // Allow the 300 ms debounce to fire.
    await page.waitForTimeout(600);

    const countAfter = await allCards.count();

    // "bench" should match at least "Barbell Bench Press" from seed data.
    expect(countAfter).toBeGreaterThanOrEqual(1);
    // Filtering must reduce or equal the original count, never exceed it.
    expect(countAfter).toBeLessThanOrEqual(totalBefore);

    // Verify at least one result contains "Bench" in its aria-label.
    const benchCard = page.locator('[aria-label*="Bench"]');
    await expect(benchCard.first()).toBeVisible({ timeout: 5_000 });
  });

  test('Chest muscle group filter shows only chest exercises', async ({
    page,
  }) => {
    const allCards = page.locator('[aria-label^="Exercise:"]');
    await expect(allCards.first()).toBeVisible({ timeout: 10_000 });
    const totalBefore = await allCards.count();

    await page.click(EXERCISE_LIST.muscleGroupFilter('Chest'));
    await page.waitForTimeout(600);

    // The filter chip must enter selected state.
    await expect(
      page.locator(EXERCISE_LIST.muscleGroupFilter('Chest')),
    ).toHaveAttribute('aria-selected', 'true');

    const countAfter = await allCards.count();
    // Must narrow the list (seed data has chest + other muscle groups).
    expect(countAfter).toBeGreaterThanOrEqual(1);
    expect(countAfter).toBeLessThanOrEqual(totalBefore);

    // Seed has 9 chest exercises — verify at least "Barbell Bench Press" shows.
    await expect(
      page.locator('[aria-label="Exercise: Barbell Bench Press"]'),
    ).toBeVisible({ timeout: 5_000 });
  });

  test('Barbell equipment filter narrows results', async ({ page }) => {
    const allCards = page.locator('[aria-label^="Exercise:"]');
    await expect(allCards.first()).toBeVisible({ timeout: 10_000 });
    const totalBefore = await allCards.count();

    await page.click(EXERCISE_LIST.equipmentFilter('Barbell'));
    await page.waitForTimeout(600);

    await expect(
      page.locator(EXERCISE_LIST.equipmentFilter('Barbell')),
    ).toHaveAttribute('aria-selected', 'true');

    const countAfter = await allCards.count();
    expect(countAfter).toBeGreaterThanOrEqual(1);
    expect(countAfter).toBeLessThanOrEqual(totalBefore);
  });

  test('combined muscle group + search filter narrows results further', async ({
    page,
  }) => {
    // Apply Chest filter first.
    await page.click(EXERCISE_LIST.muscleGroupFilter('Chest'));
    await page.waitForTimeout(600);

    const chestCards = page.locator('[aria-label^="Exercise:"]');
    await expect(chestCards.first()).toBeVisible({ timeout: 5_000 });
    const chestCount = await chestCards.count();

    // Then add a text search on top.
    await page.fill(EXERCISE_LIST.searchInput, 'incline');
    await page.waitForTimeout(600);

    const combinedCount = await chestCards.count();

    // Combined filter must produce fewer or equal results than muscle group alone.
    expect(combinedCount).toBeLessThanOrEqual(chestCount);
    // "Incline Barbell Bench Press" and "Incline Dumbbell Press" are in seed.
    if (combinedCount > 0) {
      const firstLabel = await chestCards.first().getAttribute('aria-label');
      expect(firstLabel?.toLowerCase()).toContain('incline');
    }
  });

  test('clearing filters after applying them resets to full list', async ({
    page,
  }) => {
    const allCards = page.locator('[aria-label^="Exercise:"]');
    await expect(allCards.first()).toBeVisible({ timeout: 10_000 });
    const totalBefore = await allCards.count();

    // Apply a filter that reduces the list.
    await page.click(EXERCISE_LIST.muscleGroupFilter('Core'));
    await page.waitForTimeout(600);
    const filteredCount = await allCards.count();
    expect(filteredCount).toBeLessThan(totalBefore);

    // Click "All" to reset.
    await page.click(EXERCISE_LIST.allMuscleGroupFilter);
    await page.waitForTimeout(600);

    const resetCount = await allCards.count();
    expect(resetCount).toBeGreaterThanOrEqual(totalBefore);
  });

  test('tapping an exercise card opens the detail screen showing the name', async ({
    page,
  }) => {
    const firstCard = page.locator('[aria-label^="Exercise:"]').first();
    await expect(firstCard).toBeVisible({ timeout: 10_000 });
    const label = (await firstCard.getAttribute('aria-label')) ?? '';
    const exerciseName = label.replace('Exercise: ', '');

    await firstCard.click();

    await expect(page.locator(EXERCISE_DETAIL.appBarTitle)).toBeVisible({
      timeout: 10_000,
    });
    // The exercise name must be rendered in the detail body.
    await expect(page.locator(`text=${exerciseName}`)).toBeVisible({
      timeout: 5_000,
    });
  });

  test('create a custom exercise and verify it appears in the list', async ({
    page,
  }) => {
    const customName = 'E2E Test Cable Fly';

    // Open the create exercise screen via the FAB.
    await page.click(EXERCISE_LIST.createFab);

    // Fill in the exercise name.
    await expect(page.locator(CREATE_EXERCISE.nameInput)).toBeVisible({
      timeout: 10_000,
    });
    await page.fill(CREATE_EXERCISE.nameInput, customName);

    // Save the exercise.
    await page.click(CREATE_EXERCISE.saveButton);

    // After saving the app navigates back to the exercise list.
    await expect(page.locator(EXERCISE_LIST.heading)).toBeVisible({
      timeout: 15_000,
    });

    // The new exercise must appear in the list.
    await expect(
      page.locator(EXERCISE_LIST.exerciseCard(customName)),
    ).toBeVisible({ timeout: 10_000 });
  });

  test('delete a custom exercise and verify it is removed from the list', async ({
    page,
  }) => {
    const customName = 'E2E Delete Target Exercise';

    // Create the exercise to delete.
    await page.click(EXERCISE_LIST.createFab);
    await expect(page.locator(CREATE_EXERCISE.nameInput)).toBeVisible({
      timeout: 10_000,
    });
    await page.fill(CREATE_EXERCISE.nameInput, customName);
    await page.click(CREATE_EXERCISE.saveButton);

    // Verify it was created.
    await expect(page.locator(EXERCISE_LIST.heading)).toBeVisible({
      timeout: 15_000,
    });
    const card = page.locator(EXERCISE_LIST.exerciseCard(customName));
    await expect(card).toBeVisible({ timeout: 10_000 });

    // Open the detail screen.
    await card.click();
    await expect(page.locator(EXERCISE_DETAIL.appBarTitle)).toBeVisible({
      timeout: 10_000,
    });

    // Tap delete and confirm.
    await page.click(EXERCISE_DETAIL.deleteButton);
    await expect(page.locator(EXERCISE_DETAIL.deleteDialogTitle)).toBeVisible({
      timeout: 5_000,
    });
    await page.click(EXERCISE_DETAIL.deleteConfirmButton);

    // Should navigate back to the list.
    await expect(page.locator(EXERCISE_LIST.heading)).toBeVisible({
      timeout: 15_000,
    });

    // The deleted exercise must no longer appear.
    await expect(
      page.locator(EXERCISE_LIST.exerciseCard(customName)),
    ).not.toBeVisible({ timeout: 5_000 });
  });

  test('back navigation from the detail screen returns to the list', async ({
    page,
  }) => {
    const firstCard = page.locator('[aria-label^="Exercise:"]').first();
    await expect(firstCard).toBeVisible({ timeout: 10_000 });
    await firstCard.click();

    await expect(page.locator(EXERCISE_DETAIL.appBarTitle)).toBeVisible({
      timeout: 10_000,
    });

    // Use the browser back navigation.
    await page.goBack();

    await expect(page.locator(EXERCISE_LIST.heading)).toBeVisible({
      timeout: 10_000,
    });
    // Exercise cards must still be present after returning.
    await expect(
      page.locator('[aria-label^="Exercise:"]').first(),
    ).toBeVisible({ timeout: 10_000 });
  });

  // ---------------------------------------------------------------------------
  // EX-003 (P0) — Soft-deleted exercise excluded from search
  // Extends the delete test: after deletion, searching for the deleted name
  // must return zero results.
  // ---------------------------------------------------------------------------
  test('EX-003: deleted exercise does not appear in search results', async ({
    page,
  }) => {
    const customName = 'E2E SoftDelete SearchTest';

    // Create the exercise.
    await page.click(EXERCISE_LIST.createFab);
    await expect(page.locator(CREATE_EXERCISE.nameInput)).toBeVisible({
      timeout: 10_000,
    });
    await page.fill(CREATE_EXERCISE.nameInput, customName);
    await page.click(CREATE_EXERCISE.saveButton);
    await expect(page.locator(EXERCISE_LIST.heading)).toBeVisible({
      timeout: 15_000,
    });

    // Verify it exists in the list before deletion.
    const card = page.locator(EXERCISE_LIST.exerciseCard(customName));
    await expect(card).toBeVisible({ timeout: 10_000 });

    // Open the detail and delete.
    await card.click();
    await expect(page.locator(EXERCISE_DETAIL.appBarTitle)).toBeVisible({
      timeout: 10_000,
    });
    await page.click(EXERCISE_DETAIL.deleteButton);
    await expect(page.locator(EXERCISE_DETAIL.deleteDialogTitle)).toBeVisible({
      timeout: 5_000,
    });
    await page.click(EXERCISE_DETAIL.deleteConfirmButton);

    // Should navigate back to the list.
    await expect(page.locator(EXERCISE_LIST.heading)).toBeVisible({
      timeout: 15_000,
    });

    // Now search for the deleted exercise name — must return zero results.
    await page.fill(EXERCISE_LIST.searchInput, customName);
    // Allow the 300 ms debounce to fire plus a safety buffer.
    await page.waitForTimeout(700);

    // Either the filtered empty state or zero matching cards must be shown.
    const matchingCards = page.locator(
      EXERCISE_LIST.exerciseCard(customName),
    );
    const count = await matchingCards.count();
    expect(count).toBe(0);
  });

  // ---------------------------------------------------------------------------
  // EX-005 (P1) — Filter combination zero results shows empty state
  // Core + Kettlebell is unlikely to have a seeded match; if it does, the
  // test still passes because the assertion is on the empty state itself.
  // We exhaust filters until we reach zero, then assert the empty state text.
  // ---------------------------------------------------------------------------
  test('EX-005: filter combination with zero results shows filtered empty state', async ({
    page,
  }) => {
    // Wait for the full list to load before filtering.
    const allCards = page.locator('[aria-label^="Exercise:"]');
    await expect(allCards.first()).toBeVisible({ timeout: 10_000 });

    // Apply Core muscle group + Kettlebell equipment — a combination unlikely
    // to be in the seed data. If it IS seeded, the test falls back to a further
    // search term that will guarantee zero results.
    await page.click(EXERCISE_LIST.muscleGroupFilter('Core'));
    await page.waitForTimeout(600);
    await page.click(EXERCISE_LIST.equipmentFilter('Kettlebell'));
    await page.waitForTimeout(600);

    // Check if the empty state appeared. If not (seed has Core+Kettlebell
    // exercises), also apply a nonsense search to force zero results.
    const emptyStateVisible = await page
      .locator(EXERCISE_LIST.emptyStateFiltered)
      .isVisible({ timeout: 3_000 })
      .catch(() => false);

    if (!emptyStateVisible) {
      await page.fill(EXERCISE_LIST.searchInput, 'ZZZnoResultsXXX');
      await page.waitForTimeout(700);
    }

    // The filtered empty state text must now be visible.
    await expect(page.locator(EXERCISE_LIST.emptyStateFiltered)).toBeVisible({
      timeout: 5_000,
    });

    // The "Clear Filters" button must accompany the empty state.
    await expect(page.locator(EXERCISE_LIST.clearFiltersButton)).toBeVisible({
      timeout: 3_000,
    });
  });

  // ---------------------------------------------------------------------------
  // EX-007 (P1) — Duplicate exercise name validation
  // Create one exercise, then attempt to create another with the same name.
  // The server (or client-side check) must return a validation error.
  // ---------------------------------------------------------------------------
  test('EX-007: submitting a duplicate exercise name shows a validation error', async ({
    page,
  }) => {
    const uniqueName = `E2E DuplicateCheck ${Date.now()}`;

    // Helper: fill the create form with the given name and the required
    // muscle group + equipment type selections, then submit.
    async function createExercise(name: string) {
      await page.click(EXERCISE_LIST.createFab);
      await expect(page.locator(CREATE_EXERCISE.nameInput)).toBeVisible({
        timeout: 10_000,
      });
      await page.fill(CREATE_EXERCISE.nameInput, name);

      // Select Chest muscle group (first selectable card in the grid).
      await page.click('role=button[name*="Muscle group: Chest"]');
      // Select Barbell equipment type.
      await page.click('role=button[name*="Equipment type: Barbell"]');

      await page.click(CREATE_EXERCISE.saveButton);
    }

    // First creation — must succeed and return to the list.
    await createExercise(uniqueName);
    await expect(page.locator(EXERCISE_LIST.heading)).toBeVisible({
      timeout: 15_000,
    });
    await expect(
      page.locator(EXERCISE_LIST.exerciseCard(uniqueName)),
    ).toBeVisible({ timeout: 10_000 });

    // Second creation with the same name — must show a validation error.
    await createExercise(uniqueName);

    // The validation error appears as inline form field error text.
    // The CreateExerciseScreen surfaces it via ValidationException → _nameError.
    const hasValidationError =
      (await page
        .locator('text=already exists')
        .isVisible({ timeout: 10_000 })
        .catch(() => false)) ||
      (await page
        .locator('text=duplicate')
        .isVisible({ timeout: 3_000 })
        .catch(() => false)) ||
      (await page
        .locator('[aria-live="polite"]')
        .isVisible({ timeout: 3_000 })
        .catch(() => false));

    expect(hasValidationError).toBe(true);

    // Must still be on the create screen (no navigation on error).
    await expect(page.locator(CREATE_EXERCISE.nameInput)).toBeVisible({
      timeout: 5_000,
    });
  });
});
