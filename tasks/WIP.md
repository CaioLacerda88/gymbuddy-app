# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Next up: Phase 13a Sprint A — PR 5 (observability)

**Status (2026-04-10):** PR 4 (W2 wakelock) shipped as #45 — squash-merged to main. PR 5 still needs design work before implementation.

### PR 5: B2 + B3 — Observability (Sentry + Analytics)  (5-8h, needs design)

**Goal:** Crash reporting via Sentry + basic product analytics for retention tracking.

**Open questions (answer before starting implementation):**
1. **Analytics provider** — recommendation: **PostHog** (1M events/mo free, self-hostable, open-source, LGPD-friendly, one SDK covers analytics + flags + replay). Alternatives: Amplitude (10M/mo free, US-based, closed), Mixpanel (20M/mo free, closed). Solo Brazilian dev + LGPD → PostHog is the right default but confirm with user.
2. **Sentry DSN management** — options: `.env` file (like Supabase creds), compile-time `--dart-define`, or CI-only secret. `.env` is simplest and matches existing pattern; compile-time is more secure for release builds. Recommend `.env` for parity, document the trade-off.
3. **PII policy** (LGPD — user is in Brazil, privacy policy already promises "no advertising identifiers, no third-party analytics sharing data" — need to verify that claim is still honored with PostHog + Sentry):
   - Sentry: send `user_id` only? Scrub emails from breadcrumbs? Sample rate?
   - Analytics: send anonymous `distinct_id` (generated UUID) only? No email, no name. Does this need a Profile opt-out toggle? **LGPD likely requires an opt-out** — plan for a "Usage analytics" toggle in Profile → Settings.
   - **Privacy policy update:** section 2 currently says "GymBuddy does not use tracking SDKs, advertising identifiers, or analytics services that share data with third parties." That claim will break with PostHog + Sentry. Rewrite section 2 of `assets/legal/privacy_policy.md` + `docs/privacy_policy.md` to accurately describe what we collect, why, retention, opt-out path.
4. **Event schema** — PLAN.md B3 lists 7 events: `signup`, `login`, `first_workout_completed`, `workout_finished`, `routine_started`, `pr_broken`, `app_opened`. Need to define props per event (e.g., `workout_finished` → duration, exercise_count, set_count, volume; `pr_broken` → exercise_id, record_type, value). User should ratify the schema before implementation.
5. **Sentry integration points** — where to `Sentry.captureException`:
   - `BaseRepository` catch sites (all AppException creation points)
   - Top-level `runZonedGuarded` in `main.dart`
   - FlutterError.onError
   - Breadcrumbs: `NavigatorObserver` on `GoRouter`, Auth state changes, workout start/save/finish

**Files to read on session resume (for context):**
- `lib/main.dart` — Sentry.init wiring
- `lib/app.dart` — NavigatorObserver + app_opened event
- `lib/core/exceptions/app_exception.dart` — sealed hierarchy
- `lib/core/data/base_repository.dart` — catch sites
- `lib/features/auth/providers/notifiers/auth_notifier.dart` — signup/login events
- `lib/features/workouts/providers/active_workout_controller.dart` (or equiv) — workout_finished event
- `lib/features/workouts/data/workout_repository.dart` — first_workout_completed gate (needs user-local check)
- `lib/features/personal_records/providers/*.dart` — pr_broken event (fires from PR detection logic)
- `lib/features/profile/ui/*.dart` — for opt-out toggle UI
- `assets/legal/privacy_policy.md` section 2 — needs rewrite
- `.env` — where to add SENTRY_DSN + POSTHOG_API_KEY

**Proposed PR 5 sub-sequence (if we end up bundling):**
1. Dependency + env setup (dotenv keys, DSN in .env.example)
2. AnalyticsRepository abstraction + PostHog impl (mockable)
3. Sentry init in main.dart with runZonedGuarded + FlutterError hook
4. Privacy policy section 2 rewrite + opt-out toggle in Profile
5. Wire analytics events at call sites (one per logical feature)
6. Wire Sentry captureException at BaseRepository catch sites + add NavigatorObserver breadcrumbs
7. Widget tests for AnalyticsRepository, unit tests for event-emission logic, E2E smoke: verify opt-out toggle persists and disables sends

### Immediate next action on resume

1. Re-read this WIP section
2. Lock in PR 5 answers (provider, DSN, PII, event schema) with user
3. Brainstorming → writing-plans → implement

---

## Parallel track: pixel-art-skill v0.1 (general-purpose Claude skill)

**Source repo:** `~/Projects/pixel-art-skill/` (separate git history, not part of GymBuddy)

- Spec: `~/Projects/pixel-art-skill/docs/specs/2026-04-10-pixel-art-skill-design.md`
- Plan: `~/Projects/pixel-art-skill/docs/plans/2026-04-10-pixel-art-skill-v0.1.md`
- Being picked up in a separate Claude Code window — do NOT touch from the GymBuddy session
- After v0.1 ships and installs to `~/.claude/skills/pixel-art/`, first real-world test is the deferred GymBuddy P6 app icon
