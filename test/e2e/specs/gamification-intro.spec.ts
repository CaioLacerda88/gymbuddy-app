/**
 * Gamification intro spec — Phase 17b.
 *
 * Tests the SagaIntroGate + SagaIntroOverlay first-run flow:
 *   1. Fresh user sees the 3-step SagaIntroOverlay on first home load.
 *   2. After dismissal the overlay does not re-appear on page reload
 *      (Hive `saga_intro_seen` flag persists in IndexedDB).
 *   3. The LVL badge is visible on HomeScreen after the flow completes.
 *
 * User: `sagaIntroUser` — created by global-setup with a profile row (so
 * the router lands on /home, not /onboarding) and zero workout history
 * (retro yields 0 XP → LVL 1 on first launch).
 *
 * Hive is keyed per-user and stored in browser IndexedDB. Within a single
 * Playwright browser context (same `page` object) storage persists across
 * reloads — which is exactly the "same device" scenario. Across separate
 * browser contexts (separate `page` objects) storage is isolated by default
 * because Playwright spawns each test with a fresh browser context.
 * We rely on this isolation so each test starts with a clean Hive state.
 */

import { test, expect } from '@playwright/test';
import { login } from '../helpers/auth';
import { dismissSagaIntroOverlay, waitForAppReady } from '../helpers/app';
import { NAV, GAMIFICATION } from '../helpers/selectors';
import { TEST_USERS } from '../fixtures/test-users';

// ---------------------------------------------------------------------------
// Smoke — gamification intro flow (Phase 17b)
// ---------------------------------------------------------------------------
test.describe('Gamification intro', { tag: '@smoke' }, () => {
  // --------------------------------------------------------------------------
  // Test 1: 3-step overlay appears on first mount and can be dismissed.
  //
  // Flow: login → overlay step 0 visible → NEXT → step 1 → NEXT → step 2
  //       → BEGIN → overlay gone → home nav visible → lvl-badge shows LVL 1.
  //
  // The sagaIntroUser has zero workout history so retro_backfill_xp produces
  // 0 XP and the badge shows LVL 1.
  // --------------------------------------------------------------------------
  test('should show saga intro overlay on first mount and advance through all 3 steps to dismiss', async ({
    page,
  }) => {
    await login(
      page,
      TEST_USERS.sagaIntroUser.email,
      TEST_USERS.sagaIntroUser.password,
    );

    // The SagaIntroGate kicks retro_backfill_xp in a post-frame callback and
    // shows the overlay once xpProvider resolves. Give the RPC time to return.
    // Step 0 must appear before we can interact with the overlay.
    await expect(page.locator(GAMIFICATION.step0)).toBeVisible({
      timeout: 20_000,
    });

    // Verify only step 0 is rendered at this point (step 1 and 2 are not yet shown).
    await expect(page.locator(GAMIFICATION.step1)).not.toBeVisible({
      timeout: 3_000,
    });

    // NEXT → step 1.
    await page.locator(GAMIFICATION.nextButton).click();
    await expect(page.locator(GAMIFICATION.step1)).toBeVisible({
      timeout: 5_000,
    });
    await expect(page.locator(GAMIFICATION.step0)).not.toBeVisible({
      timeout: 3_000,
    });

    // NEXT → step 2.
    await page.locator(GAMIFICATION.nextButton).click();
    await expect(page.locator(GAMIFICATION.step2)).toBeVisible({
      timeout: 5_000,
    });

    // BEGIN → overlay dismissed.
    await page.locator(GAMIFICATION.beginButton).click();

    // Overlay is gone; home navigation is accessible.
    await expect(page.locator(GAMIFICATION.step0)).not.toBeVisible({
      timeout: 5_000,
    });
    await expect(page.locator(GAMIFICATION.step2)).not.toBeVisible({
      timeout: 3_000,
    });
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 5_000 });

    // LVL badge is visible. Fresh user with no history → LVL 1.
    await expect(page.locator(GAMIFICATION.lvlBadge)).toBeVisible({
      timeout: 10_000,
    });
  });

  // --------------------------------------------------------------------------
  // Test 2: Overlay does NOT re-appear after dismissal on the same device.
  //
  // After dismissing the overlay (test 1's flow) within the same browser
  // context, we reload the page and verify the overlay is absent. Hive
  // stores the `saga_intro_seen` flag in browser IndexedDB, which persists
  // across reloads within the same browser context (same "device" semantics).
  // --------------------------------------------------------------------------
  test('should not re-show overlay after dismissal on page reload', async ({
    page,
  }) => {
    await login(
      page,
      TEST_USERS.sagaIntroUser.email,
      TEST_USERS.sagaIntroUser.password,
    );

    await dismissSagaIntroOverlay(page);

    // Reload the page — Hive (IndexedDB) persists within the same browser
    // context, so `saga_intro_seen` remains true.
    await page.reload();
    await waitForAppReady(page);

    // The router redirects to /home because the user is still authenticated.
    await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 20_000 });

    // Wait for xpProvider to resolve and the LVL badge to render — this means
    // SagaIntroGate finished its decision and chose NOT to show the overlay
    // (Hive flag gate suppressed it). Asserting badge visible before asserting
    // overlay absent prevents the race where the app is still initializing.
    await expect(page.locator(GAMIFICATION.lvlBadge)).toBeVisible({
      timeout: 15_000,
    });

    // Overlay must NOT re-appear — the Hive flag gate in SagaIntroGate
    // (hasSeenSagaIntroForUser) must suppress it.
    await expect(page.locator(GAMIFICATION.step0)).not.toBeVisible({
      timeout: 3_000,
    });
  });

  // --------------------------------------------------------------------------
  // Test 3: LVL badge is visible on HomeScreen after login.
  //
  // A minimal visibility check: after the saga intro flow completes, the
  // LVL badge placeholder rendered by _LvlBadge is present on the home screen.
  // This exercises the xpProvider → currentLevelOrDefault → badge path without
  // caring about the exact XP value (that depends on the user's history).
  // --------------------------------------------------------------------------
  test('should render LVL badge on home screen after saga intro dismissal', async ({
    page,
  }) => {
    await login(
      page,
      TEST_USERS.sagaIntroUser.email,
      TEST_USERS.sagaIntroUser.password,
    );

    await dismissSagaIntroOverlay(page);

    // LVL badge must be present on HomeScreen.
    await expect(page.locator(GAMIFICATION.lvlBadge)).toBeVisible({
      timeout: 10_000,
    });
  });
});
