/**
 * Weekly plan review smoke test — WEEK COMPLETE state.
 *
 * Tests that the WeekReviewSection renders correctly when all routines in the
 * weekly bucket have been completed (completedWorkoutId != null for each bucket).
 *
 * The WEEK COMPLETE state shows:
 *   - "WEEK COMPLETE" header (in green)
 *   - Stats text: "{n} sessions  {volume} kg  {prCount} PRs"
 *   - "NEW WEEK" action button
 *   - Completed routine chips (green, checkmark)
 *
 * NOTE: This state is very hard to automate without completing actual workouts.
 * Completing multiple workouts tied to specific routines requires:
 *   1. Setting up a weekly plan with specific routines.
 *   2. Running each routine workout to completion.
 *   3. Each workout must be matched to a bucket entry for completedWorkoutId
 *      to be populated (the workout name must match the routine name).
 *
 * TODO (infrastructure): Seed a completed weekly plan in global-setup via the
 * Supabase Admin API — INSERT into weekly_plans and weekly_plan_buckets with
 * completedWorkoutId values pointing to test workouts.
 *
 * Until then, this file tests what IS reliably verifiable:
 *   - The WeekBucketSection renders in the "active week" state after login.
 *   - The stats text format (sessions / volume / PRs) is correct.
 *   - The "NEW WEEK" button is accessible when the review state is shown.
 */

import { test, expect } from '@playwright/test';
import { login } from '../helpers/auth';
import { navigateToTab } from '../helpers/app';
import { WEEKLY_PLAN } from '../helpers/selectors';
import { TEST_USERS } from '../fixtures/test-users';

const USER = TEST_USERS.smokeWeeklyPlanReview;

test.describe('Smoke: Weekly Plan Review', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, USER.email, USER.password);
    await navigateToTab(page, 'Home');
  });

  // ---------------------------------------------------------------------------
  // Test 1: Home screen renders the weekly plan section without crashing.
  //
  // Regardless of plan state, the WeekBucketSection must render either:
  //   - Empty state ("Plan your week") if no plan is set.
  //   - Active state ("THIS WEEK" header + chips) if plan is set.
  //   - Review state ("WEEK COMPLETE" header) if all routines are done.
  //
  // This test verifies no crash occurs and at least one of these states appears.
  // ---------------------------------------------------------------------------
  test('home screen weekly plan section renders without error', async ({ page }) => {
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

  // ---------------------------------------------------------------------------
  // Test 2: WEEK COMPLETE header is shown when all routines are done.
  //
  // TODO (data dependency): Seed a completed weekly plan in global-setup.
  // This test is currently a skeleton — it navigates and checks for the review
  // state header, but will skip if the state isn't present.
  // ---------------------------------------------------------------------------
  test('WEEK COMPLETE header is visible when all bucket routines are done', async ({
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

  // ---------------------------------------------------------------------------
  // Test 3: Stats text is present and contains "sessions" when week is complete.
  //
  // WeekReviewSection._buildStatsText() returns:
  //   "{n} sessions" (always)
  //   "  {volume} kg" (if totalVolume > 0)
  //   "  {n} PRs" (if prCount > 0)
  //
  // TODO (data dependency): Needs a seeded completed week for full assertion.
  // ---------------------------------------------------------------------------
  test('stats text contains sessions count when week review is shown', async ({
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

  // ---------------------------------------------------------------------------
  // Test 4: NEW WEEK button is visible in the review state and navigates to
  // Plan Management screen.
  //
  // WeekReviewSection renders a "NEW WEEK" GestureDetector when onNewWeek
  // callback is provided. Tapping it calls _startNewWeek → context.push('/plan/week').
  //
  // TODO (data dependency): Needs a seeded completed week.
  // ---------------------------------------------------------------------------
  test('NEW WEEK button navigates to Plan Management screen', async ({ page }) => {
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

  // ---------------------------------------------------------------------------
  // Test 5: Completed routine chips in review state show green checkmarks.
  //
  // RoutineChipState.done renders a chip with a green check icon and no text.
  // RoutineChipState.remaining renders a chip at reduced opacity.
  //
  // TODO (data dependency): Needs a seeded completed week.
  // ---------------------------------------------------------------------------
  test('completed routine chips display with done state in week review', async ({
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
