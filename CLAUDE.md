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

| Agent           | Role                                                     | Writes Code | Model  |
| --------------- | -------------------------------------------------------- | ----------- | ------ |
| `tech-lead`     | Architecture, scaffolding, coordination, Git flow, PRs   | Yes         | Opus   |
| `flutter-dev`   | UI screens, widgets, Riverpod providers                  | Yes         | Opus   |
| `supabase-dev`  | Database, migrations, RLS, auth, repositories            | Yes         | Sonnet |
| `devops`        | CI/CD pipelines, GitHub Actions, releases                | Yes         | Sonnet |
| `qa-engineer`   | Test strategy, unit/widget/e2e tests, Playwright         | Yes         | Opus   |
| `product-owner` | Market research, competitor analysis, feature priorities | Read-only   | Opus   |
| `reviewer`      | Code review, quality checks                              | Read-only   | Sonnet |
| `ui-ux-critic`  | Design critique, anti-generic-AI aesthetics              | Read-only   | Opus   |

### Development Flow (Agile Sprint Cycle)

Each PLAN.md step is treated as a sprint increment. The team follows this pipeline:

#### 1. Planning & Kickoff
- **product-owner** provides market context, user stories, and acceptance criteria
- **tech-lead** breaks the step into sub-tasks, creates feature branch (`feature/step<N>-description`)
- **tech-lead** identifies which agents are needed and what they'll build

#### 2. Implementation (Parallel where possible)
- **tech-lead** builds architecture scaffolding, core patterns, and cross-cutting concerns first
- **flutter-dev** and/or **supabase-dev** implement feature work (can run in parallel on independent sub-tasks)
- Each implementer runs `make format` and `make analyze` before considering their work done
- Implementers hand off by summarizing: what was built, which files changed, any decisions made

#### 3. Design Review
- **ui-ux-critic** reviews any new/changed screens (read-only)
- Provides verdict (Generic / Acceptable / Distinctive) with actionable feedback
- If verdict is "Generic": implementer revises before proceeding
- Skip this step if no UI was added or changed

#### 4. Testing
- **qa-engineer** reads the implementation, identifies risk areas and edge cases
- Writes unit tests, widget tests, and e2e smoke tests (per PLAN.md step requirements)
- Runs `flutter test` — all tests must pass before proceeding
- Reports coverage gaps or concerns back to the team

#### 5. Code Review & PR
- **reviewer** reviews all changed files for quality, consistency, and security (read-only)
- Reports issues by severity: Critical (must fix) > Warning (should fix) > Suggestion
- **tech-lead** addresses Critical and Warning feedback with fixup commits
- **tech-lead** runs `make ci` — must pass clean
- **tech-lead** creates PR via `gh pr create` with structured description (What / Why / Changes / Testing / Checklist)

#### 6. PR Review & Merge
- PR requires CI status checks to pass (format, analyze, test)
- **reviewer** and **qa-engineer** review the PR on GitHub
- **tech-lead** addresses review feedback, pushes fixes
- Squash merge to `main`, delete feature branch
- Tag release if step completes a milestone (`v0.X.0`)

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
