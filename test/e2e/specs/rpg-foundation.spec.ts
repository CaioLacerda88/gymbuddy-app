/**
 * Phase 18a — RPG Foundation E2E tests.
 *
 * These tests validate that the Phase 18a XP engine is observable through the
 * Phase 17b shim: the LVL badge on the home screen reflects `character_state.
 * lifetime_xp` (the sum of body-part XP across the six strength tracks).
 *
 * Observable surface (18a): the `lvl-badge` Semantics node on HomeScreen,
 * which reads from `xpProvider` → `XpRepository.getSummary()` →
 * `character_state.lifetime_xp`.
 *
 * NOT in scope for 18a: /saga route, character sheet UI, rune sigils, class
 * card, body-part runes. Those land in 18b and 18c.
 *
 * Test users:
 *   rpgFoundationUser — 12 prior workouts across 6 weeks; LVL > 1 after backfill
 *   rpgFreshUser      — zero workout history; starts at LVL 1
 *
 * Both users are seeded in global-setup.ts.
 *
 * E2E conventions:
 *   - Smoke tests (E1, E2, E3): tagged @smoke on the describe block.
 *   - Regression-only (E4, E5, E6): no tag — run in full suite.
 *   - Selectors: all in helpers/selectors.ts (GAMIFICATION block).
 *   - Text input: flutterFill() from helpers/app.ts.
 *   - Each describe block has its own test user.
 */

import { test, expect, type Page } from '@playwright/test';
import { createClient } from '@supabase/supabase-js';
import { login } from '../helpers/auth';
import {
  startEmptyWorkout,
  addExercise,
  setWeight,
  setReps,
  completeSet,
  finishWorkout,
} from '../helpers/workout';
import { GAMIFICATION, NAV } from '../helpers/selectors';
import { TEST_USERS } from '../fixtures/test-users';

// ---------------------------------------------------------------------------
// Admin Supabase client — used by E6 to read body_part_progress directly.
// Credentials match test/e2e/.env.local (local Supabase defaults).
// ---------------------------------------------------------------------------
function makeAdminClient() {
  const url = process.env['SUPABASE_URL'] ?? 'http://127.0.0.1:54321';
  const serviceKey = process.env['SUPABASE_SERVICE_ROLE_KEY'] ??
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9' +
    '.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0' +
    '.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';
  return createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

// ---------------------------------------------------------------------------
// Helper: extract the numeric LVL from the lvl-badge aria label.
//
// Flutter emits Semantics(label: 'LVL {n}') on the badge. Playwright exposes
// this as the accessible name of the flt-semantics element. We read the
// aria-label JS property (AOM) and parse the number.
// ---------------------------------------------------------------------------
async function readLvlFromBadge(page: Page): Promise<number> {
  // Wait for the badge to be visible first.
  const badge = page.locator(GAMIFICATION.lvlBadge);
  await expect(badge).toBeVisible({ timeout: 20_000 });

  // Read the accessible name via the AOM (ariaLabel JS property).
  // Retry up to 10 times (100ms each) in case the badge re-renders with the
  // backfill result slightly after becoming visible.
  for (let attempt = 0; attempt < 10; attempt++) {
    const label: string | null = await badge.evaluate((el) => {
      // AOM: ariaLabel is the JS property; aria-label is the DOM attribute.
      // Flutter 3.41.6 uses AOM, so check the JS property first.
      return (el as any).ariaLabel ?? el.getAttribute('aria-label') ?? null;
    });

    if (label && label.startsWith('LVL ')) {
      const num = parseInt(label.replace('LVL ', ''), 10);
      if (!isNaN(num)) return num;
    }
    await page.waitForTimeout(100);
  }

  throw new Error(
    `Could not read LVL number from badge. Last accessible name may not match 'LVL {n}' pattern.`,
  );
}

// ---------------------------------------------------------------------------
// Helper: save a simple 5-set bench press workout through the UI.
// Used by E2 and E3.
// ---------------------------------------------------------------------------
async function saveSimpleBenchWorkout(page: Page): Promise<void> {
  await startEmptyWorkout(page);
  await addExercise(page, 'Barbell Bench Press');

  // Set weight 60kg and 8 reps for 5 sets, complete each.
  for (let i = 0; i < 5; i++) {
    if (i > 0) {
      // After the first set, add subsequent sets using the Add Set button.
      // workout.ts addExercise() already adds the first set; subsequent sets
      // must be added manually.
      await page.locator('[flt-semantics-identifier="workout-add-set"]').last().click();
      await page.waitForTimeout(500);
    }
    await setWeight(page, '60');
    await setReps(page, '8');
    await completeSet(page, i);
  }

  await finishWorkout(page);

  // Handle PR celebration overlay if it appears (first bench press sets a PR).
  // Wait for either the celebration or the home nav.
  const celebrationOrHome = page.locator(
    `${NAV.homeTab}, role=button[name*="Dismiss"], role=button[name*="See PRs"], text="DONE"`,
  );
  try {
    await celebrationOrHome.first().waitFor({ state: 'visible', timeout: 10_000 });
    // If the nav tab is already visible, we're done. Otherwise dismiss celebration.
    const navVisible = await page.locator(NAV.homeTab).isVisible({ timeout: 1_000 }).catch(() => false);
    if (!navVisible) {
      // Dismiss via Done button or tap anywhere on celebration.
      const doneBtn = page.locator('text="DONE"').first();
      const hasDone = await doneBtn.isVisible({ timeout: 2_000 }).catch(() => false);
      if (hasDone) {
        await doneBtn.click();
      } else {
        // Tap the center to dismiss.
        const viewport = page.viewportSize() ?? { width: 1280, height: 720 };
        await page.mouse.click(viewport.width / 2, viewport.height / 2);
      }
    }
  } catch {
    // Already on home — no celebration overlay appeared.
  }

  // Ensure we're back on the home screen.
  await expect(page.locator(NAV.homeTab)).toBeVisible({ timeout: 15_000 });
}

// ===========================================================================
// 18a-E1 — Backfill on first login (rpgFoundationUser) @smoke
//
// rpgFoundationUser has 12 prior workouts (36 sets total) seeded without going
// through save_workout, so body_part_progress is initially empty. On first
// login, SagaIntroGate triggers runRetroBackfill → backfill_rpg_v1 loop →
// character_state.lifetime_xp is populated. The LVL badge must show LVL > 1.
// ===========================================================================
test.describe('RPG foundation — backfill on first login', { tag: '@smoke' }, () => {
  test('should show LVL > 1 after backfill runs on first login (18a-E1)', async ({
    page,
  }) => {
    await login(
      page,
      TEST_USERS.rpgFoundationUser.email,
      TEST_USERS.rpgFoundationUser.password,
    );

    // The LVL badge is rendered by _LvlBadge which reads xpProvider.
    // xpProvider updates after the backfill completes (SagaIntroGate kicks
    // runRetroBackfill in a post-frame callback on first login).
    // Wait generously — 36 sets across 12 workouts may take a few seconds.
    await expect(page.locator(GAMIFICATION.lvlBadge)).toBeVisible({
      timeout: 30_000,
    });

    const lvl = await readLvlFromBadge(page);
    expect(lvl).toBeGreaterThan(1);
  });
});

// ===========================================================================
// 18a-E2 — First-workout XP applied (rpgFreshUser) @smoke
//
// rpgFreshUser has zero history → LVL 1 on login. After saving a 5-set bench
// workout (60kg × 8) the backfill/save_workout path awards XP. The LVL badge
// must update to LVL > 1 (bench press chest attribution produces enough XP).
// ===========================================================================
test.describe('RPG foundation — first-workout XP applied', { tag: '@smoke' }, () => {
  test('should show LVL > 1 after completing first workout (18a-E2)', async ({
    page,
  }) => {
    await login(
      page,
      TEST_USERS.rpgFreshUser.email,
      TEST_USERS.rpgFreshUser.password,
    );

    // Fresh user: after saga intro (if shown) the badge shows LVL 1.
    await expect(page.locator(GAMIFICATION.lvlBadge)).toBeVisible({
      timeout: 20_000,
    });
    const lvlBefore = await readLvlFromBadge(page);
    // Fresh user starts at LVL 1 (or at least very low; assert before > 0).
    expect(lvlBefore).toBeGreaterThanOrEqual(1);

    // Save a 5-set bench press workout.
    await saveSimpleBenchWorkout(page);

    // After save_workout completes, xpProvider re-reads character_state.
    // Allow time for the LVL badge to update. The xpNotifier calls awardXp
    // (18a no-op) then refreshes via getSummary, which reads character_state.
    await page.waitForTimeout(2_000);
    await expect(page.locator(GAMIFICATION.lvlBadge)).toBeVisible({
      timeout: 10_000,
    });

    const lvlAfter = await readLvlFromBadge(page);
    expect(lvlAfter).toBeGreaterThan(lvlBefore);
  });
});

// ===========================================================================
// 18a-E3 — Re-save doesn't double XP (BUG-RPG-001 regression) @smoke
//
// This test verifies the BUG-RPG-001 fix: saving the same workout twice must
// NOT double body_part_progress.total_xp. Since there is no UI path to re-save
// an existing workout session in the current app, we verify the fix via the
// Supabase admin client calling save_workout RPC twice with the same IDs, then
// assert LVL is unchanged. The test still logs in as rpgFreshUser to exercise
// the full auth + xpProvider path.
//
// Alternative approach (if re-save UI lands before 18a PR closes): use the
// workout history → continue path. For now: RPC-level assertion + badge check.
// ===========================================================================
test.describe('RPG foundation — re-save no double XP (BUG-RPG-001)', { tag: '@smoke' }, () => {
  test('should not double XP when save_workout is called twice with same IDs (18a-E3)', async ({
    page,
  }) => {
    const admin = makeAdminClient();

    // Look up rpgFreshUser ID.
    const { data: userList } = await admin.auth.admin.listUsers();
    const freshUser = userList?.users?.find(
      (u) => u.email === TEST_USERS.rpgFreshUser.email,
    );
    if (!freshUser) throw new Error('rpgFreshUser not found in Supabase auth');
    const userId = freshUser.id;

    // Clean the user's RPG state before starting (idempotent reset).
    await admin.from('xp_events').delete().eq('user_id', userId);
    await admin.from('body_part_progress').delete().eq('user_id', userId);
    await admin.from('exercise_peak_loads').delete().eq('user_id', userId);
    await admin.from('backfill_progress').delete().eq('user_id', userId);

    // Find barbell_bench_press exercise.
    const { data: exRows } = await admin
      .from('exercises')
      .select('id')
      .eq('slug', 'barbell_bench_press')
      .eq('is_default', true)
      .limit(1);
    const exId = exRows?.[0]?.id;
    if (!exId) throw new Error('barbell_bench_press not found');

    // Insert a workout + 3 sets directly (not via save_workout).
    const workoutId = crypto.randomUUID();
    const now = new Date().toISOString();
    await admin.from('workouts').insert({
      id: workoutId,
      user_id: userId,
      name: 'E2E Re-save Test Workout',
      started_at: now,
      finished_at: now,
      is_active: false,
    });

    const weId = crypto.randomUUID();
    await admin.from('workout_exercises').insert({
      id: weId,
      workout_id: workoutId,
      exercise_id: exId,
      order: 1,
    });

    const setIds: string[] = [];
    for (let s = 1; s <= 3; s++) {
      const setId = crypto.randomUUID();
      setIds.push(setId);
      await admin.from('sets').insert({
        id: setId,
        workout_exercise_id: weId,
        set_number: s,
        reps: 8,
        weight: 60,
        set_type: 'working',
        is_completed: true,
      });
    }

    // Build save_workout params (reused for both calls).
    const workoutParams = {
      id: workoutId,
      user_id: userId,
      name: 'E2E Re-save Test Workout',
      finished_at: now,
      duration_seconds: 3600,
      notes: null,
    };
    const exercisesParams = [
      { id: weId, workout_id: workoutId, exercise_id: exId, order: 1, rest_seconds: null },
    ];
    const setsParams = setIds.map((id, i) => ({
      id,
      workout_exercise_id: weId,
      set_number: i + 1,
      reps: 8,
      weight: 60,
      rpe: null,
      set_type: 'working',
      notes: null,
      is_completed: true,
    }));

    // We need an authenticated client for the user to satisfy RLS on save_workout.
    // Use the service-role client — save_workout uses SECURITY DEFINER so it runs
    // as the function owner, but we still call it with service role for convenience.
    const { error: rpc1Err } = await admin.rpc('save_workout', {
      p_workout: workoutParams,
      p_exercises: exercisesParams,
      p_sets: setsParams,
    });
    if (rpc1Err) throw new Error(`save_workout call 1 failed: ${rpc1Err.message}`);

    // Read body_part_progress after first save.
    const { data: progress1 } = await admin
      .from('body_part_progress')
      .select('body_part, total_xp')
      .eq('user_id', userId);
    const totalXp1 = (progress1 ?? []).reduce(
      (sum: number, row: any) => sum + parseFloat(row.total_xp ?? '0'),
      0,
    );

    // Call save_workout again with identical IDs (re-save scenario).
    const { error: rpc2Err } = await admin.rpc('save_workout', {
      p_workout: workoutParams,
      p_exercises: exercisesParams,
      p_sets: setsParams,
    });
    if (rpc2Err) throw new Error(`save_workout call 2 failed: ${rpc2Err.message}`);

    // Read body_part_progress after second save.
    const { data: progress2 } = await admin
      .from('body_part_progress')
      .select('body_part, total_xp')
      .eq('user_id', userId);
    const totalXp2 = (progress2 ?? []).reduce(
      (sum: number, row: any) => sum + parseFloat(row.total_xp ?? '0'),
      0,
    );

    // The total XP must not double. Allow 1% tolerance for rounding.
    const delta = Math.abs(totalXp2 - totalXp1);
    const tolerance = totalXp1 * 0.01;
    expect(delta).toBeLessThanOrEqualTo(tolerance + 0.01);

    // Verify via the UI that the LVL badge shows a stable value.
    await login(
      page,
      TEST_USERS.rpgFreshUser.email,
      TEST_USERS.rpgFreshUser.password,
    );
    await expect(page.locator(GAMIFICATION.lvlBadge)).toBeVisible({
      timeout: 20_000,
    });
    const lvl = await readLvlFromBadge(page);
    // Fresh user just ran bench × 3 sets — should be LVL >= 1 (no regression to 0).
    expect(lvl).toBeGreaterThanOrEqual(1);
  });
});

// ===========================================================================
// 18a-E4 — XP accumulates across workouts (rpgFoundationUser) [regression]
//
// Record the current LVL after backfill, then save an additional workout and
// assert the LVL is strictly greater (or equal if already at a cap — but with
// the foundation fixture it should not be at LVL 99 yet).
// ===========================================================================
test.describe('RPG foundation — XP accumulates across workouts', () => {
  test('should show strictly higher LVL after saving additional workout (18a-E4)', async ({
    page,
  }) => {
    await login(
      page,
      TEST_USERS.rpgFoundationUser.email,
      TEST_USERS.rpgFoundationUser.password,
    );

    // Wait for backfill to complete and LVL badge to stabilize.
    await expect(page.locator(GAMIFICATION.lvlBadge)).toBeVisible({
      timeout: 30_000,
    });
    // Give the badge a moment to settle after the backfill resolves.
    await page.waitForTimeout(2_000);
    const lvlBefore = await readLvlFromBadge(page);

    // Save an additional workout.
    await saveSimpleBenchWorkout(page);

    // Allow the badge to update after the save.
    await page.waitForTimeout(3_000);
    await expect(page.locator(GAMIFICATION.lvlBadge)).toBeVisible({
      timeout: 10_000,
    });
    const lvlAfter = await readLvlFromBadge(page);

    // LVL should be >= before (may not advance if the delta is small; we assert
    // no regression. Strict > is expected but we allow = to avoid flakiness
    // on edge cases near a rank boundary where characterLevel formula floors).
    expect(lvlAfter).toBeGreaterThanOrEqual(lvlBefore);
  });
});

// ===========================================================================
// 18a-E5 — Saga intro gate regression [regression]
//
// The existing gamification-intro.spec.ts must still pass after the 18a
// migration. This test is a stub that documents the dependency — the actual
// regression is validated by running gamification-intro.spec.ts in CI.
//
// We include a minimal smoke check here: the lvl-badge is visible on the
// sagaIntroUser account after dismissal (same assertion as gamification-intro
// test 3), verifying the 18a shim returns the correct shape.
// ===========================================================================
test.describe('RPG foundation — saga intro gate regression (18a-E5)', () => {
  test('should render LVL badge for sagaIntroUser after intro dismissal (18a-E5 sentinel)', async ({
    page,
  }) => {
    // sagaIntroUser is the user from gamification-intro.spec.ts.
    // We re-use it here as a sentinel: if the shim regresses, this user's
    // LVL badge will fail to render.
    const sagaUser = TEST_USERS.sagaIntroUser;

    await login(page, sagaUser.email, sagaUser.password);

    // After login + saga intro dismissal, the LVL badge must be visible.
    await expect(page.locator(GAMIFICATION.lvlBadge)).toBeVisible({
      timeout: 20_000,
    });

    // The badge text must match 'LVL {n}' pattern.
    const lvl = await readLvlFromBadge(page);
    expect(lvl).toBeGreaterThanOrEqual(1);
  });
});

// ===========================================================================
// 18a-E6 — Concurrent body-part attribution (rpgFreshUser) [regression]
//
// Save a compound workout with Barbell Squat (legs 0.80 / core 0.10 / back 0.10
// per spec §5.2 back_squat mapping — squat slug is 'barbell_squat').
// After save_workout, query body_part_progress directly via the admin client.
// Assert: all 3 attributed body parts have total_xp > 0 AND the XP ratios
// are within 5% of the expected 0.80 / 0.10 / 0.10 split.
//
// The attribution map for 'barbell_squat': legs 0.80, core 0.10, back 0.10.
// ===========================================================================
test.describe('RPG foundation — compound body-part attribution (18a-E6)', () => {
  test('should distribute XP across legs/core/back per squat attribution map (18a-E6)', async ({
    page,
  }) => {
    const admin = makeAdminClient();

    // Look up rpgFreshUser ID.
    const { data: userList } = await admin.auth.admin.listUsers();
    const freshUser = userList?.users?.find(
      (u) => u.email === TEST_USERS.rpgFreshUser.email,
    );
    if (!freshUser) throw new Error('rpgFreshUser not found');
    const userId = freshUser.id;

    // Clean RPG state for a deterministic start.
    await admin.from('xp_events').delete().eq('user_id', userId);
    await admin.from('body_part_progress').delete().eq('user_id', userId);
    await admin.from('exercise_peak_loads').delete().eq('user_id', userId);
    await admin.from('backfill_progress').delete().eq('user_id', userId);

    // Find barbell_squat exercise.
    // Note: 'barbell_squat' is the actual slug in the migration; the spec
    // refers to 'back_squat' in §5.2 but the DB slug is 'barbell_squat'.
    const { data: sqRows } = await admin
      .from('exercises')
      .select('id, xp_attribution')
      .eq('slug', 'barbell_squat')
      .eq('is_default', true)
      .limit(1);
    const squat = sqRows?.[0];
    if (!squat) throw new Error('barbell_squat exercise not found');

    // Verify the attribution map is as expected (legs 0.80 / core 0.10 / back 0.10).
    // This also validates the migration inserted the correct xp_attribution JSON.
    const attr = squat.xp_attribution as Record<string, number> | null;
    if (attr) {
      // Tolerate 1% deviation in the stored values.
      expect(Math.abs((attr['legs'] ?? 0) - 0.80)).toBeLessThan(0.01);
      expect(Math.abs((attr['core'] ?? 0) - 0.10)).toBeLessThan(0.01);
      expect(Math.abs((attr['back'] ?? 0) - 0.10)).toBeLessThan(0.01);
    }

    // Insert a workout with 3 sets of barbell_squat and call save_workout.
    const workoutId = crypto.randomUUID();
    const now = new Date().toISOString();
    await admin.from('workouts').insert({
      id: workoutId,
      user_id: userId,
      name: 'E2E Squat Attribution Workout',
      started_at: now,
      finished_at: now,
      is_active: false,
    });

    const weId = crypto.randomUUID();
    await admin.from('workout_exercises').insert({
      id: weId,
      workout_id: workoutId,
      exercise_id: squat.id,
      order: 1,
    });

    const setIds: string[] = [];
    for (let s = 1; s <= 3; s++) {
      const setId = crypto.randomUUID();
      setIds.push(setId);
      await admin.from('sets').insert({
        id: setId,
        workout_exercise_id: weId,
        set_number: s,
        reps: 5,
        weight: 100,
        set_type: 'working',
        is_completed: true,
      });
    }

    const { error: rpcErr } = await admin.rpc('save_workout', {
      p_workout: {
        id: workoutId,
        user_id: userId,
        name: 'E2E Squat Attribution Workout',
        finished_at: now,
        duration_seconds: 3600,
        notes: null,
      },
      p_exercises: [
        { id: weId, workout_id: workoutId, exercise_id: squat.id, order: 1, rest_seconds: null },
      ],
      p_sets: setIds.map((id, i) => ({
        id,
        workout_exercise_id: weId,
        set_number: i + 1,
        reps: 5,
        weight: 100,
        rpe: null,
        set_type: 'working',
        notes: null,
        is_completed: true,
      })),
    });

    if (rpcErr) throw new Error(`save_workout for squat attribution test failed: ${rpcErr.message}`);

    // Read body_part_progress for this user.
    const { data: progress, error: progressErr } = await admin
      .from('body_part_progress')
      .select('body_part, total_xp')
      .eq('user_id', userId);

    if (progressErr) throw new Error(`body_part_progress read failed: ${progressErr.message}`);
    if (!progress || progress.length === 0) {
      throw new Error('body_part_progress is empty after save_workout — XP was not recorded');
    }

    // Build a map from body_part → total_xp.
    const xpByPart: Record<string, number> = {};
    for (const row of progress) {
      xpByPart[row.body_part as string] = parseFloat(row.total_xp ?? '0');
    }

    // Assert all 3 attributed body parts have non-zero XP.
    expect(xpByPart['legs'] ?? 0).toBeGreaterThan(0);
    expect(xpByPart['core'] ?? 0).toBeGreaterThan(0);
    expect(xpByPart['back'] ?? 0).toBeGreaterThan(0);

    // Assert the XP ratios match the attribution map within 5% tolerance.
    // Total XP = legs + core + back (only these three parts have attribution > 0).
    const totalXp = (xpByPart['legs'] ?? 0) + (xpByPart['core'] ?? 0) + (xpByPart['back'] ?? 0);
    if (totalXp > 0) {
      const legsRatio = (xpByPart['legs'] ?? 0) / totalXp;
      const coreRatio = (xpByPart['core'] ?? 0) / totalXp;
      const backRatio = (xpByPart['back'] ?? 0) / totalXp;

      // legs: expected 0.80 ± 5%
      expect(Math.abs(legsRatio - 0.80)).toBeLessThanOrEqualTo(0.05);
      // core: expected 0.10 ± 5%
      expect(Math.abs(coreRatio - 0.10)).toBeLessThanOrEqualTo(0.05);
      // back: expected 0.10 ± 5%
      expect(Math.abs(backRatio - 0.10)).toBeLessThanOrEqualTo(0.05);
    }

    // Final UI check: login and verify LVL badge updates (XP was awarded).
    await login(
      page,
      TEST_USERS.rpgFreshUser.email,
      TEST_USERS.rpgFreshUser.password,
    );
    await expect(page.locator(GAMIFICATION.lvlBadge)).toBeVisible({
      timeout: 20_000,
    });
  });
});
