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
| `team-lead`     | **Orchestrator** — task breakdown, agent dispatch, handoffs, quality gates, PRs | No          | Opus   |
| `tech-lead`     | Architecture, core scaffolding, cross-cutting patterns       | Yes         | Opus   |
| `flutter-dev`   | UI screens, widgets, Riverpod providers, navigation          | Yes         | Opus   |
| `supabase-dev`  | Database, migrations, RLS, auth, repositories                | Yes         | Sonnet |
| `devops`        | CI/CD pipelines, GitHub Actions, releases                    | Yes         | Sonnet |
| `qa-engineer`   | Test strategy, unit/widget/e2e tests, Playwright             | Yes         | Opus   |
| `product-owner` | Market research, competitor analysis, feature priorities     | Read-only   | Opus   |
| `reviewer`      | Code review, quality checks                                  | Read-only   | Sonnet |
| `ui-ux-critic`  | Design critique, anti-generic-AI aesthetics                  | Read-only   | Opus   |

### How it works

**The main conversation orchestrates agents directly for most work.** Only dispatch `team-lead` for complex steps requiring 4+ agents with interdependencies. For simpler tasks (1-3 agents), the main conversation dispatches agents directly, runs CI, and manages PRs.

### Development Flow

Each PLAN.md step is a sprint increment:

1. **Plan** — Read PLAN.md step. Dispatch `product-owner` + `ui-ux-critic` (if user-facing) for context.
2. **Write WIP checklist** — Before touching code, write a checklist in `tasks/WIP.md` (see below).
3. **Implement** — Dispatch `tech-lead` (scaffolding), `flutter-dev`/`supabase-dev` (feature work). Parallel when independent. Check off WIP items as they complete.
4. **Verify** — Run `dart format .` + `dart analyze --fatal-infos` after each agent.
5. **Design review** (if UI) — `ui-ux-critic` reviews. Generic → revise.
6. **Test** — `qa-engineer` writes tests, runs `flutter test`.
7. **Code review** — `reviewer` checks all files. Fix Critical/Warning findings.
8. **Ship** — Run CI, commit, push, `gh pr create`, squash merge.
9. **Close WIP** — Remove completed items from `tasks/WIP.md`. Log results in PLAN.md.

### WIP Tracking (`tasks/WIP.md`)

**Every agent that changes code MUST follow this protocol:**

1. **Before writing code:** Read the relevant definition files (`PLAN.md`, `GAMIFICATION.md`, `PROD-READINESS.md`, etc.), then write a checklist in `tasks/WIP.md` with:
   - Task name and branch name
   - Reference to the source definition (e.g., "Per PLAN.md Step 11c", "Per GAMIFICATION.md Phase 1")
   - Checkable items for each change to make
   - Files to modify/create
2. **During implementation:** Check off items as they're completed (`- [x]`)
3. **After merge:** Remove the completed section from `tasks/WIP.md` and update PLAN.md with results

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
