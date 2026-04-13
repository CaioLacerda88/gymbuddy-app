/**
 * Manage Data full spec — delete history, reset all, and regression guards.
 *
 * Tests:
 *  1. MD-001 — Profile screen has a "Manage Data" row
 *  2. MD-002 — Tapping "Manage Data" navigates to the Manage Data screen
 *  3. MD-003 — Manage Data screen shows "Delete Workout History" tile with count
 *  4. MD-004 — Manage Data screen shows "Reset All Account Data" tile
 *  5. MD-005 — Cancel at first delete-history dialog leaves data intact
 *  6. MD-006 — Full delete-history confirmation flow clears history
 *  7. MD-007 — After deletion no error messages expose raw database table names
 *  8. MD-008 — Reset All: "Reset Account" button disabled until RESET is typed
 *  9. MD-009 — Cancel on Reset All modal leaves data intact
 * 10. MD-010 — Full Reset All flow clears workouts and PRs
 * 11. MD-011 (regression) — No raw DB table names visible in any error or
 *     SnackBar text after delete operations
 *
 * The delete-bug regression (MD-007 / MD-011) catches the specific failure mode
 * where the error handler surfaced the raw Supabase table name in a SnackBar,
 * e.g. "Failed to clear history: relation \"workouts\" does not exist".
 *
 * Uses the dedicated `fullManageData` test user.
 * The Flutter web app is served automatically by Playwright's webServer config
 * during local dev. In CI the FLUTTER_APP_URL env var is set by the workflow.
 */

import { test, expect, type Page } from '@playwright/test';
import { flutterFill, navigateToTab } from '../helpers/app';
import { login } from '../helpers/auth';
import { NAV, WORKOUT, PROFILE, MANAGE_DATA, PR, HISTORY, HOME_STATS } from '../helpers/selectors';
import {
  startEmptyWorkout,
  addExercise,
  setWeight,
  setReps,
  completeSet,
  finishWorkout,
} from '../helpers/workout';
import { TEST_USERS } from '../fixtures/test-users';
import { SEED_EXERCISES } from '../fixtures/test-exercises';

const USER = TEST_USERS.fullManageData;

// ---------------------------------------------------------------------------
// Raw DB table names that must NEVER appear in visible page text.
// This list is the regression guard — if error messages ever leak internal
// Supabase/Postgres identifiers again, this array catches it.
// ---------------------------------------------------------------------------
const FORBIDDEN_TABLE_NAMES = [
  'workouts',
  'workout_exercises',
  'sets',
  'personal_records',
  'profiles',
] as const;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Complete a single-exercise workout with one set so there is data to delete.
 * Dismisses the PR celebration if shown.
 */
async function doWorkoutAndReturnHome(page: Page): Promise<void> {
  await startEmptyWorkout(page);
  await addExercise(page, SEED_EXERCISES.benchPress);
  await setWeight(page, '60');
  await setReps(page, '5');
  await completeSet(page, 0);
  await finishWorkout(page);

  const isCelebration = await page
    .locator(PR.firstWorkoutHeading)
    .isVisible({ timeout: 15_000 })
    .catch(() => false);
  const isNewPR = await page
    .locator(PR.newPRHeading)
    .isVisible({ timeout: isCelebration ? 0 : 3_000 })
    .catch(() => false);

  if (isCelebration || isNewPR) {
    await page.click(PR.continueButton);
  }

  await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
}

/** Navigate to Profile → Manage Data screen. */
async function openManageData(page: Page): Promise<void> {
  await navigateToTab(page, 'Profile');
  await expect(page.locator(PROFILE.manageData)).toBeVisible({ timeout: 10_000 });
  await page.click(PROFILE.manageData);
  await expect(page.locator(MANAGE_DATA.heading)).toBeVisible({ timeout: 15_000 });
}

/**
 * Assert that no currently visible page text contains any of the forbidden
 * database table names. Checks all flt-semantics aria-labels and text nodes.
 *
 * This is the regression guard for the delete bug: if Supabase returns an
 * error like 'relation "workouts" does not exist' and the app forwards that
 * message verbatim to the UI, this assertion catches it.
 */
async function assertNoTableNamesVisible(page: Page): Promise<void> {
  // Gather all accessible text from flt-semantics accessible names (snackbars,
  // dialogs, headings) and visible text nodes.
  // Flutter 3.41.6+ uses AOM — try ariaLabel JS property first, then DOM attr.
  const visibleText = await page.evaluate(() => {
    const labels = Array.from(document.querySelectorAll('flt-semantics'))
      .map((el) => (el as any).ariaLabel ?? el.getAttribute('aria-label') ?? '')
      .join(' ');
    const bodyText = document.body.innerText ?? '';
    return (labels + ' ' + bodyText).toLowerCase();
  });

  for (const tableName of FORBIDDEN_TABLE_NAMES) {
    // We only care if the table name appears in a context that looks like an
    // error. A table name in normal data (e.g. the word "sets" in "3 sets")
    // could be a false positive. We check for the table name surrounded by
    // quotes or preceded by "relation" which is a Postgres error pattern.
    const dangerPatterns = [
      `relation "${tableName}"`,
      `table "${tableName}"`,
      `"${tableName}"`,
    ];
    for (const pattern of dangerPatterns) {
      expect(
        visibleText,
        `Found forbidden DB identifier "${pattern}" in visible page text`,
      ).not.toContain(pattern);
    }
  }
}

// ---------------------------------------------------------------------------
// Spec
// ---------------------------------------------------------------------------

test.describe('Manage Data — full suite', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, USER.email, USER.password);
  });

  // -------------------------------------------------------------------------
  // MD-001 — Profile screen has a "Manage Data" row
  // -------------------------------------------------------------------------
  test('MD-001: Profile screen shows a Manage Data row in the DATA MANAGEMENT section', async ({
    page,
  }) => {
    await navigateToTab(page, 'Profile');

    await expect(page.locator(PROFILE.manageData)).toBeVisible({
      timeout: 10_000,
    });
  });

  // -------------------------------------------------------------------------
  // MD-002 — Tapping "Manage Data" navigates to the Manage Data screen
  // -------------------------------------------------------------------------
  test('MD-002: tapping Manage Data row navigates to the Manage Data screen', async ({
    page,
  }) => {
    await openManageData(page);

    // Both main sections must be visible on the screen.
    await expect(page.locator(MANAGE_DATA.deleteHistory)).toBeVisible({
      timeout: 10_000,
    });
    await expect(page.locator(MANAGE_DATA.resetAll)).toBeVisible({
      timeout: 5_000,
    });
  });

  // -------------------------------------------------------------------------
  // MD-003 — Delete Workout History tile shows workout count subtitle
  //
  // ManageDataScreen renders the subtitle as "$workoutCountText workouts will
  // be removed". We verify the word "workouts" appears in the subtitle.
  // -------------------------------------------------------------------------
  test('MD-003: Delete Workout History tile shows a workout count subtitle', async ({
    page,
  }) => {
    await openManageData(page);

    // The subtitle text "N workouts will be removed" (or "... workouts")
    // must appear on screen.
    await expect(page.locator('text=/workouts will be removed/')).toBeVisible({
      timeout: 10_000,
    });
  });

  // -------------------------------------------------------------------------
  // MD-004 — Reset All Account Data tile is visible with "Removes everything" subtitle
  // -------------------------------------------------------------------------
  test('MD-004: Reset All Account Data tile is visible with danger subtitle', async ({
    page,
  }) => {
    await openManageData(page);

    await expect(page.locator(MANAGE_DATA.resetAll)).toBeVisible({
      timeout: 10_000,
    });

    // The subtitle "Removes everything. Permanent." must accompany the tile.
    await expect(page.locator('text=Removes everything')).toBeVisible({
      timeout: 5_000,
    });
  });

  // -------------------------------------------------------------------------
  // MD-005 — Cancel at the first delete-history dialog leaves data intact
  //
  // The two-step dialog: first dialog has "Delete History" + "Cancel".
  // Pressing Cancel must dismiss the dialog without deleting anything.
  // We verify the history screen still shows a workout afterwards.
  // -------------------------------------------------------------------------
  test('MD-005: cancelling the first delete-history dialog leaves workout data intact', async ({
    page,
  }) => {
    // Log a workout so there is something to cancel-delete.
    await doWorkoutAndReturnHome(page);

    await openManageData(page);

    // Open the delete history flow.
    await page.click(MANAGE_DATA.deleteHistory);

    // The first dialog must appear.
    await expect(
      page.locator('text=Delete all workout history?'),
    ).toBeVisible({ timeout: 8_000 });

    // Cancel — do NOT proceed.
    await page.click('text=Cancel');

    // The dialog must dismiss and we should still be on the Manage Data screen.
    await expect(
      page.locator('text=Delete all workout history?'),
    ).not.toBeVisible({ timeout: 5_000 });
    await expect(page.locator(MANAGE_DATA.heading)).toBeVisible({
      timeout: 5_000,
    });

    // Navigate to history via SPA navigation (page.goto reloads the Flutter
    // SPA and the router doesn't preserve the deep link).
    await navigateToTab(page, 'Home');
    await page.click(HOME_STATS.lastSessionCell);
    await expect(page.locator(HISTORY.heading)).toBeVisible({ timeout: 15_000 });

    // The history list must NOT show the empty state — at least one workout exists.
    await expect(page.locator(HISTORY.emptyState)).not.toBeVisible({
      timeout: 5_000,
    });
  });

  // -------------------------------------------------------------------------
  // MD-006 — Full delete-history flow clears the workout history
  //
  // Both confirmation dialogs are accepted. Afterwards the history screen must
  // show the empty state and the manage-data subtitle must show 0 workouts.
  // -------------------------------------------------------------------------
  test('MD-006: confirming both delete-history dialogs clears all workout history', async ({
    page,
  }) => {
    // Ensure at least one workout exists.
    await doWorkoutAndReturnHome(page);

    await openManageData(page);

    // Tap the tile to start the flow.
    await page.click(MANAGE_DATA.deleteHistory);

    // First dialog — confirm.
    await expect(
      page.locator('text=Delete all workout history?'),
    ).toBeVisible({ timeout: 8_000 });
    await page.click(MANAGE_DATA.deleteHistoryConfirmButton);

    // Second dialog — confirm.
    await expect(page.locator('text=Are you sure?')).toBeVisible({
      timeout: 8_000,
    });
    await page.click(MANAGE_DATA.yesDeleteButton);

    // The success SnackBar must appear.
    await expect(page.locator(MANAGE_DATA.historyCleared).first()).toBeVisible({
      timeout: 10_000,
    });

    // No DB table names in visible text (regression check for the delete bug).
    await assertNoTableNamesVisible(page);

    // Navigate to history via SPA navigation.
    await navigateToTab(page, 'Home');
    await page.click(HOME_STATS.lastSessionCell);
    await expect(page.locator(HISTORY.heading)).toBeVisible({ timeout: 15_000 });
    await expect(page.locator(HISTORY.emptyState)).toBeVisible({
      timeout: 10_000,
    });
  });

  // -------------------------------------------------------------------------
  // MD-007 (regression) — No raw DB table names visible after delete-history
  //
  // This is the direct regression test for the production bug where error
  // messages like 'Failed to clear history: relation "workouts" does not exist'
  // were shown to users. We perform the delete flow and assert the entire
  // visible DOM contains none of the forbidden patterns.
  //
  // Even if the operation itself succeeds, the test runs assertNoTableNamesVisible
  // to catch any future regression where internal identifiers leak to the UI.
  // -------------------------------------------------------------------------
  test('MD-007 (regression): delete history does not expose raw database table names in the UI', async ({
    page,
  }) => {
    await doWorkoutAndReturnHome(page);
    await openManageData(page);

    await page.click(MANAGE_DATA.deleteHistory);

    await expect(
      page.locator('text=Delete all workout history?'),
    ).toBeVisible({ timeout: 8_000 });
    await page.click(MANAGE_DATA.deleteHistoryConfirmButton);

    await expect(page.locator('text=Are you sure?')).toBeVisible({
      timeout: 8_000,
    });
    await page.click(MANAGE_DATA.yesDeleteButton);

    // Wait for either success SnackBar or for the dialog to close.
    // Then immediately check for forbidden identifiers — the bug manifested
    // as a SnackBar appearing with the table name in the message.
    await expect(page.locator(MANAGE_DATA.historyCleared).first()).toBeVisible({ timeout: 10_000 });

    await assertNoTableNamesVisible(page);

    // Also assert there is no generic error SnackBar that could carry an
    // internal message (belt-and-suspenders).
    await expect(page.locator('text=Failed to clear history')).not.toBeVisible({
      timeout: 3_000,
    });
  });

  // -------------------------------------------------------------------------
  // MD-008 — Reset All: "Reset Account" button is disabled until RESET is typed
  //
  // _ResetAllDialogState enables the GradientButton only when
  // _controller.text.trim().toUpperCase() == 'RESET'.
  // When disabled, GradientButton receives onPressed: null.
  // -------------------------------------------------------------------------
  test('MD-008: Reset Account button is disabled until RESET is typed in the confirmation field', async ({
    page,
  }) => {
    await openManageData(page);

    // Open the Reset All modal.
    await page.click(MANAGE_DATA.resetAll);

    // The full-screen modal must appear (AppBar shows "Reset Account Data").
    await expect(page.locator('text=Reset Account Data')).toBeVisible({
      timeout: 8_000,
    });

    // The "Reset Account" button must be present but disabled (not tappable).
    // Flutter renders a disabled GradientButton with onPressed: null.
    // We verify the button exists but clicking it does NOT close the dialog.
    await expect(page.locator(MANAGE_DATA.resetButton)).toBeVisible({
      timeout: 5_000,
    });

    // The modal stays open after clicking the disabled button.
    await page.click(MANAGE_DATA.resetButton, { force: true });
    await expect(page.locator('text=Reset Account Data')).toBeVisible({
      timeout: 3_000,
    });

    // Type the wrong word — button must remain disabled.
    await flutterFill(page, 'role=dialog >> role=textbox', 'wrong');
    await page.waitForTimeout(500); // debounce — no condition to wait for
    await page.click(MANAGE_DATA.resetButton, { force: true });
    await expect(page.locator('text=Reset Account Data')).toBeVisible({
      timeout: 3_000,
    });

    // Type the correct word "RESET" — button must become enabled.
    // First clear the field using the Flutter fill helper.
    await flutterFill(page, 'role=dialog >> role=textbox', 'RESET');
    await expect(page.locator(MANAGE_DATA.resetButton)).not.toHaveAttribute('aria-disabled', 'true', { timeout: 5_000 });

    // Now clicking the button should close the modal (pop(true)) and trigger
    // the reset. We close by clicking Cancel instead to avoid side effects.
    await page.click(MANAGE_DATA.resetCancelButton);
    await expect(page.locator('text=Reset Account Data')).not.toBeVisible({
      timeout: 5_000,
    });
  });

  // -------------------------------------------------------------------------
  // MD-009 — Cancel on Reset All modal leaves data intact
  //
  // The _ResetAllDialog Cancel button calls Navigator.of(context).pop(false).
  // The close (X) icon calls Navigator.of(context).pop(false) as well.
  // Neither triggers the actual reset.
  // -------------------------------------------------------------------------
  test('MD-009: cancelling the Reset All modal leaves all data intact', async ({
    page,
  }) => {
    // Log a workout so there is data to preserve.
    await doWorkoutAndReturnHome(page);

    await openManageData(page);

    await page.click(MANAGE_DATA.resetAll);

    // Modal must open.
    await expect(page.locator('text=Reset Account Data')).toBeVisible({
      timeout: 8_000,
    });

    // Cancel via the X button in the AppBar.
    await page.click(MANAGE_DATA.resetCancelButton);

    // Modal must close.
    await expect(page.locator('text=Reset Account Data')).not.toBeVisible({
      timeout: 5_000,
    });

    // We must still be on the Manage Data screen.
    await expect(page.locator(MANAGE_DATA.heading)).toBeVisible({
      timeout: 5_000,
    });

    // Navigate to history via SPA navigation.
    await navigateToTab(page, 'Home');
    await page.click(HOME_STATS.lastSessionCell);
    await expect(page.locator(HISTORY.heading)).toBeVisible({ timeout: 15_000 });
    await expect(page.locator(HISTORY.emptyState)).not.toBeVisible({
      timeout: 5_000,
    });
  });

  // -------------------------------------------------------------------------
  // MD-010 — Full Reset All flow clears workouts and PRs
  //
  // Types "RESET", confirms, and verifies:
  //   - Success SnackBar "Account data reset" appears
  //   - Workout history is now empty
  //   - No DB table names are visible at any point (regression guard)
  // -------------------------------------------------------------------------
  test('MD-010: confirming Reset All clears all workout history and personal records', async ({
    page,
  }) => {
    // Create data to reset.
    await doWorkoutAndReturnHome(page);

    await openManageData(page);

    await page.click(MANAGE_DATA.resetAll);

    await expect(page.locator('text=Reset Account Data')).toBeVisible({
      timeout: 8_000,
    });

    // Type RESET to enable the confirm button.
    await flutterFill(page, 'role=dialog >> role=textbox', 'RESET');
    await expect(page.locator(MANAGE_DATA.resetButton)).not.toHaveAttribute('aria-disabled', 'true', { timeout: 5_000 });

    // Click the now-enabled "Reset Account" button.
    await page.click(MANAGE_DATA.resetButton);

    // The success SnackBar must appear.
    await expect(page.locator(MANAGE_DATA.accountReset).first()).toBeVisible({
      timeout: 10_000,
    });

    // Regression guard: no table names visible.
    await assertNoTableNamesVisible(page);

    // Verify history is empty.
    await navigateToTab(page, 'Home');
    await page.click(HOME_STATS.lastSessionCell);
    await expect(page.locator(HISTORY.heading)).toBeVisible({ timeout: 15_000 });
    await expect(page.locator(HISTORY.emptyState)).toBeVisible({
      timeout: 10_000,
    });
  });

  // -------------------------------------------------------------------------
  // MD-011 (regression) — No raw DB table names visible after Reset All
  //
  // Mirror of MD-007 but for the resetAllAccountData path.
  // resetAllAccountData calls prRepo.clearAllRecords in addition to
  // workoutRepo.clearHistory — two separate Supabase operations that could
  // each leak a table name if either fails.
  // -------------------------------------------------------------------------
  test('MD-011 (regression): Reset All does not expose raw database table names in the UI', async ({
    page,
  }) => {
    await doWorkoutAndReturnHome(page);
    await openManageData(page);

    await page.click(MANAGE_DATA.resetAll);

    await expect(page.locator('text=Reset Account Data')).toBeVisible({
      timeout: 8_000,
    });

    await flutterFill(page, 'role=dialog >> role=textbox', 'RESET');
    await expect(page.locator(MANAGE_DATA.resetButton)).not.toHaveAttribute('aria-disabled', 'true', { timeout: 5_000 });

    await page.click(MANAGE_DATA.resetButton);

    // Wait for the success SnackBar to confirm the operation completed.
    await expect(page.locator(MANAGE_DATA.accountReset).first()).toBeVisible({ timeout: 10_000 });

    // Check the full visible DOM for any forbidden identifiers.
    await assertNoTableNamesVisible(page);

    // Assert no "Failed to reset data" SnackBar appeared.
    await expect(page.locator('text=Failed to reset data')).not.toBeVisible({
      timeout: 3_000,
    });
  });
});
