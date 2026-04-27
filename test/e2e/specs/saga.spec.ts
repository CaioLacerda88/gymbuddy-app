/**
 * Saga (Character Sheet) — E2E smoke tests.
 * Phase 18b: /profile now renders CharacterSheetScreen.
 *
 * Scenarios covered:
 *   S1 @smoke — fresh user sees character sheet with zero-history banner
 *   S2 @smoke — foundation user sees filled character sheet (no banner, body-part rows visible)
 *   S3 @smoke — gear icon navigates to profile settings
 *   S4 @smoke — re-tapping Saga tab from settings pops back to character sheet
 *   S5 @smoke — Stats codex nav row navigates to stub screen
 *   S6 @smoke — Titles codex nav row navigates to stub screen
 *   S7 @smoke — History codex nav row navigates to /home/history
 *
 * User isolation:
 *   - Fresh user:      rpgFreshUser (zero workout history, no XP)
 *   - Foundation user: rpgFoundationUser (12+ workouts, LVL > 1, multi-body-part XP)
 *
 * Selector note: All character-sheet elements use flt-semantics-identifier
 * wrappers. The SAGA.* selectors in helpers/selectors.ts map to these.
 */

import { test, expect } from '@playwright/test';
import { createClient } from '@supabase/supabase-js';
import { login } from '../helpers/auth';
import { navigateToTab } from '../helpers/app';
import { SAGA, NAV, HISTORY } from '../helpers/selectors';
import { TEST_USERS } from '../fixtures/test-users';

function makeAdminClient() {
  const url = process.env['SUPABASE_URL'] ?? 'http://127.0.0.1:54321';
  const serviceKey =
    process.env['SUPABASE_SERVICE_ROLE_KEY'] ??
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9' +
    '.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0' +
    '.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';
  return createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

async function getRpgFreshUserId(): Promise<string | null> {
  const admin = makeAdminClient();
  const { data } = await admin.auth.admin.listUsers();
  const user = data?.users?.find(
    (u) => u.email === TEST_USERS.rpgFreshUser.email,
  );
  return user?.id ?? null;
}

// ---------------------------------------------------------------------------
// S1–S2: Character sheet renders (smoke)
// Uses separate describe blocks for user isolation.
// ---------------------------------------------------------------------------

test.describe('Saga — fresh user character sheet', { tag: '@smoke' }, () => {
  test.beforeEach(async ({ page }) => {
    // E2 (rpg-foundation.spec.ts) also uses rpgFreshUser and may run before S1
    // in the full suite, leaving XP rows in body_part_progress from the workout
    // it completes. Reset RPG state here so S1 always starts from a true
    // zero-history baseline regardless of test-file ordering.
    const userId = await getRpgFreshUserId();
    if (userId) {
      const admin = makeAdminClient();
      await admin.from('xp_events').delete().eq('user_id', userId);
      await admin.from('body_part_progress').delete().eq('user_id', userId);
      await admin.from('exercise_peak_loads').delete().eq('user_id', userId);
      await admin.from('backfill_progress').delete().eq('user_id', userId);
      // Re-seed backfill_progress as completed so the SagaIntroGate's
      // runRetroBackfill is a no-op (no workouts → nothing to backfill).
      await admin.from('backfill_progress').insert({
        user_id: userId,
        sets_processed: 0,
        started_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        completed_at: new Date().toISOString(),
      });
    }

    await login(page, TEST_USERS.rpgFreshUser.email, TEST_USERS.rpgFreshUser.password);
    await navigateToTab(page, 'Profile');
    await page.locator(SAGA.characterSheet).first().waitFor({ state: 'visible', timeout: 20_000 });
  });

  // S1: Zero-history state — banner visible, all structural elements present.
  //
  // rpgFreshUser has no workout history so lifetimeXp == 0.
  // CharacterSheetScreen renders _FirstSetAwakensBanner when isZeroHistory == true.
  // All other structural elements (halo, radar, body-part rows, codex nav) must
  // also render — even with zero data, the sheet is fully laid out.
  test('should render character sheet with first-set-awakens banner for zero-history user (S1)', async ({
    page,
  }) => {
    // Core structural elements must be present.
    await expect(page.locator(SAGA.runeHalo).first()).toBeVisible({ timeout: 10_000 });
    await expect(page.locator(SAGA.vitalityRadar).first()).toBeVisible({ timeout: 10_000 });
    await expect(page.locator(SAGA.classBadge).first()).toBeVisible({ timeout: 10_000 });

    // Zero-history onboarding banner must appear.
    await expect(page.locator(SAGA.firstSetAwakensBanner).first()).toBeVisible({
      timeout: 10_000,
    });

    // At least one body-part row must be present (chest is always seeded).
    await expect(page.locator(SAGA.bodyPartRow('chest')).first()).toBeVisible({
      timeout: 10_000,
    });

    // Codex navigation rows must be present.
    await expect(page.locator(SAGA.codexNavStats).first()).toBeVisible({ timeout: 10_000 });
    await expect(page.locator(SAGA.codexNavTitles).first()).toBeVisible({ timeout: 10_000 });
    await expect(page.locator(SAGA.codexNavHistory).first()).toBeVisible({ timeout: 10_000 });
  });
});

test.describe('Saga — foundation user character sheet', { tag: '@smoke' }, () => {
  test.beforeEach(async ({ page }) => {
    await login(page, TEST_USERS.rpgFoundationUser.email, TEST_USERS.rpgFoundationUser.password);
    await navigateToTab(page, 'Profile');
    await page.locator(SAGA.characterSheet).first().waitFor({ state: 'visible', timeout: 20_000 });
  });

  // S2: Foundation user — no zero-history banner, has XP and level > 1.
  //
  // rpgFoundationUser has ~12 prior workouts so lifetimeXp > 0.
  // _FirstSetAwakensBanner must NOT render.
  // The Lvl numeral must be > 1 (seeded workouts grant enough XP for level-up).
  // Multiple body-part rows must be expanded (trained).
  test('should render filled character sheet without zero-history banner for foundation user (S2)', async ({
    page,
  }) => {
    // Zero-history banner must NOT be visible for a user with history.
    await expect(page.locator(SAGA.firstSetAwakensBanner)).not.toBeVisible({ timeout: 5_000 });

    // Halo and radar must be present.
    await expect(page.locator(SAGA.runeHalo).first()).toBeVisible({ timeout: 10_000 });
    await expect(page.locator(SAGA.vitalityRadar).first()).toBeVisible({ timeout: 10_000 });

    // Class badge must be visible — even if class is null (placeholder shows).
    // The presence of the badge confirms the data state rendered (not loading skeleton).
    await expect(page.locator(SAGA.classBadge).first()).toBeVisible({ timeout: 15_000 });

    // Multiple body-part rows must be present.
    for (const slug of ['chest', 'back', 'legs'] as const) {
      await expect(page.locator(SAGA.bodyPartRow(slug)).first()).toBeVisible({
        timeout: 10_000,
      });
    }

    // Level must be > 1 — rpgFoundationUser has 12+ seeded workouts which
    // grant enough XP to push past LVL 1. Read the AOM accessible name on
    // the character-level Semantics wrapper (canvaskit renders the numeral
    // on a canvas, but the Semantics(identifier:'character-level') wrapper
    // exposes the text via the accessibility tree).
    const lvlText = await page
      .locator(SAGA.characterLevel)
      .first()
      .textContent();
    const lvl = Number(lvlText?.replace(/^Lvl\s*/, '').trim());
    expect(lvl).toBeGreaterThan(1);
  });
});

// ---------------------------------------------------------------------------
// S3–S7: Navigation tests (smoke)
// All use rpgFoundationUser — avoids zero-history banner scrolling issues.
// ---------------------------------------------------------------------------

test.describe('Saga — navigation', { tag: '@smoke' }, () => {
  test.beforeEach(async ({ page }) => {
    await login(page, TEST_USERS.rpgFoundationUser.email, TEST_USERS.rpgFoundationUser.password);
    await navigateToTab(page, 'Profile');
    await page.locator(SAGA.characterSheet).first().waitFor({ state: 'visible', timeout: 20_000 });
  });

  // S3: Gear icon → profile settings.
  //
  // The gear icon in the CharacterSheetScreen AppBar calls context.push('/profile/settings').
  // ProfileSettingsScreen root is identified by Semantics(identifier: 'profile-heading').
  test('should open profile settings screen when tapping gear icon (S3)', async ({ page }) => {
    await page.locator(SAGA.gearIcon).first().click();
    // ProfileSettingsScreen renders a "Profile" section heading (profile-heading identifier).
    // URL update via context.push is unreliable in Flutter web — assert on element visibility.
    await expect(page.locator(SAGA.profileSettingsScreen).first()).toBeVisible({
      timeout: 15_000,
    });
  });

  // S4: Re-tap Saga tab from settings → back to character sheet.
  //
  // _ShellScaffold.onDestinationSelected handles re-tap of the active branch
  // by popping any pushed sub-routes (e.g. /profile/settings, /saga/stats)
  // back to the branch root (/profile, the character sheet). This test
  // verifies that contract: open settings via the gear icon, re-tap the Saga
  // tab, expect the character sheet back (settings no longer visible).
  test('should show character sheet after re-tapping Saga tab from settings (S4)', async ({
    page,
  }) => {
    // Navigate into settings via gear icon.
    await page.locator(SAGA.gearIcon).first().click();
    await page.locator(SAGA.profileSettingsScreen).first().waitFor({ state: 'visible', timeout: 10_000 });

    // Re-tap the Saga / Profile nav tab.
    await page.click(NAV.profileTab);

    // Expect: settings popped off, character sheet visible again.
    await expect(page.locator(SAGA.runeHalo).first()).toBeVisible({ timeout: 15_000 });
    await expect(page.locator(SAGA.profileSettingsScreen)).not.toBeVisible({ timeout: 5_000 });
  });

  // S5: Stats codex nav row → stats stub screen.
  //
  // CodexNavRow with semanticIdentifier 'codex-nav-stats' calls context.push('/saga/stats').
  // SagaStubScreen renders l10n.comingSoonStub = "Coming soon.".
  test('should navigate to stats stub screen when tapping Stats codex nav row (S5)', async ({
    page,
  }) => {
    // Scroll to bring codex nav rows into view (they are below the fold).
    await page.locator(SAGA.codexNavStats).first().scrollIntoViewIfNeeded();
    await page.locator(SAGA.codexNavStats).first().click();

    // Flutter web pushes the route via context.push — assert on visible content
    // rather than URL (URL update timing is unreliable with Flutter web routing).
    await expect(page.locator(SAGA.sagaStubScreen).first()).toBeVisible({ timeout: 15_000 });
  });

  // S6: Titles codex nav row → titles stub screen.
  //
  // CodexNavRow with semanticIdentifier 'codex-nav-titles' calls context.push('/saga/titles').
  // SagaStubScreen renders l10n.comingSoonStub = "Coming soon.".
  test('should navigate to titles stub screen when tapping Titles codex nav row (S6)', async ({
    page,
  }) => {
    await page.locator(SAGA.codexNavTitles).first().scrollIntoViewIfNeeded();
    await page.locator(SAGA.codexNavTitles).first().click();

    // Flutter web pushes the route via context.push — assert on visible content.
    await expect(page.locator(SAGA.sagaStubScreen).first()).toBeVisible({ timeout: 15_000 });
  });

  // S7: History codex nav row → workout history screen.
  //
  // CodexNavRow with semanticIdentifier 'codex-nav-history' calls context.push('/home/history').
  // WorkoutHistoryScreen AppBar uses Semantics(identifier: 'history-heading').
  test('should navigate to workout history screen when tapping History codex nav row (S7)', async ({
    page,
  }) => {
    await page.locator(SAGA.codexNavHistory).first().scrollIntoViewIfNeeded();
    await page.locator(SAGA.codexNavHistory).first().click();

    // Flutter web pushes the route — assert on history-heading OR history-empty.
    // Foundation user has workout history so heading should appear; empty state
    // is the fallback in case the history list loads slower than expected.
    const hasHeading = await page
      .locator(HISTORY.heading)
      .isVisible({ timeout: 15_000 })
      .catch(() => false);
    const hasEmpty = await page
      .locator(HISTORY.emptyState)
      .isVisible({ timeout: 5_000 })
      .catch(() => false);
    expect(hasHeading || hasEmpty).toBe(true);
  });
});
