/**
 * Routine start smoke tests — P0/P1 regression coverage.
 *
 * Covers the regression bugs that shipped without E2E detection:
 *
 *   BUG-001 (P0): Exercise names survive a full page reload (Hive persistence).
 *     Start a routine → reload the page → resume → exercise name must NOT show
 *     the "Exercise" fallback — the actual name must be preserved.
 *
 *   BUG-003 (P1): Starting a routine whose exercises loaded correctly navigates
 *     to the active workout screen (positive path). A routine with exercises
 *     must NOT silently do nothing.
 *
 *   BUG-004 (P2): Routine start pre-fills non-zero weights for first-time
 *     exercises. A brand-new user who has never logged the exercise before
 *     must see a non-zero weight when starting a routine.
 *
 *   BUG-005 (P2): Routine list cards show muscle group names in the subtitle,
 *     not just a bare exercise count fallback ("6 exercises").
 *
 * Uses the dedicated `smokeRoutineStart` test user to keep state isolated.
 * User is created in global-setup.ts and deleted in global-teardown.ts.
 */

import { test, expect } from '@playwright/test';
import { login } from '../helpers/auth';
import { navigateToTab, waitForAppReady } from '../helpers/app';
import { NAV, ROUTINE, WORKOUT } from '../helpers/selectors';
import { TEST_USERS } from '../fixtures/test-users';

const USER = TEST_USERS.smokeRoutineStart;

// The Push Day starter routine is seeded by seed.sql and always present.
const PUSH_DAY = 'Push Day';

// "Barbell Bench Press" is a barbell exercise in Push Day.
// Its equipment default is 20 kg — so a first-time user must see non-zero weight.
const BENCH_PRESS = 'Barbell Bench Press';

test.describe('Routine start smoke', () => {
  test.beforeEach(async ({ page }) => {
    await login(page, USER.email, USER.password);
    await navigateToTab(page, 'Routines');
  });

  // ---------------------------------------------------------------------------
  // BUG-001 (P0): Exercise name persists after page reload
  //
  // Active workout state is serialised to Hive (IndexedDB in web). Before the
  // fix, WorkoutExercise.exercise was excluded from toJson
  // (@JsonKey(includeToJson: false)), so on restore exercise was null and the
  // UI fell back to rendering "Exercise" as the card header.
  //
  // This test is deliberately in the SMOKE suite because the bug is P0 — it
  // must be caught on every CI run, not just the full suite.
  // ---------------------------------------------------------------------------
  test('BUG-001: exercise name is preserved (not "Exercise" fallback) after page reload', async ({
    page,
  }) => {
    // Start a workout from the Push Day routine.
    await expect(page.locator(ROUTINE.starterRoutinesSection)).toBeVisible({
      timeout: 10_000,
    });
    await page.locator(ROUTINE.routineName(PUSH_DAY)).first().click();

    // The active workout screen must load with exercises pre-filled.
    await expect(page.locator(WORKOUT.finishButton)).toBeVisible({
      timeout: 20_000,
    });

    // Bench Press must be visible in the exercise card before reload.
    await expect(page.locator(`text=${BENCH_PRESS}`)).toBeVisible({
      timeout: 10_000,
    });

    // Simulate app restore by reloading the page (preserves IndexedDB/Hive).
    await page.reload();

    // Wait for the app to re-initialise and route to home or active workout.
    await page.waitForFunction(
      () => {
        const text = document.body.innerText ?? '';
        return text.includes('GymBuddy') || text.includes('Home') || text.includes('Finish Workout');
      },
      { timeout: 30_000, polling: 500 },
    );

    // Navigate back to the active workout (via resume banner or direct route).
    const finishVisible = await page
      .locator(WORKOUT.finishButton)
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    if (!finishVisible) {
      // The resume banner or a "Resume" link should be on the home screen.
      const resumeVisible = await page
        .locator('text=Resume')
        .isVisible({ timeout: 10_000 })
        .catch(() => false);

      if (resumeVisible) {
        await page.locator('text=Resume').click();
      } else {
        // Try tapping the active workout banner (em-dash separator in name).
        const banner = page.locator('flt-semantics[aria-label*="Push Day"]');
        if (await banner.isVisible({ timeout: 5_000 }).catch(() => false)) {
          await banner.click();
        }
      }

      await expect(page.locator(WORKOUT.finishButton)).toBeVisible({
        timeout: 15_000,
      });
    }

    // KEY ASSERTION FOR BUG-001:
    // The exercise name must show the real name, NOT the "Exercise" fallback.
    // We assert both: the real name IS visible, and the raw fallback is absent.
    await expect(page.locator(`text=${BENCH_PRESS}`)).toBeVisible({
      timeout: 10_000,
    });

    // Verify the fallback "Exercise" is NOT used as the standalone card header.
    // The Semantics label pattern is "Exercise: <name>. Tap for details."
    // If BUG-001 is present, the label becomes "Exercise: Exercise. Tap for details."
    // We detect this by looking for the specific fallback aria-label.
    const fallbackLabel = page.locator(
      'flt-semantics[aria-label*="Exercise: Exercise. Tap for details"]',
    );
    await expect(fallbackLabel).not.toBeVisible({ timeout: 3_000 });

    // Clean up.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator('text=Discard').last();
    if (await confirmDiscard.isVisible({ timeout: 3_000 }).catch(() => false)) {
      await confirmDiscard.click();
    }
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  // ---------------------------------------------------------------------------
  // BUG-003 (positive path): Starting a routine with valid exercises navigates
  // to the active workout screen.
  //
  // The positive path must continue to work — tapping a seeded starter routine
  // that has properly resolved exercises must navigate to the workout screen,
  // not silently fail.
  // ---------------------------------------------------------------------------
  test('BUG-003 positive: tapping a starter routine starts an active workout', async ({
    page,
  }) => {
    await expect(page.locator(ROUTINE.starterRoutinesSection)).toBeVisible({
      timeout: 10_000,
    });

    await page.locator(ROUTINE.routineName(PUSH_DAY)).first().click();

    // The active workout screen must appear — the Finish Workout button confirms it.
    await expect(page.locator(WORKOUT.finishButton)).toBeVisible({
      timeout: 20_000,
    });

    // At least one exercise card must be rendered (Add Set button signals this).
    await expect(page.locator(WORKOUT.addSetButton)).toBeVisible({
      timeout: 10_000,
    });

    // The exercise name from the seeded routine must be visible in the card.
    await expect(page.locator(`text=${BENCH_PRESS}`)).toBeVisible({
      timeout: 10_000,
    });

    // Clean up.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator('text=Discard').last();
    if (await confirmDiscard.isVisible({ timeout: 3_000 }).catch(() => false)) {
      await confirmDiscard.click();
    }
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  // ---------------------------------------------------------------------------
  // BUG-004 (P2): Routine start uses smart weight defaults, not 0.
  //
  // A brand-new user who has never logged Barbell Bench Press before must see
  // a non-zero weight when the routine pre-fills sets. The equipment default
  // for a barbell exercise is 20 kg.
  //
  // Before the fix, `startFromRoutine` used `weight: prev?.weight ?? 0` which
  // produced 0 when no previous session existed for the exercise.
  // After the fix it falls back to `defaultSetValues(equipmentType, weightUnit)`.
  // ---------------------------------------------------------------------------
  test('BUG-004: routine start pre-fills non-zero weight for first-time exercises', async ({
    page,
  }) => {
    await expect(page.locator(ROUTINE.starterRoutinesSection)).toBeVisible({
      timeout: 10_000,
    });

    await page.locator(ROUTINE.routineName(PUSH_DAY)).first().click();

    await expect(page.locator(WORKOUT.finishButton)).toBeVisible({
      timeout: 20_000,
    });

    // The Bench Press card must be visible.
    await expect(page.locator(`text=${BENCH_PRESS}`)).toBeVisible({
      timeout: 10_000,
    });

    // The weight value in the first set row must NOT be "0" for a barbell exercise.
    // The Semantics label for the weight button is:
    //   "Weight value: <N> kg. Tap to enter weight."
    // We verify no weight button shows "0" as the value (i.e. "Weight value: 0 kg").
    const zeroWeightButton = page.locator(
      'flt-semantics[aria-label*="Weight value: 0 kg"]',
    );
    await expect(zeroWeightButton).not.toBeVisible({ timeout: 5_000 });

    // Also verify that at least one weight button with a positive value is shown.
    // Barbell default is 20 kg, dumbbell default is 10 kg.
    const positiveWeightButton = page.locator(
      'flt-semantics[aria-label*="Weight value:"]',
    ).filter({ hasNotText: '0 kg' });

    // We can't directly check text content via hasNotText on an aria-label,
    // so instead assert the "Weight value: 0 kg" element is absent (above)
    // and that some weight button exists.
    const anyWeightButton = page.locator(
      'flt-semantics[aria-label*="Weight value:"]',
    );
    await expect(anyWeightButton.first()).toBeVisible({ timeout: 10_000 });

    // Clean up.
    await page.locator(WORKOUT.discardButton).click();
    const confirmDiscard = page.locator('text=Discard').last();
    if (await confirmDiscard.isVisible({ timeout: 3_000 }).catch(() => false)) {
      await confirmDiscard.click();
    }
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
  });

  // ---------------------------------------------------------------------------
  // BUG-005 (P2): Routine cards show muscle group names, not bare exercise count.
  //
  // RoutineCard._buildSubtitle() falls back to "N exercises" when exercise
  // references are null. When exercises are resolved correctly the subtitle
  // shows the distinct muscle group names joined with "·".
  //
  // Push Day exercises include Chest, Shoulder, and Triceps exercises —
  // so the subtitle must contain at least one muscle group name, not just
  // a raw count like "6 exercises".
  // ---------------------------------------------------------------------------
  test('BUG-005: routine card subtitle shows muscle group names, not bare count', async ({
    page,
  }) => {
    await expect(page.locator(ROUTINE.starterRoutinesSection)).toBeVisible({
      timeout: 10_000,
    });

    // The Push Day card subtitle must contain at least one muscle group name.
    // Push Day exercises: Bench Press (Chest), Overhead Press (Shoulders), etc.
    // If exercises resolved correctly, the subtitle includes "Chest" or "Shoulders".
    const chestSubtitle = page.locator('text=Chest');
    const shoulderSubtitle = page.locator('text=Shoulders');
    const tricepsSubtitle = page.locator('text=Triceps');

    const hasChest = await chestSubtitle
      .isVisible({ timeout: 10_000 })
      .catch(() => false);
    const hasShoulders = await shoulderSubtitle
      .isVisible({ timeout: 3_000 })
      .catch(() => false);
    const hasTriceps = await tricepsSubtitle
      .isVisible({ timeout: 3_000 })
      .catch(() => false);

    // At least one muscle group name must appear in the card subtitle.
    expect(hasChest || hasShoulders || hasTriceps).toBe(true);

    // The fallback text "6 exercises" must NOT appear as the Push Day subtitle.
    // (Push Day has 6 exercises per seed.sql — that number would appear
    // iff exercise resolution failed and BUG-005 is present.)
    await expect(page.locator('text=6 exercises')).not.toBeVisible({
      timeout: 3_000,
    });
  });
});
