/**
 * Playwright global setup — creates E2E test users via Supabase Admin Auth API.
 *
 * Runs once before all tests. Creates each test user with email_confirm: true
 * so they can log in immediately without email verification.
 *
 * Uses the Service Role key (admin privileges) — never expose this key to the
 * client-side app. It is only used here in the test setup process.
 *
 * If a user already exists (e.g., from a previous interrupted run), the error
 * is swallowed and setup continues so reruns are idempotent.
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';

dotenv.config({ path: path.join(__dirname, '.env.local') });

const TEST_USERS = [
  // Smoke suite users
  'e2e-smoke-auth@test.local',
  'e2e-smoke-workout@test.local',
  'e2e-smoke-pr@test.local',
  'e2e-smoke-exercise@test.local',
  // Regression smoke users (BUG-001 through BUG-005)
  'e2e-smoke-routine-start@test.local',
  'e2e-smoke-form-tips@test.local',
  // BUG-001 manual workout restore path
  'e2e-smoke-workout-restore@test.local',
  // BUG-003 negative path smoke
  'e2e-smoke-routine-error@test.local',
  // New smoke suite users (weekly plan, onboarding, routine management, etc.)
  'e2e-smoke-weekly-plan@test.local',
  'e2e-smoke-onboarding@test.local',
  'e2e-smoke-routine-mgmt@test.local',
  'e2e-smoke-weekly-plan-review@test.local',
  'e2e-smoke-profile-goal@test.local',
  // First-workout beginner CTA (P8) — fresh user with zero workouts
  'e2e-smoke-first-workout@test.local',
  // Full suite users (one per spec file)
  'e2e-full-auth@test.local',
  'e2e-full-exercises@test.local',
  'e2e-full-workout@test.local',
  'e2e-full-routines@test.local',
  'e2e-full-pr@test.local',
  'e2e-full-home@test.local',
  'e2e-full-crash@test.local',
  'e2e-full-history@test.local',
  'e2e-full-manage-data@test.local',
  // Regression full suite user (BUG-003/BUG-004/BUG-005)
  'e2e-full-routine-regression@test.local',
  // Exercise detail bottom sheet full spec (BUG-002 in-workout path)
  'e2e-full-ex-detail-sheet@test.local',
  // Exercise progress chart smoke (P1) — needs a seeded completed working set
  'e2e-smoke-exercise-progress@test.local',
  // Offline sync smoke (Phase 14) — offline-sync.spec.ts
  'e2e-smoke-offline-sync@test.local',
  // Localization smoke (Phase 15e) — localization.spec.ts
  'e2e-smoke-localization@test.local',
  // Localization en-default (Phase 15e) — en→pt picker + persistence tests
  'e2e-smoke-localization-en@test.local',
  // Phase 17b gamification intro — fresh user, saga intro never dismissed
  'e2e-saga-intro@test.local',
  // Phase 15f localization — pt-BR content tests
  'e2e-smoke-loc-workout@test.local',
  'e2e-full-history-pt@test.local',
  'e2e-smoke-loc-routines@test.local',
  'e2e-full-pr-pt@test.local',
  // Phase 18a — RPG foundation e2e tests
  'e2e-rpg-foundation@test.local',
  'e2e-rpg-fresh@test.local',
  // Phase 18c — celebration overlay e2e tests
  'e2e-rpg-rank-up-threshold@test.local',
  'e2e-rpg-multi-celebration@test.local',
  'e2e-rpg-overflow-queue@test.local',
  // Dedicated user for overflow card tap-to-/profile test (isolated from
  // rpgOverflowQueue to prevent cross-worker XP races under --repeat-each).
  'e2e-rpg-overflow-tap@test.local',
  // Phase 18e — class-cross and title-equip E2E tests
  'e2e-rpg-class-cross@test.local',
  'e2e-rpg-title-equip@test.local',
];

/**
 * Look up a user ID by email from the Supabase auth admin API.
 * Returns null if not found.
 */
async function getUserId(
  supabase: SupabaseClient,
  email: string,
): Promise<string | null> {
  const { data: listData } = await supabase.auth.admin.listUsers();
  const user = listData?.users?.find((u) => u.email === email);
  return user?.id ?? null;
}

/**
 * Seed a single minimal completed workout for a user.
 *
 * P8 introduced a new-user CTA that replaces the "Plan your week" empty state
 * when `workoutCount == 0`. Some weekly-plan tests still assume the empty state
 * shows "Plan your week", so we seed one workout for those users to push
 * `workoutCount` above 0. This preserves the test semantics (weekly plan
 * feature is tested for "already-onboarded" users, not brand-new ones).
 *
 * Idempotent: checks for an existing workout named 'E2E Warmup Workout'.
 */
async function seedMinimalWorkout(
  supabase: SupabaseClient,
  userId: string,
): Promise<void> {
  const { data: existing } = await supabase
    .from('workouts')
    .select('id')
    .eq('user_id', userId)
    .eq('name', 'E2E Warmup Workout')
    .maybeSingle();

  if (existing) return;

  const now = new Date();
  const startedAt = new Date(now.getTime() - 2 * 60 * 60 * 1000);
  const finishedAt = new Date(now.getTime() - 90 * 60 * 1000);

  const { error } = await supabase.from('workouts').insert({
    user_id: userId,
    name: 'E2E Warmup Workout',
    started_at: startedAt.toISOString(),
    finished_at: finishedAt.toISOString(),
    duration_seconds: 1800,
  });

  if (error) {
    console.log(
      `[global-setup] Warning: could not seed minimal workout for ${userId}: ${error.message}`,
    );
  }
}

/**
 * Seed workout data for the smokePR user so PR display tests find records.
 *
 * Inserts: workout -> workout_exercise -> set -> personal_record
 * Uses "Barbell Bench Press" (seeded by seed.sql).
 *
 * Idempotent: checks if a workout named 'E2E Seed Workout' already exists.
 */
async function seedPRData(
  supabase: SupabaseClient,
  userId: string,
): Promise<void> {
  // Check if seed workout already exists
  const { data: existing } = await supabase
    .from('workouts')
    .select('id')
    .eq('user_id', userId)
    .eq('name', 'E2E Seed Workout')
    .maybeSingle();

  if (existing) {
    console.log('[global-setup] PR seed data already exists, skipping.');
    return;
  }

  // Find "Barbell Bench Press" exercise by slug (slug column is stable; name
  // column was dropped in Phase 15f migration 00034).
  const { data: exercises, error: exError } = await supabase
    .from('exercises')
    .select('id')
    .eq('slug', 'barbell_bench_press')
    .eq('is_default', true)
    .limit(1);
  const exercise = exercises?.[0] ?? null;

  if (exError || !exercise) {
    console.log(
      `[global-setup] Warning: could not find Barbell Bench Press exercise: ${exError?.message}`,
    );
    return;
  }

  const now = new Date();
  const startedAt = new Date(now.getTime() - 60 * 60 * 1000); // 1h ago
  const finishedAt = new Date(now.getTime() - 30 * 60 * 1000); // 30min ago

  // Insert completed workout
  const { data: workout, error: wError } = await supabase
    .from('workouts')
    .insert({
      user_id: userId,
      name: 'E2E Seed Workout',
      started_at: startedAt.toISOString(),
      finished_at: finishedAt.toISOString(),
      duration_seconds: 1800,
    })
    .select('id')
    .single();

  if (wError || !workout) {
    console.log(
      `[global-setup] Warning: could not insert seed workout: ${wError?.message}`,
    );
    return;
  }

  // Insert workout_exercise
  const { data: wx, error: wxError } = await supabase
    .from('workout_exercises')
    .insert({
      workout_id: workout.id,
      exercise_id: exercise.id,
      order: 0,
    })
    .select('id')
    .single();

  if (wxError || !wx) {
    console.log(
      `[global-setup] Warning: could not insert seed workout_exercise: ${wxError?.message}`,
    );
    return;
  }

  // Insert set
  const { data: set, error: setError } = await supabase
    .from('sets')
    .insert({
      workout_exercise_id: wx.id,
      set_number: 1,
      reps: 5,
      weight: 100,
      set_type: 'working',
      is_completed: true,
    })
    .select('id')
    .single();

  if (setError || !set) {
    console.log(
      `[global-setup] Warning: could not insert seed set: ${setError?.message}`,
    );
    return;
  }

  // Insert personal_record
  const { error: prError } = await supabase.from('personal_records').insert({
    user_id: userId,
    exercise_id: exercise.id,
    record_type: 'max_weight',
    value: 100,
    reps: 5,
    achieved_at: finishedAt.toISOString(),
    set_id: set.id,
  });

  if (prError) {
    console.log(
      `[global-setup] Warning: could not insert seed personal_record: ${prError.message}`,
    );
    return;
  }

  console.log(`[global-setup] Seeded PR data for smokePR user (workout: ${workout.id})`);
}

/**
 * Seed a completed weekly plan for the smokeWeeklyPlanReview user.
 *
 * Inserts: profile (frequency 1), workout, weekly_plan with completed routine.
 * Uses the "Push Day" starter template (seeded by seed.sql).
 *
 * Idempotent: checks if a weekly_plan for this week already exists.
 */
async function seedWeeklyPlanReviewData(
  supabase: SupabaseClient,
  userId: string,
): Promise<void> {
  // Calculate this Monday (ISO week start)
  const now = new Date();
  const dayOfWeek = now.getUTCDay(); // 0=Sun, 1=Mon, ..., 6=Sat
  const mondayOffset = dayOfWeek === 0 ? -6 : 1 - dayOfWeek;
  const thisMonday = new Date(now);
  thisMonday.setUTCDate(now.getUTCDate() + mondayOffset);
  thisMonday.setUTCHours(0, 0, 0, 0);
  const weekStart = thisMonday.toISOString().split('T')[0]; // YYYY-MM-DD

  // Check if weekly plan already exists for this week
  const { data: existingPlan } = await supabase
    .from('weekly_plans')
    .select('id')
    .eq('user_id', userId)
    .eq('week_start', weekStart)
    .maybeSingle();

  if (existingPlan) {
    console.log('[global-setup] Weekly plan review seed data already exists, skipping.');
    return;
  }

  // Upsert profile with training_frequency_per_week: 2 (minimum valid value, low enough that 1 routine = done)
  // Note: the CHECK constraint is BETWEEN 2 AND 6, so minimum is 2.
  // However, for "WEEK COMPLETE" we need completed_count >= frequency.
  // We'll set frequency to 2 and insert 2 completed workouts to satisfy it.
  const { error: profileError } = await supabase
    .from('profiles')
    .upsert(
      {
        id: userId,
        display_name: 'Weekly Plan Reviewer',
        fitness_level: 'intermediate',
        training_frequency_per_week: 2,
      },
      { onConflict: 'id' },
    );

  if (profileError) {
    console.log(
      `[global-setup] Warning: could not upsert profile for weekly plan review: ${profileError.message}`,
    );
    return;
  }

  // Find "Push Day" workout template (limit 1 in case seed.sql ran multiple times)
  const { data: templates, error: templateError } = await supabase
    .from('workout_templates')
    .select('id')
    .eq('name', 'Push Day')
    .eq('is_default', true)
    .limit(1);
  const pushDay = templates?.[0] ?? null;

  if (templateError || !pushDay) {
    console.log(
      `[global-setup] Warning: could not find Push Day template: ${templateError?.message}`,
    );
    return;
  }

  // Insert 2 completed workouts (to match frequency of 2)
  const startedAt1 = new Date(now.getTime() - 2 * 60 * 60 * 1000);
  const finishedAt1 = new Date(now.getTime() - 90 * 60 * 1000);
  const startedAt2 = new Date(now.getTime() - 60 * 60 * 1000);
  const finishedAt2 = new Date(now.getTime() - 30 * 60 * 1000);

  const { data: workout1, error: w1Error } = await supabase
    .from('workouts')
    .insert({
      user_id: userId,
      name: 'Push Day',
      started_at: startedAt1.toISOString(),
      finished_at: finishedAt1.toISOString(),
      duration_seconds: 1800,
    })
    .select('id')
    .single();

  if (w1Error || !workout1) {
    console.log(
      `[global-setup] Warning: could not insert seed workout 1: ${w1Error?.message}`,
    );
    return;
  }

  const { data: workout2, error: w2Error } = await supabase
    .from('workouts')
    .insert({
      user_id: userId,
      name: 'Push Day',
      started_at: startedAt2.toISOString(),
      finished_at: finishedAt2.toISOString(),
      duration_seconds: 1800,
    })
    .select('id')
    .single();

  if (w2Error || !workout2) {
    console.log(
      `[global-setup] Warning: could not insert seed workout 2: ${w2Error?.message}`,
    );
    return;
  }

  // Insert weekly_plan with 2 completed routines
  const routines = [
    {
      routine_id: pushDay.id,
      order: 0,
      completed_workout_id: workout1.id,
      completed_at: finishedAt1.toISOString(),
    },
    {
      routine_id: pushDay.id,
      order: 1,
      completed_workout_id: workout2.id,
      completed_at: finishedAt2.toISOString(),
    },
  ];

  const { error: planError } = await supabase.from('weekly_plans').insert({
    user_id: userId,
    week_start: weekStart,
    routines: routines,
  });

  if (planError) {
    console.log(
      `[global-setup] Warning: could not insert seed weekly_plan: ${planError.message}`,
    );
    return;
  }

  console.log(
    `[global-setup] Seeded completed weekly plan for smokeWeeklyPlanReview (week: ${weekStart})`,
  );
}

/**
 * Seed two completed working sets on two different calendar dates for the
 * smokeExerciseProgress user so ProgressChartSection renders its multi-point
 * LineChart branch (which emits the `image: true` Semantics node the smoke
 * test selector matches).
 *
 * A single-point series is intentionally rendered as copy-only ("1 session
 * logged") with NO `image: true` semantics — see
 * `lib/features/exercises/ui/widgets/progress_chart_section.dart`. Seeding a
 * second session on a distinct calendar day bumps us onto the chart branch.
 *
 * Inserts: profile → 2 × (workout → workout_exercise → set). The two workouts
 * are >1 day apart (8 days and today) to avoid device-local timezone edge
 * cases around day-bucketing in `buildProgressPoints`.
 *
 * Uses "Barbell Bench Press" (seeded by seed.sql). Both sets are
 * `set_type = 'working'` and `is_completed = true` — the predicate in
 * `lib/features/workouts/utils/set_filters.dart` filters on exactly that.
 *
 * Idempotent: checks if a workout named 'E2E Progress Chart Workout 1' already
 * exists for this user.
 */
async function seedExerciseProgressData(
  supabase: SupabaseClient,
  userId: string,
): Promise<void> {
  const { data: existing } = await supabase
    .from('workouts')
    .select('id')
    .eq('user_id', userId)
    .eq('name', 'E2E Progress Chart Workout 1')
    .maybeSingle();

  if (existing) {
    console.log('[global-setup] Exercise progress seed data already exists, skipping.');
    return;
  }

  // Find "Barbell Bench Press" exercise by slug (slug column is stable; name
  // column was dropped in Phase 15f migration 00034).
  const { data: exercises, error: exError } = await supabase
    .from('exercises')
    .select('id')
    .eq('slug', 'barbell_bench_press')
    .eq('is_default', true)
    .limit(1);
  const exercise = exercises?.[0] ?? null;

  if (exError || !exercise) {
    console.log(
      `[global-setup] Warning: could not find Barbell Bench Press for progress seed: ${exError?.message}`,
    );
    return;
  }

  const now = new Date();
  // Session 1: ~8 days ago (>1-day gap keeps us clear of timezone edge cases).
  const startedAt1 = new Date(now.getTime() - 8 * 24 * 60 * 60 * 1000);
  const finishedAt1 = new Date(
    now.getTime() - 8 * 24 * 60 * 60 * 1000 + 30 * 60 * 1000,
  );
  // Session 2: today (~90 minutes ago, matches the pattern of other seed helpers).
  const startedAt2 = new Date(now.getTime() - 2 * 60 * 60 * 1000);
  const finishedAt2 = new Date(now.getTime() - 90 * 60 * 1000);

  const sessions: Array<{
    name: string;
    startedAt: Date;
    finishedAt: Date;
    weight: number;
  }> = [
    {
      name: 'E2E Progress Chart Workout 1',
      startedAt: startedAt1,
      finishedAt: finishedAt1,
      weight: 80,
    },
    {
      name: 'E2E Progress Chart Workout 2',
      startedAt: startedAt2,
      finishedAt: finishedAt2,
      weight: 82.5,
    },
  ];

  const insertedWorkoutIds: string[] = [];
  for (const session of sessions) {
    const { data: workout, error: wError } = await supabase
      .from('workouts')
      .insert({
        user_id: userId,
        name: session.name,
        started_at: session.startedAt.toISOString(),
        finished_at: session.finishedAt.toISOString(),
        duration_seconds: 1800,
      })
      .select('id')
      .single();

    if (wError || !workout) {
      console.log(
        `[global-setup] Warning: could not insert progress chart workout (${session.name}): ${wError?.message}`,
      );
      return;
    }

    const { data: wx, error: wxError } = await supabase
      .from('workout_exercises')
      .insert({
        workout_id: workout.id,
        exercise_id: exercise.id,
        order: 0,
      })
      .select('id')
      .single();

    if (wxError || !wx) {
      console.log(
        `[global-setup] Warning: could not insert progress chart workout_exercise (${session.name}): ${wxError?.message}`,
      );
      return;
    }

    const { error: setError } = await supabase.from('sets').insert({
      workout_exercise_id: wx.id,
      set_number: 1,
      reps: 5,
      weight: session.weight,
      set_type: 'working',
      is_completed: true,
    });

    if (setError) {
      console.log(
        `[global-setup] Warning: could not insert progress chart set (${session.name}): ${setError.message}`,
      );
      return;
    }

    insertedWorkoutIds.push(workout.id);
  }

  console.log(
    `[global-setup] Seeded exercise progress data for smokeExerciseProgress (workouts: ${insertedWorkoutIds.join(', ')})`,
  );
}

/**
 * Seed the rpgFoundationUser with ~12 prior workouts across 6 weeks and
 * multiple body parts, so the backfill produces lifetime_xp > 0 and LVL > 1.
 *
 * Workout plan (12 sessions over 6 weeks, 2 per week):
 *   Sessions 1-4:  barbell_bench_press (chest dominant)
 *   Sessions 5-8:  barbell_squat (legs dominant)
 *   Sessions 9-12: barbell_bent_over_row (back dominant)
 *
 * Each session: 3 working sets × the exercise. This ensures multiple body-part
 * progress rows are created by backfill. Seeding inserts the raw workout/set
 * rows directly (bypass save_workout RPC) so backfill processes them on first
 * login.
 *
 * Idempotent: checks for 'E2E RPG Foundation Workout 1' before seeding.
 */
async function seedRpgFoundationUser(supabase: SupabaseClient): Promise<void> {
  const email = 'e2e-rpg-foundation@test.local';
  const userId = await getUserId(supabase, email);
  if (!userId) return;

  // Ensure profile row exists so the router lands on /home.
  await supabase.from('profiles').upsert(
    {
      id: userId,
      display_name: 'RPG Foundation User',
      fitness_level: 'intermediate',
    },
    { onConflict: 'id' },
  );

  // Check idempotency.
  const { data: existing } = await supabase
    .from('workouts')
    .select('id')
    .eq('user_id', userId)
    .eq('name', 'E2E RPG Foundation Workout 1')
    .maybeSingle();
  if (existing) {
    console.log('[global-setup] RPG foundation seed data already exists, skipping.');
    return;
  }

  // Find exercises by slug.
  const slugs = ['barbell_bench_press', 'barbell_squat', 'barbell_bent_over_row'];
  const exerciseMap: Record<string, string> = {};
  for (const slug of slugs) {
    const { data: exRows } = await supabase
      .from('exercises')
      .select('id')
      .eq('slug', slug)
      .eq('is_default', true)
      .limit(1);
    const ex = exRows?.[0];
    if (!ex) {
      console.log(`[global-setup] Warning: could not find exercise ${slug} for RPG foundation seed.`);
      return;
    }
    exerciseMap[slug] = ex.id;
  }

  // 12 workout sessions: 2 per week for 6 weeks ago → now.
  // Weeks 6-5-4-3-2-1 ago (oldest first so backfill cursor traverses in order).
  const sessions: Array<{ name: string; slug: string; weightKg: number; reps: number; weeksAgo: number; dayOffset: number }> = [
    // Week 6 ago
    { name: 'E2E RPG Foundation Workout 1', slug: 'barbell_bench_press', weightKg: 70, reps: 8, weeksAgo: 6, dayOffset: 1 },
    { name: 'E2E RPG Foundation Workout 2', slug: 'barbell_squat', weightKg: 90, reps: 5, weeksAgo: 6, dayOffset: 4 },
    // Week 5 ago
    { name: 'E2E RPG Foundation Workout 3', slug: 'barbell_bench_press', weightKg: 72.5, reps: 8, weeksAgo: 5, dayOffset: 1 },
    { name: 'E2E RPG Foundation Workout 4', slug: 'barbell_squat', weightKg: 92.5, reps: 5, weeksAgo: 5, dayOffset: 4 },
    // Week 4 ago
    { name: 'E2E RPG Foundation Workout 5', slug: 'barbell_bent_over_row', weightKg: 60, reps: 10, weeksAgo: 4, dayOffset: 1 },
    { name: 'E2E RPG Foundation Workout 6', slug: 'barbell_bench_press', weightKg: 75, reps: 8, weeksAgo: 4, dayOffset: 4 },
    // Week 3 ago
    { name: 'E2E RPG Foundation Workout 7', slug: 'barbell_squat', weightKg: 95, reps: 5, weeksAgo: 3, dayOffset: 1 },
    { name: 'E2E RPG Foundation Workout 8', slug: 'barbell_bent_over_row', weightKg: 62.5, reps: 10, weeksAgo: 3, dayOffset: 4 },
    // Week 2 ago
    { name: 'E2E RPG Foundation Workout 9', slug: 'barbell_bench_press', weightKg: 77.5, reps: 8, weeksAgo: 2, dayOffset: 1 },
    { name: 'E2E RPG Foundation Workout 10', slug: 'barbell_squat', weightKg: 97.5, reps: 5, weeksAgo: 2, dayOffset: 4 },
    // Week 1 ago
    { name: 'E2E RPG Foundation Workout 11', slug: 'barbell_bent_over_row', weightKg: 65, reps: 10, weeksAgo: 1, dayOffset: 1 },
    { name: 'E2E RPG Foundation Workout 12', slug: 'barbell_bench_press', weightKg: 80, reps: 8, weeksAgo: 1, dayOffset: 4 },
  ];

  const now = new Date();
  let seededCount = 0;
  for (const session of sessions) {
    const startedAt = new Date(now);
    startedAt.setDate(now.getDate() - session.weeksAgo * 7 - session.dayOffset);
    startedAt.setHours(10, 0, 0, 0);
    const finishedAt = new Date(startedAt.getTime() + 60 * 60 * 1000);

    const { data: workout, error: wErr } = await supabase
      .from('workouts')
      .insert({
        user_id: userId,
        name: session.name,
        started_at: startedAt.toISOString(),
        finished_at: finishedAt.toISOString(),
        duration_seconds: 3600,
      })
      .select('id')
      .single();

    if (wErr || !workout) {
      console.log(`[global-setup] Warning: could not insert RPG foundation workout (${session.name}): ${wErr?.message}`);
      continue;
    }

    const { data: wx, error: wxErr } = await supabase
      .from('workout_exercises')
      .insert({
        workout_id: workout.id,
        exercise_id: exerciseMap[session.slug],
        order: 1,
      })
      .select('id')
      .single();

    if (wxErr || !wx) {
      console.log(`[global-setup] Warning: could not insert workout_exercise for ${session.name}: ${wxErr?.message}`);
      continue;
    }

    // 3 working sets per session.
    for (let s = 1; s <= 3; s++) {
      const { error: setErr } = await supabase.from('sets').insert({
        workout_exercise_id: wx.id,
        set_number: s,
        reps: session.reps,
        weight: session.weightKg,
        set_type: 'working',
        is_completed: true,
      });
      if (setErr) {
        console.log(`[global-setup] Warning: could not insert set ${s} for ${session.name}: ${setErr.message}`);
      }
    }

    seededCount++;
  }

  console.log(`[global-setup] Seeded ${seededCount} RPG foundation workouts for rpgFoundationUser`);
}

/**
 * Seed the rpgFreshUser with just a profile row (zero workout history).
 * The backfill produces 0 XP → LVL 1. Used by E2-E3-E6 tests.
 *
 * Clean on every run: deletes all workouts + XP data so state is deterministic.
 */
async function seedRpgFreshUser(supabase: SupabaseClient): Promise<void> {
  const email = 'e2e-rpg-fresh@test.local';
  const userId = await getUserId(supabase, email);
  if (!userId) return;

  // Clean all workout data + RPG XP state every run (fresh user must start clean).
  const { data: existingWorkouts } = await supabase
    .from('workouts')
    .select('id')
    .eq('user_id', userId);
  if (existingWorkouts && existingWorkouts.length > 0) {
    const workoutIds = existingWorkouts.map((w: { id: string }) => w.id);
    const { data: wxs } = await supabase
      .from('workout_exercises')
      .select('id')
      .in('workout_id', workoutIds);
    if (wxs && wxs.length > 0) {
      await supabase.from('sets').delete().in('workout_exercise_id', wxs.map((wx: { id: string }) => wx.id));
    }
    await supabase.from('workout_exercises').delete().in('workout_id', workoutIds);
    await supabase.from('workouts').delete().in('id', workoutIds);
  }

  // Clean RPG tables.
  await supabase.from('xp_events').delete().eq('user_id', userId);
  await supabase.from('body_part_progress').delete().eq('user_id', userId);
  await supabase.from('exercise_peak_loads').delete().eq('user_id', userId);
  await supabase.from('backfill_progress').delete().eq('user_id', userId);

  // Pre-seed backfill_progress as completed (sets_processed=0, completed_at=NOW).
  // This prevents the Flutter app's SagaIntroGate from triggering
  // backfill_rpg_v1 on login (the server-side completed_at guard short-circuits
  // it). Without this, the RPC might create tiny floating-point XP artifacts
  // in the full E2E suite, causing isZeroHistory to return false and hiding
  // the first-set-awakens banner.
  await supabase.from('backfill_progress').upsert(
    {
      user_id: userId,
      sets_processed: 0,
      started_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      completed_at: new Date().toISOString(),
    },
    { onConflict: 'user_id' },
  );

  // Upsert profile so the router lands on /home (not /onboarding).
  await supabase.from('profiles').upsert(
    {
      id: userId,
      display_name: 'RPG Fresh User',
      fitness_level: 'beginner',
    },
    { onConflict: 'id' },
  );

  // Seed peak loads for the two exercises used in S3 so strength_mult = 1.0
  // on the first workout attempt. Without peak loads, the RPC uses peak=0
  // and advances peak to the current weight before computing strength_mult —
  // that works correctly (strength_mult = 1.0 per the RPC comment) but the
  // timing of the peak-load upsert inside save_workout can occasionally cause
  // the second save in the same test run to fail XP attribution, making S3
  // flaky on first run. Seeding peaks up-front makes the run deterministic.
  const { data: benchRows } = await supabase
    .from('exercises').select('id').eq('slug', 'barbell_bench_press').eq('is_default', true).limit(1);
  const benchIdFresh = benchRows?.[0]?.id;
  if (benchIdFresh) {
    await supabase.from('exercise_peak_loads').upsert(
      { user_id: userId, exercise_id: benchIdFresh, peak_weight: 60, peak_reps: 5, peak_date: new Date().toISOString() },
      { onConflict: 'user_id,exercise_id' },
    );
  }
  const { data: squatRows } = await supabase
    .from('exercises').select('id').eq('slug', 'barbell_squat').eq('is_default', true).limit(1);
  const squatIdFresh = squatRows?.[0]?.id;
  if (squatIdFresh) {
    await supabase.from('exercise_peak_loads').upsert(
      { user_id: userId, exercise_id: squatIdFresh, peak_weight: 80, peak_reps: 5, peak_date: new Date().toISOString() },
      { onConflict: 'user_id,exercise_id' },
    );
  }

  console.log('[global-setup] Cleaned and seeded profile for rpgFreshUser');
}

/**
 * Seed rpgRankUpThreshold user:
 * chest body_part_progress at ~270 XP (Rank 5 threshold ≈ 278.46 XP).
 * One working bench-press set earns ~10-15 XP and crosses the boundary.
 *
 * Also seeds a prior minimal workout so the app lands in lapsed state
 * (Quick workout entry point visible).
 *
 * Idempotent: skips if body_part_progress row for chest already exists.
 */
async function seedRpgRankUpThresholdUser(supabase: SupabaseClient): Promise<void> {
  const email = 'e2e-rpg-rank-up-threshold@test.local';
  const userId = await getUserId(supabase, email);
  if (!userId) return;

  // Delete workouts first so record_session_xp_batch sees zero historical sets
  // on every run. The cascade chain (workouts → workout_exercises → sets) removes
  // all child rows automatically. Without this, the XP novelty discount grows on
  // each subsequent run and may prevent the rank-threshold from being crossed.
  await supabase.from('workouts').delete().eq('user_id', userId);

  // Clean RPG tables every run so XP state is deterministic.
  await supabase.from('xp_events').delete().eq('user_id', userId);
  await supabase.from('body_part_progress').delete().eq('user_id', userId);
  await supabase.from('exercise_peak_loads').delete().eq('user_id', userId);
  await supabase.from('backfill_progress').delete().eq('user_id', userId);
  await supabase.from('earned_titles').delete().eq('user_id', userId);

  // Mark backfill as completed so SagaIntroGate doesn't re-run it.
  await supabase.from('backfill_progress').upsert(
    {
      user_id: userId,
      sets_processed: 0,
      started_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      completed_at: new Date().toISOString(),
    },
    { onConflict: 'user_id' },
  );

  // Upsert profile so router lands on /home.
  await supabase.from('profiles').upsert(
    { id: userId, display_name: 'Rank Up Threshold User', fitness_level: 'intermediate' },
    { onConflict: 'id' },
  );

  // Seed chest body_part_progress at rank 2 with 120 XP.
  // Rank 3 cumulative threshold = 126 XP (60 × (1.10² − 1) / 0.10).
  // One bench press set earns ~8–12 XP for chest → crosses rank 3.
  // No title is awarded at rank 3 (first title at rank 5), so the
  // celebration queue contains only a FirstAwakeningOverlay (shoulders
  // awakens from bench secondary XP) + a RankUpOverlay — no title sheet
  // that would block navigation and fail S1.
  // Character level with chest=2, others=1: floor((2+5-6)/4)+1 = 1.
  // After chest→3: floor((3+5-6)/4)+1 = 1. No level-up. Clean queue.
  const bodyParts = ['chest', 'back', 'legs', 'shoulders', 'arms', 'core'];
  for (const bp of bodyParts) {
    const xp = bp === 'chest' ? 120 : 0;
    const rank = bp === 'chest' ? 2 : 1;
    const { error } = await supabase.from('body_part_progress').upsert(
      { user_id: userId, body_part: bp, total_xp: xp, rank },
      { onConflict: 'user_id,body_part' },
    );
    if (error) {
      console.log(`[global-setup] Warning: could not seed body_part_progress (${bp}) for rpgRankUpThreshold: ${error.message}`);
    }
  }

  // Seed peak load for bench press so strength_mult = 1.0 (weight = peak).
  const { data: benchExercises } = await supabase
    .from('exercises').select('id').eq('slug', 'barbell_bench_press').eq('is_default', true).limit(1);
  const benchId = benchExercises?.[0]?.id;
  if (benchId) {
    await supabase.from('exercise_peak_loads').upsert(
      { user_id: userId, exercise_id: benchId, peak_weight: 80, peak_reps: 5, peak_date: new Date().toISOString() },
      { onConflict: 'user_id,exercise_id' },
    );
  }

  // Seed one prior minimal workout so the app shows Quick workout (lapsed state).
  await seedMinimalWorkout(supabase, userId);

  console.log('[global-setup] Seeded rpgRankUpThresholdUser (chest at 120 XP, rank 2 → crosses rank 3 on bench set)');
}

/**
 * Seed rpgMultiCelebration user (BUG-017, Cluster 3):
 * Pre-state designed so a single bench set produces EXACTLY 3 celebration
 * events — rank-up + level-up + title — with NO class-change and NO
 * first-awakening overlay sneaking in. The pre-fix seed (chest R4→R5)
 * triggered both a class-change (Initiate→Bulwark) and a shoulders
 * first-awakening alongside the intended trio, and the cap-at-3 queue
 * silently dropped the title.
 *
 * Pre-state:
 *   * chest:                rank 9 (810 XP — just below rank-10 cumulative 815)
 *   * back, legs, shoulders: rank 2 (65 XP each — past rank-2 cumulative 60)
 *   * arms, core:           rank 1 (1 XP each — > 0 prevents first-awakening
 *                                    if attribution touches them)
 *
 * Workout: one bench set @ 80 kg × 5 reps (≈ 30 XP to chest).
 *
 * Post-state derivation:
 *   * chest: 810 + ~30 = ~840 XP, rank 10 → RankUpEvent(chest, 10)
 *   * sum_pre = 9 + 2 + 2 + 2 + 1 + 1 = 17, level = floor(11/4) + 1 = 3
 *   * sum_post = 10 + 2 + 2 + 2 + 1 + 1 = 18, level = floor(12/4) + 1 = 4
 *     → LevelUpEvent(4)
 *   * pre-class: max=9 (chest), min=1, ratio>30%, dominant=chest = Bulwark
 *     post-class: max=10 (chest), min=1, ratio>30%, dominant=chest = Bulwark
 *     → NO class change
 *   * shoulders/arms/core all have pre-XP > 0 → NO first-awakening
 *   * chest_r10_plate_bearer title fires (threshold 10, in (9, 10])
 *
 * Final queue: [rankUp(chest, 10), levelUp(4), titleUnlock(chest_r10)]
 * Exactly fits cap-at-3 — no overflow, no silent drops.
 */
async function seedRpgMultiCelebrationUser(supabase: SupabaseClient): Promise<void> {
  const email = 'e2e-rpg-multi-celebration@test.local';
  const userId = await getUserId(supabase, email);
  if (!userId) return;

  // Delete workouts first so record_session_xp_batch sees zero historical sets
  // on every run. The cascade (workouts → workout_exercises → sets) removes all
  // child rows automatically. personal_records.set_id is set to NULL by the FK
  // ON DELETE SET NULL rule — the explicit personal_records delete below then
  // removes the now-nulled records before re-seeding fresh ones.
  await supabase.from('workouts').delete().eq('user_id', userId);

  await supabase.from('xp_events').delete().eq('user_id', userId);
  await supabase.from('body_part_progress').delete().eq('user_id', userId);
  await supabase.from('exercise_peak_loads').delete().eq('user_id', userId);
  await supabase.from('personal_records').delete().eq('user_id', userId);
  await supabase.from('backfill_progress').delete().eq('user_id', userId);
  await supabase.from('earned_titles').delete().eq('user_id', userId);

  await supabase.from('backfill_progress').upsert(
    {
      user_id: userId,
      sets_processed: 0,
      started_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      completed_at: new Date().toISOString(),
    },
    { onConflict: 'user_id' },
  );

  await supabase.from('profiles').upsert(
    { id: userId, display_name: 'Multi Celebration User', fitness_level: 'intermediate' },
    { onConflict: 'id' },
  );

  // BUG-017 seed shape — see doc comment above for the full derivation.
  // Three rank-2 body parts + two rank-1 with > 0 XP avoid the first-
  // awakening overlay; chest at rank 9 with chest already dominant
  // avoids the Initiate→Bulwark class change.
  const bodyPartSeed: Record<string, { xp: number; rank: number }> = {
    chest:     { xp: 810, rank: 9 },
    back:      { xp: 65,  rank: 2 },
    legs:      { xp: 65,  rank: 2 },
    shoulders: { xp: 65,  rank: 2 },
    arms:      { xp: 1,   rank: 1 },
    core:      { xp: 1,   rank: 1 },
  };
  for (const [bp, seed] of Object.entries(bodyPartSeed)) {
    const { error } = await supabase.from('body_part_progress').upsert(
      { user_id: userId, body_part: bp, total_xp: seed.xp, rank: seed.rank },
      { onConflict: 'user_id,body_part' },
    );
    if (error) {
      console.log(`[global-setup] Warning: body_part_progress seed error (${bp}) for rpgMultiCelebration: ${error.message}`);
    }
  }

  const { data: benchExercises } = await supabase
    .from('exercises').select('id').eq('slug', 'barbell_bench_press').eq('is_default', true).limit(1);
  const benchId = benchExercises?.[0]?.id;
  if (benchId) {
    await supabase.from('exercise_peak_loads').upsert(
      { user_id: userId, exercise_id: benchId, peak_weight: 80, peak_reps: 5, peak_date: new Date().toISOString() },
      { onConflict: 'user_id,exercise_id' },
    );
    // Seed prior personal records for all three record types so the workout
    // finish does NOT trigger pr-celebration navigation (bench at 80kg/5
    // produces max_weight=80, max_reps=5, max_volume=400 — all already known).
    const benchAchievedAt = new Date(Date.now() - 86_400_000).toISOString();
    await supabase.from('personal_records').insert([
      { user_id: userId, exercise_id: benchId, record_type: 'max_weight', value: 80, reps: 5, achieved_at: benchAchievedAt },
      { user_id: userId, exercise_id: benchId, record_type: 'max_reps', value: 5, achieved_at: benchAchievedAt },
      { user_id: userId, exercise_id: benchId, record_type: 'max_volume', value: 400, achieved_at: benchAchievedAt },
    ]);
  }

  await seedMinimalWorkout(supabase, userId);

  console.log('[global-setup] Seeded rpgMultiCelebrationUser (chest 810 XP / rank 9 → R10 + level 4 + chest_r10 title; class stable, no first-awakening)');
}

/**
 * Seed rpgOverflowQueue user:
 * All 6 body-parts each seeded 8 XP below their respective rank thresholds.
 * One set per body part → 6 rank-ups in a single workout finish.
 * CelebrationQueue cap-at-3 fires: 3 overlays shown + overflow card "3 more rank-ups".
 *
 * Each body part is seeded at the XP level for its current rank - 1 set below
 * the next rank threshold. We use rank 4 → 5 boundary (≈ 270 XP) for all 6
 * body parts for simplicity. Each body part needs a different exercise so
 * XP attribution hits the right body part.
 */
async function seedRpgOverflowQueueUser(supabase: SupabaseClient): Promise<void> {
  const email = 'e2e-rpg-overflow-queue@test.local';
  const userId = await getUserId(supabase, email);
  if (!userId) return;

  // Delete workouts first so record_session_xp_batch sees zero historical sets
  // on every run (fixes seed-depletion bug: novelty discount from prior-run sets
  // reduced XP below the rank-4 threshold on the 2nd+ run, preventing overflow).
  // The cascade chain (workouts → workout_exercises → sets) removes children
  // automatically. personal_records.set_id is nulled by ON DELETE SET NULL.
  await supabase.from('workouts').delete().eq('user_id', userId);

  await supabase.from('xp_events').delete().eq('user_id', userId);
  await supabase.from('body_part_progress').delete().eq('user_id', userId);
  await supabase.from('exercise_peak_loads').delete().eq('user_id', userId);
  await supabase.from('personal_records').delete().eq('user_id', userId);
  await supabase.from('backfill_progress').delete().eq('user_id', userId);
  await supabase.from('earned_titles').delete().eq('user_id', userId);

  await supabase.from('backfill_progress').upsert(
    {
      user_id: userId,
      sets_processed: 0,
      started_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      completed_at: new Date().toISOString(),
    },
    { onConflict: 'user_id' },
  );

  await supabase.from('profiles').upsert(
    { id: userId, display_name: 'Overflow Queue User', fitness_level: 'intermediate' },
    { onConflict: 'id' },
  );

  // All 6 body parts seeded at rank 3, 196 XP (2.6 XP below R4 threshold ≈ 198.6).
  // Raised from 190 XP to 196 XP to reduce the novelty-discount risk: a single
  // working set must earn only ~2.6 XP per body part to cross rank 4, ensuring
  // the threshold is reached reliably even with novelty discounting.
  //
  // The S4 test uses bench_press (chest), barbell_squat (legs),
  // barbell_bent_over_row (back), and overhead_press (shoulders) — 4 primary
  // exercises. Secondary XP attribution also pushes arms and core over the
  // rank-4 threshold, so all 6 body parts rank up in the single workout.
  //
  // Rank 4 threshold = 60 × (1.10³ − 1) / 0.10 ≈ 198.6 XP. No titles at rank 4
  // (first title at rank 5), so titles do NOT eat into the cap-at-3 budget.
  //
  // CelebrationQueue with 6 rank-ups + 1 level-up + 0 titles:
  //   closersCount = 1 (level-up), rankUpCapacity = 3 − 1 = 2
  //   queue = [top-2 rank-ups, level-up], overflow = 4 remaining rank-ups.
  // The test checks: 2 rank-up overlays, 1 level-up overlay, overflow card (4).
  const bodyParts = ['chest', 'back', 'legs', 'shoulders', 'arms', 'core'];
  for (const bp of bodyParts) {
    const { error } = await supabase.from('body_part_progress').upsert(
      { user_id: userId, body_part: bp, total_xp: 196, rank: 3 },
      { onConflict: 'user_id,body_part' },
    );
    if (error) {
      console.log(`[global-setup] Warning: body_part_progress seed error (${bp}) for rpgOverflowQueue: ${error.message}`);
    }
  }

  // Seed peak loads and prior personal records for the 4 exercises used in S4.
  // Peak loads keep strength_mult = 1.0; personal records prevent pr-celebration
  // navigation after workout finish (the app only navigates to /pr-celebration
  // when prResult.hasNewRecords is true — no record exists means any set is a PR).
  const exerciseSlugs: Record<string, { slug: string; peak: number }> = {
    chest:     { slug: 'barbell_bench_press',   peak: 80 },
    legs:      { slug: 'barbell_squat',          peak: 80 },
    back:      { slug: 'barbell_bent_over_row',  peak: 70 },
    shoulders: { slug: 'overhead_press',         peak: 50 },
  };
  for (const { slug, peak } of Object.values(exerciseSlugs)) {
    const { data: exRows } = await supabase
      .from('exercises').select('id').eq('slug', slug).eq('is_default', true).limit(1);
    const exId = exRows?.[0]?.id;
    if (exId) {
      await supabase.from('exercise_peak_loads').upsert(
        { user_id: userId, exercise_id: exId, peak_weight: peak, peak_reps: 5, peak_date: new Date().toISOString() },
        { onConflict: 'user_id,exercise_id' },
      );
      // Seed prior personal records for all three record types so workout
      // finish does not trigger pr-celebration navigation (any set at the
      // seeded weight/reps would otherwise register as a new max_reps or
      // max_volume record even when max_weight is already known).
      const achievedAt = new Date(Date.now() - 86_400_000).toISOString();
      await supabase.from('personal_records').insert([
        { user_id: userId, exercise_id: exId, record_type: 'max_weight', value: peak, reps: 5, achieved_at: achievedAt },
        { user_id: userId, exercise_id: exId, record_type: 'max_reps', value: 5, achieved_at: achievedAt },
        { user_id: userId, exercise_id: exId, record_type: 'max_volume', value: peak * 5, achieved_at: achievedAt },
      ]);
    }
  }

  await seedMinimalWorkout(supabase, userId);

  console.log('[global-setup] Seeded rpgOverflowQueueUser (all 6 body parts at rank 3, 196 XP — rank 4 boundary, no titles)');
}

/**
 * Seed rpgOverflowTapCard user — identical seeding contract to rpgOverflowQueue
 * but on a dedicated user. This prevents cross-worker XP state races when
 * --repeat-each=2 runs the auto-dismiss test (S4) and the tap-card test (S4b)
 * on parallel workers: each test now operates on its own user.
 */
async function seedRpgOverflowTapCardUser(supabase: SupabaseClient): Promise<void> {
  const email = 'e2e-rpg-overflow-tap@test.local';
  const userId = await getUserId(supabase, email);
  if (!userId) return;

  await supabase.from('workouts').delete().eq('user_id', userId);
  await supabase.from('xp_events').delete().eq('user_id', userId);
  await supabase.from('body_part_progress').delete().eq('user_id', userId);
  await supabase.from('exercise_peak_loads').delete().eq('user_id', userId);
  await supabase.from('personal_records').delete().eq('user_id', userId);
  await supabase.from('backfill_progress').delete().eq('user_id', userId);
  await supabase.from('earned_titles').delete().eq('user_id', userId);

  await supabase.from('backfill_progress').upsert(
    {
      user_id: userId,
      sets_processed: 0,
      started_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      completed_at: new Date().toISOString(),
    },
    { onConflict: 'user_id' },
  );

  await supabase.from('profiles').upsert(
    { id: userId, display_name: 'Overflow Tap User', fitness_level: 'intermediate' },
    { onConflict: 'id' },
  );

  // All 6 body parts at rank 3, 196 XP (2.6 XP below R4 threshold ~198.6).
  const bodyParts = ['chest', 'back', 'legs', 'shoulders', 'arms', 'core'];
  for (const bp of bodyParts) {
    const { error } = await supabase.from('body_part_progress').upsert(
      { user_id: userId, body_part: bp, total_xp: 196, rank: 3 },
      { onConflict: 'user_id,body_part' },
    );
    if (error) {
      console.log(`[global-setup] Warning: body_part_progress seed error (${bp}) for rpgOverflowTapCard: ${error.message}`);
    }
  }

  const exerciseSlugs: Record<string, { slug: string; peak: number }> = {
    chest:     { slug: 'barbell_bench_press',   peak: 80 },
    legs:      { slug: 'barbell_squat',          peak: 80 },
    back:      { slug: 'barbell_bent_over_row',  peak: 70 },
    shoulders: { slug: 'overhead_press',         peak: 50 },
  };
  for (const { slug, peak } of Object.values(exerciseSlugs)) {
    const { data: exRows } = await supabase
      .from('exercises').select('id').eq('slug', slug).eq('is_default', true).limit(1);
    const exId = exRows?.[0]?.id;
    if (exId) {
      await supabase.from('exercise_peak_loads').upsert(
        { user_id: userId, exercise_id: exId, peak_weight: peak, peak_reps: 5, peak_date: new Date().toISOString() },
        { onConflict: 'user_id,exercise_id' },
      );
      const achievedAt = new Date(Date.now() - 86_400_000).toISOString();
      await supabase.from('personal_records').insert([
        { user_id: userId, exercise_id: exId, record_type: 'max_weight', value: peak, reps: 5, achieved_at: achievedAt },
        { user_id: userId, exercise_id: exId, record_type: 'max_reps', value: 5, achieved_at: achievedAt },
        { user_id: userId, exercise_id: exId, record_type: 'max_volume', value: peak * 5, achieved_at: achievedAt },
      ]);
    }
  }

  await seedMinimalWorkout(supabase, userId);

  console.log('[global-setup] Seeded rpgOverflowTapCardUser (all 6 body parts at rank 3, 196 XP — rank 4 boundary, no titles)');
}

async function globalSetup(): Promise<void> {
  const supabaseUrl = process.env['SUPABASE_URL'];
  const supabaseAnonKey = process.env['SUPABASE_ANON_KEY'];
  const serviceRoleKey = process.env['SUPABASE_SERVICE_ROLE_KEY'];
  const password = process.env['TEST_USER_PASSWORD'];

  // ── Inject local Supabase credentials into the Flutter web build ──────
  // flutter_dotenv loads build/web/assets/.env at runtime. The production
  // build bundles the hosted Supabase URL, but E2E tests run against the
  // local Supabase instance. We overwrite the .env in the build directory
  // so the app connects to the same Supabase the tests use.
  if (supabaseUrl && supabaseAnonKey) {
    const envContent = `SUPABASE_URL=${supabaseUrl}\nSUPABASE_ANON_KEY=${supabaseAnonKey}\n`;
    const buildWebDir = path.join(__dirname, '..', '..', 'build', 'web');
    const envPaths = [
      path.join(buildWebDir, 'assets', '.env'),
      path.join(buildWebDir, '.env'),
    ];
    for (const envPath of envPaths) {
      if (fs.existsSync(path.dirname(envPath))) {
        fs.writeFileSync(envPath, envContent);
        console.log(`[global-setup] Injected local .env into ${envPath}`);
      }
    }
  }

  if (!supabaseUrl || !serviceRoleKey || !password) {
    throw new Error(
      'Missing required environment variables: SUPABASE_URL, ' +
        'SUPABASE_SERVICE_ROLE_KEY, TEST_USER_PASSWORD. ' +
        'Ensure test/e2e/.env.local is present.',
    );
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  console.log('[global-setup] Creating E2E test users...');

  for (const email of TEST_USERS) {
    const { data, error } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (error) {
      // 422 "User already registered" — idempotent, skip.
      // Different Supabase versions return slightly different status codes and
      // messages for duplicate users, so we match on message content.
      if (
        error.message.toLowerCase().includes('already') ||
        error.message.toLowerCase().includes('registered') ||
        error.message.toLowerCase().includes('exists')
      ) {
        console.log(`[global-setup] User already exists, skipping: ${email}`);
        continue;
      }

      // Any other error is unexpected — fail setup.
      throw new Error(
        `[global-setup] Failed to create user ${email}: ${error.message}`,
      );
    }

    console.log(
      `[global-setup] Created user: ${email} (id: ${data.user?.id})`,
    );
  }

  // ── Clean workout data for users that depend on fresh state ───────────
  // Some test suites (personal-records, manage-data, crash-recovery, etc.)
  // depend on the user starting with no prior workouts. If the user already
  // exists from a prior run, accumulated workout data causes test failures.
  // Delete workouts, workout_exercises, sets, and personal_records for these
  // users so each test run starts clean.
  const freshStateUsers = [
    'e2e-full-pr@test.local',
    'e2e-full-manage-data@test.local',
    'e2e-full-crash@test.local',
    'e2e-full-home@test.local',
    'e2e-full-workout@test.local',
    'e2e-full-ex-detail-sheet@test.local',
    'e2e-smoke-workout@test.local',
    'e2e-smoke-pr@test.local',
    // P8 beginner CTA requires zero workouts for the CTA to render
    'e2e-smoke-first-workout@test.local',
    // Offline sync — clean Hive queue state on each run
    'e2e-smoke-offline-sync@test.local',
    // Localization — must start with a clean slate each run because tests
    // may mutate the locale; the profile row is re-upserted with locale:'pt'
    // below so the app boots in Portuguese.
    'e2e-smoke-localization@test.local',
    // Localization en-default — tests mutate the locale (en→pt and back),
    // so we clean and re-seed each run to guarantee an en-default start.
    'e2e-smoke-localization-en@test.local',
    // Phase 17b gamification intro — must start fresh so the SagaIntroGate
    // logic sees a clean Hive state (no retro flag, no intro-seen flag) and
    // the overlay appears on first login. Also cleans xp_events / user_xp
    // so retro_backfill_xp has a deterministic outcome.
    'e2e-saga-intro@test.local',
    // Phase 18c celebration overlay users — XP state is re-seeded by
    // dedicated seed functions below, but we clean workouts/PRs here first.
    'e2e-rpg-rank-up-threshold@test.local',
    'e2e-rpg-multi-celebration@test.local',
    'e2e-rpg-overflow-queue@test.local',
    'e2e-rpg-overflow-tap@test.local',
    // Phase 18e class-cross + title-equip users — XP/title state is re-seeded
    // by dedicated seed functions below.
    'e2e-rpg-class-cross@test.local',
    'e2e-rpg-title-equip@test.local',
  ];

  for (const email of freshStateUsers) {
    const userId = await getUserId(supabase, email);
    if (!userId) continue;

    // Delete in dependency order: sets → workout_exercises → personal_records → workouts
    const { data: workouts } = await supabase
      .from('workouts')
      .select('id')
      .eq('user_id', userId);

    if (workouts && workouts.length > 0) {
      const workoutIds = workouts.map((w: { id: string }) => w.id);

      // Delete sets via workout_exercises
      const { data: wxs } = await supabase
        .from('workout_exercises')
        .select('id')
        .in('workout_id', workoutIds);

      if (wxs && wxs.length > 0) {
        const wxIds = wxs.map((wx: { id: string }) => wx.id);
        await supabase.from('sets').delete().in('workout_exercise_id', wxIds);
      }

      await supabase.from('workout_exercises').delete().in('workout_id', workoutIds);
      await supabase.from('workouts').delete().in('id', workoutIds);
    }

    // Delete personal records
    await supabase.from('personal_records').delete().eq('user_id', userId);

    // Delete weekly plans (P8 CTA requires plan == null || plan.routines.isEmpty)
    await supabase.from('weekly_plans').delete().eq('user_id', userId);

    // Delete XP data (Phase 17b) so retro_backfill_xp starts from a clean
    // slate on each run. Only relevant for users whose tests rely on XP state.
    await supabase.from('xp_events').delete().eq('user_id', userId);
    await supabase.from('user_xp').delete().eq('user_id', userId);

    console.log(`[global-setup] Cleaned workout data for ${email}`);
  }

  // ── Ensure profile rows exist for tests that need them ────────────────
  // Some tests (e.g., profile-weekly-goal) require an existing profile row
  // in the `profiles` table. Users created via auth.admin.createUser do NOT
  // automatically get a profile row — that happens during onboarding.
  // We upsert minimal profile rows for users that need them.
  const profileUsers = [
    'e2e-smoke-profile-goal@test.local',
    'e2e-smoke-exercise@test.local',
    // P8 first-workout user needs a profile row (otherwise router redirects
    // to /onboarding, not /home where the beginner CTA is shown).
    'e2e-smoke-first-workout@test.local',
    // Phase 17b: sagaIntroUser needs a profile row so the router lands on
    // /home (not /onboarding), where the SagaIntroGate wraps the shell.
    // Zero workout history is intentional — retro yields 0 XP, user gets LVL 1.
    'e2e-saga-intro@test.local',
  ];

  // Delete profile rows for users that need to test onboarding (fresh state).
  const onboardingUsers = ['e2e-smoke-onboarding@test.local'];
  for (const email of onboardingUsers) {
    const obUserId = await getUserId(supabase, email);
    if (obUserId) {
      await supabase.from('profiles').delete().eq('id', obUserId);
      console.log(`[global-setup] Deleted profile row for ${email} (onboarding)`);
    }
  }

  for (const email of profileUsers) {
    const userId = await getUserId(supabase, email);
    if (!userId) continue;

    const { error: profileError } = await supabase
      .from('profiles')
      .upsert(
        {
          id: userId,
          display_name: 'Gym User',
          fitness_level: 'intermediate',
        },
        { onConflict: 'id' },
      );

    if (profileError) {
      console.log(
        `[global-setup] Warning: could not upsert profile for ${email}: ${profileError.message}`,
      );
    } else {
      console.log(`[global-setup] Ensured profile row for ${email}`);
    }
  }

  // ── Seed test data for specific users ─────────────────────────────────

  // Seed PR data for smokePR user
  const prUserId = await getUserId(supabase, 'e2e-smoke-pr@test.local');
  if (prUserId) {
    // Ensure profile exists (required for FK constraints in some tables)
    await supabase
      .from('profiles')
      .upsert(
        {
          id: prUserId,
          display_name: 'PR Test User',
          fitness_level: 'intermediate',
        },
        { onConflict: 'id' },
      );
    await seedPRData(supabase, prUserId);
  }

  // Seed completed weekly plan for smokeWeeklyPlanReview user
  const weeklyPlanUserId = await getUserId(
    supabase,
    'e2e-smoke-weekly-plan-review@test.local',
  );
  if (weeklyPlanUserId) {
    await seedWeeklyPlanReviewData(supabase, weeklyPlanUserId);
  }

  // Seed exercise history for smokeExerciseProgress user (P1 progress chart)
  const exerciseProgressUserId = await getUserId(
    supabase,
    'e2e-smoke-exercise-progress@test.local',
  );
  if (exerciseProgressUserId) {
    await supabase
      .from('profiles')
      .upsert(
        {
          id: exerciseProgressUserId,
          display_name: 'Progress Chart User',
          fitness_level: 'intermediate',
        },
        { onConflict: 'id' },
      );
    await seedExerciseProgressData(supabase, exerciseProgressUserId);
  }

  // Clear weekly plans for users whose tests add/clear plans during the test
  // run, so each run starts with a clean slate and the plan picker shows all
  // available routines (not filtered by "already in plan").
  const usersNeedingWeeklyPlanClean = [
    'e2e-smoke-weekly-plan@test.local',
  ];
  for (const email of usersNeedingWeeklyPlanClean) {
    const uid = await getUserId(supabase, email);
    if (!uid) continue;
    await supabase.from('weekly_plans').delete().eq('user_id', uid);
    console.log(`[global-setup] Cleared weekly plan for ${email}`);
  }

  // Seed a minimal workout for users whose tests rely on the "Plan your week"
  // empty state or need "Quick workout" (lapsed state). W8 replaced the
  // "Start Empty Workout" button with state-dependent entry points: brand-new
  // users (workoutCount == 0) see "YOUR FIRST WORKOUT" CTA (starts a routine,
  // not an empty workout), while lapsed users see "Quick workout" (empty workout).
  //
  // Tests that call startEmptyWorkout() and then manipulate individual sets /
  // exercises expect an empty workout (no pre-filled exercises). These users must
  // start in lapsed state. The clean step above resets them to zero workouts, so
  // we re-seed one minimal completed workout to push them into lapsed state.
  const usersNeedingSeededWorkoutForP8 = [
    'e2e-smoke-weekly-plan@test.local',
    // All freshStateUsers that call startEmptyWorkout() in their tests must
    // start in lapsed state (Quick workout → empty workout) rather than
    // brand-new state (YOUR FIRST WORKOUT CTA → Full Body routine with
    // pre-filled exercises). The clean step resets them to zero workouts, so
    // we re-seed one minimal completed workout here.
    'e2e-smoke-workout@test.local',
    'e2e-full-workout@test.local',
    'e2e-full-home@test.local',
    'e2e-full-manage-data@test.local',
    'e2e-full-pr@test.local',
    'e2e-full-crash@test.local',
    'e2e-full-ex-detail-sheet@test.local',
    // Offline sync — needs lapsed state so startEmptyWorkout() finds Quick workout
    'e2e-smoke-offline-sync@test.local',
  ];
  for (const email of usersNeedingSeededWorkoutForP8) {
    const uid = await getUserId(supabase, email);
    if (!uid) continue;
    // Ensure a profile row exists so the router doesn't bounce to onboarding.
    await supabase
      .from('profiles')
      .upsert(
        {
          id: uid,
          display_name: 'Weekly Plan Tester',
          fitness_level: 'intermediate',
        },
        { onConflict: 'id' },
      );
    await seedMinimalWorkout(supabase, uid);
  }

  // ── Seed Portuguese locale for smokeLocalization user ─────────────────
  // The Flutter app reads `profiles.locale` on login and seeds the local Hive
  // box, which MaterialApp.locale reads at render time. By upserting
  // locale: 'pt' here we guarantee the app boots in Portuguese without any
  // test-side setup dance. Also seed one minimal workout so the app lands in
  // lapsed state (not the brand-new CTA state).
  const localizationUserId = await getUserId(
    supabase,
    'e2e-smoke-localization@test.local',
  );
  if (localizationUserId) {
    const { error: localeProfileError } = await supabase
      .from('profiles')
      .upsert(
        {
          id: localizationUserId,
          display_name: 'Localization User',
          fitness_level: 'intermediate',
          locale: 'pt',
        },
        { onConflict: 'id' },
      );
    if (localeProfileError) {
      console.log(
        `[global-setup] Warning: could not upsert pt-locale profile: ${localeProfileError.message}`,
      );
    } else {
      console.log(
        '[global-setup] Seeded pt locale profile for smokeLocalization user',
      );
    }
    await seedMinimalWorkout(supabase, localizationUserId);
  }

  // ── Seed en-default profile for smokeLocalizationEn user ──────────────
  // locale is explicitly set to 'en' (the column is NOT NULL DEFAULT 'en').
  // Omitting the field would leave stale values if a prior run wrote 'pt' — an
  // upsert only overwrites columns that are present in the payload.
  // One minimal workout is seeded so the app lands in lapsed state.
  const localizationEnUserId = await getUserId(
    supabase,
    'e2e-smoke-localization-en@test.local',
  );
  if (localizationEnUserId) {
    const { error: localeEnProfileError } = await supabase
      .from('profiles')
      .upsert(
        {
          id: localizationEnUserId,
          display_name: 'Localization En User',
          fitness_level: 'intermediate',
          locale: 'en',
        },
        { onConflict: 'id' },
      );
    if (localeEnProfileError) {
      console.log(
        `[global-setup] Warning: could not upsert en-default profile: ${localeEnProfileError.message}`,
      );
    } else {
      console.log(
        '[global-setup] Seeded en-default profile for smokeLocalizationEn user',
      );
    }
    await seedMinimalWorkout(supabase, localizationEnUserId);
  }

  // ── Phase 15f: seed 4 pt-BR locale users ─────────────────────────────
  // smokeLocalizationWorkout — pt locale, one prior workout (lapsed state)
  // for active-workout pt name smoke tests (scenario C1).
  const smokeLocWorkoutUserId = await getUserId(
    supabase,
    'e2e-smoke-loc-workout@test.local',
  );
  if (smokeLocWorkoutUserId) {
    // Clean workout data on each run so the state is deterministic.
    const { data: existingWorkouts } = await supabase
      .from('workouts')
      .select('id')
      .eq('user_id', smokeLocWorkoutUserId);
    if (existingWorkouts && existingWorkouts.length > 0) {
      const ids = existingWorkouts.map((w: { id: string }) => w.id);
      const { data: wxs } = await supabase
        .from('workout_exercises')
        .select('id')
        .in('workout_id', ids);
      if (wxs && wxs.length > 0) {
        await supabase
          .from('sets')
          .delete()
          .in('workout_exercise_id', wxs.map((wx: { id: string }) => wx.id));
      }
      await supabase.from('workout_exercises').delete().in('workout_id', ids);
      await supabase.from('workouts').delete().in('id', ids);
    }
    await supabase.from('personal_records').delete().eq('user_id', smokeLocWorkoutUserId);

    const { error: ptWorkoutProfileError } = await supabase
      .from('profiles')
      .upsert(
        {
          id: smokeLocWorkoutUserId,
          display_name: 'PT Workout User',
          fitness_level: 'intermediate',
          locale: 'pt',
        },
        { onConflict: 'id' },
      );
    if (ptWorkoutProfileError) {
      console.log(
        `[global-setup] Warning: could not upsert pt profile for smokeLocalizationWorkout: ${ptWorkoutProfileError.message}`,
      );
    } else {
      console.log('[global-setup] Seeded pt profile for smokeLocalizationWorkout');
    }
    await seedMinimalWorkout(supabase, smokeLocWorkoutUserId);
  }

  // fullHistoryPt — pt locale, 5 prior workouts so history renders entries.
  const fullHistoryPtUserId = await getUserId(
    supabase,
    'e2e-full-history-pt@test.local',
  );
  if (fullHistoryPtUserId) {
    const { error: ptHistoryProfileError } = await supabase
      .from('profiles')
      .upsert(
        {
          id: fullHistoryPtUserId,
          display_name: 'PT History User',
          fitness_level: 'intermediate',
          locale: 'pt',
        },
        { onConflict: 'id' },
      );
    if (ptHistoryProfileError) {
      console.log(
        `[global-setup] Warning: could not upsert pt profile for fullHistoryPt: ${ptHistoryProfileError.message}`,
      );
    } else {
      console.log('[global-setup] Seeded pt profile for fullHistoryPt');
    }
    // Seed 5 workouts so the history screen renders multiple entries.
    // Workout #1 (the most recent) gets a workout_exercise + set pointing at
    // barbell_bench_press so its exerciseSummary renders the pt-localized
    // name ("Supino Reto com Barra"). D1 asserts that name on the card.
    const existingHistoryWorkout = await supabase
      .from('workouts')
      .select('id')
      .eq('user_id', fullHistoryPtUserId)
      .eq('name', 'E2E PT History Workout 1')
      .maybeSingle();
    if (!existingHistoryWorkout.data) {
      // Look up barbell_bench_press by slug (slug is stable; name column was
      // dropped from exercises in Phase 15f migration 00034).
      const { data: ptBenchExercises } = await supabase
        .from('exercises')
        .select('id')
        .eq('slug', 'barbell_bench_press')
        .eq('is_default', true)
        .limit(1);
      const ptBenchExercise = ptBenchExercises?.[0] ?? null;

      const now = new Date();
      for (let i = 0; i < 5; i++) {
        const startedAt = new Date(now.getTime() - (i + 1) * 24 * 60 * 60 * 1000);
        const finishedAt = new Date(startedAt.getTime() + 60 * 60 * 1000);
        const { data: workout, error: wError } = await supabase
          .from('workouts')
          .insert({
            user_id: fullHistoryPtUserId,
            name: `E2E PT History Workout ${i + 1}`,
            started_at: startedAt.toISOString(),
            finished_at: finishedAt.toISOString(),
            duration_seconds: 3600,
          })
          .select('id')
          .single();

        // Attach a barbell_bench_press exercise + completed set on the most
        // recent workout (i === 0). The history screen renders this as the
        // pt exercise name in the workout summary line.
        if (i === 0 && workout && !wError && ptBenchExercise) {
          const { data: wx } = await supabase
            .from('workout_exercises')
            .insert({
              workout_id: workout.id,
              exercise_id: ptBenchExercise.id,
              order: 0,
            })
            .select('id')
            .single();

          if (wx) {
            await supabase.from('sets').insert({
              workout_exercise_id: wx.id,
              set_number: 1,
              reps: 5,
              weight: 80,
              set_type: 'working',
              is_completed: true,
            });
          }
        }
      }
      console.log(
        '[global-setup] Seeded 5 workouts for fullHistoryPt (most recent has barbell_bench_press)',
      );
    }
  }

  // smokeLocalizationRoutines — pt locale, one prior workout (lapsed state)
  // for routine create/edit pt exercise picker smoke tests (scenario E1).
  const smokeLocRoutinesUserId = await getUserId(
    supabase,
    'e2e-smoke-loc-routines@test.local',
  );
  if (smokeLocRoutinesUserId) {
    // Clean workout data on each run.
    const { data: existingRRoutineWorkouts } = await supabase
      .from('workouts')
      .select('id')
      .eq('user_id', smokeLocRoutinesUserId);
    if (existingRRoutineWorkouts && existingRRoutineWorkouts.length > 0) {
      const ids = existingRRoutineWorkouts.map((w: { id: string }) => w.id);
      const { data: wxs } = await supabase
        .from('workout_exercises')
        .select('id')
        .in('workout_id', ids);
      if (wxs && wxs.length > 0) {
        await supabase
          .from('sets')
          .delete()
          .in('workout_exercise_id', wxs.map((wx: { id: string }) => wx.id));
      }
      await supabase.from('workout_exercises').delete().in('workout_id', ids);
      await supabase.from('workouts').delete().in('id', ids);
    }

    const { error: ptRoutinesProfileError } = await supabase
      .from('profiles')
      .upsert(
        {
          id: smokeLocRoutinesUserId,
          display_name: 'PT Routines User',
          fitness_level: 'intermediate',
          locale: 'pt',
        },
        { onConflict: 'id' },
      );
    if (ptRoutinesProfileError) {
      console.log(
        `[global-setup] Warning: could not upsert pt profile for smokeLocalizationRoutines: ${ptRoutinesProfileError.message}`,
      );
    } else {
      console.log('[global-setup] Seeded pt profile for smokeLocalizationRoutines');
    }
    await seedMinimalWorkout(supabase, smokeLocRoutinesUserId);
  }

  // fullPRPt — pt locale, prior PRs seeded via seedPRData.
  const fullPRPtUserId = await getUserId(
    supabase,
    'e2e-full-pr-pt@test.local',
  );
  if (fullPRPtUserId) {
    // Clean workout/PR data on each run.
    const { data: existingPRWorkouts } = await supabase
      .from('workouts')
      .select('id')
      .eq('user_id', fullPRPtUserId);
    if (existingPRWorkouts && existingPRWorkouts.length > 0) {
      const ids = existingPRWorkouts.map((w: { id: string }) => w.id);
      const { data: wxs } = await supabase
        .from('workout_exercises')
        .select('id')
        .in('workout_id', ids);
      if (wxs && wxs.length > 0) {
        await supabase
          .from('sets')
          .delete()
          .in('workout_exercise_id', wxs.map((wx: { id: string }) => wx.id));
      }
      await supabase.from('workout_exercises').delete().in('workout_id', ids);
      await supabase.from('workouts').delete().in('id', ids);
    }
    await supabase.from('personal_records').delete().eq('user_id', fullPRPtUserId);

    const { error: ptPRProfileError } = await supabase
      .from('profiles')
      .upsert(
        {
          id: fullPRPtUserId,
          display_name: 'PT PR User',
          fitness_level: 'intermediate',
          locale: 'pt',
        },
        { onConflict: 'id' },
      );
    if (ptPRProfileError) {
      console.log(
        `[global-setup] Warning: could not upsert pt profile for fullPRPt: ${ptPRProfileError.message}`,
      );
    } else {
      console.log('[global-setup] Seeded pt profile for fullPRPt');
    }
    await seedPRData(supabase, fullPRPtUserId);
  }

  // ── Phase 18a: seed RPG foundation + fresh users ─────────────────────
  await seedRpgFoundationUser(supabase);
  await seedRpgFreshUser(supabase);

  // ── Phase 18c: seed celebration overlay test users ────────────────────
  await seedRpgRankUpThresholdUser(supabase);
  await seedRpgMultiCelebrationUser(supabase);
  await seedRpgOverflowQueueUser(supabase);
  await seedRpgOverflowTapCardUser(supabase);

  // ── Phase 18e: seed class-cross + title-equip test users ─────────────
  await seedRpgClassCrossUser(supabase);
  await seedRpgTitleEquipUser(supabase);

  console.log('[global-setup] Done.');
}

/**
 * Seed rpgClassCrossUser: chest at rank 4 (270 XP), all others at rank 1.
 *
 * Seeding mirrors rpgMultiCelebration but on a dedicated user so the
 * class-cross test can run independently without interfering with the
 * multi-celebration XP state. After one bench-press set chest crosses
 * rank 4 → rank 5: class resolver fires dominant chest → Bulwark.
 *
 * The class badge before the workout reads "Initiate" (max rank 4 < 5).
 * After the workout finish + provider refresh it reads "Bulwark".
 */
async function seedRpgClassCrossUser(supabase: SupabaseClient): Promise<void> {
  const email = 'e2e-rpg-class-cross@test.local';
  const userId = await getUserId(supabase, email);
  if (!userId) return;

  // Full clean on every run so XP state is deterministic.
  await supabase.from('workouts').delete().eq('user_id', userId);
  await supabase.from('xp_events').delete().eq('user_id', userId);
  await supabase.from('body_part_progress').delete().eq('user_id', userId);
  await supabase.from('exercise_peak_loads').delete().eq('user_id', userId);
  await supabase.from('personal_records').delete().eq('user_id', userId);
  await supabase.from('backfill_progress').delete().eq('user_id', userId);
  await supabase.from('earned_titles').delete().eq('user_id', userId);

  await supabase.from('backfill_progress').upsert(
    {
      user_id: userId,
      sets_processed: 0,
      started_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      completed_at: new Date().toISOString(),
    },
    { onConflict: 'user_id' },
  );

  await supabase.from('profiles').upsert(
    { id: userId, display_name: 'Class Cross User', fitness_level: 'intermediate' },
    { onConflict: 'id' },
  );

  // Chest at 270 XP / rank 4 (Rank 5 threshold ≈ 278.46 XP).
  // One bench-press set at 80 kg × 5 reps earns ~8–15 chest XP → crosses rank 5.
  // All other body parts at rank 1 / 0 XP (resolver default).
  const bodyParts = ['chest', 'back', 'legs', 'shoulders', 'arms', 'core'];
  for (const bp of bodyParts) {
    const xp = bp === 'chest' ? 270 : 0;
    const rank = bp === 'chest' ? 4 : 1;
    await supabase.from('body_part_progress').upsert(
      { user_id: userId, body_part: bp, total_xp: xp, rank },
      { onConflict: 'user_id,body_part' },
    );
  }

  // Seed bench-press peak load = 80 kg so strength_mult = 1.0 on the test set.
  const { data: benchExercises } = await supabase
    .from('exercises').select('id').eq('slug', 'barbell_bench_press').eq('is_default', true).limit(1);
  const benchId = benchExercises?.[0]?.id;
  if (benchId) {
    await supabase.from('exercise_peak_loads').upsert(
      { user_id: userId, exercise_id: benchId, peak_weight: 80, peak_reps: 5, peak_date: new Date().toISOString() },
      { onConflict: 'user_id,exercise_id' },
    );
    // Pre-seed personal records so workout finish doesn't navigate to /pr-celebration.
    const achievedAt = new Date(Date.now() - 86_400_000).toISOString();
    await supabase.from('personal_records').insert([
      { user_id: userId, exercise_id: benchId, record_type: 'max_weight', value: 80, reps: 5, achieved_at: achievedAt },
      { user_id: userId, exercise_id: benchId, record_type: 'max_reps', value: 5, achieved_at: achievedAt },
      { user_id: userId, exercise_id: benchId, record_type: 'max_volume', value: 400, achieved_at: achievedAt },
    ]);
  }

  // One prior minimal workout so the app shows Quick workout (lapsed state).
  await seedMinimalWorkout(supabase, userId);

  console.log('[global-setup] Seeded rpgClassCrossUser (chest 270 XP / rank 4 → crosses rank 5 on bench set)');
}

/**
 * Seed rpgTitleEquipUser: chest at rank 5 (290 XP) with the R5 chest title
 * already earned in earned_titles. The user also has a prior minimal workout
 * so the app lands in lapsed state (Quick workout entry point visible).
 *
 * The first per-body-part title ("Plate-Bearer" at rank 5) is pre-seeded in
 * earned_titles directly (bypassing save_workout) so it appears in the Titles
 * screen without requiring a real workout to cross the threshold.
 *
 * Idempotent: skips if body_part_progress row for chest already exists.
 */
async function seedRpgTitleEquipUser(supabase: SupabaseClient): Promise<void> {
  const email = 'e2e-rpg-title-equip@test.local';
  const userId = await getUserId(supabase, email);
  if (!userId) return;

  // Full clean on every run.
  await supabase.from('workouts').delete().eq('user_id', userId);
  await supabase.from('xp_events').delete().eq('user_id', userId);
  await supabase.from('body_part_progress').delete().eq('user_id', userId);
  await supabase.from('exercise_peak_loads').delete().eq('user_id', userId);
  await supabase.from('personal_records').delete().eq('user_id', userId);
  await supabase.from('backfill_progress').delete().eq('user_id', userId);
  await supabase.from('earned_titles').delete().eq('user_id', userId);

  await supabase.from('backfill_progress').upsert(
    {
      user_id: userId,
      sets_processed: 0,
      started_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      completed_at: new Date().toISOString(),
    },
    { onConflict: 'user_id' },
  );

  await supabase.from('profiles').upsert(
    { id: userId, display_name: 'Title Equip User', fitness_level: 'intermediate' },
    { onConflict: 'id' },
  );

  // Chest at rank 5 (290 XP — above the 278.46 XP threshold).
  const bodyParts = ['chest', 'back', 'legs', 'shoulders', 'arms', 'core'];
  for (const bp of bodyParts) {
    const xp = bp === 'chest' ? 290 : 0;
    const rank = bp === 'chest' ? 5 : 1;
    await supabase.from('body_part_progress').upsert(
      { user_id: userId, body_part: bp, total_xp: xp, rank },
      { onConflict: 'user_id,body_part' },
    );
  }

  // Seed the chest R5 title directly in earned_titles.
  // Slug: 'chest_r5_initiate_of_the_forge' (rank 5 chest title per titles_v1.json).
  // is_active = false so the test can equip it and verify the badge updates.
  const earnedAt = new Date(Date.now() - 3_600_000).toISOString();
  const { error: titleError } = await supabase.from('earned_titles').insert({
    user_id: userId,
    title_id: 'chest_r5_initiate_of_the_forge',
    earned_at: earnedAt,
    is_active: false,
  });
  if (titleError) {
    console.log(`[global-setup] Warning: could not seed earned_title for rpgTitleEquipUser: ${titleError.message}`);
  }

  await seedMinimalWorkout(supabase, userId);

  console.log('[global-setup] Seeded rpgTitleEquipUser (chest rank 5, plate_bearer earned but not equipped)');
}

export default globalSetup;
