# Step 9a: Playwright Infrastructure + Smoke Tests — Design Spec

## Goal

Stand up production-quality Playwright E2E infrastructure against the local Supabase stack, then deliver 3 smoke spec files covering auth, core workout, and PR detection journeys. All tests must be runnable (no `test.skip`), parallel-safe with unique users, and complete in under 3 minutes.

## Architecture

### Test Environment

- **Local Supabase** (Docker via `supabase start`): API at `http://127.0.0.1:54321`, DB at port 54322
- **Flutter web** (HTML renderer): served at `http://localhost:8080` via `flutter build web --web-renderer html` + static server
- **Email confirmation disabled** in local config (`enable_confirmations = false`), so signups are instant
- **Service role key** (`sb_secret_...`): used in global-setup to create/delete test users via Supabase Admin Auth API

### Global Setup/Teardown

- `global-setup.ts`: Creates test users via `supabase.auth.admin.createUser()` with `email_confirm: true`
- `global-teardown.ts`: Deletes all `e2e-*` test users via `supabase.auth.admin.deleteUser()`
- Each smoke spec gets its own dedicated user (no shared mutable state)

### Test Users

| User | Purpose | Email |
|------|---------|-------|
| smokeAuth | Auth smoke tests (login/logout/signup toggle) | `e2e-smoke-auth@test.local` |
| smokeWorkout | Workout smoke tests (start/log/finish) | `e2e-smoke-workout@test.local` |
| smokePR | PR detection smoke tests | `e2e-smoke-pr@test.local` |
| smokeSignup | Fresh signup flow (created during test, not in setup) | `e2e-smoke-signup-{timestamp}@test.local` |

### Existing Code Reuse

- Keep existing `helpers/auth.ts`, `helpers/app.ts`, `helpers/selectors.ts` — update them
- Keep `playwright.config.ts` structure — add globalSetup/globalTeardown
- Existing smoke specs in `smoke/` are from earlier steps — update `auth.smoke.spec.ts`, keep exercise-library and step5e as-is (they'll be updated in 9b)

## Deliverables

### New Files
- `test/e2e/.env.local` — local Supabase credentials (gitignored)
- `test/e2e/global-setup.ts` — create test users
- `test/e2e/global-teardown.ts` — delete test users
- `test/e2e/fixtures/test-users.ts` — user credential constants
- `test/e2e/fixtures/test-exercises.ts` — known exercise names from seed
- `test/e2e/helpers/workout.ts` — startWorkout(), addExercise(), logSet(), finishWorkout()
- `test/e2e/smoke/workout.smoke.spec.ts` — core workout journey
- `test/e2e/smoke/pr.smoke.spec.ts` — PR detection journey

### Modified Files
- `test/e2e/package.json` — add `@supabase/supabase-js`, `dotenv` deps
- `test/e2e/playwright.config.ts` — add globalSetup/globalTeardown
- `test/e2e/helpers/selectors.ts` — add WORKOUT, HOME, PR selectors
- `test/e2e/helpers/auth.ts` — use fixtures instead of env vars, update logout
- `test/e2e/smoke/auth.smoke.spec.ts` — remove test.skip, use fixtures, add signup flow
- `test/e2e/README.md` — update with local Supabase instructions
- `test/e2e/.gitignore` — ensure .env* files are ignored

### Smoke Test Coverage

1. **auth.smoke.spec.ts**: login screen visible → login with valid creds → bottom nav visible → toggle signup mode → logout → back to login
2. **workout.smoke.spec.ts**: login → start empty workout → add exercise → log a set (weight + reps) → finish workout → verify in history
3. **pr.smoke.spec.ts**: login → workout A (bench press 60kg x 8) → finish → workout B (bench press 80kg x 5) → PR celebration screen → PR list shows new record

## Constraints

- All tests must run without `test.skip` — they're real, runnable tests
- Each test file uses its own dedicated user — no cross-test state sharing
- Tests must be idempotent (re-runnable without manual cleanup)
- Global teardown cleans up all e2e users even if tests fail
- No hardcoded Supabase keys in committed files — use .env.local (gitignored)
