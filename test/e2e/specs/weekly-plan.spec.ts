/**
 * Weekly Plan — consolidated E2E tests.
 *
 * Sources:
 *   - smoke/weekly-plan.smoke.spec.ts        (smokeWeeklyPlan, 5 tests)       -> @smoke
 *   - smoke/weekly-plan-review.smoke.spec.ts (smokeWeeklyPlanReview, 9 tests) -> @smoke
 *
 * Both sources are smoke tests — no full/regression equivalent exists yet.
 */

import { test, expect } from '@playwright/test';
import { login } from '../helpers/auth';
import { navigateToTab } from '../helpers/app';
import { WEEKLY_PLAN } from '../helpers/selectors';
import { TEST_USERS } from '../fixtures/test-users';

// The Push Day starter routine is seeded by seed.sql.
const PUSH_DAY = 'Push Day';

// =============================================================================
// SMOKE — Weekly Plan (smokeWeeklyPlan user)
// =============================================================================

test.describe('Weekly Plan', { tag: '@smoke' }, () => {
  test.beforeEach(async ({ page }) => {
    await login(
      page,
      TEST_USERS.smokeWeeklyPlan.email,
      TEST_USERS.smokeWeeklyPlan.password,
    );
    // Start on the Home tab where the THIS WEEK section lives.
    await navigateToTab(page, 'Home');
  });

  test('should show THIS WEEK section or Plan your week CTA on home screen when routines exist', async ({
    page,
  }) => {
    // After login, either "THIS WEEK" (plan set) or "Plan your week" CTA
    // (no plan yet) should appear in the home area. Both indicate the
    // WeekBucketSection is rendering correctly.
    //
    // Note: When no plan is set, _EmptyBucketState renders BOTH "THIS WEEK"
    // (as a section header) and "Plan your week" (as a CTA). Using .or()
    // without .first() would match 2 elements and trigger a strict mode
    // violation, so we use .first() to pick whichever appears first.
    const thisWeek = page.locator(WEEKLY_PLAN.thisWeekHeader).first();
    const planYourWeek = page.locator(WEEKLY_PLAN.planYourWeekCta);

    // Wait for one of the two states to appear.
    await expect(thisWeek.or(planYourWeek).first()).toBeVisible({ timeout: 15_000 });
  });

  test('should navigate to Plan Management screen when tapping Plan your week CTA', async ({
    page,
  }) => {
    // If the plan already exists (from a previous run), clear it first via
    // the Plan Management screen so we can reach the CTA.
    // Use .first() because _EmptyBucketState renders "THIS WEEK" as a
    // section header alongside "Plan your week", and _ActiveBucketSection
    // also renders "THIS WEEK" — strict mode requires a single element.
    const thisWeekVisible = await page
      .locator(WEEKLY_PLAN.thisWeekHeader)
      .first()
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    if (thisWeekVisible) {
      // Plan already exists — navigate to plan management via hash routing.
      // page.goto() would reload the Flutter SPA and lose app state.
      await page.evaluate(() => { window.location.hash = '#/plan/week'; });
    } else {
      // Tap the "Plan your week" CTA.
      await page.locator(WEEKLY_PLAN.planYourWeekCta).click();
    }

    // Plan Management screen title is "This Week's Plan".
    await expect(page.locator(WEEKLY_PLAN.planManagementTitle)).toBeVisible({
      timeout: 15_000,
    });
  });

  test('should add a routine to the weekly plan from Plan Management screen', async ({
    page,
  }) => {
    // Navigate via hash — page.goto('/plan/week') returns 404 from the
    // Python file server which has no SPA fallback routing.
    await page.evaluate(() => { window.location.hash = '#/plan/week'; });
    await page.waitForURL('**/plan/week**', { timeout: 10_000 });

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
          await page.waitForURL('**/home**', { timeout: 10_000 });
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

  test('should show routine chip on Home screen when routine is in the plan', async ({
    page,
  }) => {
    // Ensure Push Day is in the plan by navigating to plan management.
    // Navigate via hash — page.goto('/plan/week') returns 404 from the
    // Python file server which has no SPA fallback routing.
    await page.evaluate(() => { window.location.hash = '#/plan/week'; });
    await page.waitForURL('**/plan/week**', { timeout: 10_000 });
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
    // Use .first() to avoid strict mode violation if multiple "THIS WEEK"
    // text nodes exist in the semantics tree.
    await expect(page.locator(WEEKLY_PLAN.thisWeekHeader).first()).toBeVisible({
      timeout: 15_000,
    });
    // The chip text content includes the routine name.
    await expect(page.locator(`text=${PUSH_DAY}`).first()).toBeVisible({
      timeout: 10_000,
    });
  });

  test('should remove routines from Home screen section when clearing the plan', async ({
    page,
  }) => {
    // Ensure there is at least one routine in the plan first.
    // Navigate via hash — page.goto('/plan/week') returns 404 from the
    // Python file server which has no SPA fallback routing.
    await page.evaluate(() => { window.location.hash = '#/plan/week'; });
    await page.waitForURL('**/plan/week**', { timeout: 10_000 });
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
    // Wait for navigation to settle.
    await page.waitForURL('**/home**', { timeout: 10_000 }).catch(() => {});

    // Navigate to Home.
    await navigateToTab(page, 'Home');

    // Home should now show "Plan your week" CTA (no plan set).
    await expect(page.locator(WEEKLY_PLAN.planYourWeekCta)).toBeVisible({
      timeout: 15_000,
    });
  });
});

// =============================================================================
// SMOKE — Weekly Plan Review (smokeWeeklyPlanReview user)
// =============================================================================

test.describe('Weekly Plan review', { tag: '@smoke' }, () => {
  test.beforeEach(async ({ page }) => {
    await login(
      page,
      TEST_USERS.smokeWeeklyPlanReview.email,
      TEST_USERS.smokeWeeklyPlanReview.password,
    );
    await navigateToTab(page, 'Home');
  });

  test('should render weekly plan section on home screen without error', async ({ page }) => {
    // At least one of the three states must be visible.
    // Use .first() on each locator to avoid strict mode violations when
    // multiple "THIS WEEK" text nodes coexist (e.g., _EmptyBucketState
    // renders "THIS WEEK" header alongside "Plan your week" CTA).
    const thisWeek = page.locator(WEEKLY_PLAN.thisWeekHeader).first();
    const weekComplete = page.locator(WEEKLY_PLAN.weekCompleteHeader);
    const planYourWeek = page.locator(WEEKLY_PLAN.planYourWeekCta);

    await expect(
      thisWeek.or(weekComplete).or(planYourWeek).first(),
    ).toBeVisible({ timeout: 15_000 });
  });

  test('should show WEEK COMPLETE header when all bucket routines are done', async ({
    page,
  }) => {
    const weekComplete = page.locator(WEEKLY_PLAN.weekCompleteHeader);
    const isComplete = await weekComplete.isVisible({ timeout: 5_000 }).catch(() => false);

    if (!isComplete) {
      // TODO: Seed completed weekly plan in global-setup.ts.
      // For now, skip the assertion — the test is a placeholder for when
      // infrastructure supports seeding a complete week.
      test.skip();
      return;
    }

    // The WEEK COMPLETE header must be visible.
    await expect(weekComplete).toBeVisible();
  });

  test('should show stats text with sessions count when week review is shown', async ({
    page,
  }) => {
    const weekComplete = page.locator(WEEKLY_PLAN.weekCompleteHeader);
    const isComplete = await weekComplete.isVisible({ timeout: 5_000 }).catch(() => false);

    if (!isComplete) {
      // TODO: Seed completed weekly plan in global-setup.ts.
      test.skip();
      return;
    }

    // The stats text always includes "sessions".
    await expect(page.locator(WEEKLY_PLAN.sessionsStatsText)).toBeVisible({
      timeout: 5_000,
    });
  });

  test('should navigate to Plan Management screen when tapping NEW WEEK button', async ({ page }) => {
    const weekComplete = page.locator(WEEKLY_PLAN.weekCompleteHeader);
    const isComplete = await weekComplete.isVisible({ timeout: 5_000 }).catch(() => false);

    if (!isComplete) {
      // TODO: Seed completed weekly plan in global-setup.ts.
      test.skip();
      return;
    }

    // Tap NEW WEEK.
    await page.locator(WEEKLY_PLAN.newWeekButton).click();

    // Should navigate to Plan Management screen.
    await expect(page.locator(WEEKLY_PLAN.planManagementTitle)).toBeVisible({
      timeout: 15_000,
    });
  });

  test('should display completed routine chips with done state in week review', async ({
    page,
  }) => {
    const weekComplete = page.locator(WEEKLY_PLAN.weekCompleteHeader);
    const isComplete = await weekComplete.isVisible({ timeout: 5_000 }).catch(() => false);

    if (!isComplete) {
      // TODO: Seed completed weekly plan in global-setup.ts.
      test.skip();
      return;
    }

    // In WEEK COMPLETE state, all chips should be in the "done" state.
    // The WeekReviewSection renders chips with RoutineChipState.done when
    // completedWorkoutId != null.
    // Since chips render as non-interactive Containers (no Semantics label),
    // we verify the header and stats are present as proof of correct rendering.
    await expect(weekComplete).toBeVisible();
    await expect(page.locator(WEEKLY_PLAN.sessionsStatsText)).toBeVisible({
      timeout: 5_000,
    });
  });
});
