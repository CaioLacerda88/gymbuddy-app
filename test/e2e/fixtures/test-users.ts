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
  smokeExercise: {
    email: 'e2e-smoke-exercise@test.local',
    password: 'TestPassword123!',
  },
  // Regression smoke users — added to cover BUG-001 through BUG-005.
  smokeRoutineStart: {
    email: 'e2e-smoke-routine-start@test.local',
    password: 'TestPassword123!',
  },
  smokeFormTips: {
    email: 'e2e-smoke-form-tips@test.local',
    password: 'TestPassword123!',
  },
  // BUG-001 manual workout restore path (separate from routine-start path).
  smokeWorkoutRestore: {
    email: 'e2e-smoke-workout-restore@test.local',
    password: 'TestPassword123!',
  },
  // BUG-003 negative path smoke (error snackbar when all exercises deleted).
  smokeRoutineError: {
    email: 'e2e-smoke-routine-error@test.local',
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
  fullHistory: {
    email: 'e2e-full-history@test.local',
    password: 'TestPassword123!',
  },
  fullManageData: {
    email: 'e2e-full-manage-data@test.local',
    password: 'TestPassword123!',
  },
  // Regression full suite user — added to cover BUG-003/BUG-004/BUG-005.
  fullRoutineRegression: {
    email: 'e2e-full-routine-regression@test.local',
    password: 'TestPassword123!',
  },
  // Exercise detail bottom sheet full spec (BUG-002 in-workout path).
  fullExDetailSheet: {
    email: 'e2e-full-ex-detail-sheet@test.local',
    password: 'TestPassword123!',
  },
} as const;
