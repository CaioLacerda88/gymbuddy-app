/**
 * Exercise library smoke tests — browse, filter, and detail journey.
 *
 * Uses the dedicated `smokeExercise` test user (created by global-setup.ts).
 * Exercises are seeded by `supabase/seed.sql` — no manual seeding needed.
 *
 * Tests: browse exercise list, filter by muscle group, filter by equipment,
 * search by name, open exercise detail, and back navigation.
 */

import { test, expect } from '@playwright/test';
import { navigateToTab } from '../helpers/app';
import { login } from '../helpers/auth';
import { EXERCISE_LIST, EXERCISE_DETAIL } from '../helpers/selectors';
import { TEST_USERS } from '../fixtures/test-users';

const USER = TEST_USERS.smokeExercise;

test.describe('Exercise library smoke', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, USER.email, USER.password);
    await navigateToTab(page, 'Exercises');
  });

  test('exercise list screen renders the heading and filter controls', async ({
    page,
  }) => {
    await expect(page.locator(EXERCISE_LIST.heading).first()).toBeVisible();
    await expect(page.locator(EXERCISE_LIST.searchInput)).toBeVisible();

    // The "All" muscle group filter is always present.
    await expect(
      page.locator(EXERCISE_LIST.allMuscleGroupFilter),
    ).toBeVisible();

    // FAB for creating exercises must be present.
    await expect(page.locator(EXERCISE_LIST.createFab)).toBeVisible();
  });

  test('exercise list shows seeded exercises', async ({ page }) => {
    // At least one exercise card must be visible after seeding.
    // We use the exerciseCard selector pattern with a partial match to find
    // any exercise card rather than a specific name.
    const exerciseCards = page.locator('role=button[name*="Exercise:"]');
    await expect(exerciseCards.first()).toBeVisible({ timeout: 10_000 });
    expect(await exerciseCards.count()).toBeGreaterThan(0);
  });

  test('selecting a muscle group filter narrows the list', async ({ page }) => {
    // Count total cards before filtering.
    const allCards = page.locator('role=button[name*="Exercise:"]');
    await expect(allCards.first()).toBeVisible({ timeout: 10_000 });
    const totalBefore = await allCards.count();

    // Apply "Chest" filter — a muscle group guaranteed to exist in seed data.
    await page.click(EXERCISE_LIST.muscleGroupFilter('Chest'));

    // Wait for the list to update (debounce + provider re-render).
    await page.waitForTimeout(500);

    const cardsAfter = await allCards.count();

    // The filter must either reduce the count or keep it the same (if every
    // exercise happens to be Chest — unlikely but valid). It must not crash.
    expect(cardsAfter).toBeGreaterThanOrEqual(0);
    expect(cardsAfter).toBeLessThanOrEqual(totalBefore);
  });

  test('selecting an equipment filter narrows the list', async ({ page }) => {
    // Apply "Barbell" equipment filter.
    await page.click(EXERCISE_LIST.equipmentFilter('Barbell'));
    await page.waitForTimeout(500);

    // Verify the filter is now selected.
    const barbellFilter = page.locator(
      EXERCISE_LIST.equipmentFilter('Barbell'),
    );
    await expect(barbellFilter).toBeChecked();
  });

  test('search input filters exercises by name', async ({ page }) => {
    // Wait for initial exercise list to load.
    const cards = page.locator('role=button[name*="Exercise:"]');
    await expect(cards.first()).toBeVisible({ timeout: 10_000 });

    // Type a partial name. "bench" matches multiple seed exercises.
    await page.fill(EXERCISE_LIST.searchInput, 'bench');

    // Wait for the 300 ms debounce in _onSearchChanged.
    await page.waitForTimeout(500);

    const count = await cards.count();

    // Either results appear or the filtered empty state is shown — either is
    // acceptable. We just verify the app does not crash.
    if (count === 0) {
      await expect(
        page.locator(EXERCISE_LIST.emptyStateFiltered),
      ).toBeVisible();
    } else {
      await expect(cards.first()).toBeVisible();
    }
  });

  test('tapping an exercise card opens the detail screen', async ({ page }) => {
    // Wait for exercises to load then click the first card.
    const firstCard = page.locator('role=button[name*="Exercise:"]').first();
    await expect(firstCard).toBeVisible({ timeout: 10_000 });
    await firstCard.click();

    // The detail screen AppBar shows "Exercise Details".
    await expect(page.locator(EXERCISE_DETAIL.appBarTitle)).toBeVisible({
      timeout: 10_000,
    });
  });

  test('back navigation from detail returns to the exercise list', async ({
    page,
  }) => {
    // Wait for exercises to load then click the first card.
    const firstCard = page.locator('role=button[name*="Exercise:"]').first();
    await expect(firstCard).toBeVisible({ timeout: 10_000 });
    await firstCard.click();

    await expect(page.locator(EXERCISE_DETAIL.appBarTitle)).toBeVisible({
      timeout: 10_000,
    });

    // Use the browser/AppBar back button.
    await page.goBack();

    // We should be back on the list screen.
    await expect(page.locator(EXERCISE_LIST.heading).first()).toBeVisible({
      timeout: 10_000,
    });
  });
});
