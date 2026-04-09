# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

GymBuddy — a gym training app for logging workouts, tracking personal records, and managing exercises.

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
make ci                      # full pipeline: format + analyze + gen + test

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

# Override FLUTTER_APP_URL so Playwright auto-starts python http.server on :4200
# (.env.local sets FLUTTER_APP_URL=http://localhost:8080 for CI — we override it)
FLUTTER_APP_URL= npx playwright test --project=smoke --reporter=list

# Run a single test file:
FLUTTER_APP_URL= npx playwright test --project=smoke smoke/auth.smoke.spec.ts

# Run a specific test by line number:
FLUTTER_APP_URL= npx playwright test --project=smoke "smoke/auth.smoke.spec.ts:16"
```

**Key details:**
- `FLUTTER_APP_URL=` (empty) overrides `.env.local` → Playwright auto-serves `build/web/` via `python -m http.server` on port 4200
- **Env auto-swap**: Global setup injects local Supabase credentials into `build/web/assets/.env` so the Flutter app connects to the same Supabase instance the tests use. No manual `.env` swap needed.
- Global setup creates test users via Supabase Admin API → requires local Supabase running
- Global teardown deletes test users → idempotent, safe to rerun
- Screenshots on failure: `test/e2e/test-results/`
- Config: `test/e2e/playwright.config.ts`
- **CI vs local**: The root `.env` has hosted Supabase (production). `test/e2e/.env.local` has local Supabase. Global setup handles the swap automatically.

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
   - **E2E (always):** Verify no selectors/text strings broke; update `selectors.ts` if needed
   - **E2E (new/changed user flows):** Write/update E2E regression tests for the feature, run full E2E suite locally — all must pass
   - **E2E (visual-only / no flow change):** Selector impact assessment is sufficient; skip suite run and new E2E tests
   - Removes or updates stale E2E tests affected by the change
   - Bugs found → back to `tech-lead` → fix → QA re-runs from top
6. **Open PR** — only after QA gate passes.
7. **Code review** — `reviewer` flags issues → `tech-lead` fixes → `qa-engineer` re-validates.
8. **Ship** — QA OK + CI green → squash merge.
9. **Apply migrations** — After merge, check if the step added/modified SQL migrations (`supabase/migrations/`). If so, apply them to the hosted Supabase instance with `npx supabase db push` (or link + push). Verify the schema matches what the code expects before moving on. During QA/testing, always confirm that any new migrations have been applied to the environment under test.
10. **Close WIP** — Remove WIP section, condense step in PLAN.md (see lifecycle below).

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
