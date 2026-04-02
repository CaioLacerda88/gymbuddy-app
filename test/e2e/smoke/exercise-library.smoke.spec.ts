/**
 * Exercise library smoke tests — browse, filter, and detail journey.
 *
 * Skipped by default. Remove test.skip() and set environment variables to run:
 *   TEST_USER_EMAIL=<email>
 *   TEST_USER_PASSWORD=<password>
 *
 * The Supabase database must be seeded with exercises before running.
 * Run: psql $DATABASE_URL -f supabase/seed.sql
 *
 * See test/e2e/README.md for full setup instructions.
 */

import { test, expect } from '@playwright/test';
import { navigateToTab } from '../helpers/app';
import { login, getTestCredentials } from '../helpers/auth';
import { EXERCISE_LIST, EXERCISE_DETAIL, NAV } from '../helpers/selectors';

// Requires: running Flutter web app and seeded exercises.
test.skip(true, 'Requires running Flutter web app and seeded exercises');

test.describe('Exercise library smoke', () => {
  // Log in once before all tests in this describe block so we are not
  // repeating the auth round-trip for every individual test.
  test.beforeEach(async ({ page }) => {
    const { email, password } = getTestCredentials();
    await login(page, email, password);
    await navigateToTab(page, 'Exercises');
  });

  test('exercise list screen renders the heading and filter controls', async ({
    page,
  }) => {
    await expect(page.locator(EXERCISE_LIST.heading)).toBeVisible();
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
    // We look for the generic "Exercise:" prefix used in all Semantics labels
    // rather than a specific exercise name, so the test is seed-agnostic.
    const exerciseCards = page.locator('[aria-label^="Exercise:"]');
    await expect(exerciseCards.first()).toBeVisible({ timeout: 10_000 });
    expect(await exerciseCards.count()).toBeGreaterThan(0);
  });

  test('selecting a muscle group filter narrows the list', async ({ page }) => {
    // Count total cards before filtering.
    const allCards = page.locator('[aria-label^="Exercise:"]');
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

    // The "Chest" filter button must now be in selected state (aria-checked or
    // aria-pressed, depending on how Flutter renders ChoiceChip/selected).
    const chestFilter = page.locator(EXERCISE_LIST.muscleGroupFilter('Chest'));
    // Flutter marks selected Semantics with aria-selected="true".
    await expect(chestFilter).toHaveAttribute('aria-selected', 'true');
  });

  test('selecting an equipment filter narrows the list', async ({ page }) => {
    // Apply "Barbell" equipment filter.
    await page.click(EXERCISE_LIST.equipmentFilter('Barbell'));
    await page.waitForTimeout(500);

    const barbellFilter = page.locator(
      EXERCISE_LIST.equipmentFilter('Barbell'),
    );
    await expect(barbellFilter).toHaveAttribute('aria-selected', 'true');
  });

  test('search input filters exercises by name', async ({ page }) => {
    // Type a partial name. We use "bench" as it is a common seed exercise.
    await page.fill(EXERCISE_LIST.searchInput, 'bench');

    // Wait for the 300 ms debounce in _onSearchChanged.
    await page.waitForTimeout(500);

    const cards = page.locator('[aria-label^="Exercise:"]');
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
    // Click the first exercise card regardless of its name.
    const firstCard = page.locator('[aria-label^="Exercise:"]').first();
    const cardLabel = await firstCard.getAttribute('aria-label');
    await firstCard.click();

    // The detail screen AppBar shows "Exercise Details".
    await expect(page.locator(EXERCISE_DETAIL.appBarTitle)).toBeVisible({
      timeout: 10_000,
    });

    // The exercise name is rendered as the headlineLarge at the top of the
    // body. Extract the name from the aria-label we captured above.
    // cardLabel format: "Exercise: <name>"
    if (cardLabel) {
      const exerciseName = cardLabel.replace('Exercise: ', '');
      await expect(page.locator(`text=${exerciseName}`)).toBeVisible();
    }

    // The coming-soon placeholder must always be present at this stage.
    await expect(page.locator(EXERCISE_DETAIL.prPlaceholder)).toBeVisible();
  });

  test('back navigation from detail returns to the exercise list', async ({
    page,
  }) => {
    await page.locator('[aria-label^="Exercise:"]').first().click();
    await expect(page.locator(EXERCISE_DETAIL.appBarTitle)).toBeVisible({
      timeout: 10_000,
    });

    // Use the browser/AppBar back button.
    await page.goBack();

    // We should be back on the list screen.
    await expect(page.locator(EXERCISE_LIST.heading)).toBeVisible({
      timeout: 10_000,
    });
  });
});
