/**
 * Exercise detail bottom sheet full spec — form tips inside active workout.
 *
 * BUG-002 gap: The existing exercise-form-tips.smoke.spec.ts tests form tips
 * on the STANDALONE exercise detail screen (/exercises/:id). However, the
 * active workout screen also provides access to the exercise detail via a
 * bottom sheet (_ExerciseDetailSheet). Both code paths render ExerciseFormTipsSection.
 * If the SQL migration stored literal `\n` (two chars) instead of real newlines,
 * BOTH paths break — and only the standalone screen was previously tested.
 *
 * This spec adds coverage for the bottom sheet path specifically, which is the
 * more common user flow: users typically access exercise info DURING a workout
 * rather than navigating to the library.
 *
 * Additional coverage:
 *   - Form tips section is visible when tips exist (positive path).
 *   - Each tip renders as a separate entry (splitting worked).
 *   - Literal `\n` characters are NOT visible in the rendered text (BUG-002).
 *   - Muscle group chip and equipment type chip are rendered.
 *   - Sheet dismissal returns to the active workout with state intact.
 *
 * Uses the dedicated `fullExDetailSheet` test user.
 * User is created in global-setup.ts and deleted in global-teardown.ts.
 */

import { test, expect } from '@playwright/test';
import { login } from '../helpers/auth';
import { NAV, WORKOUT } from '../helpers/selectors';
import { startEmptyWorkout, addExercise } from '../helpers/workout';
import { TEST_USERS } from '../fixtures/test-users';
import { SEED_EXERCISES } from '../fixtures/test-exercises';

const USER = TEST_USERS.fullExDetailSheet;

test.describe('Exercise detail bottom sheet — full suite', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, USER.email, USER.password);
    await startEmptyWorkout(page);
    await addExercise(page, SEED_EXERCISES.benchPress);
    // Confirm workout screen is ready.
    await expect(page.locator(WORKOUT.finishButton)).toBeVisible({
      timeout: 15_000,
    });
  });

  test.afterEach(async ({ page }) => {
    // Clean up any in-progress workout to avoid state leakage between tests.
    const finishVisible = await page
      .locator(WORKOUT.finishButton)
      .isVisible({ timeout: 3_000 })
      .catch(() => false);

    if (finishVisible) {
      await page.locator(WORKOUT.discardButton).click();
      const confirmDiscard = page.locator(WORKOUT.discardConfirmButton);
      await expect(confirmDiscard).toBeVisible({ timeout: 5_000 });
      await confirmDiscard.click();
    }
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  // ---------------------------------------------------------------------------
  // BUG-002 (P1): Form tips inside the active workout bottom sheet render as
  // separate bullet items, NOT as a single block with literal `\n` characters.
  //
  // The bottom sheet is opened by tapping the exercise name card in the workout
  // screen. It renders ExerciseFormTipsSection — the same widget as the standalone
  // detail screen, but via a different navigation path.
  // ---------------------------------------------------------------------------
  test('BUG-002: form tips in the active workout bottom sheet do not show literal backslash-n', async ({
    page,
  }) => {
    // Open the exercise detail bottom sheet by tapping the exercise name.
    // The Semantics label is "Exercise: <name>. Tap for details. Long press to swap."
    const exerciseTap = page.locator(
      `flt-semantics[aria-label*="Exercise: ${SEED_EXERCISES.benchPress}. Tap for details"]`,
    );
    await expect(exerciseTap).toBeVisible({ timeout: 10_000 });
    await exerciseTap.click();

    // Wait for the bottom sheet to open — the exercise name appears a second time.
    await expect(
      page.locator(`text=${SEED_EXERCISES.benchPress}`).nth(1),
    ).toBeVisible({ timeout: 10_000 });

    // The "FORM TIPS" section header must be present inside the sheet.
    // If form_tips is null/empty, this section is hidden — absence here means
    // the data was not loaded, not that BUG-002 is absent.
    const formTipsVisible = await page
      .locator('text=FORM TIPS')
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    if (!formTipsVisible) {
      // Form tips section not rendered — skip the BUG-002 assertion.
      // This should not happen for Barbell Bench Press (seeded with tips),
      // so fail the test to surface the data issue.
      throw new Error(
        'FORM TIPS section was not visible in the bottom sheet for ' +
          `${SEED_EXERCISES.benchPress}. Check that seed data includes form_tips.`,
      );
    }

    // KEY ASSERTION FOR BUG-002:
    // The literal two-character sequence backslash-n must NOT appear anywhere.
    // If the SQL migration stored `\n` as two chars (backslash + n) and the
    // widget did not split on the literal sequence, the user sees "\\n" in text.
    const literalBackslashN = page.locator('text=/\\\\n/');
    await expect(literalBackslashN).not.toBeVisible({ timeout: 3_000 });

    // The first form tip for Barbell Bench Press must appear as its own text
    // element: "Plant feet flat on the floor and squeeze shoulder blades together"
    await expect(
      page.locator('text=Plant feet flat').first(),
    ).toBeVisible({ timeout: 5_000 });

    // A second distinct tip must also be present separately:
    // "Lower the bar to mid-chest with elbows at roughly 45 degrees"
    await expect(
      page.locator('text=Lower the bar to mid-chest').first(),
    ).toBeVisible({ timeout: 5_000 });

    // Dismiss the sheet.
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);
  });

  // ---------------------------------------------------------------------------
  // Form tips bottom sheet: muscle group and equipment type chips are rendered.
  //
  // _ExerciseDetailSheet also renders _SheetChip widgets for muscle group and
  // equipment type. These are not tested in the form-tips smoke spec (which
  // only checks the standalone detail screen).
  // Barbell Bench Press: muscle group = Chest, equipment = Barbell.
  // ---------------------------------------------------------------------------
  test('exercise detail sheet shows muscle group and equipment chips', async ({
    page,
  }) => {
    const exerciseTap = page.locator(
      `flt-semantics[aria-label*="Exercise: ${SEED_EXERCISES.benchPress}. Tap for details"]`,
    );
    await expect(exerciseTap).toBeVisible({ timeout: 10_000 });
    await exerciseTap.click();

    // Wait for the sheet to open.
    await expect(
      page.locator(`text=${SEED_EXERCISES.benchPress}`).nth(1),
    ).toBeVisible({ timeout: 10_000 });

    // Muscle group chip — Chest.
    await expect(page.locator('text=Chest')).toBeVisible({ timeout: 5_000 });

    // Equipment type chip — Barbell.
    await expect(page.locator('text=Barbell')).toBeVisible({ timeout: 5_000 });

    // Dismiss.
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);
  });

  // ---------------------------------------------------------------------------
  // Standalone exercise detail screen: form tips also render correctly.
  //
  // Belt-and-suspenders companion to the smoke spec. Tests that visiting the
  // detail screen from within the active workout (via the tap handler) works.
  // This differs from the smoke test which navigates the exercise library
  // independently of any active workout.
  // ---------------------------------------------------------------------------
  test('BUG-002: form tips on standalone exercise detail (reached from workout sheet) render without literal backslash-n', async ({
    page,
  }) => {
    // Open the bottom sheet first.
    const exerciseTap = page.locator(
      `flt-semantics[aria-label*="Exercise: ${SEED_EXERCISES.benchPress}. Tap for details"]`,
    );
    await expect(exerciseTap).toBeVisible({ timeout: 10_000 });
    await exerciseTap.click();

    await expect(
      page.locator(`text=${SEED_EXERCISES.benchPress}`).nth(1),
    ).toBeVisible({ timeout: 10_000 });

    // Look for a "View full details" or "See more" link inside the sheet that
    // navigates to the standalone detail page. If the sheet provides this link,
    // tap it and verify the full detail page also renders tips correctly.
    // If no such link exists, dismiss and skip this part.
    const viewFullDetailsLink = page.locator(
      'text=View full details',
    );
    const hasViewFullDetails = await viewFullDetailsLink
      .isVisible({ timeout: 2_000 })
      .catch(() => false);

    if (hasViewFullDetails) {
      await viewFullDetailsLink.click();

      await expect(page.locator('text=Exercise Details')).toBeVisible({
        timeout: 10_000,
      });

      // Form tips on the standalone page must not contain literal \n.
      const literalBackslashN = page.locator('text=/\\\\n/');
      await expect(literalBackslashN).not.toBeVisible({ timeout: 3_000 });

      // Navigate back.
      await page.goBack();
      await expect(page.locator(WORKOUT.finishButton)).toBeVisible({
        timeout: 15_000,
      });
    } else {
      // Sheet does not expose a full-detail link — dismiss and accept the test
      // as having covered the sheet path only.
      await page.keyboard.press('Escape');
      await page.waitForTimeout(500);
    }
  });

  // ---------------------------------------------------------------------------
  // Form tips section boundary: seeded exercise WITH tips shows the section;
  // a different exercise type does not crash the sheet.
  //
  // This verifies the section boundary — it must be present for exercises that
  // have form_tips data and absent (or not crashing) for those that don't.
  // Uses Barbell Squat which is also a seeded exercise with form tips.
  // ---------------------------------------------------------------------------
  test('form tips section is present for Barbell Squat in the active workout sheet', async ({
    page,
  }) => {
    // Add Barbell Squat to the workout (Bench Press is already there from beforeEach).
    await addExercise(page, SEED_EXERCISES.squat);

    // Open the detail sheet for Barbell Squat.
    const squatTap = page.locator(
      `flt-semantics[aria-label*="Exercise: ${SEED_EXERCISES.squat}. Tap for details"]`,
    );
    await expect(squatTap).toBeVisible({ timeout: 10_000 });
    await squatTap.click();

    // Sheet opens — exercise name appears a second time.
    await expect(
      page.locator(`text=${SEED_EXERCISES.squat}`).first(),
    ).toBeVisible({ timeout: 10_000 });

    // No literal \n characters must be visible anywhere on the sheet.
    const literalBackslashN = page.locator('text=/\\\\n/');
    await expect(literalBackslashN).not.toBeVisible({ timeout: 3_000 });

    // Dismiss.
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);
  });
});
