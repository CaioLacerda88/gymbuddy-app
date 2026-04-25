/**
 * Routines content localization — E2E scenario E1.
 * Phase 15f: exercise names in routine create/edit resolved from exercise_translations.
 *
 * Scenarios:
 *   E1 — pt user creates routine with pt-picker → pt names in routine list
 */

import { test, expect } from '@playwright/test';
import { navigateToTab } from '../helpers/app';
import { login } from '../helpers/auth';
import {
  ROUTINE,
  CREATE_ROUTINE,
  ROUTINE_MANAGEMENT,
  EXERCISE_PICKER,
} from '../helpers/selectors';
import { TEST_USERS } from '../fixtures/test-users';
import { EXERCISE_NAMES } from '../fixtures/test-exercises';

// =============================================================================
// FULL: Routine create with pt exercise picker (E1)
// Uses smokeLocalizationRoutines user (pt locale, lapsed state)
// =============================================================================

test.describe('Routine localization pt locale', () => {
  test.beforeEach(async ({ page }) => {
    await login(
      page,
      TEST_USERS.smokeLocalizationRoutines.email,
      TEST_USERS.smokeLocalizationRoutines.password,
    );
    await navigateToTab(page, 'Routines');
  });

  // E1: pt user creates routine with pt-picker → pt names in routine list.
  test('should show pt exercise names in routine exercise picker for pt user (E1)', async ({
    page,
  }) => {
    const routineName = `Rotina PT ${Date.now()}`;

    // Open the create routine screen.
    await page.click(ROUTINE_MANAGEMENT.createIconButton);
    await expect(
      page.locator(ROUTINE_MANAGEMENT.createRoutineScreenTitle),
    ).toBeVisible({ timeout: 10_000 });

    // Enter a routine name.
    const nameInput = page.locator(CREATE_ROUTINE.nameInput);
    await expect(nameInput).toBeVisible({ timeout: 5_000 });
    await nameInput.fill(routineName);

    // Open the exercise picker.
    await page.click(CREATE_ROUTINE.addExerciseButton);
    await expect(
      page.locator('[flt-semantics-identifier="exercise-picker-search"]'),
    ).toBeVisible({ timeout: 10_000 });

    // The pt bench press name must appear in the exercise picker.
    const ptBenchName = EXERCISE_NAMES.barbell_bench_press.pt;

    // Search for the pt bench press name in the picker.
    const searchInput = page.locator('input').last();
    await searchInput.fill(ptBenchName.substring(0, 6));
    await page.waitForTimeout(800);

    // Verify the pt name appears in the picker results.
    // pt locale: "Adicionar {name}" (app_pt.arb addExerciseSemantics).
    const ptExerciseInPicker = page
      .locator(`role=button[name*="Adicionar ${ptBenchName}"]`)
      .first();
    const altExerciseInPicker = page
      .locator(`role=button[name*="${ptBenchName}"]`)
      .first();

    const hasDirect = await ptExerciseInPicker
      .isVisible({ timeout: 5_000 })
      .catch(() => false);
    const hasAlt = await altExerciseInPicker
      .isVisible({ timeout: 5_000 })
      .catch(() => false);

    // E1 assertion: at least the pt name must appear in the picker.
    expect(
      hasDirect || hasAlt,
      `pt exercise name "${ptBenchName}" must appear in the exercise picker for pt user`,
    ).toBe(true);

    // Add the exercise if found.
    if (hasDirect) {
      await ptExerciseInPicker.click();
    } else if (hasAlt) {
      await altExerciseInPicker.click();
    } else {
      // Fallback: pick first available exercise.
      // pt locale: add button prefix is "Adicionar".
      const firstResult = page.locator('role=button[name*="Adicionar "]').first();
      await expect(firstResult).toBeVisible({ timeout: 5_000 });
      await firstResult.click();
    }

    // Wait for the picker to close.
    await expect(
      page.locator(ROUTINE_MANAGEMENT.createRoutineScreenTitle),
    ).toBeVisible({ timeout: 10_000 });

    // Save the routine.
    await page.click(CREATE_ROUTINE.saveButton);

    // Should navigate back to the routines list.
    await expect(page.locator(ROUTINE.heading)).toBeVisible({ timeout: 15_000 });

    // The routine must appear in MY ROUTINES section.
    await expect(
      page.locator(ROUTINE.routineName(routineName)),
    ).toBeVisible({ timeout: 10_000 });
  });
});
