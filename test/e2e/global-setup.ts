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

  console.log('[global-setup] Cleaned and seeded profile for rpgFreshUser');
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

  console.log('[global-setup] Done.');
}

export default globalSetup;
