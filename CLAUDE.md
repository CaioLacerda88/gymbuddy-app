# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

GymBuddy — a gym training app for logging workouts, tracking personal records, and managing exercises. See `PLAN.md` for full project details: tech stack, database schema, architecture decisions, project structure, and step-by-step implementation plan.

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

Each PLAN.md step is a sprint increment:

1. **Plan** — Read PLAN.md step. Dispatch `product-owner` + `ui-ux-critic` (if user-facing) for context.
2. **Write WIP checklist** — Before touching code, write a checklist in `tasks/WIP.md` (see below).
3. **Implement** — Dispatch `tech-lead` for all code work (architecture, UI, migrations, bug fixes). Parallel agents when independent. Check off WIP items as they complete.
4. **Verify** — Run `dart format .` + `dart analyze --fatal-infos` after each agent.
5. **Design review** (if UI) — `ui-ux-critic` reviews. Generic → revise.
6. **Test** — `qa-engineer` writes tests, runs `flutter test`.
7. **Code review** — `reviewer` checks all files. Fix Critical/Warning findings.
8. **Ship** — Run CI, commit, push, `gh pr create`, squash merge.
9. **Close WIP** — Remove completed items from `tasks/WIP.md`. Condense the step in PLAN.md (see below).

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
