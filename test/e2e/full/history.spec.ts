/**
 * Workout history full spec.
 *
 * Tests:
 *  1. HIST-005 (P1) — Empty history state shown for a fresh user with no workouts.
 *     The selector HISTORY.emptyState ('text=No workouts yet') is asserted on
 *     a user who has never completed a workout.
 *
 * Uses the dedicated `fullHistory` test user, which is created in global-setup
 * with no workout data (fresh account).
 *
 * The Flutter web app is served automatically by Playwright's webServer config
 * during local dev. In CI the FLUTTER_APP_URL env var is set by the workflow.
 */

import { test, expect } from '@playwright/test';
import { login } from '../helpers/auth';
import { HISTORY } from '../helpers/selectors';
import { TEST_USERS } from '../fixtures/test-users';

const USER = TEST_USERS.fullHistory;

test.describe('Workout history — full suite', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, USER.email, USER.password);
  });

  // ---------------------------------------------------------------------------
  // HIST-005 (P1) — Empty history state with fresh user
  //
  // WorkoutHistoryScreen renders _EmptyHistoryBody when the workouts list is
  // empty. _EmptyHistoryBody displays "No workouts yet" (HISTORY.emptyState)
  // and a "Start your first workout" CTA (HISTORY.emptyStateCta).
  //
  // The fullHistory user is created fresh in global-setup with no workout data,
  // so this assertion is reliable on every run.
  // ---------------------------------------------------------------------------
  test('HIST-005: history screen shows empty state for a user with no completed workouts', async ({
    page,
  }) => {
    // Navigate to the history screen via the "View All" link if it exists,
    // or directly via the URL. A fresh user has no workouts, so "View All"
    // will not be shown on the home screen — we use direct navigation.
    await page.goto('/home/history');

    // The history screen AppBar title confirms we are on the right screen.
    await expect(page.locator(HISTORY.heading)).toBeVisible({ timeout: 15_000 });

    // The empty state text must be visible.
    await expect(page.locator(HISTORY.emptyState)).toBeVisible({
      timeout: 10_000,
    });

    // The call-to-action button must accompany the empty state.
    await expect(page.locator(HISTORY.emptyStateCta)).toBeVisible({
      timeout: 5_000,
    });

    // The "Retry" error button must NOT be visible — this is an empty state,
    // not an error state.
    await expect(page.locator(HISTORY.retryButton)).not.toBeVisible();
  });
});
