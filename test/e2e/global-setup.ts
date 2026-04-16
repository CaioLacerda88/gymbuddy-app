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

  // Find "Barbell Bench Press" exercise (limit 1 in case seed.sql ran multiple times)
  const { data: exercises, error: exError } = await supabase
    .from('exercises')
    .select('id')
    .eq('name', 'Barbell Bench Press')
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

  // Find "Barbell Bench Press" exercise (limit 1 in case seed.sql ran multiple times)
  const { data: exercises, error: exError } = await supabase
    .from('exercises')
    .select('id')
    .eq('name', 'Barbell Bench Press')
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

  console.log('[global-setup] Done.');
}

export default globalSetup;
