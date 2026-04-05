/**
 * Test user fixtures for E2E tests.
 *
 * Each smoke spec uses its own dedicated user to avoid shared state between
 * test files. Users are created in global-setup.ts and deleted in
 * global-teardown.ts using the Supabase Admin Auth API.
 */

export const TEST_USERS = {
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
} as const;
