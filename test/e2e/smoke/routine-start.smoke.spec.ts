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

// Semantics label for the Barbell Bench Press exercise card in the active workout.
// The _ExerciseCard wraps the name in Semantics with this label pattern.
const BENCH_PRESS_ARIA = 'role=group[name*="Exercise: Barbell Bench Press. Tap for details"]';

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
    // Use the Semantics aria-label (set on the tappable exercise name area)
    // rather than a plain text selector, which can fail for flt-semantics
    // elements with zero CSS dimensions (text drawn on canvas).
    await expect(page.locator(BENCH_PRESS_ARIA)).toBeVisible({
      timeout: 10_000,
    });

    // Simulate app restore by reloading the page (preserves IndexedDB/Hive).
    await page.reload();

    // After a reload, Flutter CanvasKit re-downloads and must re-initialise.
    // waitForAppReady() re-enables the semantics tree and waits for the auth
    // stream to resolve — document.body.innerText is empty in CanvasKit because
    // text is drawn to canvas, so a plain waitForFunction on innerText never fires.
    await waitForAppReady(page);

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
        const banner = page.locator('role=button[name*="Push Day"]');
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
    await expect(page.locator(BENCH_PRESS_ARIA)).toBeVisible({
      timeout: 10_000,
    });

    // Verify the fallback "Exercise" is NOT used as the standalone card header.
    // The Semantics label pattern is "Exercise: <name>. Tap for details."
    // If BUG-001 is present, the label becomes "Exercise: Exercise. Tap for details."
    // We detect this by looking for the specific fallback aria-label.
    const fallbackLabel = page.locator(
      'role=group[name*="Exercise: Exercise. Tap for details"]',
    );
    await expect(fallbackLabel).not.toBeVisible({ timeout: 3_000 });

    // Clean up.
    await page.locator(WORKOUT.discardButton).click();
    await expect(page.locator(WORKOUT.discardConfirmButton)).toBeVisible({ timeout: 5_000 });
    await page.locator(WORKOUT.discardConfirmButton).click();
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
    // Use .first() to avoid strict mode violations when multiple exercise cards
    // are rendered (each has its own "Add Set" button).
    await expect(page.locator(WORKOUT.addSetButton).first()).toBeVisible({
      timeout: 10_000,
    });

    // The exercise name from the seeded routine must be accessible via its
    // Semantics aria-label in the workout card header.
    await expect(page.locator(BENCH_PRESS_ARIA)).toBeVisible({
      timeout: 10_000,
    });

    // Clean up.
    await page.locator(WORKOUT.discardButton).click();
    await expect(page.locator(WORKOUT.discardConfirmButton)).toBeVisible({ timeout: 5_000 });
    await page.locator(WORKOUT.discardConfirmButton).click();
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

    // The Bench Press card must be accessible via its Semantics aria-label.
    await expect(page.locator(BENCH_PRESS_ARIA)).toBeVisible({
      timeout: 10_000,
    });

    // The weight value in the first set row must NOT be "0" for a barbell exercise.
    // Flutter Semantics uses label: 'Weight value: <N> kg. Tap to enter weight.'
    // with button: true. In Flutter web CanvasKit, the accessible name of the
    // flt-semantics element is exposed via aria-label on the element itself.
    // However Playwright's role=button[name*="..."] uses computed accessible name,
    // which correctly matches these buttons regardless of attribute vs text source.
    const zeroWeightButton = page.locator(
      'role=button[name*="Weight value: 0 kg"]',
    );
    await expect(zeroWeightButton).not.toBeVisible({ timeout: 5_000 });

    // Also verify that at least one weight button with a positive value is shown.
    // Barbell default is 20 kg, dumbbell default is 10 kg.
    const anyWeightButton = page.locator(
      'role=button[name*="Weight value:"]',
    );
    await expect(anyWeightButton.first()).toBeVisible({ timeout: 10_000 });

    // Clean up.
    await page.locator(WORKOUT.discardButton).click();
    await expect(page.locator(WORKOUT.discardConfirmButton)).toBeVisible({ timeout: 5_000 });
    await page.locator(WORKOUT.discardConfirmButton).click();
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
  //
  // NOTE: In Flutter CanvasKit, flt-semantics text elements for subtitles may
  // have zero CSS dimensions (the actual text is drawn on canvas). We therefore
  // check that the routine card BUTTON's text content contains the muscle group
  // name rather than relying on `isVisible()` of a text child element.
  // ---------------------------------------------------------------------------
  test('BUG-005: routine card subtitle shows muscle group names, not bare count', async ({
    page,
  }) => {
    await expect(page.locator(ROUTINE.starterRoutinesSection)).toBeVisible({
      timeout: 10_000,
    });

    // The Push Day card is a flt-semantics[role="button"] whose text content
    // includes the subtitle. Check that the subtitle contains a muscle group name.
    // We filter buttons by text content to find the Push Day card.
    const pushDayCard = page
      .locator('flt-semantics[role="button"]')
      .filter({ hasText: 'Push Day' });

    await expect(pushDayCard.first()).toBeVisible({ timeout: 10_000 });

    // The card's text content should include at least one of the expected
    // muscle group names from Push Day exercises.
    const cardText = await pushDayCard.first().textContent();
    const hasChest = cardText?.includes('Chest') ?? false;
    const hasShoulders = cardText?.includes('Shoulders') ?? false;
    const hasArms = cardText?.includes('Arms') ?? false;

    // At least one muscle group name must appear in the card subtitle.
    expect(hasChest || hasShoulders || hasArms).toBe(true);

    // The fallback text "6 exercises" must NOT appear in the Push Day card text.
    // (Push Day has 6 exercises per seed.sql — that number would appear
    // iff exercise resolution failed and BUG-005 is present.)
    expect(cardText?.includes('6 exercises')).toBe(false);
  });
});
