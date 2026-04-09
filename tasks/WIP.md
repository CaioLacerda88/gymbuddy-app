# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## In Progress: Fix E2E Smoke Tests

**Branch:** `fix/e2e-smoke-selectors`
**Context:** E2E smoke tests failing — mix of infrastructure issues and test code bugs.

### Infrastructure Fixes (DONE)
- [x] `test/e2e/playwright.config.ts` — `python3` → `python` (Windows compat); `??` → `||` (empty string baseURL fallback)
- [x] `test/e2e/global-setup.ts` — auto-inject local Supabase `.env` into `build/web/assets/.env` so app connects to same Supabase as tests
- [x] `test/e2e/helpers/app.ts` — `navigateToTab` uses URL-based wait (`page.waitForURL`) instead of broken `text=` selector
- [x] `test/e2e/helpers/selectors.ts` — `addConfirmButton` changed from `flt-semantics[aria-label*="ADD "]` to `role=button[name*="ADD "]`
- [x] `test/e2e/smoke/pr-display.smoke.spec.ts` — added `waitForAppReady` after 3 `page.goto('/records')` calls
- [x] `CLAUDE.md` — added E2E local execution instructions + agent progress reporting protocol

### Test Results After Infra Fixes
- **28 passed** (all pre-existing tests work)
- **12 skipped** (orphaned test users with FK constraints: exercise, form-tips, routine-error)
- **20 failed** (all in the 6 NEW test files from Step 12)

### All 6 Files Now Pass (was 20 failures)

Infrastructure fixes from earlier session resolved everything:
- `workers: 1` in playwright.config.ts eliminated "Flutter app failed to render" timing issues
- Semantics labels added to Dart widgets (`tooltip: 'Create routine'`, `Semantics(label: 'More options')`)
- Hash navigation (`window.location.hash`) instead of `page.goto()` for SPA routes
- `test.skip()` guards for data-dependency tests (no completed workouts/weeks seeded)

**Individual file results (verified 2026-04-08):**
- `profile-weekly-goal.smoke.spec.ts` — 4 passed
- `routine-management.smoke.spec.ts` — 3 passed
- `onboarding.smoke.spec.ts` — 4 passed
- `weekly-plan.smoke.spec.ts` — 5 passed
- `pr-display.smoke.spec.ts` — 2 passed, 1 skipped (needs workout data seeded)
- `weekly-plan-review.smoke.spec.ts` — 1 passed, 4 skipped (needs completed week seeded)

**Full suite verified:** 47 passed, 0 failed, 13 skipped (10min, workers: 1).

### Step 12.1: E2E Infrastructure Improvements (same branch)

**Per PLAN.md Step 12.1 — 4 sub-tasks:**

- [x] **12.1a** — `http-server` (concurrent) replaces `python -m http.server`. `workers: 2` in config + CI.
- [x] **12.1b** — `global-teardown.ts` cascades FK deletes. All 24 users delete cleanly.
- [x] **12.1c** — Seeded workout+PR for `smokePR`, completed weekly plan for `smokeWeeklyPlanReview`, profile for `smokeExercise`.
- [x] **12.1d** — `exercise-library.smoke.spec.ts` rewritten to standard infra (7 tests now run).

**Result:** 58 passed, 2 skipped (expected), 0 failures, 6.1 min, workers: 2. Teardown clean.

### How to Run E2E Locally
```bash
export PATH="/c/flutter/bin:$PATH"
# 1. Ensure Supabase containers running: docker ps | grep supa
# 2. Build from current branch: flutter build web
# 3. Run: cd test/e2e && FLUTTER_APP_URL= npx playwright test --project=smoke --reporter=line
# Global setup auto-injects local .env into build/web/assets/.env
```

---

## Completed This Session
- [x] Step 12 merged (PR #32) — weekly training plan, 5 regression bug fixes, 6 E2E smoke tests
- [x] Docs optimization merged (PR #33) — PLAN.md restructured (73% smaller)
- [x] Dev flow update merged (PR #34) — TDD requirement, QA gate, session-start guide
- [x] Agent team leaned: removed team-lead, flutter-dev, supabase-dev; trimmed QA Playwright tools 14→8
