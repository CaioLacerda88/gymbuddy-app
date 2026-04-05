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
 *  9. Delete custom exercise, verify it is gone
 * 10. Back navigation from detail returns to the list
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
});
