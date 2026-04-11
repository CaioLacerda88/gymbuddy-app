# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## In progress: Phase 13a Sprint A — PR 5 (observability)

**Status (2026-04-10):** Plan written (`docs/superpowers/plans/2026-04-10-pr5-observability.md`), branch `feature/phase13a-sprintA-pr5-observability`, **Tasks 1-11 of 19 implemented + committed**. Paused before Task 12 to restart for `.mcp.json` (openai-gpt-image) to load. Resume at Task 12.

### Execution mode

Subagent-driven development (superpowers:subagent-driven-development). One tech-lead subagent per task, spec + quality review between tasks, TaskList tracks state.

### Branch state

Feature branch: `feature/phase13a-sprintA-pr5-observability` (from main @ f9c95ee)

Commits so far (bottom = oldest):

1. `eebde73` docs(phase13a): add PR 5 observability plan + WIP decisions
2. `62f5627` feat(core): add analytics_events table migration (PR 5) — Task 1
3. `b771ce4` feat(analytics): add typed AnalyticsEvent union for 9 events (PR 5) — Task 2
4. `0eaba7e` feat(analytics): add AnalyticsRepository with fire-and-forget insert (PR 5) — Task 3
5. `5492d77` feat(analytics): add platform info helper + repository provider (PR 5) — Task 4
6. `a795bbd` chore(deps): add sentry_flutter + SENTRY_DSN env key (PR 5) — Task 5
7. `3494629` feat(core): add SentryReport gating wrapper (PR 5) — Task 6
8. `3fa3567` feat(core): wire SentryFlutter.init with strict PII scrubbing (PR 5) — Task 7
9. `22c89d7` feat(core): capture unexpected repo errors to Sentry (PR 5) — Task 8
10. `46ee672` feat(core): add SentryNavigatorObserver with UUID scrubbing (PR 5) — Task 9
11. `da92413` feat(profile): add crash reports opt-out provider (PR 5) — Task 10
12. `b3df7a7` feat(profile): add Send crash reports toggle in Privacy section (PR 5) — Task 11

**Current test count:** 939 passing (935 baseline + 4 new in crash_reports_enabled_provider_test). Analyzer: 0 issues.

### Deviations applied during implementation (not in the plan file)

- **Task 2 (AnalyticsEvent):** `name` getter uses Freezed's `map` instead of `when` to avoid 25 `unnecessary_underscores` analyzer infos that `--fatal-infos` treats as failures. `props` getter still uses `when` since it destructures fields. Semantically equivalent.
- **Task 3 (AnalyticsRepository test Fake):** Two fixes to the spec's Fake infrastructure because it wouldn't compile/run as written:
  1. Removed `PostgrestQueryOptions? options` from `_FakeInsertBuilder.insert` — that parameter doesn't exist in pinned `postgrest 2.6.0`.
  2. Rewrote `_FakeErrorFilterBuilder.then` to actively invoke the `onError` callback — the spec version returned `Future.error(_error)` but that hangs Dart's `await` because when you implement `Future<T>`, `await` passes its own internal `onError` to `.then()` and the Fake must call it to signal the awaiter's completer. Added `// ignore: must_be_immutable` on the Fake (intentional test spy).
  - Production code (`analytics_repository.dart`) matches spec exactly.
- **Task 7 (sentry_init.dart):** Three API adjustments to match installed `sentry_flutter 8.14.2` (verified against the installed source):
  1. Callback signatures typed with concrete types: `(SentryEvent event, Hint hint)` for `beforeSend`, `(Breadcrumb? crumb, Hint hint)` for `beforeBreadcrumb`.
  2. `event.copyWith(user: null)` CANNOT clear the user — `copyWith` internally uses `user: user ?? this.user`, so null preserves existing. When no Supabase user exists, the code now returns `event` unchanged (relies on `sendDefaultPii: false` to keep user fields empty). Inline comment added so nobody re-introduces the bug.
  3. `sanitizeRouteName` return type changed from `RouteSettings` → `RouteSettings?` to match the `RouteNameExtractor` typedef.
- **Task 7 (package_info_plus):** Pinned to `^9.0.1` (10.0.0 requires a newer Dart SDK).
- **Task 10 (crash_reports_enabled_provider_test):** Uses `Directory.systemTemp.createTemp` + `Hive.init(tempDir.path)` instead of the spec's `FakePathProviderPlatform` + `Hive.initFlutter`. Reason: `path_provider_platform_interface` and `plugin_platform_interface` are transitive-only in pubspec.lock — importing them requires new dev_deps AND trips `depend_on_referenced_packages`. The temp-dir pattern is already the house style (matches `test/unit/features/workouts/data/workout_local_storage_test.dart`) and needs zero new packages.
- **Task 11 (profile_screen + widget tests):** Plan literal had `BorderRadius.circular(12)` and `surfaceContainerLow`; used the existing project conventions instead — `BorderRadius.circular(kRadiusMd)` and `theme.cardTheme.color ?? theme.colorScheme.surface` — to match `DATA MANAGEMENT` / `LEGAL` sections.
- **Task 11 (profile widget tests):** `ProfileScreen` now watches `crashReportsEnabledProvider` which reads `Hive.box(HiveService.userPrefs)`. The 3 profile widget test files (`profile_screen_test.dart`, `profile_stats_test.dart`, `profile_stats_navigation_test.dart`) didn't initialize Hive → HiveError. Fix: added `setUpAll` to each that opens a temp-dir-backed `user_prefs` box, with matching `tearDownAll` cleanup. Zero changes to the 8+ ProviderScope blocks — fixing the test setup is cleaner than overriding the provider in every scope.

### Tasks remaining (8/19)

- [ ] **Task 12** — Privacy policy edits (both `assets/legal/privacy_policy.md` and `docs/privacy_policy.md`, preserving Jekyll front-matter in docs/). 5 targeted changes. Plan lines 1599-1689.
- [ ] **Task 13** — Fire `onboarding_completed` in `_finishOnboarding`. Plan lines 1693-1753.
- [ ] **Task 14** — Wire workout lifecycle (3 events + breadcrumbs) into `active_workout_notifier.dart` with `_trackWorkoutEvent` helper. Plan lines 1757-1938. Most complex event-wire task.
- [ ] **Task 15** — Fire `pr_celebration_seen` (initState + addPostFrameCallback) and `add_to_plan_prompt_responded` (3-way action enum) in `pr_celebration_screen.dart`. Plan lines 1942-2060.
- [ ] **Task 16** — Refactor `_savePlan` in `plan_management_screen.dart` to accept `{usedAutofill, replacedExisting}` + fire `week_plan_saved`. Update all 4 call sites. Plan lines 2064-2156.
- [ ] **Task 17** — Fire `week_complete` in `WeeklyPlanNotifier.markRoutineComplete` on `!wasAllComplete && isNowAllComplete` transition. Plan lines 2160-2251.
- [ ] **Task 18** — Auth breadcrumbs (sign-up/sign-in/sign-out) + `account_deleted` event with `await` (not unawaited — CASCADE DELETE race). Plan lines 2255-2390.
- [ ] **Task 19** — Final verification gate: `make ci`, local migration apply, E2E smoke, manual event verification, `gh pr create`. Plan lines 2394-2500.

### How to resume after restart (for `.mcp.json` load)

1. Read `tasks/WIP.md` (this file) and `docs/superpowers/plans/2026-04-10-pr5-observability.md`
2. `git checkout feature/phase13a-sprintA-pr5-observability` (should already be checked out)
3. Verify baseline: `export PATH="/c/flutter/bin:$PATH" && dart analyze --fatal-infos && flutter test` → expect 939 passing
4. Resume TaskList from task #17 (plan Task 12 — Privacy policy edits). The TaskList IDs are #6-#24 mapping to plan Tasks 1-19.
5. New plan Task per commit: user asked to commit after every task completes (short of final verification task). Keep this habit.
6. Keep using `superpowers:subagent-driven-development` workflow: dispatch `tech-lead` per task with the full step-by-step text from the plan, then verify the diff + run the full suite before advancing.
7. MCP note: `.mcp.json` at repo root registers `openai-gpt-image` MCP server. Needs `OPENAI_API_KEY` in shell env. Should load automatically on Claude Code restart; verify with `/mcp`.

### Prior design decisions (locked in before implementation)

All 5 design questions are already resolved and cemented in the plan. Preserved here for context:

### PR 5: B2 + B3 — Observability (Sentry + Analytics) (5-8h, needs design)

**Goal:** Crash reporting via Sentry + basic product analytics for retention tracking.

**Design decisions locked in:**

- **Q1 — Analytics backend:** ✅ **Supabase-native** `public.analytics_events` table. No PostHog, no third-party SDK. Reasons: LGPD (data stays first-party, privacy policy section 2 survives with a one-line tweak), zero new dependencies, free tier effectively unlimited for MVP volume, full SQL for retention/funnels via views.
  - Schema: `(id uuid pk, user_id uuid fk auth.users on delete cascade, name text, props jsonb default '{}', created_at timestamptz default now())`
  - Indexes: `(user_id, created_at desc)`, `(name, created_at desc)`
  - RLS: enable; policy "users insert own events" with `auth.uid() = user_id`. No SELECT policy (service role only for our own querying).
  - Flutter: thin `AnalyticsRepository` wrapping `supabase.from('analytics_events').insert(...)`, mockable for tests.

**Open questions (remaining):**

- **Q2 — Sentry DSN management:** ✅ **`.env` file** (parity with Supabase creds) with **empty-DSN-skips-init** twist. In `main.dart`, read `dotenv.env['SENTRY_DSN'] ?? ''`; if empty, bypass `SentryFlutter.init` entirely. Benefits: dev builds and tests never send (empty DSN locally), prod CI writes the real one, no separate codepath. `tracesSampleRate: 0.0` for MVP (no perf tracing). `environment: kReleaseMode ? 'prod' : 'dev'`.
- **Q3 — PII + LGPD + opt-out:** ✅ locked in.
  - **Q3a Sentry scrubbing — strict mode:**
    - `sendDefaultPii: false`, `tracesSampleRate: 0.0`, `environment: kReleaseMode ? 'prod' : 'dev'`
    - `beforeSend`: set `SentryUser(id: supabase.auth.currentUser?.id)` only — never email/name
    - `beforeBreadcrumb`: drop any breadcrumb whose message contains `@` (email filter)
    - 100% error capture rate, no sampling
  - **Q3b opt-out toggle — Option A:** one toggle "Send crash reports" in Profile → Settings, defaults ON, controls Sentry only. Analytics runs for all users (first-party, disclosed). No analytics toggle for MVP.
  - **Q3c privacy policy — targeted edits** (NOT a rewrite), in both `assets/legal/privacy_policy.md` and `docs/privacy_policy.md`:
    1. Section 2 line 13: replace "no tracking SDKs, ..." with "no advertising SDKs, ad networks, or analytics services that share your data with advertisers. We use Sentry for crash reports — see Section 5."
    2. Section 2: add new "Usage Events" subsection describing the first-party analytics_events table
    3. Section 3: soften "We do not track..." to "...outside of the usage events described in Section 2."
    4. Section 5: add Sentry processor disclosure (user_id only, no email/IP, opt-out path, sentry.io/privacy link)
    5. Bump "Last updated" to PR 5 merge date
- **Q4 — Event schema:** ✅ locked in after PO + UX critic analysis (both agents ratified the current feature set). Original PLAN.md 7-event list was stale — new schema is 9 must-have events grounded in actual app loops (weekly plan, PR celebration, add-to-plan prompt).

  **Must-have (9 events):**
  1. `onboarding_completed` → `{ fitness_level, training_frequency }`
  2. `workout_started` → `{ source: planned_bucket|routine_card|empty, routine_id?, exercise_count, had_active_workout_conflict }`
  3. `workout_discarded` → `{ elapsed_seconds, completed_sets, exercise_count, source }`
  4. `workout_finished` → `{ duration_seconds, exercise_count, total_sets, completed_sets, incomplete_sets_skipped, had_pr, source, workout_number }`
  5. `pr_celebration_seen` → `{ is_first_workout, pr_count, record_types: [max_weight|max_reps|max_volume, ...] }`
  6. `week_plan_saved` → `{ routine_count, at_soft_cap, used_autofill, replaced_existing }`
  7. `week_complete` → `{ sessions_completed, pr_count_this_week, plan_size, week_number }`
  8. `add_to_plan_prompt_responded` → `{ action: added|skipped|dismissed, trigger: pr_celebration_continue|direct_prompt, routine_id }`
  9. `account_deleted` → `{ workout_count, days_since_signup }`

  **Deferred (later PR):** `routine_created`, `exercise_created`, `rest_timer_skipped`, `week_plan_cleared`, `exercise_swapped_during_workout`, `pr_celebration_dismissed`

  **Cut:** original `signup` / `login` / `app_opened` / `first_workout_completed` / `routine_started`, all `screen_view_*`, `set_completed`

  **Key decisions baked in:**
  - `first_workout_completed` merged into `workout_finished` via `workout_number = 1`
  - `routine_started` merged into `workout_started` via `source = routine_card` or `planned_bucket`
  - `workout_number` precomputed client-side (count before save) to enable cohort SQL without CTEs
  - `pr_celebration_seen` fires from the celebration UI, not the detection logic — measures the experience
  - `add_to_plan_prompt_responded` has three-way `action` enum (added/skipped/dismissed) to avoid the dark-pattern of conflating swipe-away with explicit skip
  - No free-text fields, no email/name, no PII in any prop. `user_id` is on the row (not in props).

  **Q4a — Platform + app_version as TABLE COLUMNS** (not props):

  ```sql
  platform    text,        -- 'android' | 'ios' | 'web'
  app_version text,        -- e.g. '1.2.3+45'
  ```

  Indexable, type-safe, populated on every insert by the `AnalyticsRepository` wrapper.

- **Q5 — Sentry integration points:** ✅ locked in. Three-tier instrumentation:
  - **Tier 1 — Foundation:** `runZonedGuarded` in `lib/main.dart` wrapping `runApp`, `SentryFlutter.init(appRunner: ...)` which auto-wires `FlutterError.onError` and `PlatformDispatcher.instance.onError`. Canonical pattern from Sentry docs.
  - **Tier 2 — Explicit captures:** `Sentry.captureException(e, stackTrace: st)` in `lib/core/data/base_repository.dart` catch blocks where AppExceptions are constructed. Single chokepoint for all data-layer errors.
  - **Tier 3 — Breadcrumbs:**
    - `SentryNavigatorObserver()` added to `lib/core/router/app_router.dart` GoRouter config (route changes)
    - `Sentry.addBreadcrumb` on sign-in / sign-out in `lib/features/auth/providers/notifiers/auth_notifier.dart`
    - `Sentry.addBreadcrumb` on workout start / finish / discard in `lib/features/workouts/providers/notifiers/active_workout_notifier.dart` — transition name + workout_id only, no weights/notes
  - **Tier 4 — explicitly NOT captured:** `print()`/`debugPrint`, 404s/401s bubbled as AppException subclasses (would double-log), network failures with retry success, user-initiated cancellations
  - **Q5a — Route sanitization:** ✅ Option A. Use `SentryNavigatorObserver` + `beforeBreadcrumb` scrubber to replace UUIDs in paths with `:id` if any leak. Verify at implementation time what the observer actually sends.
  - **Files touched: 5** — main.dart, base_repository.dart, app_router.dart, auth_notifier.dart, active_workout_notifier.dart

- **Post-merge follow-up (NOT in PR 5 scope) — Sentry → GitHub issue automation:**
  - Install Sentry's GitHub integration (OAuth on the GymBuddy org/repo)
  - Configure alert rule: "When issue is seen N+ times by M+ users" → action: "Create GitHub issue in caio/gymbuddy-app" with labels `bug`, `sentry`, `triage`
  - Recommended threshold for MVP: **seen 25+ times AND affecting 5+ distinct users in 24h** — avoids single-device anomalies becoming tickets
  - Document in a `docs/ops/sentry-runbook.md` file during a future ops PR, not now

**Files to read on session resume (for context):**

- `lib/main.dart` — Sentry.init wiring
- `lib/app.dart` — NavigatorObserver + app_opened event
- `lib/core/exceptions/app_exception.dart` — sealed hierarchy
- `lib/core/data/base_repository.dart` — catch sites
- `lib/features/auth/providers/notifiers/auth_notifier.dart` — signup/login events
- `lib/features/workouts/providers/active_workout_controller.dart` (or equiv) — workout_finished event
- `lib/features/workouts/data/workout_repository.dart` — first_workout_completed gate (needs user-local check)
- `lib/features/personal_records/providers/*.dart` — pr_broken event (fires from PR detection logic)
- `lib/features/profile/ui/*.dart` — for opt-out toggle UI (if we build one)
- `assets/legal/privacy_policy.md` section 2 — targeted Sentry disclosure edit
- `docs/privacy_policy.md` — mirror of the above
- `.env` / `.env.example` — where to add SENTRY_DSN
- `supabase/migrations/` — new migration for `public.analytics_events` + RLS policy

**Proposed PR 5 sub-sequence (Supabase-native analytics + Sentry):**

1. Migration: `public.analytics_events` table + indexes + RLS policy (apply to hosted Supabase post-merge)
2. `AnalyticsRepository` abstraction + Supabase impl (mockable via BaseRepository pattern)
3. Sentry dep + DSN in `.env`/`.env.example` + `Sentry.init` in `main.dart` with `runZonedGuarded` + `FlutterError.onError`
4. Privacy policy section 2 targeted edit (disclose Sentry as crash-reporting processor)
5. (Optional) Profile opt-out toggle — decision pending Q3
6. Wire analytics events at call sites (auth notifier, workout controller, PR detection, app_opened in app.dart)
7. Wire Sentry captureException at BaseRepository catch sites + add NavigatorObserver breadcrumbs
8. Unit tests for AnalyticsRepository + event-emission logic, widget test for opt-out toggle (if built), E2E smoke: verify events land in the local Supabase table

### Immediate next action on resume

1. Re-read this WIP section
2. Q1 analytics backend ✅ locked in (Supabase-native). Remaining questions: Q2 DSN, Q3 PII/opt-out, Q4 event schema, Q5 Sentry integration points
3. Brainstorming → writing-plans → implement

---
