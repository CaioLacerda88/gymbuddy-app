/**
 * Title equip — E2E tests for the title library equip flow (Phase 18e).
 *
 * Scenarios covered:
 *   T1 — Titles codex nav row opens the title library screen.
 *   T2 — An earned unequipped title row is tappable; tapping it equips the
 *         title (EQUIPPED badge appears, active-title-pill on character sheet
 *         updates on next visit).
 *
 * User isolation:
 *   rpgTitleEquipUser — chest at rank 5; 'chest_r5_initiate_of_the_forge'
 *   pre-seeded in earned_titles (is_active = false). The title is NOT yet
 *   equipped so the test can drive the equip interaction from a clean state.
 *
 * Seeding: global-setup.ts → seedRpgTitleEquipUser()
 *
 * E2E conventions (CLAUDE.md):
 *   - Describe: feature name only ("Title equip"), no "smoke"/"full" suffix.
 *   - Tests: "should ..." naming.
 *   - Selectors: CELEBRATION.titleLibraryButton, CELEBRATION.titleLibrarySheet,
 *     CELEBRATION.titleRow(slug), CELEBRATION.equippedTitleLabel, SAGA.activeTitlePill.
 *   - Text input: flutterFill() — not used here (no text fields).
 *   - SnackBar text: .first() selector.
 */

import { test, expect } from '@playwright/test';
import { login } from '../helpers/auth';
import { navigateToTab } from '../helpers/app';
import { SAGA, CELEBRATION } from '../helpers/selectors';
import { TEST_USERS } from '../fixtures/test-users';

// Slug of the earned title pre-seeded for rpgTitleEquipUser.
const EARNED_SLUG = 'chest_r5_initiate_of_the_forge';

test.describe('Title equip', () => {
  test.beforeEach(async ({ page }) => {
    await login(
      page,
      TEST_USERS.rpgTitleEquipUser.email,
      TEST_USERS.rpgTitleEquipUser.password,
    );
    await navigateToTab(page, 'Profile');
    await page
      .locator(SAGA.characterSheet)
      .first()
      .waitFor({ state: 'visible', timeout: 20_000 });
  });

  // T1: Titles codex nav row opens the title library screen.
  //
  // SAGA.codexNavTitles (= CELEBRATION.titleLibraryButton) calls
  // context.push('/profile/titles') → TitlesScreen (CELEBRATION.titleLibrarySheet).
  // Phase 18e extended TitlesScreen with CHARACTER LEVEL and DISTINCTION sections;
  // the 'titles-screen' Semantics identifier is unchanged.
  test('should open title library screen when tapping Titles codex nav row (T1)', async ({
    page,
  }) => {
    await page
      .locator(CELEBRATION.titleLibraryButton)
      .first()
      .scrollIntoViewIfNeeded();
    await page.locator(CELEBRATION.titleLibraryButton).first().click();

    await expect(
      page.locator(CELEBRATION.titleLibrarySheet).first(),
    ).toBeVisible({ timeout: 15_000 });
  });

  // T2: Tapping an earned unequipped title row equips the title.
  //
  // rpgTitleEquipUser has 'chest_r5_initiate_of_the_forge' in earned_titles
  // with is_active = false. The TitlesScreen _TitleRow renders this row as
  // tappable (earned but not active → onTap fires _equip). After the equip
  // round-trip completes, the EQUIPPED badge (equipped-title-label identifier)
  // appears on the same row.
  //
  // The active-title-pill on the character sheet is checked on a second
  // navigation so the earnedTitlesProvider + equippedTitleSlugProvider
  // invalidation has time to propagate before we assert.
  test('should equip an earned title and show EQUIPPED badge on title row (T2)', async ({
    page,
  }) => {
    // Open the title library.
    await page
      .locator(CELEBRATION.titleLibraryButton)
      .first()
      .scrollIntoViewIfNeeded();
    await page.locator(CELEBRATION.titleLibraryButton).first().click();

    await page
      .locator(CELEBRATION.titleLibrarySheet)
      .first()
      .waitFor({ state: 'visible', timeout: 15_000 });

    // The earned title row must be visible (chest section, rank 5 entry).
    const titleRow = page.locator(CELEBRATION.titleRow(EARNED_SLUG)).first();
    await titleRow.scrollIntoViewIfNeeded();
    await expect(titleRow).toBeVisible({ timeout: 10_000 });

    // Tap the row to equip. The row's InkWell fires _equip → equipTitle RPC
    // → earnedTitlesProvider + equippedTitleSlugProvider invalidation.
    await titleRow.click();

    // The EQUIPPED badge must appear on the row after the round-trip completes.
    // equip_title is a Postgres UPSERT (fast path) — the round-trip typically
    // completes in < 2 s on the local Supabase instance.
    await expect(
      page.locator(CELEBRATION.equippedTitleLabel).first(),
    ).toBeVisible({ timeout: 15_000 });
  });

  // T3: After equipping a title, the character sheet shows the active-title-pill.
  //
  // This test runs after T2 in the same describe block and relies on the
  // rpgTitleEquipUser's equip state persisting across the navigation. Because
  // each test has its own beforeEach (login + navigate to Profile), we equip
  // the title again in T3 to avoid cross-test state coupling.
  test('should show active-title-pill on character sheet after equipping a title (T3)', async ({
    page,
  }) => {
    // Open the title library and equip the title.
    await page
      .locator(CELEBRATION.titleLibraryButton)
      .first()
      .scrollIntoViewIfNeeded();
    await page.locator(CELEBRATION.titleLibraryButton).first().click();

    await page
      .locator(CELEBRATION.titleLibrarySheet)
      .first()
      .waitFor({ state: 'visible', timeout: 15_000 });

    const titleRow = page.locator(CELEBRATION.titleRow(EARNED_SLUG)).first();
    await titleRow.scrollIntoViewIfNeeded();
    await expect(titleRow).toBeVisible({ timeout: 10_000 });

    // If EQUIPPED badge is already showing (prior test run left the title
    // equipped), skip the equip tap — the pill check below still validates
    // the character sheet contract.
    const alreadyEquipped = await page
      .locator(CELEBRATION.equippedTitleLabel)
      .first()
      .isVisible({ timeout: 2_000 })
      .catch(() => false);

    if (!alreadyEquipped) {
      await titleRow.click();
      await expect(
        page.locator(CELEBRATION.equippedTitleLabel).first(),
      ).toBeVisible({ timeout: 15_000 });
    }

    // Navigate back to the character sheet. The active-title-pill should render
    // because equippedTitleSlugProvider was invalidated after the equip RPC.
    // go_router.pop() or re-tapping the Profile tab returns to /profile.
    await page.goBack();

    await page
      .locator(SAGA.characterSheet)
      .first()
      .waitFor({ state: 'visible', timeout: 20_000 });

    // The active-title-pill renders when activeTitle != null && isNotEmpty.
    // equippedTitleSlugProvider watch fires on the character sheet rebuild.
    await expect(page.locator(SAGA.activeTitlePill).first()).toBeVisible({
      timeout: 15_000,
    });
  });
});
