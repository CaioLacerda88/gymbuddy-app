/**
 * Weekly plan smoke test.
 *
 * Covers the core weekly plan flow on the Home screen:
 *   - THIS WEEK section is visible after login when routines exist.
 *   - Navigating to Plan Management via the long-press CTA.
 *   - Adding a starter routine to the weekly bucket.
 *   - Verifying the routine chip appears.
 *   - Removing the routine from the plan (swipe-to-dismiss or Clear Week).
 *   - Verifying the bucket is empty after removal.
 *
 * Uses the dedicated `smokeWeeklyPlan` user so state is isolated.
 * The Push Day starter routine is seeded by seed.sql and always present.
 */

import { test, expect } from '@playwright/test';
import { login } from '../helpers/auth';
import { navigateToTab, waitForAppReady } from '../helpers/app';
import { WEEKLY_PLAN } from '../helpers/selectors';
import { TEST_USERS } from '../fixtures/test-users';

const USER = TEST_USERS.smokeWeeklyPlan;

// The Push Day starter routine is seeded by seed.sql.
const PUSH_DAY = 'Push Day';

test.describe('Smoke: Weekly Plan', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, USER.email, USER.password);
    // Start on the Home tab where the THIS WEEK section lives.
    await navigateToTab(page, 'Home');
  });

  // ---------------------------------------------------------------------------
  // Test 1: THIS WEEK section is visible on the home screen.
  //
  // The WeekBucketSection renders "THIS WEEK" text when routines exist and a
  // plan has been set. On a fresh user with no plan, it shows "Plan your week"
  // CTA. Both states confirm the section area is present.
  // ---------------------------------------------------------------------------
  test('home screen shows THIS WEEK section or Plan your week CTA when routines exist', async ({
    page,
  }) => {
    // After login, either "THIS WEEK" (plan set) or "Plan your week" CTA
    // (no plan yet) should appear in the home area. Both indicate the
    // WeekBucketSection is rendering correctly.
    const thisWeek = page.locator(WEEKLY_PLAN.thisWeekHeader);
    const planYourWeek = page.locator(WEEKLY_PLAN.planYourWeekCta);

    // Wait for one of the two states to appear.
    await expect(thisWeek.or(planYourWeek)).toBeVisible({ timeout: 15_000 });
  });

  // ---------------------------------------------------------------------------
  // Test 2: Navigate to plan management screen.
  //
  // The Plan Management screen (/plan/week) is reachable from the Home screen
  // by tapping the "Plan your week" CTA, or by long-pressing the chip row.
  // We navigate via the CTA path (most reliable for a fresh user with no plan).
  // ---------------------------------------------------------------------------
  test('tapping Plan your week CTA navigates to Plan Management screen', async ({
    page,
  }) => {
    // If the plan already exists (from a previous run), clear it first via
    // the Plan Management screen so we can reach the CTA.
    const thisWeekVisible = await page
      .locator(WEEKLY_PLAN.thisWeekHeader)
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    if (thisWeekVisible) {
      // Long-press on the chip row to open plan management.
      // WeekBucketSection wraps the chip ScrollView in a GestureDetector with
      // onLongPress: () => context.push('/plan/week').
      // For automation we navigate directly via URL instead.
      await page.goto('/plan/week');
      await waitForAppReady(page);
    } else {
      // Tap the "Plan your week" CTA.
      await page.locator(WEEKLY_PLAN.planYourWeekCta).click();
    }

    // Plan Management screen title is "This Week's Plan".
    await expect(page.locator(WEEKLY_PLAN.planManagementTitle)).toBeVisible({
      timeout: 15_000,
    });
  });

  // ---------------------------------------------------------------------------
  // Test 3: Add a routine to the weekly plan.
  //
  // From the Plan Management screen, tap "Add Routine" or "Add Routines" (empty
  // state button) to open the AddRoutinesSheet, select Push Day, and confirm.
  // Verify the routine appears in the plan list.
  // ---------------------------------------------------------------------------
  test('can add a routine to the weekly plan from Plan Management screen', async ({
    page,
  }) => {
    // Navigate via hash — page.goto('/plan/week') returns 404 from the
    // Python file server which has no SPA fallback routing.
    await page.evaluate(() => { window.location.hash = '#/plan/week'; });
    await page.waitForTimeout(2_000);

    await expect(page.locator(WEEKLY_PLAN.planManagementTitle)).toBeVisible({
      timeout: 15_000,
    });

    // Clear any existing plan so we can add fresh. Use the popup menu.
    // The AppBar overflow menu has "Clear Week" option.
    // For a fresh user the plan is empty, but we handle the case where
    // previous test runs left state behind.
    const popupButton = page.locator(WEEKLY_PLAN.overflowMenuButton);

    const popupVisible = await popupButton.isVisible({ timeout: 3_000 }).catch(() => false);
    if (popupVisible) {
      await popupButton.click();
      const clearWeek = page.locator(WEEKLY_PLAN.clearWeekOption);
      const clearVisible = await clearWeek.isVisible({ timeout: 3_000 }).catch(() => false);
      if (clearVisible) {
        await clearWeek.click();
        // Confirm the clear dialog.
        const clearConfirm = page.locator(WEEKLY_PLAN.clearConfirmButton);
        const dialogShown = await clearConfirm.isVisible({ timeout: 5_000 }).catch(() => false);
        if (dialogShown) {
          await clearConfirm.click();
          // After clearing, context.pop() navigates away — navigate back via hash.
          await page.waitForTimeout(1_000);
          await page.evaluate(() => { window.location.hash = '#/plan/week'; });
          await page.waitForTimeout(2_000);
        }
      } else {
        // Popup opened but no clear needed — dismiss the popup with Escape.
        await page.keyboard.press('Escape');
        await page.waitForTimeout(500);
      }
    }

    // Dismiss any lingering popup overlay (Escape closes Flutter popups).
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);

    // Ensure we're on the plan management screen.
    await expect(page.locator(WEEKLY_PLAN.planManagementTitle)).toBeVisible({
      timeout: 10_000,
    });

    // Tap "Add Routines" button (empty state) or "Add Routine" row.
    const addRoutinesBtn = page.locator(WEEKLY_PLAN.addRoutinesButton)
      .or(page.locator(WEEKLY_PLAN.addRoutineRow));
    await expect(addRoutinesBtn.first()).toBeVisible({ timeout: 10_000 });
    await addRoutinesBtn.first().click();

    // AddRoutinesSheet appears. Select Push Day.
    await expect(page.locator(WEEKLY_PLAN.addRoutinesSheetTitle)).toBeVisible({
      timeout: 10_000,
    });

    // Tap the Push Day tile in the sheet.
    const pushDayTile = page.locator(`text=${PUSH_DAY}`).first();
    await expect(pushDayTile).toBeVisible({ timeout: 10_000 });
    await pushDayTile.click();

    // Confirm with "ADD 1 ROUTINE" button.
    await expect(page.locator(WEEKLY_PLAN.addConfirmButton)).toBeVisible({
      timeout: 5_000,
    });
    await page.locator(WEEKLY_PLAN.addConfirmButton).click();

    // Push Day should now appear as a row in the plan.
    await expect(page.locator(`text=${PUSH_DAY}`).first()).toBeVisible({
      timeout: 10_000,
    });
  });

  // ---------------------------------------------------------------------------
  // Test 4: Routine chip appears on Home screen after plan is set.
  //
  // After adding Push Day to the plan, go back to Home and verify a chip
  // with the routine name is visible in the THIS WEEK section.
  // ---------------------------------------------------------------------------
  test('routine chip appears on Home screen when routine is in the plan', async ({
    page,
  }) => {
    // Ensure Push Day is in the plan by navigating to plan management.
    // Navigate via hash — page.goto('/plan/week') returns 404 from the
    // Python file server which has no SPA fallback routing.
    await page.evaluate(() => { window.location.hash = '#/plan/week'; });
    await page.waitForTimeout(2_000);
    await expect(page.locator(WEEKLY_PLAN.planManagementTitle)).toBeVisible({
      timeout: 15_000,
    });

    // Check if Push Day is already in the list.
    const alreadyIn = await page
      .locator(`text=${PUSH_DAY}`)
      .first()
      .isVisible({ timeout: 3_000 })
      .catch(() => false);

    if (!alreadyIn) {
      // Add it.
      const addBtn = page.locator(WEEKLY_PLAN.addRoutinesButton)
        .or(page.locator(WEEKLY_PLAN.addRoutineRow));
      await addBtn.first().click();
      await expect(page.locator(WEEKLY_PLAN.addRoutinesSheetTitle)).toBeVisible({
        timeout: 10_000,
      });
      await page.locator(`text=${PUSH_DAY}`).first().click();
      await page.locator(WEEKLY_PLAN.addConfirmButton).click();
      await expect(page.locator(`text=${PUSH_DAY}`).first()).toBeVisible({
        timeout: 10_000,
      });
    }

    // Navigate to Home.
    await navigateToTab(page, 'Home');

    // The THIS WEEK section should now show and Push Day chip should be visible.
    await expect(page.locator(WEEKLY_PLAN.thisWeekHeader)).toBeVisible({
      timeout: 15_000,
    });
    // The chip text content includes the routine name.
    await expect(page.locator(`text=${PUSH_DAY}`).first()).toBeVisible({
      timeout: 10_000,
    });
  });

  // ---------------------------------------------------------------------------
  // Test 5: Remove routine from plan — verify it disappears.
  //
  // Go to Plan Management, use "Clear Week" to remove all routines.
  // Navigate back to Home and verify the section reverts to "Plan your week" CTA.
  // ---------------------------------------------------------------------------
  test('clearing the plan removes routines from the Home screen section', async ({
    page,
  }) => {
    // Ensure there is at least one routine in the plan first.
    // Navigate via hash — page.goto('/plan/week') returns 404 from the
    // Python file server which has no SPA fallback routing.
    await page.evaluate(() => { window.location.hash = '#/plan/week'; });
    await page.waitForTimeout(2_000);
    await expect(page.locator(WEEKLY_PLAN.planManagementTitle)).toBeVisible({
      timeout: 15_000,
    });

    const alreadyIn = await page
      .locator(`text=${PUSH_DAY}`)
      .first()
      .isVisible({ timeout: 3_000 })
      .catch(() => false);

    if (!alreadyIn) {
      const addBtn = page.locator(WEEKLY_PLAN.addRoutinesButton)
        .or(page.locator(WEEKLY_PLAN.addRoutineRow));
      const addVisible = await addBtn.first().isVisible({ timeout: 5_000 }).catch(() => false);
      if (addVisible) {
        await addBtn.first().click();
        await expect(page.locator(WEEKLY_PLAN.addRoutinesSheetTitle)).toBeVisible({
          timeout: 10_000,
        });
        await page.locator(`text=${PUSH_DAY}`).first().click();
        await page.locator(WEEKLY_PLAN.addConfirmButton).click();
        await expect(page.locator(`text=${PUSH_DAY}`).first()).toBeVisible({
          timeout: 10_000,
        });
      }
    }

    // Now clear the week via the popup menu.
    // The PopupMenuButton is wrapped in Semantics(label: 'More options').
    const popupButton = page.locator(WEEKLY_PLAN.overflowMenuButton);
    await expect(popupButton).toBeVisible({ timeout: 5_000 });
    await popupButton.click();

    await expect(page.locator(WEEKLY_PLAN.clearWeekOption)).toBeVisible({
      timeout: 5_000,
    });
    await page.locator(WEEKLY_PLAN.clearWeekOption).click();

    // Confirm the "Clear Week" dialog.
    await expect(page.locator(WEEKLY_PLAN.clearConfirmButton)).toBeVisible({
      timeout: 5_000,
    });
    await page.locator(WEEKLY_PLAN.clearConfirmButton).click();

    // After clearing, we pop back to home or re-navigate.
    // Allow some time for navigation.
    await page.waitForTimeout(1_000);

    // Navigate to Home.
    await navigateToTab(page, 'Home');

    // Home should now show "Plan your week" CTA (no plan set).
    await expect(page.locator(WEEKLY_PLAN.planYourWeekCta)).toBeVisible({
      timeout: 15_000,
    });
  });
});
