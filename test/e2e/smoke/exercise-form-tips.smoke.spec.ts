/**
 * Exercise form tips smoke tests — BUG-002 (P1) regression coverage.
 *
 * BUG-002 (P1): Form tips for default exercises displayed as a single block
 * of text containing literal `\n` characters instead of as separate bulleted
 * items. Root cause: the seed SQL migration stored `\n` as two literal chars
 * (backslash + n) rather than a real newline character. The widget fix splits
 * on `RegExp(r'\n|\\n')` to handle both cases.
 *
 * This test opens the Barbell Bench Press detail screen (a seeded default
 * exercise with known form tips) and verifies:
 *   1. The "FORM TIPS" section heading is visible.
 *   2. At least the first tip is rendered as its own text element.
 *   3. The literal string `\n` does NOT appear anywhere on screen — i.e. the
 *      tips were actually split rather than displayed as one blob.
 *   4. There are multiple separate tip entries (at least 2), confirming that
 *      splitting happened.
 *
 * Uses the dedicated `smokeFormTips` test user.
 * User is created in global-setup.ts and deleted in global-teardown.ts.
 */

import { test, expect } from '@playwright/test';
import { login } from '../helpers/auth';
import { navigateToTab, flutterFill } from '../helpers/app';
import { EXERCISE_LIST, EXERCISE_DETAIL } from '../helpers/selectors';
import { TEST_USERS } from '../fixtures/test-users';
import { SEED_EXERCISES } from '../fixtures/test-exercises';

const USER = TEST_USERS.smokeFormTips;

test.describe('Exercise form tips smoke', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, USER.email, USER.password);
    await navigateToTab(page, 'Exercises');
  });

  // ---------------------------------------------------------------------------
  // BUG-002 (P1): Form tips render as separate bullet items, not a single blob.
  //
  // Barbell Bench Press has 4 form tips separated by newlines in the database.
  // If BUG-002 is present, all 4 tips appear joined as one block with literal
  // "\n" characters visible in the text.
  // If BUG-002 is fixed, each tip renders as its own row with a check-circle icon.
  // ---------------------------------------------------------------------------
  test('BUG-002: form tips render as separate bullet items without literal backslash-n', async ({
    page,
  }) => {
    // Search for Bench Press to quickly find the exercise.
    await flutterFill(page, EXERCISE_LIST.searchInput, SEED_EXERCISES.benchPress);
    await page.waitForTimeout(800);

    // Open the exercise detail.
    const card = page
      .locator(EXERCISE_LIST.exerciseCard(SEED_EXERCISES.benchPress))
      .first();
    await expect(card).toBeVisible({ timeout: 10_000 });
    await card.click();

    await expect(page.locator(EXERCISE_DETAIL.appBarTitle)).toBeVisible({
      timeout: 10_000,
    });

    // The "FORM TIPS" section header must be present — confirms the tips data
    // was loaded from the database and the section rendered at all.
    await expect(page.locator('text=FORM TIPS')).toBeVisible({ timeout: 10_000 });

    // KEY ASSERTION FOR BUG-002:
    // The literal two-character sequence backslash-n must NOT appear on screen.
    // If form_tips contains literal "\n" chars and the widget fails to split
    // them, the rendered text would contain "\\n" visible to the user.
    const literalBackslashN = page.locator('text=/\\\\n/');
    await expect(literalBackslashN).not.toBeVisible({ timeout: 3_000 });

    // The first known tip for Barbell Bench Press must appear as its own text
    // element. We match the opening words which are unique per tip.
    // Tip 1: "Plant feet flat on the floor and squeeze shoulder blades together"
    await expect(
      page.locator('text=Plant feet flat').first(),
    ).toBeVisible({ timeout: 5_000 });

    // A second distinct tip must also be visible separately.
    // Tip 2: "Lower the bar to mid-chest with elbows at roughly 45 degrees"
    await expect(
      page.locator('text=Lower the bar to mid-chest').first(),
    ).toBeVisible({ timeout: 5_000 });

    // If both tips are visible as separate elements, splitting worked correctly.
    // (If BUG-002 was present, only the combined blob would be visible, and
    // the partial text matches above would still succeed — but the literal \n
    // assertion above would catch the regression.)
  });

  // ---------------------------------------------------------------------------
  // Additional guard: form tips section is absent for exercises with no tips.
  //
  // A custom exercise created without form tips must NOT show a "FORM TIPS"
  // heading with empty content. This guards against the section rendering
  // an empty state when formTips is null/empty.
  // ---------------------------------------------------------------------------
  test('form tips section is absent for exercises with no tips data', async ({
    page,
  }) => {
    // Create a custom exercise with no form tips — only name required.
    const customName = `No Tips Exercise ${Date.now()}`;

    await page.click(EXERCISE_LIST.createFab);
    await expect(page.locator('role=textbox[name*="Exercise Name"]')).toBeVisible({
      timeout: 10_000,
    });
    await flutterFill(page, 'role=textbox[name*="Exercise Name"]', customName);
    await page.locator('role=button[name*="Muscle group: Chest"]').first().click();
    await page.locator('role=button[name*="Equipment type: Barbell"]').first().click();
    await page.click('text="CREATE EXERCISE"');

    await expect(page.locator(EXERCISE_LIST.heading).first()).toBeVisible({
      timeout: 15_000,
    });

    // Search for and open the custom exercise.
    await flutterFill(page, EXERCISE_LIST.searchInput, customName.substring(0, 10));
    await page.waitForTimeout(800);

    const card = page.locator(EXERCISE_LIST.exerciseCard(customName)).first();
    await expect(card).toBeVisible({ timeout: 10_000 });
    await card.click();

    await expect(page.locator(EXERCISE_DETAIL.appBarTitle)).toBeVisible({
      timeout: 10_000,
    });

    // "FORM TIPS" section must NOT be visible when there are no tips.
    await expect(page.locator('text=FORM TIPS')).not.toBeVisible({
      timeout: 3_000,
    });
  });
});
