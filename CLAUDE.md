# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

RepSaga — a gym training app for logging workouts, tracking personal records, and managing exercises.

**On session start:** Read `PLAN.md` Quick Reference (progress table + current state) and `tasks/WIP.md` (in-flight work). Only read full PLAN.md sections relevant to the current task.

## Commands

```bash
export PATH="/c/flutter/bin:$PATH"

flutter pub get              # install dependencies
make gen                     # code generation (Freezed/json_serializable)
make gen-watch               # code generation in watch mode
make format                  # dart format .
make analyze                 # dart analyze --fatal-infos
make test                    # flutter test
make build-android-debug     # android debug APK (Gradle/Kotlin compile check)
make ci                      # full pipeline: format + gen + analyze + test + android-debug-build (~3-5 min)

flutter run -d android       # run on Android
flutter run -d chrome        # run on Chrome (for Playwright e2e)
```

## Code Style

- `const` constructors wherever possible
- No hardcoded colors or text styles — use `AppTheme` from `core/theme/`
- Extract widgets when build method exceeds ~50 lines
- Import our exceptions with prefix when Supabase types clash: `import '...' as app;`
- Commit format: `feat|fix|refactor|test|docs|ci|chore(scope): description`
- Scopes: `auth`, `exercises`, `workouts`, `progress`, `profile`, `core`, `theme`, `ci`

### Exercise content pairing rule

Any migration that inserts `is_default = true` exercises MUST be paired with a migration that populates `description` and `form_tips` for every inserted row (either the same file or a sibling migration in the same PR). No default exercise ships with NULL content.

CI enforces this via `scripts/check_exercise_content_pairing.sh`. Violation fails the pipeline.

## Testing

- Structure: `test/unit/`, `test/widget/`, `test/e2e/`, `test/fixtures/`
- Mock Supabase with `mocktail` — never hit real backend in unit tests
- Test factories in `test/fixtures/test_factories.dart`
- `testWidgets` for widget tests, `test` for unit tests

### E2E Tests (Playwright) — Local Execution

**Prerequisites check (run all before writing tests):**
```bash
export PATH="/c/flutter/bin:$PATH"

# 1. Supabase containers must be running (auth, db, rest, storage)
docker ps --format '{{.Names}} {{.Status}}' | grep supa | grep -v healthy && echo "WARNING: unhealthy containers"

# 2. If containers are down:
npx supabase start

# 3. Flutter web build must be fresh (from your current branch!)
git branch --show-current          # verify you're on the right branch
flutter build web                  # rebuilds build/web/ from current code

# 4. E2E deps installed
cd test/e2e && npm install && cd ../..
```

**Running tests:**
```bash
cd test/e2e

# Run full regression suite (all 145 tests)
FLUTTER_APP_URL= npx playwright test --reporter=list

# Quick smoke check only (~68 tests tagged @smoke)
FLUTTER_APP_URL= npx playwright test --grep @smoke --reporter=list

# Run a single feature file:
FLUTTER_APP_URL= npx playwright test specs/auth.spec.ts

# Run a specific test by line number:
FLUTTER_APP_URL= npx playwright test "specs/auth.spec.ts:16"
```

**Key details:**
- `FLUTTER_APP_URL=` (empty) overrides `.env.local` → Playwright auto-serves `build/web/` via custom Node.js static server on port 4200
- **Env auto-swap**: Global setup injects local Supabase credentials into `build/web/assets/.env` so the Flutter app connects to the same Supabase instance the tests use. No manual `.env` swap needed.
- Global setup creates test users via Supabase Admin API → requires local Supabase running
- Global teardown deletes test users → idempotent, safe to rerun
- Screenshots on failure: `test/e2e/test-results/`
- Config: `test/e2e/playwright.config.ts`
- **CI vs local**: The root `.env` has hosted Supabase (production). `test/e2e/.env.local` has local Supabase. Global setup handles the swap automatically.

### E2E Conventions (must follow for all new/modified tests)

**File structure:** Feature-based files in `test/e2e/specs/`. One file per feature area (auth, exercises, workouts, routines, etc.). Never create `smoke/` or `full/` directories — use tags instead.

**Tagging:** Smoke tests (quick CI gate) use `test.describe('Name', { tag: '@smoke' }, () => { ... })`. Regression-only tests have no tag. Run smoke: `--grep @smoke`. Run all: no filter.

**Naming:**
- Describe blocks: feature name (`'Exercises'`, `'Workout logging'`). No "smoke"/"full" suffix.
- Tests: always start with `should`. Bug IDs parenthesized at end: `test('should show error snackbar (BUG-003)')`.

**User isolation:** Each describe block has a dedicated test user. Inline `TEST_USERS.xxx` directly in `beforeEach` — no `const USER` aliases (prevents collisions in merged files). New features needing isolated state require a new user in `fixtures/test-users.ts` + `global-setup.ts`.

**Selectors:** All in `helpers/selectors.ts`. Use Playwright `role=TYPE[name*="..."]` selectors (accessibility protocol), NOT CSS `flt-semantics[aria-label="..."]` (Flutter 3.41.6 uses AOM, not DOM attributes). For SnackBar text, always use `.first()` (Flutter renders two DOM elements per SnackBar). For search inputs, use `.last()` on `toBeVisible` assertions (Flutter renders two `<input>` elements).

**Text input:** Use `flutterFill()` from `helpers/app.ts`, NOT `page.fill()`. Flutter CanvasKit's hidden `<input>` proxy requires real keyboard events. `page.fill()` uses synthetic events that Flutter ignores.

**Adding a new test:**
1. Place in the appropriate `specs/<feature>.spec.ts` file
2. Add `{ tag: '@smoke' }` on the describe block if it's a CI gate test
3. Use an existing test user if the describe block already has one, or create a new user+describe block
4. Follow naming: `test('should ...')`
5. Add selectors to `helpers/selectors.ts` — never inline magic strings
6. Run locally: `FLUTTER_APP_URL= npx playwright test specs/<feature>.spec.ts`

## Development Team (Agent Workflow)

**All implementation is done by specialized agents, not the main conversation.** The main conversation coordinates and delegates.

### Team

| Agent           | Role                                                         | Writes Code | Model  |
| --------------- | ------------------------------------------------------------ | ----------- | ------ |
| `tech-lead`     | Architecture, implementation, bug fixes, migrations          | Yes         | Opus   |
| `qa-engineer`   | Test strategy, unit/widget/e2e tests, Playwright             | Yes         | Sonnet |
| `devops`        | CI/CD pipelines, GitHub Actions, releases                    | Yes         | Sonnet |
| `reviewer`      | Code review, quality checks                                  | Read-only   | Sonnet |
| `product-owner` | Market research, competitor analysis, feature priorities     | Read-only   | Sonnet |
| `ui-ux-critic`  | Design critique, anti-generic-AI aesthetics                  | Read-only   | Sonnet |

### How it works

**The main conversation orchestrates agents directly.** It dispatches specialists, runs CI, and manages PRs. No intermediate orchestrator layer.

### Development Flow

Each PLAN.md step follows this pipeline. **No step is skippable.**

1. **Plan** — Read PLAN.md step. Dispatch `product-owner` + `ui-ux-critic` (if user-facing).
2. **WIP** — Write checklist in `tasks/WIP.md` before any code.
3. **Implement (TDD)** — `tech-lead` writes code WITH unit/widget tests. Test-first when possible. Run `dart format .` + `dart analyze` after each change.
4. **Design review** (if UI) — `ui-ux-critic` reviews. Generic → revise.
5. **QA gate** (before PR) — `qa-engineer`:
   - Reviews test coverage, flags gaps, adds missing unit/widget cases
   - **E2E (always):** Verify no selectors/text strings broke; update `helpers/selectors.ts` if needed. New tests go in existing `specs/<feature>.spec.ts` files — follow E2E Conventions above.
   - **E2E (new/changed user flows):** Write/update E2E tests in the appropriate `specs/` file, run full E2E suite locally — all 145 must pass. **Navigation changes (go↔push, route restructuring) count as flow changes** even if no UI text changed.
   - **E2E (visual-only / no flow change):** Selector impact assessment is sufficient; skip suite run and new E2E tests. Only applies when zero navigation/routing/provider logic changed.
   - Removes or updates stale E2E tests affected by the change
   - Bugs found → back to `tech-lead` → fix → QA re-runs from top
6. **Verify before PR** — Orchestrator runs `superpowers:verification-before-completion` skill: fresh `make ci` (or format + analyze + test), reads full output, confirms 0 failures. No "should pass" — evidence only. Also re-read PLAN.md acceptance criteria and check each item against the diff.
7. **Open PR** — only after verification gate passes.
8. **Code review** — `reviewer` flags issues → `tech-lead` fixes → `qa-engineer` re-validates.
9. **Ship** — QA OK + CI green → squash merge.
10. **Apply migrations** — After merge, check if the step added/modified SQL migrations (`supabase/migrations/`). If so, apply them to the hosted Supabase instance with `npx supabase db push` (or link + push). Verify the schema matches what the code expects before moving on. During QA/testing, always confirm that any new migrations have been applied to the environment under test.
11. **Close WIP** — Remove WIP section, condense step in PLAN.md (see lifecycle below).

### Debugging Protocol

When ANY non-obvious failure occurs during the pipeline (CI red, E2E failure, unexpected behavior, review-found bugs):

1. **IMMEDIATELY deploy `tech-lead` with `superpowers:systematic-debugging`** — no ad-hoc guessing, no trial-and-error. Non-obvious bugs waste massive time when investigated without systematic analysis.
2. **Phase 1 (Root Cause):** Read the actual error output. Reproduce. Check what changed. Trace data flow backward from the symptom. **Dispatch the tech-lead agent to investigate architecture-level root causes** — don't just grep and patch.
3. **Phase 2 (Pattern):** Find working examples in the codebase. Compare broken vs working.
4. **Phase 3 (Hypothesis):** Form ONE specific theory ("X causes Y because Z"). Test minimally — one variable at a time.
5. **Phase 4 (Fix):** Fix root cause, not symptom. Verify with tests.
6. **If 3+ fix attempts fail:** Stop. Question the architecture. Discuss with user before continuing.

**This applies to the orchestrator, not just agents.** When investigating CI failures, E2E regressions, or review feedback — follow the phases, don't ad-hoc grep around hoping to stumble on the answer. The instinct to "just try something" wastes context window and time. Invest in understanding first.

### PLAN.md Lifecycle

PLAN.md is the single source of truth for all project specs. It's structured for **token-efficient reading** — agents read the Quick Reference first, then only their relevant section.

**During development** (step is active):
- The step has a **full detailed spec** in PLAN.md: acceptance criteria, file plans, schema, UX details
- Agents read the Quick Reference + their active step section — never the entire file
- WIP.md tracks real-time progress during implementation

**After merge** (step is done):
- **Condense** the step to 3-5 bullet points: what was built, key files, test count, notable decisions
- Move the full spec to git history — it's in the PR/commit, not needed for future agents
- Update the progress table status to DONE with PR number(s)
- Remove the WIP.md section for that step

This prevents PLAN.md from growing unbounded. Completed steps are summaries; only active/future steps have full specs.

### WIP Tracking (`tasks/WIP.md`)

**Every agent that changes code MUST follow this protocol:**

1. **Before writing code:** Read the relevant PLAN.md step section, then write a checklist in `tasks/WIP.md` with:
   - Task name and branch name
   - Reference to the source definition (e.g., "Per PLAN.md Step 12", "Per PLAN.md Phase 13")
   - Checkable items for each change to make
   - Files to modify/create
2. **During implementation:** Check off items as they're completed (`- [x]`)
3. **After merge:** Remove the completed section from `tasks/WIP.md` and condense the PLAN.md step

This keeps the coordinator (main conversation) informed of progress and ensures agents don't drift from specs. If `tasks/WIP.md` doesn't exist, create it.

### Handoff Protocol

**When delegating to an agent:**
- Provide the PLAN.md step number and specific sub-tasks
- List files the agent must read before starting
- State what to build, which existing patterns to follow
- Include `export PATH="/c/flutter/bin:$PATH"` for Flutter/Dart commands
- Include the progress reporting instruction (see below)
- **Run code-writing agents in FOREGROUND** so the user sees progress in real-time. Background mode hides the agent's progress lines — only use it for read-only research agents where step-by-step visibility is not needed.

**Agent progress reporting (include in every agent prompt):**
```
PROGRESS REPORTING: Before each major step, output a brief status line so the
orchestrator can track progress. Format: "## [Step N/Total] Description"
Example: "## [1/4] Reading test files..." → "## [2/4] Fixing selectors.ts..."
Output these as plain text between tool calls. Keep them to one line.
```

**When an agent completes work:**
- Agent summarizes: files created/modified, decisions made, known issues
- Coordinator runs `make ci` to verify before handing to next agent
- Next agent in pipeline reads the changed files before starting their work

**When reviewing a PR (reviewer / qa-engineer):**
- Read all changed files, not just the diff summary
- Check against PLAN.md requirements for that step
- Verify tests cover the acceptance criteria
- Flag real issues only — skip style nitpicks (that's what `make format` and `make analyze` are for)

### Context Hygiene

The main conversation must stay under 60% context usage. When approaching 60%:

1. **Update `tasks/WIP.md`** with current state: what's done, what's in progress, what's next, any decisions or blockers
2. **Compact** — use `/compact` to free context
3. After compacting, re-read `tasks/WIP.md` to restore working state

This prevents context rot — losing track of in-flight work after auto-compaction. Agents should also keep context lean: delegate research to sub-agents, avoid reading entire large files when a section suffices.

### Agent Permissions

- Code-writing agents need Bash for `flutter pub get`, `dart format`, `dart analyze`, `flutter test`
- Read-only agents (reviewer, ui-ux-critic, product-owner) never get Write/Edit tools
- QA engineer needs Playwright MCP tools for e2e tests

## Git Flow

- `main` is protected — everything through PRs
- Branches: `feature/step<N>-description` or `fix/description`
- Squash merge to main, delete branch after
- Releases: semver `v0.1.0`, `v0.2.0`, etc.
- No direct commits to main, no force pushes, no skipping CI
