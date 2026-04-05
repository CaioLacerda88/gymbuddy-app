/**
 * Test user fixtures for E2E tests.
 *
 * Each spec file uses its own dedicated user to avoid shared mutable state
 * between test files. Users are created in global-setup.ts and deleted in
 * global-teardown.ts using the Supabase Admin Auth API.
 *
 * Smoke users: isolated users for the smoke spec suite.
 * Full users: isolated users for the full spec suite (one per spec file).
 */

export const TEST_USERS = {
  // -------------------------------------------------------------------------
  // Smoke users (existing)
  // -------------------------------------------------------------------------
  smokeAuth: {
    email: 'e2e-smoke-auth@test.local',
    password: 'TestPassword123!',
  },
  smokeWorkout: {
    email: 'e2e-smoke-workout@test.local',
    password: 'TestPassword123!',
  },
  smokePR: {
    email: 'e2e-smoke-pr@test.local',
    password: 'TestPassword123!',
  },

  // -------------------------------------------------------------------------
  // Full suite users (one per spec file)
  // -------------------------------------------------------------------------
  fullAuth: {
    email: 'e2e-full-auth@test.local',
    password: 'TestPassword123!',
  },
  fullExercises: {
    email: 'e2e-full-exercises@test.local',
    password: 'TestPassword123!',
  },
  fullWorkout: {
    email: 'e2e-full-workout@test.local',
    password: 'TestPassword123!',
  },
  fullRoutines: {
    email: 'e2e-full-routines@test.local',
    password: 'TestPassword123!',
  },
  fullPR: {
    email: 'e2e-full-pr@test.local',
    password: 'TestPassword123!',
  },
  fullHome: {
    email: 'e2e-full-home@test.local',
    password: 'TestPassword123!',
  },
  fullCrash: {
    email: 'e2e-full-crash@test.local',
    password: 'TestPassword123!',
  },
} as const;
