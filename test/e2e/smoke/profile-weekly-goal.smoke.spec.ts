/**
 * Profile weekly goal smoke test.
 *
 * Tests changing the training frequency (weekly goal) from the Profile screen:
 *   - Login → navigate to Profile tab.
 *   - Find the "Weekly Goal" row showing "{n}x per week".
 *   - Tap it to open the frequency bottom sheet.
 *   - Select a different frequency chip.
 *   - Verify the row now shows the new frequency.
 *   - Restore the original frequency so the test is idempotent.
 *
 * Uses the dedicated `smokeProfileWeeklyGoal` user for state isolation.
 *
 * Label source: ProfileScreen._WeeklyGoalRow renders the row text as
 * "${frequency}x per week" and the bottom sheet title as "Weekly Goal".
 * The ChoiceChips in the sheet are labeled "${freq}x" (e.g. "3x", "4x").
 */

import { test, expect } from '@playwright/test';
import { login } from '../helpers/auth';
import { navigateToTab } from '../helpers/app';
import { PROFILE, PROFILE_WEEKLY_GOAL } from '../helpers/selectors';
import { TEST_USERS } from '../fixtures/test-users';

const USER = TEST_USERS.smokeProfileWeeklyGoal;

test.describe('Smoke: Profile Weekly Goal', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, USER.email, USER.password);
    await navigateToTab(page, 'Profile');
  });

  // ---------------------------------------------------------------------------
  // Test 1: Profile screen shows the Weekly Goal section.
  //
  // ProfileScreen renders a "Weekly Goal" titleMedium Text above the
  // _WeeklyGoalRow widget. The row shows "${frequency}x per week".
  // ---------------------------------------------------------------------------
  test('Profile screen shows Weekly Goal section with frequency text', async ({
    page,
  }) => {
    await expect(page.locator(PROFILE.heading).first()).toBeVisible({ timeout: 10_000 });
    await expect(page.locator(PROFILE_WEEKLY_GOAL.sectionLabel)).toBeVisible({
      timeout: 10_000,
    });
    // The row text matches "${n}x per week" where n is 2-6.
    await expect(page.locator(PROFILE_WEEKLY_GOAL.frequencyRow)).toBeVisible({
      timeout: 10_000,
    });
  });

  // ---------------------------------------------------------------------------
  // Test 2: Tapping the Weekly Goal row opens the frequency bottom sheet.
  //
  // _WeeklyGoalRow is an InkWell that calls _showFrequencySheet on tap.
  // The sheet has title "Weekly Goal" and ChoiceChips: 2x, 3x, 4x, 5x, 6x.
  // ---------------------------------------------------------------------------
  test('tapping Weekly Goal row opens the frequency selection sheet', async ({
    page,
  }) => {
    await expect(page.locator(PROFILE_WEEKLY_GOAL.frequencyRow)).toBeVisible({
      timeout: 10_000,
    });
    await page.locator(PROFILE_WEEKLY_GOAL.frequencyRow).click();

    // Bottom sheet title.
    await expect(page.locator(PROFILE_WEEKLY_GOAL.sheetTitle)).toBeVisible({
      timeout: 10_000,
    });

    // All frequency options must be present (rendered as ChoiceChips).
    for (const chip of ['2x', '3x', '4x', '5x', '6x']) {
      await expect(page.locator(`role=checkbox[name="${chip}"]`)).toBeVisible({
        timeout: 5_000,
      });
    }
  });

  // ---------------------------------------------------------------------------
  // Test 3: Selecting a different frequency updates the displayed value.
  //
  // If the current frequency is 3x, we change it to 4x and verify the row
  // text updates to "4x per week". Then we restore it to 3x.
  // ---------------------------------------------------------------------------
  test('selecting a frequency chip updates the weekly goal row text', async ({
    page,
  }) => {
    await expect(page.locator(PROFILE_WEEKLY_GOAL.frequencyRow)).toBeVisible({
      timeout: 10_000,
    });

    // Read the current frequency from the row text.
    const rowText = await page
      .locator(PROFILE_WEEKLY_GOAL.frequencyRow)
      .textContent({ timeout: 5_000 });
    const currentFreq = rowText?.match(/(\d+)x per week/)?.[1] ?? '3';
    const currentFreqNum = parseInt(currentFreq, 10);

    // Pick a different frequency to switch to.
    // Cycle: if current is 3, use 4; if current is 6, use 5; otherwise +1.
    const newFreqNum = currentFreqNum < 6 ? currentFreqNum + 1 : currentFreqNum - 1;
    const newFreqChip = `${newFreqNum}x`;
    const originalFreqChip = `${currentFreqNum}x`;

    // Open the sheet.
    await page.locator(PROFILE_WEEKLY_GOAL.frequencyRow).click();
    await expect(page.locator(PROFILE_WEEKLY_GOAL.sheetTitle)).toBeVisible({
      timeout: 10_000,
    });

    // Select the new frequency chip (rendered as ChoiceChip → checkbox role).
    // Use CSS selector to target the flt-semantics element directly, ensuring
    // Playwright sends a pointer click (not a checkbox toggle action).
    await page.locator(`role=checkbox[name="${newFreqChip}"]`).click();

    // The sheet should close automatically after selection (Navigator.of(ctx).pop()).
    await expect(page.locator(PROFILE_WEEKLY_GOAL.sheetTitle)).not.toBeVisible({
      timeout: 10_000,
    });

    // Wait for the async profile update to propagate to the UI.
    await page.waitForTimeout(500);

    // The row should now show the new frequency.
    await expect(
      page.locator(PROFILE_WEEKLY_GOAL.frequencyRowWithValue(newFreqNum)),
    ).toBeVisible({ timeout: 10_000 });

    // Restore to original frequency (cleanup for test isolation).
    await page.locator(PROFILE_WEEKLY_GOAL.frequencyRow).click();
    await expect(page.locator(PROFILE_WEEKLY_GOAL.sheetTitle)).toBeVisible({
      timeout: 10_000,
    });
    await page.locator(`role=checkbox[name="${originalFreqChip}"]`).click();
    await expect(page.locator(PROFILE_WEEKLY_GOAL.sheetTitle)).not.toBeVisible({
      timeout: 10_000,
    });

    // Verify the original value is restored.
    await expect(
      page.locator(PROFILE_WEEKLY_GOAL.frequencyRowWithValue(currentFreqNum)),
    ).toBeVisible({ timeout: 10_000 });
  });

  // ---------------------------------------------------------------------------
  // Test 4: Selecting the already-active frequency still closes the sheet.
  //
  // Tapping the currently selected chip also calls onSelected, which calls
  // updateTrainingFrequency and pops the sheet. The displayed value should not
  // change but the sheet must close.
  // ---------------------------------------------------------------------------
  test('selecting the current frequency closes the sheet without error', async ({
    page,
  }) => {
    await expect(page.locator(PROFILE_WEEKLY_GOAL.frequencyRow)).toBeVisible({
      timeout: 10_000,
    });

    // Read current frequency.
    const rowText = await page
      .locator(PROFILE_WEEKLY_GOAL.frequencyRow)
      .textContent({ timeout: 5_000 });
    const currentFreq = rowText?.match(/(\d+)x per week/)?.[1] ?? '3';
    const currentFreqNum = parseInt(currentFreq, 10);
    const currentChipText = `${currentFreqNum}x`;

    // Open sheet.
    await page.locator(PROFILE_WEEKLY_GOAL.frequencyRow).click();
    await expect(page.locator(PROFILE_WEEKLY_GOAL.sheetTitle)).toBeVisible({
      timeout: 10_000,
    });

    // Tap the currently selected chip (rendered as ChoiceChip → checkbox role).
    // Use CSS selector for consistent pointer click behavior.
    await page.locator(`role=checkbox[name="${currentChipText}"]`).click();

    // Sheet must close.
    await expect(page.locator(PROFILE_WEEKLY_GOAL.sheetTitle)).not.toBeVisible({
      timeout: 5_000,
    });

    // Value is unchanged.
    await expect(
      page.locator(PROFILE_WEEKLY_GOAL.frequencyRowWithValue(currentFreqNum)),
    ).toBeVisible({ timeout: 5_000 });
  });
});
