# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Next up: Phase 13a Sprint A — PR 5 (observability)

**Status (2026-04-10):** PR 4 (W2 wakelock) shipped as #45 — squash-merged to main. PR 5 still needs design work before implementation.

### PR 5: B2 + B3 — Observability (Sentry + Analytics)  (5-8h, needs design)

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

## Parallel track: pixel-art-skill v0.1 (general-purpose Claude skill)

**Source repo:** `~/Projects/pixel-art-skill/` (separate git history, not part of GymBuddy)

- Spec: `~/Projects/pixel-art-skill/docs/specs/2026-04-10-pixel-art-skill-design.md`
- Plan: `~/Projects/pixel-art-skill/docs/plans/2026-04-10-pixel-art-skill-v0.1.md`
- Being picked up in a separate Claude Code window — do NOT touch from the GymBuddy session
- After v0.1 ships and installs to `~/.claude/skills/pixel-art/`, first real-world test is the deferred GymBuddy P6 app icon
