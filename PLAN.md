# GymBuddy — Master Plan

## Quick Reference

Gym training app for logging workouts, tracking personal records, and managing exercises. Flutter + Supabase + Riverpod. Android-first, iOS deferred. Dark bold theme, gym-floor UX (one-handed, glanceable, sweat-proof).

**Market context:** $12B+ fitness app market, 70% abandoned within 90 days. Core differentiator: RPG gamification tightly coupled to real training data (see Phase 15-16).

### Progress

| Step/Phase | Name | Status | PR(s) |
|------------|------|--------|-------|
| 1 | Project Setup & CI | DONE | #1 |
| 2 | Database Schema & Seed | DONE | #2 |
| 3 | Auth & Onboarding | DONE | #3-#5 |
| 3b | Auth UX Polish | DONE | #6 |
| 4 | Exercise Library + Images | DONE | #7-#10 |
| 5 | Workout Logging (5a-5d) | DONE | #11-#15 |
| 5e | UX Polish Sprint | DONE | #16-#18 |
| 6 | Routines | DONE | #19 |
| 7 | Personal Records | DONE | #20 |
| 8 | Home Polish & PR Integration | DONE | #21 |
| 9 | E2E Testing & CI/CD | DONE | #22-#23 |
| 9d | Final QA Pass | DONE | #24 |
| 10 | UX Improvements & Security | DONE | #25-#26 |
| 11 | Exercise Content, Smart Defaults, Home Simplification | DONE | #27-#30 |
| 12 | Weekly Training Plan (Bucket Model) | DONE | #32 |
| 12.1 | E2E Infrastructure: Parallelism, Teardown, Data Seeding | DONE | #35 |
| 12.2a | Bug Fixes (7 UX bugs) | DONE | #36 |
| 12.2b | Home Screen Redesign | DONE | #37 |
| 12.2c | Plan Management UX Polish | DONE | #38 |
| 12.3a | P0 Bug Fixes (back nav, home flicker) | DONE | #39 |
| 12.3b | Copy Fix + Content Expansion (exercises, routines) | DONE | #40 |
| 12.3c | Standalone Routine → Plan Prompt | DONE | #41 |
| 13a-PR1 | Account Deletion + Volume Unit + OAuth Deep Link | DONE | #42 |
| 13a-PR2 | Release Signing + Branding + Privacy Policy & ToS (icon DEFERRED) | DONE | #43 |
| 13a-PR3 | Sprint A QA follow-ups (legal polish, PWA theme, test coverage, live delete E2E) | DONE | #44 |
| 13a-PR5 | Observability: Sentry crash reporting + first-party analytics_events (B2 + B3) | DONE | #46 |
| 13a-PR6 | Bulk Dependency Upgrade + Toolchain Refresh (Riverpod 3, GoRouter 17, Freezed 3) | PLANNED | - |
| 13a-PR7 | Close local CI Android build gap (`make ci` runs `flutter build apk --debug`) | PLANNED | - |
| 13c | UX Polish & Athletic Brutalism Redesign | PLANNED | - |
| 13 | Production Readiness (remaining Sprint A: W2; icon post-gamification) | IN PROGRESS | - |
| 14 | Offline Support | TODO | - |
| 15 | Gamification Foundation (XP, Levels, Streaks) | TODO | - |
| 16 | Gamification Advanced (Quests, Stats Panel) | TODO | - |
| 17 | Nice-to-Have (v2.0+) | BACKLOG | - |

### Section Index

Read only what you need:

| Section | When to read |
|---------|-------------|
| Tech Stack & Architecture | Building any code |
| Completed Steps (1-11) | Need context on what already exists |
| Step 12: Weekly Training Plan | Implementing Step 12 |
| Step 12.2: Home Redesign + Bug Fixes | Implementing Step 12.2 |
| Step 12.3: UX Polish & Content Expansion | Implementing Step 12.3 |
| Phase 13: Production Readiness | Preparing for Play Store |
| Phase 14: Offline Support | Implementing offline-first workout capture |
| Phase 15-16: Gamification | Implementing RPG system |
| QA Status | Doing QA or review |
| Verification & Testing | Writing tests |
| UX Design Direction | Building UI |

---

## Tech Stack & Architecture

- **Frontend:** Flutter (Android-first), SDK `^3.11.4`
- **Backend:** Supabase (Postgres, Auth, Storage)
- **Auth:** Supabase Auth — email/password + Google, `AuthFlowType.pkce`
- **State:** Riverpod `^2.4.0` (AsyncNotifier pattern)
- **Local:** Hive (active workout cache, offline queue)
- **Models:** Freezed `^2.5.0` + json_serializable
- **Theme:** Dark & bold, Material 3

### Architecture Decisions

- **Repository pattern**: All Supabase access through repository classes. No `supabase.from()` in providers/UI.
- **Feature isolation**: `lib/features/<feature>/{data,models,providers,ui}/`. No cross-feature imports.
- **Sealed exceptions**: All errors mapped to `AppException` subtypes in repository layer.
- **Offline strategy**: Server is source of truth. Active workouts use Hive with sync-on-save. Last-write-wins.
- **Atomic saves**: `save_workout` Postgres RPC — single transaction, no partial data.
- **Weight units**: Stored in user's chosen unit (kg/lbs). `weight_unit` in profile.
- **Hive boxes**: `active_workout`, `offline_queue`, `user_prefs`. Schema versioned.

### Route Tree (GoRouter)

```
/splash, /login, /onboarding, /email-confirmation  (no shell)
/workout/active                                      (no shell, full-screen)
ShellRoute:
  /home, /home/history, /home/history/:workoutId
  /exercises, /exercises/:id
  /routines, /routines/create, /routines/:id/edit
  /records
  /profile, /profile/manage-data
  /plan/week
```

### Database Schema

**Tables:** `profiles`, `exercises`, `workouts`, `workout_exercises`, `sets`, `personal_records`, `workout_templates`, `weekly_plans`

Key columns and relationships — read migration files in `supabase/migrations/` for full DDL.

- **profiles** — `id (FK auth.users)`, `username`, `display_name`, `avatar_url`, `fitness_level`, `weight_unit` (kg/lbs), `training_frequency_per_week` (2-6)
- **exercises** — `id`, `name`, `muscle_group` (enum), `equipment_type` (enum), `description`, `form_tips`, `image_start_url`, `image_end_url`, `is_default`, `user_id`, `deleted_at` (soft delete)
- **workouts** — `id`, `user_id`, `name`, `started_at`, `finished_at`, `duration_seconds`, `is_active`, `notes`
- **workout_exercises** — `id`, `workout_id`, `exercise_id`, `order`, `rest_seconds`
- **sets** — `id`, `workout_exercise_id`, `set_number`, `reps`, `weight`, `rpe`, `set_type` (working/warmup/dropset/failure), `is_completed`
- **personal_records** — `id`, `user_id`, `exercise_id`, `record_type` (max_weight/max_reps/max_volume), `value`, `reps`, `achieved_at`, `set_id`
- **workout_templates** — `id`, `user_id`, `name`, `is_default`, `exercises` (JSONB)
- **weekly_plans** — `id`, `user_id`, `week_start` (Monday), `routines` (JSONB), `UNIQUE(user_id, week_start)`

**RLS:** All user data scoped by `user_id = auth.uid()`. Default exercises/templates readable by all.

### Project Structure

```
lib/
  main.dart, app.dart
  core/          theme/, router/, data/, constants/, exceptions/, local_storage/, utils/
  features/
    auth/        data/, providers/, ui/
    exercises/   data/, models/, providers/, ui/
    workouts/    data/, models/, providers/, ui/
    personal_records/  data/, models/, domain/, providers/, ui/
    routines/    data/, models/, providers/, ui/
    profile/     data/, models/, providers/, ui/
    weekly_plan/ data/, models/, providers/, ui/
  shared/widgets/

supabase/migrations/  (00001-00011)
test/  unit/, widget/, e2e/, fixtures/
```

---

## Completed Steps (1-11)

> Condensed summaries. Full specs in git history (PR branches).

### Step 1: Project Setup & CI (PR #1)
- Flutter project scaffold, dependencies pinned, Supabase init with PKCE
- Core infrastructure: `BaseRepository`, sealed `AppException`, GoRouter skeleton, Hive service
- Shared widgets: `AsyncValueBuilder`, `ErrorOverlay`, `ThemedButton`, `FormInput`
- Dark bold theme, Makefile targets, strict `analysis_options.yaml`
- CI pipeline: format + analyze + build_runner + test

### Step 2: Database Schema & Seed (PR #2)
- Initial migration: all tables, enums, indexes, RLS policies
- Seed: ~60 default exercises, 4 starter templates (Push/Pull/Legs, Upper/Lower, Full Body)
- RLS integration tests for user isolation

### Step 3: Auth & Onboarding (PRs #3-#5)
- Supabase Auth with Google + email/password, PKCE redirect
- Auth state provider (AsyncNotifier watching `onAuthStateChange`)
- Router redirect: unauthenticated -> login, authenticated -> home
- Screens: Splash, Login/Signup, Onboarding (2 pages: welcome + profile setup)
- Profile created on first login

### Step 3b: Auth UX Polish (PR #6)
- Post-signup email confirmation screen with resend
- User-friendly auth error messages, loading states
- Custom Supabase email templates (GymBuddy-branded)

### Step 4: Exercise Library + Images (PRs #7-#10)
- Exercise model (Freezed), repository with CRUD + filters
- Exercise list: muscle group category buttons, search, equipment filter, empty states
- Exercise picker (shared contract for workout flow)
- Custom exercise creation with duplicate name validation, soft delete
- Exercise images: `cached_network_image`, start/end positions, fullscreen overlay
- Images hosted on GitHub (404 issue — see QA-005, deferred to Phase 13)

### Step 5: Workout Logging (PRs #11-#15)
- `ActiveWorkoutNotifier` (AsyncNotifier) as core state machine
- Hive persistence with schema versioning, atomic save via `save_workout` RPC
- Sub-steps: data layer (5a), active workout screen (5b), rest timer + polish (5c), finish flow + history (5d)
- WeightStepper/RepsStepper with tap-to-type, long-press repeat, 48dp targets
- Rest timer: full-screen overlay, countdown, haptic, +/-30s adjustment
- Finish dialog with incomplete sets warning, workout history with pagination
- Active workout banner in bottom nav, elapsed timer
- 328 tests (51 unit, 45 widget)

### Step 5e: UX Polish Sprint (PRs #16-#18)
- Removed start-workout name dialog (auto-naming), trimmed onboarding to 2 pages
- Set row redesign: 28-32sp numbers, tap-to-type, RPE hidden by default
- Wired onboarding data to Supabase, built minimal Profile screen
- Moved Finish button to thumb zone, added previous session hints, create-exercise in picker
- Prominent Add Set button, rest timer adjustment, active workout banner polish

### Step 6: Routines (PR #19)
- Renamed from "Templates" to "Routines" (market vocabulary)
- Bottom nav: Home | Exercises | Routines | Profile (History moved inside Home)
- Routine model (Freezed), repository, list/create screens
- Start-from-routine: 2 taps to first set (tap card -> pre-filled workout)
- Routines don't store weights — sourced from last session via `lastWorkoutSetsProvider`
- Home screen rebuild: routine launchpad + recent workouts + start empty workout
- 72dp routine cards, long-press for edit/delete, starter routines for new users

### Step 7: Personal Records (PR #20)
- PR detection in `finishWorkout()`: max weight, max reps, max volume
- Only working sets, strictly greater than previous, first workout consolidated
- Bodyweight logic: weight=0 tracks max_reps only, added weight tracks all three
- PR celebration: screen flash, spring animation, heavy haptic (no confetti)
- PR list screen with empty state

### Step 8: Home Polish & PR Integration (PR #21)
- Resume unfinished workout banner (most prominent element)
- Recent PRs section on home, "View All" to PR list
- Workout history detail with PR badges on record sets

### Step 9: E2E Testing & CI/CD (PRs #22-#24)
- Playwright infrastructure: config, helpers, fixtures, global setup/teardown
- Smoke tests (every PR): auth, workout, PR detection
- Full suite (merge to main): all features + edge cases + crash recovery
- `e2e.yml` + `release.yml` GitHub Actions workflows
- Final manual QA pass on physical devices

### Step 10: UX Improvements & Security (PRs #25-#26)
- Exercise detail bottom sheet in active workout (DraggableScrollableSheet)
- Stat cards on home (workout count, PR count with subtitles)
- Manage Data screen: delete history (two-step), reset all (type-to-confirm)
- Error message sanitization: `AppException.userMessage`, no raw DB errors in UI
- Migration: `personal_records.set_id` FK changed to `ON DELETE SET NULL`
- 61 new tests

### Step 11: Content, Smart Defaults, Home Simplification (PRs #27-#30)
- Exercise descriptions + form tips (migration, seed, UI in detail screen + bottom sheet)
- Smart set defaults: 4-priority fallback chain (prev session -> last set -> equipment defaults -> 0/0)
- Home simplification: removed Recent/Recent Records sections, enriched stat card subtitles
- 11b: 6 regression bug fixes (Hive serialization, form tips, routine start errors, equipment defaults)
- 11c: CI pipeline split into 3 parallel jobs + caching, 8 new E2E regression specs
- 787 tests total

---

## Step 12: Weekly Training Plan — Bucket Model

> **Status:** IN PROGRESS (PR #32). Migration applied to hosted Supabase. 5 regression bugs fixed. 6 E2E smoke tests added.

> **Feature overview:** Users plan their training week by placing routines into an ordered "bucket" — sequenced but not tied to specific days. The app surfaces "what's next" on the Home screen and tracks weekly completion.

#### 12a: Schema & Backend

**New table: `weekly_plans`** (migration `00011_create_weekly_plans.sql` — applied)

```sql
CREATE TABLE weekly_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  week_start DATE NOT NULL,  -- always a Monday
  routines JSONB NOT NULL DEFAULT '[]',
  -- [{routine_id: UUID, order: int, completed_workout_id: UUID|null, completed_at: timestamptz|null}]
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, week_start)
);
```

**Extend `profiles`:** `training_frequency_per_week INTEGER NOT NULL DEFAULT 3 CHECK (BETWEEN 2 AND 6)`

**Auto-populate:** On first app open of the week, copy previous week's routines (reset completion data). Show "Same plan this week?" banner with Edit/Confirm.

#### 12b: Training Frequency in Onboarding & Profile

- Onboarding page 2: 5 chip options (2x-6x/week), default 3x
- Profile: "Weekly goal" tappable row -> bottom sheet with same chips

#### 12c: Home Screen — THIS WEEK Section

Between stat cards and MY ROUTINES. Horizontal scrollable routine chips:
- **Done:** collapsed green chip with checkmark
- **Next:** solid green, taller (52dp), primary CTA, tap starts routine
- **Remaining:** ghosted, 0.55 opacity

Header: `THIS WEEK` + `{n} of {m}` count + suggested-next pill chip. Completion is automatic on workout finish. No day-of-week assignment, no shaming language.

**Empty states:** No routines -> section hidden. Has routines but no bucket -> "Plan your week ->" CTA. Disengaged 2+ weeks -> collapses to single line.

#### 12d: Plan Management Screen (`/plan/week`)

ReorderableListView of routine rows. Add via DraggableScrollableSheet multi-select. Soft cap at `training_frequency_per_week` (greys out, tooltip, still tappable). Auto-fill button, swipe-to-remove with undo, clear week action.

#### 12e: Week Review

When all complete OR new week starts: section transforms to `WEEK COMPLETE` with stats row (`{n} sessions . {kg} . {n} PRs`). `NEW WEEK` action pre-populates from completed week. Incomplete weeks show remaining at 0.3 opacity, no shame text.

**Gamification hooks (Phase 15+):** Consistency stat delta, quest XP — hidden until gamification system is built.

#### 12f: Integration Points

- Starting from bucket uses existing `startRoutineWorkout()` — zero logging changes
- Workout completion matches `routineId` in bucket and marks complete
- Bucket is a planning aid, not a gatekeeper — any workout can start anytime

#### Step 12 — Acceptance Criteria

- [x] `weekly_plans` table with RLS, `profiles.training_frequency_per_week` column
- [x] Training frequency in onboarding (page 2) and Profile
- [x] THIS WEEK section with ordered chips (done/next/remaining states)
- [x] Suggested-next pill chip, auto-completion on workout finish
- [x] Plan management: drag-to-reorder, add/remove, soft cap, auto-fill
- [x] Auto-populate from last week with confirm/edit banner
- [x] Week review: WEEK COMPLETE with stats, NEW WEEK action
- [x] Widget/unit tests (64 new), E2E smoke tests (6 new, 24 test cases)
- [x] 5 regression bugs fixed (auto-populate timing, weight unit, nav highlight, undo race)

#### Step 12 — File Plan

```
lib/features/weekly_plan/
  data/  weekly_plan_repository.dart, models/weekly_plan.dart
  providers/  weekly_plan_provider.dart, suggested_next_provider.dart, week_review_stats_provider.dart
  ui/  widgets/ (week_bucket_section, routine_chip, week_review_section), plan_management_screen, add_routines_sheet

Modified: onboarding_screen, profile_screen, home_screen, app_router, active_workout_notifier
Migration: supabase/migrations/00011_create_weekly_plans.sql
```

---

## Step 12.1: E2E Infrastructure — Parallelism, Teardown, Data Seeding (DONE — PR #35)

- Replaced Python `http.server` with `http-server` npm package (concurrent). `workers: 2` in config + CI.
- Global teardown cascades FK deletes (sets → workout_exercises → workouts → PRs → plans → profiles → auth user). All 24 test users delete cleanly.
- Seeded workout+PR data for `smokePR`, completed weekly plan for `smokeWeeklyPlanReview`, profile for `smokeExercise`.
- Rewrote `exercise-library.smoke.spec.ts` to standard infra (removed hardcoded `test.skip`, uses `smokeExercise` user).
- Added Dart semantics labels (`tooltip: 'Create routine'`, `Semantics(label: 'More options')`) for Playwright selectors.
- **Result:** 58 passed, 2 skipped (expected), 0 failures, 6.1 min runtime. Key files: `global-setup.ts`, `global-teardown.ts`, `playwright.config.ts`, `selectors.ts`, `e2e.yml`.

---

## Step 12.2: Home Redesign + Weekly Plan UX + Bug Fixes

> **Status:** TODO. Addresses 7 user-reported issues: 4 bugs, 2 UX gaps, 1 home screen redesign.
> Split into 3 sub-steps for manageable PRs.

### Context & Agent Analysis

**PO verdict:** Home screen should be action-first (weekly plan hero), not dashboard-first (stat cards). Routines list is redundant with weekly plan. Frequency limit should stay soft (goal, not gate) — matches Fitbod/Strong/Hevy. Enforced routine ordering is a retention-killer; bucket model's value is flexibility.

**UI/UX verdict:** Chip system is the strongest design element — keep and strengthen. Remove routines list from home entirely. Replace lifetime stats with contextual stats (last session, week volume). Empty plan state is invisible. "Start Empty Workout" should be FilledButton, not OutlinedButton. Don't add gradients, progress bars, or muscle group tags to chips.

---

### 12.2a: Bug Fixes (6 issues)

**Bug #1: "Fill Remaining" doesn't check off sets**
- **Root cause:** `fillRemainingSets()` in `active_workout_notifier.dart:408-444` copies weight/reps but doesn't set `isCompleted: true`
- **Fix:** Add `isCompleted: true` to the `copyWith` call for filled sets
- **File:** `lib/features/workouts/providers/notifiers/active_workout_notifier.dart`
- **Test:** Update existing test in `test/unit/features/workouts/providers/active_workout_notifier_test.dart:1096-1234` to expect completion

**Bug #2: Stat card counts not updating after workout**
- **Root cause:** After workout completion (`active_workout_screen.dart:173-175`), only `workoutHistoryProvider` and `prListProvider` are invalidated — `workoutCountProvider`, `prCountProvider`, and `recentPRsProvider` are NOT invalidated
- **Fix:** Add `ref.invalidate(workoutCountProvider)`, `ref.invalidate(prCountProvider)`, `ref.invalidate(recentPRsProvider)` after workout save
- **Files:** `lib/features/workouts/ui/active_workout_screen.dart`

**Bug #3: Profile page stat cards not navigable**
- **Root cause:** `_StatCard` in `profile_screen.dart:341-385` is a plain `Container` with no `onTap`/`GestureDetector`
- **Fix:** Wrap Workouts card → `/home/history`, PRs card → `/records`. Member Since stays informational.
- **File:** `lib/features/profile/ui/profile_screen.dart`

**Bug #4: Weekly plan enforces fixed routine order**
- **Root cause:** `week_bucket_section.dart` sets `onTap: null` for non-"next" chips. Only the `suggestedNextProvider` result is tappable.
- **Fix:** Make ALL uncompleted chips tappable (launch that routine). Keep "suggested next" as a visual recommendation (green highlight) not a gate.
- **File:** `lib/features/weekly_plan/ui/widgets/week_bucket_section.dart`

**Bug #5: No visible way to edit weekly plan mid-week**
- **Root cause:** Edit access is hidden behind long-press gesture on chip row (`GestureDetector(onLongPress: ...)`). Most users will never discover it.
- **Fix:** Add visible "Edit" icon/link in the THIS WEEK section header row. Keep long-press as secondary gesture.
- **File:** `lib/features/weekly_plan/ui/widgets/week_bucket_section.dart`

**Bug #6: "Last:" shows wrong weight after changing weight mid-workout**
- **Root cause:** `lastWorkoutSetsProvider` is a cached FutureProvider. The `lastSet` passed to `SetRow` is not reactive to current-session changes. When user changes weight on a set, "Last:" still shows stale previous-workout data.
- **Investigate further:** "Last:" is *supposed* to show the previous workout's values. Verify whether the bug is: (a) stale cache from a prior session, or (b) user expects "Last:" to reflect current-session sets. If (a), fix cache invalidation. If (b), relabel to "Previous:" and document behavior.
- **Files:** `lib/features/workouts/ui/active_workout_screen.dart:548`, `lib/features/workouts/ui/widgets/set_row.dart:170`

**Bug #7: Weekly frequency setting has no visible effect**
- **Root cause:** `trainingFrequencyPerWeek` is a soft cap only — dims the "Add Routine" button + shows tooltip. But `Tooltip` requires long-press on mobile (invisible to most users).
- **Fix (keep as soft cap per PO recommendation):** Replace invisible `Tooltip` with always-visible inline text "Goal reached — add anyway" in `bodySmall` muted style when `atSoftCap == true`. Do NOT hard-block.
- **File:** `lib/features/weekly_plan/ui/plan_management_screen.dart`

#### 12.2a — Acceptance Criteria

- [ ] Fill Remaining marks sets as completed (checkbox checked)
- [ ] Home stat cards update immediately after workout completion
- [ ] Profile Workouts card → workout history, PRs card → records screen
- [ ] All uncompleted weekly plan chips are tappable (not just "next")
- [ ] Visible "Edit" affordance in THIS WEEK section header
- [ ] "Last:" behavior verified and fixed or clarified
- [ ] Frequency soft-cap shows inline text instead of tooltip
- [ ] Existing tests updated, new unit tests for each fix
- [ ] `make ci` passes

#### 12.2a — File Plan

```
Modified:
  lib/features/workouts/providers/notifiers/active_workout_notifier.dart  — fillRemainingSets adds isCompleted: true
  lib/features/workouts/ui/active_workout_screen.dart                     — invalidate count/PR providers after save
  lib/features/profile/ui/profile_screen.dart                             — add navigation to stat cards
  lib/features/weekly_plan/ui/widgets/week_bucket_section.dart            — all chips tappable + edit icon in header
  lib/features/weekly_plan/ui/plan_management_screen.dart                 — inline soft-cap text
  lib/features/workouts/ui/widgets/set_row.dart                           — verify/fix Last: display

Tests:
  test/unit/features/workouts/providers/active_workout_notifier_test.dart  — update fillRemaining test
  test/widget/ (new)                                                       — stat card navigation, chip tappability
```

---

### 12.2b: Home Screen Redesign

**Goal:** Transform home from a generic dashboard into a gym-floor action screen. One-handed, glanceable, answers "what do I do today?" in 2 seconds.

#### Layout (top to bottom)

1. **Header** — Date ("WED, APR 9") + user display name. Remove large "GymBuddy" title (wasted prime real estate — user knows what app they opened).

2. **THIS WEEK section (hero)** — Full visual weight, always above the fold.
   - Section title "THIS WEEK" with progress counter ("2 of 4") as secondary metadata BELOW title (not competing with SuggestedNextPill in same Row).
   - Chip row: increase `next` chip to 60dp (add exercise count as secondary line: "Push Day / 6 exercises"), `remaining` to 48dp, `done` stays 44dp.
   - "Edit" icon visible in section header.
   - Empty state: full-width bordered container at 72dp min-height with centered text + icon. Not a dim line of text.

3. **Contextual stat cells** — 2 horizontal cells replacing current stat cards:
   - **Last session:** "3 days ago — Push Day" (tap → workout history)
   - **This week's volume:** "12,400 kg this week" (tap → history filtered to week)
   - NOT lifetime workout count or PR count (those live on Profile).

4. **Start Empty Workout** — `FilledButton` (not `OutlinedButton`), full-width, always visible without scrolling.

5. **Routines list** — REMOVE entirely when user has an active weekly plan. Keep "Create Your First Routine" CTA only for `userRoutines.isEmpty && defaultRoutines.isEmpty` (onboarding state).

#### What NOT to do
- No gradient overlays on chips/cards
- No progress bars inside stat cards
- No muscle group tags on chips (belongs in routine detail)
- No animated confetti beyond existing WeekReviewSection
- No streak counter until Phase 15 (broken streaks demoralize)

#### 12.2b — Acceptance Criteria

- [ ] Home shows date + name header (no large app title)
- [ ] THIS WEEK is the hero section, above stat cells
- [ ] Progress counter separated from SuggestedNextPill (different rows)
- [ ] Chip sizes: next=60dp, remaining=48dp, done=44dp
- [ ] Next chip shows exercise count as secondary line
- [ ] Empty plan state is a 72dp+ tappable container
- [ ] Contextual stats replace lifetime stats (last session + week volume)
- [ ] Week volume requires new query/RPC (sum of weight*reps this week)
- [ ] Routines list hidden when active plan exists
- [ ] Start Empty Workout is FilledButton, visible without scrolling
- [ ] `make ci` passes, E2E smoke tests updated if selectors changed

#### 12.2b — File Plan

```
Modified:
  lib/features/workouts/ui/home_screen.dart                    — restructure layout, remove routines list, new stat cells
  lib/features/weekly_plan/ui/widgets/week_bucket_section.dart  — header layout, empty state redesign, progress counter placement
  lib/features/weekly_plan/ui/widgets/routine_chip.dart         — chip size increases, exercise count on next chip
  lib/features/workouts/providers/workout_history_providers.dart — new provider: weekVolumeProvider (sum weight*reps this week)

New:
  lib/features/workouts/ui/widgets/contextual_stat_cell.dart    — reusable stat cell widget (last session, week volume)

Tests:
  test/widget/features/workouts/ui/home_screen_test.dart        — verify new layout, conditional routines list
  test/e2e/smoke/ (update selectors if needed)
```

---

### 12.2c: Plan Management UX Polish (DONE — PR #38)

- Auto-fill `OutlinedButton` (`Icons.repeat`) in empty plan state + loading guard
- Inline "X/Y routines planned" / "X/Y goal reached" counter below Add Routine row (alpha 0.55 for WCAG AA)
- `SuggestedNextCard` replaces pill — full-width 56dp card, green left border, play_arrow icon, "Up next" label
- `_ConfirmBanner` color constants unified with sibling classes
- 852 tests (15 new widget tests + 3 edge cases)

---

## Step 12.3: UX Polish & Content Expansion

> Findings from manual exploratory QA on device (2026-04-09). Prioritized by PO, root-caused by QA, design direction from UX.

### 12.3a: P0 Bug Fixes — Back Navigation + Home Screen Flicker (DONE — PR #39)

- **Bug 1 (back nav):** PopScope moved to top-level `ActiveWorkoutScreen.build()`, covers loading + active states. `_showDiscardDialog` extracted to ConsumerWidget level.
- **Bug 2 (home flicker):** `WeekBucketSection` shows stale data during provider reload via `hasValue` guard. `hasActivePlan` uses `planAsync.hasValue` to retain state during loading.
- **6 new widget tests** (858 total). Key files: `active_workout_screen.dart`, `week_bucket_section.dart`, `home_screen.dart`.
- **Lesson:** `context.go()` → `context.push()` breaks Flutter web reload in GoRouter 13.x. `PopScope(canPop: false)` is sufficient for back button. See `tasks/lessons.md`.

---

### 12.3b: Copy Fix + Content Expansion (DONE — PR #40)

- **Copy fix**: "goal reached" → "planned — ready to go" / "planned this week" in `plan_management_screen.dart`
- **31 new exercises** across 7 muscle groups including new `cardio` category (migration 00013 + 00014). Total ~92 exercises.
- **5 new routine templates**: Upper/Lower Upper, Upper/Lower Lower, 5×5 Strength, Full Body Beginner, Arms & Abs
- **Preset action sheet**: Default routines show Start + Duplicate and Edit (no Edit/Delete). `duplicateRoutine()` added to notifier.
- **871 tests** (13 new). Lesson: PG `ALTER TYPE ADD VALUE` must be in a separate transaction from INSERTs using the new value.

---

### 12.3c: Standalone Routine → Plan Prompt (DONE — PR #41)

- **Post-workout prompt**: Bottom sheet "X isn't in your plan yet. Add it?" with Add/Skip. Shown after PR celebration (or directly) when routine not in plan.
- **`addRoutineToPlan`** method on `WeeklyPlanNotifier` with idempotency guard + error handling.
- **PR celebration integration**: Prompt data passed via route extras; shown on Continue tap.
- **885 tests** (13 new). Routine name looked up from provider (immutable) instead of mutable workout name.

---

### Stale Workout Timeout (Deferred to Phase 13)

Not auto-discard. When app opens and `startedAt` is >6 hours ago, show prominent modal: "Your workout from [date] is still open — Resume or Discard?" Already handled partially by `ResumeWorkoutDialog`. Enhancement goes into Phase 13 production readiness.

### Execution Order

| Sub-step | Dependencies | Effort |
|----------|-------------|--------|
| 12.3a (P0 bugs) | None | 0.5 session |
| 12.3b (copy + content) | None (can parallel with 12.3a) | 1 session |
| 12.3c (plan prompt) | 12.3a (needs stable back nav) | 0.5 session |

---

## Phase 13: Production Readiness

> Adapted from PROD-READINESS.md. Everything needed to ship on Google Play.
> Updated 2026-04-09 with PO + UX review findings after Step 12.3 completion.

### 13a: Store Blockers (must fix before submission)

| ID | Item | Effort | Notes |
|----|------|--------|-------|
| ~~B1~~ | ~~Release signing~~ | DONE (#43) | `build.gradle.kts` reads `key.properties` via `rootProject.file()`, signs release with configured keystore, falls back to debug when absent. `key.properties.example` template + `.gitignore` covers `*.jks`/`*.keystore`/`*.p12`. User generates keystore post-merge. |
| ~~B2~~ | ~~Crash reporting~~ | DONE (#46) | `sentry_flutter 9.16.1` wired via `runZonedGuarded` + `SentryFlutter.init` in `main.dart`. Empty-DSN skips init (dev/test safe). Strict PII scrubbing: `sendDefaultPii: false`, `tracesSampleRate: 0.0`, `beforeSend` sets `SentryUser(id: ...)` only + `scrubEventPii()` walks message/exception/stack frame contextLine for emails, `beforeBreadcrumb` drops any crumb whose data values contain `@`. `BaseRepository.mapException` captures unexpected errors. `SentryNavigatorObserver` wired into GoRouter with UUID → `:id` sanitizer. Auth + workout-lifecycle breadcrumbs (transition name + workout_id only, no weights/notes). Profile → Privacy → "Send crash reports" toggle (defaults ON, Hive-backed via `crashReportsEnabledProvider`) gates `SentryReport`; flipping OFF clears breadcrumbs. 22 new unit tests covering the scrubbers and opt-out. |
| ~~B3~~ | ~~Analytics (basic events)~~ | DONE (#46) | First-party `public.analytics_events` table (migration `20260410_analytics_events.sql`) — `(id, user_id fk auth.users cascade, name, props jsonb, platform, app_version, created_at)`, RLS insert-own-only, no SELECT policy. Thin `AnalyticsRepository` (fire-and-forget, swallows errors via `unawaited`). Typed Freezed union `AnalyticsEvent` — **8 ratified events** wired at call sites: `onboarding_completed`, `workout_started`, `workout_discarded`, `workout_finished`, `pr_celebration_seen`, `week_plan_saved` (debounced to one event per edit session, flushed on dispose), `week_complete` (fires on `!wasAllComplete && isNowAllComplete`), `add_to_plan_prompt_responded`. `week_number` computed client-side via `computeWeekNumberSinceSignup` (null createdAt → event SKIPPED). Deferred `account_deleted` event → dedicated `public.account_deletion_events` audit table, written by `delete-user` Edge Function **before** the CASCADE DELETE (CASCADE-safe, anonymous `user_uuid` text column, no FK). 9th event `workout_started.had_active_workout_conflict` prop deferred pending follow-up PR. Privacy policy (`assets/legal/` + `docs/`) updated with Sentry + analytics disclosure. |
| ~~B4~~ | ~~Privacy Policy & ToS~~ | DONE (#43) | `assets/legal/privacy_policy.md` + `terms_of_service.md` rendered in-app via `flutter_markdown_plus`, mirrored to `docs/` for GitHub Pages at `https://caiolacerda88.github.io/gymbuddy-app/`. New `/privacy-policy` + `/terms-of-service` routes (public-route allowlist). Linked from Profile LEGAL section + login footer. User must enable Pages + review draft text post-merge. |
| ~~B5~~ | ~~Account deletion~~ | DONE (#42) | Edge Function `delete-user` + AuthRepository.deleteAccount + Manage Data UI with type-DELETE confirmation. Cascade via existing FKs. |
| B6 | ProGuard/R8 optimization | 2-3h | No minify/shrink today (19.7MB → ~12-14MB). Need keep rules for Supabase + Hive reflection |
| ~~B7~~ | ~~Offline workout save & retry~~ | ~~1-2 days~~ | **Superseded by Phase 14 (Offline Support).** Original scope was sync-worker only; Phase 14 is broader (read cache, sync service, PR reconciliation, UX indicators). |

### 13b: Product Gaps (blocks retention, not submission)

| ID | Item | Effort | Notes |
|----|------|--------|-------|
| P1 | Progress charts per exercise | 2-3 days | **#1 retention driver.** Line chart: weight over time. `fl_chart` or `syncfusion_flutter_charts`. Query sets+workouts by exercise_id. Without this, no "am I getting stronger?" feedback loop. |
| P2 | Exercise library expansion to 150+ | 1 day | Currently ~92. Users lose confidence when searches return 2-3 results. Priority: compound movements, isolation staples, sport-specific |
| ~~P3~~ | ~~Forgot password flow~~ | ~~done~~ | ~~Already implemented in `login_screen.dart:92-115`~~ |
| P4 | Exercise images fix (QA-005) | 3-4h | GitHub URLs return 404. Migrate to Supabase Storage or CDN. Broken images signal abandoned product. |
| P5 | 1RM estimation | 2-3h | Epley formula. Display on exercise detail + PR cards |
| P6 | App branding | DONE (#43) | Strings done: AndroidManifest label, `web/manifest.json`, `web/index.html` → "GymBuddy". **Icon DEFERRED to post-gamification phase** — pixel-RPG-meets-gym direction will be revisited then. |
| ~~P7~~ | ~~Volume unit display~~ | DONE (#42) | `formatVolume()` takes weightUnit; threaded through home_screen + workout_detail_screen (per-set rows + totals). |
| P8 | New-user empty-state CTA | 2-3h | When no workouts logged and no plan: show "Start your first workout" hero + beginner routine recommendation on home screen. Currently drops user at empty state with no guidance. **(PO finding)** |

### 13c: UX Polish & Athletic Brutalism Redesign (pre-launch quality bar)

#### Part 1: UX Polish (UX1-UX8)

> From UX review 2026-04-09. Must-fix items affect store screenshots and first impressions.

| ID | Item | Effort | Notes |
|----|------|--------|-------|
| UX1 | Routine card: add overflow `...` button | 1-2h | Long-press is sole entry point for Edit/Delete/Start — zero affordance. Fails sweat-proof principle. Add 48dp `...` icon button. |
| UX2 | PR celebration: pin Continue button | 30min | Scrolls off-screen with 3+ PRs. Move to `bottomNavigationBar` or pinned Column. |
| UX3 | Plan prompt: full-width stacked buttons | 30min | Current right-aligned Row is unreachable one-handed. Stack vertically: FilledButton("Add") + TextButton("Skip"), both full-width. |
| UX4 | Hardcoded colors → theme refs | 1-2h | `week_bucket_section.dart`, `plan_management_screen.dart`, `routine_chip.dart`, `week_review_section.dart` use hardcoded `#00E676` and `#232340`. Replace with `colorScheme.primary` / `cardTheme.color`. |
| UX5 | Demote "Start Empty Workout" when plan exists | 30min | When user has active plan with suggested next, demote to `OutlinedButton`. Elevate `_SuggestedNextCard` as primary CTA. |
| UX6 | Surface Auto-fill in plan management | 30min | Add visible "Auto-fill" `TextButton` below list header. Keep Clear in overflow (destructive). |
| UX7 | Exercise picker: filter chip counts | 1h | Add result counts: "Chest (14)". Improves picker efficiency. |
| UX8 | Routine card subtitle: exercise count over muscle list | 30min | "6 exercises · ~45 min" instead of overflowing "Chest · Back · Legs · Shoulders · Arms". |

#### Part 2: Athletic Brutalism Redesign

> Canonical spec: `tasks/ab-redesign-spec-2026-04-11.md` (532 lines).
> Synthesized 2026-04-11 from: Phase A ui-ux-critic audit (`tasks/ui-audit-2026-04-11.md`), Phase B product-owner review, Phase C tech-lead feasibility review.
> Where inputs conflict: PO overrides audit on scope; tech-lead overrides audit on implementation approach and effort.

##### 1. Goal

Athletic Brutalism is a complete visual identity change for GymBuddy -- not a polish pass. The aim is to make GymBuddy immediately, viscerally distinct from every other fitness app on the store. Strong, Hevy, and Fitbod are all clean and utilitarian; Strava is social-editorial; Fitbod uses ML-gym gradients. None of them are *brutal*. GymBuddy will look like it was designed by a powerlifter, not a design agency: heavy condensed type, maximum data density, a single violent signal color, hard rectangular edges, noise grain atmosphere, and zero decorative chrome. The single most impactful user-facing change is the 32sp JetBrains Mono weight and rep values in the set logger -- the numbers that are the entire reason the app exists, rendered as the heroes they are. Athletic Brutalism is a foundation layer, not an endpoint: the sparse industrial palette deliberately leaves room for Phase 15 gamification elements (XP bars, level badges) to pop as bright, saturated contrast against the dark concrete environment.

##### 2. Why Now / Sequencing Preconditions

The delivery order is non-negotiable. Each gate exists for a concrete reason.

```
PR7 (CI Android build gap)
  -> PR6 (bulk dependency upgrade)
    -> Sprint B retention work: UX1-UX8 (existing Part 1 items)
      -> AB-PR1 (Foundation -- after PR6 lands)
        -> AB-PR2, AB-PR3, AB-PR4 (parallel, after AB-PR1 lands)
          -> AB-PR5 (Polish -- after AB-PR2, AB-PR3, AB-PR4 land)
```

**PR7 first.** The CI Android build gap must be closed before any further feature work. AB-PR1 touches `pubspec.yaml` (font assets) and `app_theme.dart` (entire color scheme); running it against a broken CI baseline makes failures ambiguous.

**PR6 before AB-PR1.** PR6 is the bulk dependency upgrade. It rewrites `pubspec.yaml` and touches `app_theme.dart`. AB-PR1 also modifies both files extensively (font bundle, new `ColorScheme`, deleted gradient getters). Running them in parallel guarantees a merge conflict. AB-PR1 must branch from the post-PR6 `main`.

**Sprint B retention work (UX1-UX8) before any AB-PR.** The 70% 90-day churn problem is the top product priority. P1 charts, P2 content, P4 images, and P8 empty states are the retention fixes. Athletic Brutalism is a polish layer on top of the retention fixes, not a substitute. Shipping AB before UX1-UX8 would mean the retention work lands on top of a partially-redesigned system, creating integration turbulence. UX1-UX8 must be complete and merged first.

**AB-PR1 before AB-PR2/3/4.** AB-PR1 ships all design primitives (tokens, typography, new shared widgets, golden baselines, hard-cut transition helper). Feature PRs are consumers of those primitives and must not redefine them independently. Running AB-PR2/3/4 before AB-PR1 lands results in three PRs each defining their own version of `EdgeAccentCard` and fighting over `app_theme.dart`.

**AB-PR2/3/4 parallel.** Once AB-PR1 is merged, the three feature PRs touch disjoint screen groups (active workout / celebration+summary / info surfaces). No shared file writes; they can be developed and reviewed concurrently.

**AB-PR5 last.** Store screenshots require the full visual system to be merged and stable. Final animation tuning and reduced-motion QA require all screens to be in their final state. AB-PR5 is the integration and publication step.

##### 3. Aesthetic Direction

**Typography**

Two custom fonts replace the current system default (Roboto).

**Display / headline: Barlow Condensed (Bold 700 + Black 900)**
Athletic condensed sans-serif used in sport signage and athletics branding. Not Inter, not Roboto, not Space Grotesk. Applied to screen titles, section headers, and any text that functions as a moment (workout name, "NEW PR", rest timer controls).

**Numeric / monospace: JetBrains Mono (Regular 400 + Bold 700)**
Monospace for ALL numeric data: set weights, reps, volume totals, elapsed time, rest countdown. Monospace prevents digit-width jitter as values change (e.g., `100.0 kg` to `102.5 kg`). `FontFeature.tabularFigures()` is mandatory on every numeric `TextStyle` (see Section 5).

**Type scale:**

| Role | Font | Size | Weight | Usage |
|---|---|---|---|---|
| Display | Barlow Condensed | 72sp | Black (900) | Rest timer countdown |
| Headline XL | Barlow Condensed | 48sp | Black (900) | "NEW PR" |
| Headline | Barlow Condensed | 32sp | Bold (700) | Screen titles, exercise names |
| Title | Barlow Condensed | 20sp | SemiBold (600) | Card headers, routine names |
| Numeric display | JetBrains Mono | 32-48sp | Bold (700) | Set logger weight and rep values, PR numbers |
| Numeric body | JetBrains Mono | 16sp | Regular (400) | Elapsed timer, volume totals, set numbers |
| Body | System sans | 14-16sp | Regular (400) | Supporting text, hints, labels |
| Label / caption | System sans | 11-12sp | Medium (500) | Metadata, secondary info |

**Latin-only constraint.** Barlow Condensed has limited glyph coverage. If/when GymBuddy localizes to non-Latin scripts (CJK, Arabic, Cyrillic), the display font must change. This is a known future cost captured here so it is not a surprise at localization time.

**Color Palette**

Dark mode only in v1 of this redesign. The current navy-blue background (`#1A1A2E`) is replaced with near-black without blue tint.

| Token | Hex | Intention |
|---|---|---|
| `background` | `#0D0D0D` | Near-black. Concrete. No blue tint. |
| `surface` | `#161616` | Raised surface. Slightly lifted. |
| `surfaceVariant` | `#222222` | Card container. Dense but distinct. |
| `primary` | `#E8FF00` | Acid yellow-green. Signal color. High-visibility vest energy. |
| `onPrimary` | `#000000` | Black on acid yellow. WCAG AAA (~15:1 to 18:1). |
| `secondary` | `#FFFFFF` | White as secondary. Not blue, not teal. Stark. |
| `onSecondary` | `#000000` | |
| `tertiary` | `#FF3D00` | Deep orange-red for destructive / danger signals only. |
| `onTertiary` | `#FFFFFF` | |
| `error` | `#FF3D00` | Same as tertiary. |
| `onSurface` | `#F0F0F0` | Off-white body text. Not pure white. |
| `outline` | `#383838` | Borders. Visible but not loud. |
| `outlineVariant` | `#282828` | Subtle dividers. |

**Signal color discipline.** `#E8FF00` appears ONLY in: (1) the currently active / suggested element, (2) PR celebration screen, (3) the single primary CTA per screen. Everywhere else is white-on-black. The color is a signal precisely because it is rare.

**Spatial System**

**8pt rigid grid.** All spacing values: 4 / 8 / 16 / 24 / 32 / 48 dp. No inline arbitrary numbers. Constants defined in `lib/core/theme/app_spacing.dart`.

**Radius.** Zero radius on all structural containers: exercise cards, history rows, PR celebration container, section headers, rest timer overlay. Interactive chips retain small radius (8dp) for affordance perception. `CardThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero))` in the theme.

**Left-edge accent lines.** Replace Material card elevation as the primary hierarchy signal. Each exercise card: 3dp left border in `primary` when exercise has a completed set, `outline` otherwise. History rows use no left border (they are ledger rows, not active items).

**Section headers as full-width rules.** "MY ROUTINES", "THIS WEEK" etc. become a full-width `Divider` with the label inset to the left. Not floating text above a list.

**Data density.** Set logger shows all sets without scroll. Set row: 52dp tall. Exercise card: no internal padding beyond 12dp horizontal. Numbers get the space.

**Motion Language**

**Hard cuts everywhere.** Navigation between screens: `transitionDuration: Duration.zero`. No slide, no fade, no shared-element. Implemented via a `goPage<T>()` helper returning `CustomTransitionPage` with zero duration, gated behind `const bool kHardCutTransitions = true` for QA A/B.

**State-change animations only (no decoration):**
- Set completion: `AnimatedContainer` sweeps the set row background from transparent to `primary.withOpacity(0.08)` left-to-right over 200ms `Curves.easeOut`. Simultaneous `HapticFeedback.mediumImpact()`.
- Button disabled to enabled: `AnimatedOpacity` 200ms.
- Weekly plan progress counter: `TweenAnimationBuilder<int>` counting up over 300ms on workout complete.
- Routine chip completion: `AnimatedSwitcher` 200ms `FadeTransition` (not scale) on the icon change.

**PR celebration exception -- the only cinematic screen:**
- Entry: 60ms black flash (`ColoredBox(color: Colors.black)`) fading out, then instant content reveal.
- "NEW PR" text: immediate presence, word-level opacity stagger via `StaggeredTextReveal`. ~200ms total.
- PR value: `CountUpText` counts up from 0 to final over 800ms `Curves.easeOut`, then spring-settle overshoot (2% above, corrects back). Single `HapticFeedback.heavyImpact()` at lock-in.
- No `elasticOut` bounce. No scale wobble. Scoreboard energy -- final.

**Reduced motion.** Every animation above must check `MediaQuery.of(context).disableAnimations`. When true: show final state immediately, no intermediate animation, haptic feedback still fires.

**Atmosphere**

**Noise grain.** A 64x64 pre-made PNG asset (`assets/textures/noise_64.png`, ~4 KB) tiled across the scaffold background via `BoxDecoration` with `DecorationImage`, `ImageRepeat.repeat`, `opacity: 0.04`. Do not use `ShaderMask` (see Section 5, Rule 2).

**PR celebration background.** The only screen that departs from `#0D0D0D`. A full-bleed `Image.asset('assets/textures/halftone_bg.png')` with `BlendMode.multiply` at 4% opacity. Pre-rasterized PNG (~30 KB). Do not use a live `CustomPainter` (see Section 5, Rule 3).

##### 4. PR-by-PR Breakdown

###### AB-PR1 -- Foundation

**Scope.** All design primitives, tokens, and shared widgets. No feature screen changes. After AB-PR1 merges, every feature screen inherits the new ColorScheme automatically. Feature PRs only consume the new primitives -- they do not re-create them.

**Files created:**
- lib/core/theme/app_text_styles.dart -- Barlow Condensed display + JetBrains Mono numeric TextStyle constants. FontFeature.tabularFigures() baked into every numeric style.
- lib/core/theme/app_spacing.dart -- rigid 4/8/16/24/32/48 dp scale constants.
- lib/shared/widgets/set_completion_button.dart -- custom completion control: 48x48+ touch target, outline border unfilled to primary filled on completion, left-to-right sweep animation, Semantics label Mark set as done preserved verbatim.
- lib/shared/widgets/edge_accent_card.dart -- rectangular container with configurable left-border accent, zero radius, Semantics wrapper.
- lib/shared/widgets/section_rule.dart -- full-width Divider with inset text label, Semantics wrapper.
- lib/shared/widgets/staggered_text_reveal.dart -- word-level opacity stagger animation, Semantics label on outer container exposes full text immediately, reduced-motion branch shows text at opacity 1.0.
- lib/shared/widgets/count_up_text.dart -- TweenAnimationBuilder<double> counting to target value, FontFeature.tabularFigures(), Semantics label shows final value (not intermediate), reduced-motion branch shows final value immediately.
- assets/textures/noise_64.png (~4 KB, pre-made tiled noise).
- assets/textures/halftone_bg.png (~30 KB, pre-rasterized halftone).
- assets/fonts/BarlowCondensed-Bold.ttf
- assets/fonts/BarlowCondensed-Black.ttf
- assets/fonts/BarlowCondensed-SemiBold.ttf
- assets/fonts/JetBrainsMono-Regular.ttf
- assets/fonts/JetBrainsMono-Bold.ttf
- assets/fonts/OFL.txt (combined OFL license for both font families)
- test/widget/goldens/ -- golden baseline PNGs for 12 screens (see Section 9).

**Files modified:**
- pubspec.yaml -- add fonts: block declaring all 5 TTF files.
- lib/main.dart -- GoogleFonts.config.allowRuntimeFetching = false; at startup. Register OFL licenses via LicenseRegistry.addLicense() for both font families.
- lib/core/theme/app_theme.dart -- replace entire ColorScheme.dark with Athletic Brutalism palette. Delete primaryGradient and destructiveGradient static getters. Set CardThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero)). Reference new app_text_styles.dart tokens in TextTheme.
- lib/core/routes/ (all GoRoute definitions) -- wrap every route in goPage<T>() helper returning CustomTransitionPage with transitionDuration: Duration.zero. Gate behind const bool kHardCutTransitions = true.

**Files deleted:**
- lib/shared/widgets/gradient_button.dart -- deleted entirely.

**Effort estimate:** 30-40 agent-hours.

**Dependencies:** PR7 (CI fix), PR6 (bulk dep upgrade), and Sprint B UX1-UX8 all merged first.

**Acceptance criteria:**
- make ci passes green (format + analyze + test + goldens all pass).
- app_theme.dart contains zero gradient definitions.
- gradient_button.dart does not exist.
- pubspec.yaml fonts: block declares all 5 TTF files.
- main.dart sets allowRuntimeFetching = false and registers OFL licenses.
- Every new shared widget has a Semantics wrapper with a meaningful label.
- Every new animation widget has a MediaQuery.of(context).disableAnimations branch.
- 12 golden baselines generated and committed.
- goPage<T>() helper exists and applied to all GoRoute definitions.
- FontFeature.tabularFigures() present in every numeric TextStyle in app_text_styles.dart.

**Golden test targets:** All 12 screens listed in Section 9.

###### AB-PR2 -- Core Loop (Active Workout)

**Scope.** Active workout screen (active_workout_screen.dart + set_row.dart) and rest timer overlay (rest_timer_overlay.dart). Highest-traffic surfaces and biggest visible payoff. These two files share the same user session and are developed together to reduce coordination overhead.

**Files modified:**
- lib/features/workouts/ui/active_workout_screen.dart
  - _ExerciseCard: borderRadius: 0, left-border 3dp via EdgeAccentCard (primary when any set completed, outline otherwise).
  - AppBar: workout name at Barlow Condensed Bold 24sp, left-aligned. Elapsed timer moved to AppBar subtitle at JetBrains Mono 14sp.
  - _ExerciseCard header row: remove Icons.info_outline. Consolidate swap + delete behind an overflow IconButton.
  - Finish Workout FilledButton: Barlow Condensed Bold 20sp all-caps, full-width, 56dp minimum height.
  - Complete at least one set guard: replace bodySmall muted text with a warning chip or inline badge.
  - Vertical card gap: increase to 12-16dp.
  - Hardcoded Colors.black54 modal barrier replaced with theme token.
- lib/features/workouts/ui/widgets/set_row.dart
  - Weight and reps values: JetBrains Mono Bold 32sp (from app_text_styles.dart numeric display style). This is the single biggest visual change in the app.
  - Replace Checkbox with SetCompletionButton. Existing Semantics(label: Mark set as done) label preserved verbatim.
  - Set number badge: remove 9sp label. Replace with JetBrains Mono 14sp number + 1dp left-border color-coded by set type (primary / secondary / tertiary / error).
- lib/features/workouts/ui/widgets/rest_timer_overlay.dart
  - Background: Colors.black (not Colors.black87).
  - Remove CircularProgressIndicator entirely.
  - Full-bleed centered countdown: JetBrains Mono Black 120sp. Each decrement fades in over 80ms -- discrete flip, not smooth counter. MediaQuery.disableAnimations branch: instant value update.
  - Thin ambient progress bar: 4dp LinearProgressIndicator or custom CustomPaint rect, bottom of screen, draining right-to-left.
  - -30s, +30s, Skip buttons: OutlinedButton with RoundedRectangleBorder(borderRadius: BorderRadius.zero), full width, 56dp tall, Barlow Condensed Bold all-caps text.
  - Delete Tap anywhere to dismiss text.
  - Dismiss: swipe-down gesture or explicit button only. Full-screen tap dismiss removed (caused accidental dismissal).
  - Hardcoded Colors.white12 on adjustment buttons replaced with colorScheme.onSurface.withOpacity(0.12).

**Files created:** None. All new primitives shipped in AB-PR1.

**Effort estimate:** 22-28 agent-hours. set_row.dart is 401 LOC; completion button swap + 32sp metric + left-border + badge format touches ~150 LOC. Rest timer rewrite is a comparable surface.

**Dependencies:** AB-PR1 merged.

**Acceptance criteria:**
- Weight and rep values render at 32sp JetBrains Mono Bold -- verified in widget test with findsOneWidget on the specific TextStyle.
- SetCompletionButton used in place of Checkbox in every SetRow.
- Semantics label Mark set as done present and unchanged -- verified with find.bySemanticsLabel.
- Rest timer shows no CircularProgressIndicator -- widget test asserts findsNothing.
- Dismiss requires swipe-down, not full-screen tap -- widget test asserts center-screen tap does not dismiss.
- All hardcoded colors removed (make analyze passes).
- Reduced-motion: row completion sweep is instant, timer flip is instant when disableAnimations is true.
- Golden tests for active workout screen and rest timer overlay updated and passing.
- E2E selectors updated in test/e2e/selectors.ts (countdown is now a Text widget, not CircularProgressIndicator).

**Golden test targets:** Active workout screen (mid-workout state, 2 sets completed), rest timer overlay (45 seconds remaining).

###### AB-PR3 -- Celebration and Completion

**Scope.** PR celebration screen, workout summary, workout complete flow.

**Files modified:**
- lib/features/personal_records/ui/pr_celebration_screen.dart
  - Background: #0D0D0D with full-bleed Image.asset(assets/textures/halftone_bg.png) at BlendMode.multiply, opacity 0.04. (Asset shipped in AB-PR1.)
  - Remove Icons.emoji_events entirely.
  - NEW PR text: StaggeredTextReveal widget, Barlow Condensed Black 48sp. No scale animation on entry.
  - PR value: CountUpText widget, JetBrains Mono Bold 32-48sp. Counts up from 0 to final over 800ms, spring-settle at lock-in. HapticFeedback.heavyImpact() at lock-in.
  - Exercise name: Barlow Condensed SemiBold 24sp. No Card wrapper.
  - Record type label: all-caps labelLarge.
  - All _AnimatedRecordCard / Card widgets deleted. Records displayed as Divider-separated horizontal rows, zero border radius.
  - Continue FilledButton: full-width, 56dp, Barlow Condensed Bold all-caps CONTINUE.
  - Green flash overlay: initial opacity 1.0, fade duration 800ms.
  - Screen entry: PageRouteBuilder 60ms black flash then instant content reveal.
  - Scope cut (PO-mandated): No halftone CustomPainter. No per-character stagger animation. The count-up number, scoreboard layout, spring-settle haptic, and full-width CTA are retained.
- Workout summary and workout complete screens: zero radius containers, Barlow Condensed titles, FilledButton CTAs.

**Files created:** None.

**Effort estimate:** 18-24 agent-hours.

**Dependencies:** AB-PR1 merged.

**Acceptance criteria:**
- Icons.emoji_events does not appear on the PR celebration screen -- widget test asserts findsNothing.
- No Card widget in the PR records list area -- widget test asserts findsNothing.
- CountUpText widget present with correct final value.
- StaggeredTextReveal widget present for NEW PR text.
- Continue button is a FilledButton, full-width, minimum 56dp.
- Reduced-motion: CountUpText shows final value immediately; StaggeredTextReveal shows full text immediately; flash is skipped.
- Semantics label on CountUpText shows final value, not intermediate.
- Golden test for PR celebration screen updated and passing.

**Golden test targets:** PR celebration screen (PR path, one record), workout summary screen.

###### AB-PR4 -- Information Surfaces

**Scope.** Home screen, Workout History screen, Exercise List screen, Weekly Plan / WeekBucketSection.

**Files modified:**
- lib/features/workouts/ui/home_screen.dart
  - Remove primaryGradient from _CreateRoutineCta. Replace with hard-edged FilledButton, full-width.
  - Pin Start Workout as a persistent bottom bar: SafeArea + Padding + FilledButton 56dp, always visible regardless of scroll.
  - User greeting: Barlow Condensed Bold 32sp.
  - Date line: labelLarge or removed (low information value).
  - _SuggestedNextCard left-border accent: thickened to 4dp, hardcoded colors replaced with theme tokens.
  - RoutineCard: borderRadius: 0. Replace play-icon circle with left-border active state via EdgeAccentCard.
  - WeekBucketSection edit icon: padded to 48x48 minimum.
  - Icons.play_arrow_rounded removed.
- lib/features/workouts/ui/workout_history_screen.dart
  - Remove Card wrapper from _WorkoutHistoryCard. Replace with horizontal ruled row: top Divider as separator.
  - Group workouts by week: section header format APR 7 - 13 in Barlow Condensed Bold 16sp + full-width SectionRule.
  - Date: left-anchored labelLarge (not right-aligned muted metadata).
  - Remove chevron icon.
  - Duration: JetBrains Mono Regular 13sp.
  - Exercise summary: bodySmall, opacity 0.7 (up from 0.5).
  - AppBar: HISTORY Barlow Condensed Bold 28sp.
  - Empty state: delete Icons.history. Barlow Condensed Bold 32sp typographic treatment.
- lib/features/exercises/ui/exercise_list_screen.dart
  - FAB gradient removed. FloatingActionButton with colorScheme.primary fill.
  - _ExerciseCard: borderRadius: 0. Left-border 3dp in outline color.
  - Equipment filter: collapse behind FILTER OutlinedButton unless active.
  - Muscle group selector buttons: zero border-radius on selected state container.
  - Empty state: delete Icons.fitness_center. Barlow Condensed Bold 32sp typographic treatment.
- lib/features/weekly_plan/ui/widgets/week_bucket_section.dart
  - _SuggestedNextCard left-border thickened to 4dp. Hardcoded hex colors replaced with theme tokens.
  - WeekBucketSection edit icon: padded to 48x48.
  - _ConfirmBanner border color via theme token.
  - Section header THIS WEEK: full-width SectionRule.
- lib/features/weekly_plan/ui/widgets/routine_chip.dart
  - All 10 hardcoded color occurrences replaced with theme tokens.
- lib/features/weekly_plan/ui/plan_management_screen.dart
  - _RoutineRow sequence circle: replace with square (BoxDecoration(shape: BoxShape.rectangle), 24x24, zero radius). Sequence number in JetBrains Mono Bold.
  - _AddRoutineRow dashed border: solid 1dp outline color, zero radius.
  - Empty state: delete Icons.calendar_today. Barlow Condensed Bold 32sp typographic treatment.
  - Chip horizontal scroll: fade-edge affordance (partial reveal of next chip).

**Note on UX4 overlap.** UX4 (hardcoded colors to theme refs) is substantially absorbed by AB-PR4 (and partially by AB-PR1). If UX4 has not shipped by the time AB-PR4 opens, its remaining work is folded into AB-PR4 rather than creating a separate PR.

**Effort estimate:** 22-30 agent-hours.

**Dependencies:** AB-PR1 merged.

**Acceptance criteria:**
- home_screen.dart contains zero gradient references.
- Start Workout FilledButton is always visible regardless of scroll position.
- workout_history_screen.dart contains no Card widget in the history list area.
- History rows are grouped by week.
- exercise_list_screen.dart contains no Icons.fitness_center.
- routine_chip.dart contains zero Color(0x...) or Colors.* literals.
- WeekBucketSection edit icon has minimum 48dp touch target.
- All empty states use typographic treatment, no icons.
- Golden tests for home, history, exercise list, and weekly plan screens updated and passing.
- E2E regression: workout history navigation tap target updated in test/e2e/selectors.ts.

**Golden test targets:** Home screen (with active weekly plan), Workout History (grouped by week), Exercise List (muscle group filter active), Weekly Plan screen.

###### AB-PR5 -- Polish, Screenshots, Final QA

**Scope.** Store screenshot production, final animation tuning, reduced-motion full-pass QA, onboarding touch-up (if pre-AB1 audit identified issues), cross-PR integration polish.

**Files modified (variable -- depends on onboarding audit findings):**
- lib/features/onboarding/ -- apply consistent Athletic Brutalism treatment if the onboarding audit (Section 8) identified dissonance. Scope determined by audit findings.
- Any screen where cross-PR integration produced visual inconsistency identified during AB-PR5 review.
- Store listing assets directory -- new App Store / Play Store screenshots.

**Store screenshot requirement (PO-mandated).** This PR must produce fresh App Store and Play Store screenshots with the new visual system. Screenshot production is an explicit checklist item in the PR description -- not an afterthought after merge.

**Animation tuning.** Test all animations under physical gym conditions (bright ambient light, 75% screen brightness). If #E8FF00 causes glare fatigue, shift to #D4EB00 (slightly less saturated, still distinctive). Document the final chosen hex in app_theme.dart with a comment.

**Reduced-motion full pass.** With MediaQuery.disableAnimations forced to true, walk through every screen that received animations in AB-PR1 through AB-PR4 and verify: final states show immediately, no intermediate frames, haptic feedback still fires.

**Effort estimate:** 12-18 agent-hours.

**Dependencies:** AB-PR2, AB-PR3, AB-PR4 all merged.

**Acceptance criteria:**
- Fresh App Store (6.5in and 5.5in) and Play Store (phone portrait) screenshots committed and ready for upload.
- Full E2E suite passes.
- make ci green.
- Reduced-motion manual walkthrough completed and documented in PR description.
- No Icons.emoji_events, Icons.fitness_center, Icons.history, Icons.calendar_today remain in any audited screen.
- No primaryGradient or destructiveGradient references anywhere in the codebase.
- gradient_button.dart does not exist.

##### 5. Implementation Rules

These are mandatory constraints. Tech-lead must not deviate from them. Each rule traces to a specific input.

**Rule 1: FontFeature.tabularFigures() on every numeric TextStyle.**
Without tabular figures, digit widths vary and weight values like 100.0 kg to 102.5 kg visibly jitter in the set logger as the number updates. Define tabular figures once in app_text_styles.dart on the monospace and display numeric styles. Do not add it ad hoc at usage sites.

**Rule 2: DecorationImage over ShaderMask for noise texture.**
ShaderMask is approximately 10x more expensive per frame than DecorationImage with ImageRepeat.repeat. At 4% opacity there is zero visual difference. Use:

ShaderMask is forbidden for the noise grain background.

**Rule 3: Pre-rasterized PNG over live CustomPainter for halftone.**
Pre-rasterize the halftone pattern as assets/textures/halftone_bg.png (~30 KB) and render via Image.asset with BlendMode.multiply. A live CustomPainter drawing Canvas.drawCircle at grid positions for every frame is wasteful with no visual benefit at this opacity.

**Rule 4: Reduced-motion branch required in every animated widget.**

Check this flag in: StaggeredTextReveal, CountUpText, rest-timer flip, set completion sweep, AnimatedContainer transitions, hard-cut transition helper. When true: skip to final state immediately. Haptic feedback still fires.

**Rule 5: Semantics wrappers on every new custom widget.**
Every new widget shipped in AB-PR1 and consumed in AB-PR2/3/4 must include a Semantics wrapper in the same commit. No follow-up tickets. Required widgets: SetCompletionButton, EdgeAccentCard, SectionRule, CountUpText, StaggeredTextReveal.

**Rule 6: Preserve existing E2E-visible Semantics labels verbatim.**
The E2E test suite selects elements by semantic labels. Renaming any existing label silently breaks E2E. Specifically: Semantics(label: 'Mark set as done') on the set completion target must keep the exact string. Before modifying any Semantics label, grep test/e2e/selectors.ts to confirm no E2E dependency.

**Rule 7: Bundle fonts as assets, allowRuntimeFetching = false.**
No runtime font fetching. Set GoogleFonts.config.allowRuntimeFetching = false at app startup in main.dart. Declare fonts via the pubspec.yaml fonts: block. Register OFL licenses for both families via LicenseRegistry.addLicense() in main.dart. The OFL.txt file must be committed to assets/fonts/OFL.txt.

**Rule 8: Delete gradient definitions completely.**
lib/shared/widgets/gradient_button.dart is deleted. The primaryGradient and destructiveGradient static getters in app_theme.dart are deleted. Every call site is updated to use colorScheme.primary fill. This is part of AB-PR1. No gradient definition of any kind exists in the codebase after AB-PR1 merges.

**Rule 9: Hard-cut transitions via goPage<T>() helper with feature flag.**
Define a goPage<T>() helper in the routes layer and apply to every GoRoute. This lets QA A/B the transition feel during review without touching individual route definitions. Gate behind const bool kHardCutTransitions = true. When true, transitionDuration is Duration.zero and transitionsBuilder returns the child unchanged.

##### 6. Accessibility and Reduced Motion

**Contrast**

| Pairing | Ratio | WCAG Level |
|---|---|---|
| #E8FF00 on #0D0D0D | ~15:1 to 18:1 | AAA |
| #F0F0F0 on #0D0D0D | ~18:1 | AAA |
| #F0F0F0 on #161616 | ~16:1 | AAA |
| #E8FF00 on #161616 | ~14:1 | AAA |
| #383838 (outline) on #0D0D0D | ~2.5:1 | Decorative only (borders, not text) |

Muted text at 0.55 alpha on the current navy surface may fall below 4.5:1. This is corrected by moving to the new #0D0D0D surface and using #F0F0F0 at full opacity for body text.

**Touch Targets**

All interactive elements: minimum 48dp in both dimensions. Known violations corrected in this phase:
- WeekBucketSection edit icon: 36x36 padded to 48x48 (AB-PR4).
- Rest timer adjustment buttons: SizedBox(width: 64) TextButton to full-width 56dp OutlinedButton (AB-PR2).
- Weight/reps stepper buttons: verify 48dp minimum in AB-PR2.

**Semantics Policy**

Every new custom widget ships with a Semantics wrapper in the same commit. Labels describe the widget function, not its visual appearance. CountUpText exposes the final value in its label so screen readers announce the real number, not a mid-animation intermediate. StaggeredTextReveal exposes the full text immediately in its label regardless of animation state.

**Reduced Motion Policy**

MediaQuery.of(context).disableAnimations is checked at the top of every build() method containing animation logic. When true:
- StaggeredTextReveal: render full text immediately, opacity 1.0, no stagger.
- CountUpText: render final value immediately.
- Rest timer countdown: update value instantly on each decrement.
- Set completion sweep: skip AnimatedContainer transition, show final state.
- Screen transitions: already Duration.zero -- no change needed.
- Haptic feedback: fires regardless of reduced-motion setting.

##### 7. Known Constraints and Risks

**Latin-only Barlow Condensed.** Barlow Condensed has limited glyph coverage -- Latin extended at best. Any future localization to CJK, Arabic, or Cyrillic requires a display font change. Captured here as a known constraint so it is not discovered mid-localization sprint.

**APK size impact from bundled fonts.** Bundling five TTF files adds approximately 400-600 KB to the APK. Acceptable for v1. If Play Store size warnings arise, both font families can be subset to the Latin character range, reducing to ~150 KB combined. Not required for AB-PR1 but documented as an optimization path.

**Merge conflict risk with PR6.** AB-PR1 and PR6 both modify pubspec.yaml and app_theme.dart. The sequencing gate (PR6 merges before AB-PR1 branches) eliminates this risk. If the sequencing is violated, the merge conflict will be significant and require simultaneous resolution of both color scheme and dependency changes.

**E2E selector risk.** The redesign changes visual widget structure on every audited screen. E2E tests relying on widget-type selectors (Card, CircularProgressIndicator, Icons.*) will break. Tests relying on semantic labels and text strings are insulated. Before each AB-PR merges, the QA engineer must run the full E2E smoke suite and update test/e2e/selectors.ts. Known breakage points:
- Rest timer: CircularProgressIndicator selector becomes countdown Text widget.
- Workout history: Card-based tap target becomes row-based tap target.
- PR celebration: Icons.emoji_events becomes absent.

**#E8FF00 glare risk.** The acid yellow-green at full saturation on a bright screen under gym lighting may cause glare fatigue. AB-PR5 must include a physical device test. Fallback: shift to #D4EB00 (slightly less saturated, still distinctive). Document the final choice in app_theme.dart with a comment.

**Zero goldens currently in the repo.** The codebase has no matchesGoldenFile references. AB-PR1 must establish all 12 golden baselines. Golden tests must run in CI on a consistent headless environment to avoid pixel-level variance between developer machines.

##### 8. Pre-AB1 Blocker: Onboarding Audit

Before AB-PR1 opens, dispatch ui-ux-critic for a focused 1-hour audit of lib/features/onboarding/. Onboarding was not included in the 7-screen audit pass. First-run users are the most sensitive to aesthetic dissonance: they encounter Athletic Brutalism before seeing any core workout features. Shipping them a half-redesigned onboarding flow undermines the first impression the design is meant to create. Audit findings feed into AB-PR5 scope (onboarding touch-up, if warranted).

##### 9. Golden Test Baseline List

All 12 screens must have matchesGoldenFile baselines committed before AB-PR1 can merge. Baselines are generated against the post-AB-PR1 visual state (new color scheme, new typography, zero radius).

**7 audited screens (full redesign):**

| Screen | Golden file | State to capture |
|---|---|---|
| Home | test/widget/goldens/home_screen.png | Active weekly plan, 2 routines listed |
| Active Workout | test/widget/goldens/active_workout_screen.png | Mid-workout, 2 sets completed |
| Rest Timer Overlay | test/widget/goldens/rest_timer_overlay.png | 45 seconds remaining |
| PR Celebration | test/widget/goldens/pr_celebration_screen.png | PR path, 1 new record |
| Workout History | test/widget/goldens/workout_history_screen.png | 2 week-groups, 3 workouts each |
| Exercise List | test/widget/goldens/exercise_list_screen.png | Muscle group filter active, 6 exercises |
| Weekly Plan | test/widget/goldens/weekly_plan_screen.png | 3 routines, 2 completed |

**5 un-audited high-traffic screens (regression protection):**

| Screen | Golden file | State to capture |
|---|---|---|
| Onboarding | test/widget/goldens/onboarding_screen.png | Step 1 of onboarding flow |
| Auth / Login | test/widget/goldens/login_screen.png | Email/password form, empty state |
| Profile | test/widget/goldens/profile_screen.png | Logged-in user, all sections visible |
| Exercise Detail | test/widget/goldens/exercise_detail_screen.png | Exercise with description and history |
| Workout Summary | test/widget/goldens/workout_summary_screen.png | Completed workout, stats visible |

Use flutter test --update-goldens to regenerate. Never commit auto-generated goldens without visual review. Golden tests must run in CI on a consistent headless environment (flutter_test) to avoid pixel-level variance between machines.

##### 10. Total Effort

| PR | Scope | Estimate |
|---|---|---|
| AB-PR1 | Foundation (theme, typography, primitives, goldens, transitions, assets) | 30-40h |
| AB-PR2 | Core loop (active workout + rest timer) | 22-28h |
| AB-PR3 | Celebration and completion | 18-24h |
| AB-PR4 | Information surfaces (home, history, exercise list, weekly plan) | 22-30h |
| AB-PR5 | Polish, screenshots, final QA | 12-18h |
| **Total** | | **104-140h** |

These are agent-hours, not calendar days. AB-PR2/3/4 can run in parallel once AB-PR1 lands, so calendar time from AB-PR1 merge to AB-PR5 open could be as short as the longest of the three parallel PRs (~28h). Real elapsed time depends on review turnaround and CI queue.

**Context.** The original audit estimated 46-67h for the same scope. The tech-lead feasibility review identified the audit as 2-2.5x optimistic. The corrected range reflects actual surface area: set_row.dart alone is 401 LOC, the 12-screen golden baseline is unbudgeted in the audit, and the 5-PR split carries more per-PR overhead than the audit 4-PR split.

##### Revisions from Original Audit

Every place where the original audit was overridden by PO or tech-lead review. Tech-lead must not revert these without a new review cycle.

| Item | Audit direction | Final direction | Authority |
|---|---|---|---|
| AB4 scope | Halftone CustomPainter backdrop + per-character stagger animation | Drop CustomPainter (pre-rasterized PNG); word-level stagger only via StaggeredTextReveal | PO (diminishing returns; 12-16h reduced to 6-8h) |
| Noise texture | ShaderMask + ui.ImageShader | DecorationImage with AssetImage + ImageRepeat.repeat | Tech-lead (~10x per-frame cost, zero visual benefit) |
| Halftone background | Live CustomPainter | Pre-rasterized halftone_bg.png via Image.asset + BlendMode.multiply | Tech-lead (performance) |
| PR split | 4 PRs | 5 PRs (AB-PR1 foundation; AB-PR2 core loop; AB-PR3 celebration; AB-PR4 info surfaces; AB-PR5 polish) | Tech-lead (cleaner scope isolation) |
| Effort estimate | 46-67 agent-hours total | 104-140 agent-hours total | Tech-lead (audit was 2-2.5x optimistic) |
| FontFeature.tabularFigures() | Not mentioned | Mandatory on every numeric TextStyle in app_text_styles.dart | Tech-lead (digit-width jitter is visible in set logger without it) |
| Gradient cleanup | Not explicitly specified | gradient_button.dart deleted; primaryGradient and destructiveGradient getters deleted | Tech-lead (implied by aesthetic direction; made explicit) |
| Accessibility | Contrast mentioned briefly; no Semantics policy | Mandatory Semantics wrappers on every new widget in the same commit; E2E labels preserved verbatim; reduced-motion branches required | PO (a11y must ship with the widget, not as a follow-up) |
| Font bundling | google_fonts package (implied runtime fetch) | Bundle as pubspec.yaml assets, allowRuntimeFetching = false, OFL license registration | PO (no runtime fetching; license compliance) |
| Golden tests | Not mentioned | 12-screen baseline required in AB-PR1 | Tech-lead (repo has zero goldens; critical for a broad theme change) |
| Onboarding | Quick pass only (not audited) | Formal 1-hour ui-ux-critic audit required before AB-PR1 opens | PO (first-run users most sensitive to aesthetic dissonance) |
| Store screenshots | Not mentioned | Explicit deliverable in AB-PR5 scope | PO (must be produced during the PR, not as afterthought) |
| Sequencing | AB work can start alongside other work | AB-PR1 must land after PR7, PR6, and Sprint B UX1-UX8 | PO (retention work is the #1 priority; AB is polish on top, not a substitute) |
| Latin-only constraint | Not mentioned | Documented as known constraint for future localization | PO (capture now, not as a localization surprise) |

### 13d: Warnings (fix before or shortly after launch)

| ID | Item | Effort |
|----|------|--------|
| ~~W1~~ | ~~OAuth deep link registration~~ | DONE (#42) — AndroidManifest intent-filter for `io.supabase.gymbuddy` |
| ~~W2~~ | ~~Wakelock during active workout~~ | DONE (#45) — `wakelock_plus` enables on ActiveWorkoutBody mount, disables on dispose; errors swallowed for unsupported platforms; 3 widget tests via platform-interface override |
| W3 | Stale workout timeout UX | 2-3h | When `startedAt` >6h ago on app open, show prominent modal: "Workout from [date] still open — Resume or Discard?" (deferred from Step 12.3) |
| W3b | Input length limits (TextField + server CHECK) | 1-2h |
| W4 | Push notifications (workout reminders) | 1-2 days |
| W5 | Data export (CSV/JSON) | 3-4h |
| W6 | Direct Supabase access in UI (bypass repo pattern) | 30min |
| W7 | Supabase free tier monitoring (500MB DB, upgrade at 500 DAU) | - |
| W8 | HomeScreen `SingleChildScrollView` → `CustomScrollView` | 2-3h |

### Suggested Sprint Order

**Sprint A — Store-ready:** ~~B5~~ ~~P7~~ ~~W1~~ (PR #42), ~~B1~~ ~~B4~~ ~~P6~~ (PR #43, icon deferred), ~~QA follow-ups: legal placeholder cleanup across all 5 legal docs, Brazil jurisdiction with CDC carve-out, PWA theme colors, DELETE gate partial-string tests, volume-unit widget tests, live `manage-data.smoke.spec.ts` with backend-verified delete + cascade~~ (PR #44), ~~W2 wakelock~~ (PR #45). Remaining for Sprint A: B2 Sentry, B3 analytics (PR 5).
**Sprint A → B bridge — Tech debt sweep:** PR 6 — Bulk dependency upgrade + toolchain refresh (Riverpod 3, GoRouter 17, Freezed 3). PR 7 — Close local CI Android build gap (`make ci` adds `flutter build apk --debug`). Both land before Sprint B retention work so P1 (charts) can pull in `fl_chart` against the modern toolchain and the new Makefile gate catches Android plugin breakage pre-push.
**Sprint B (1 week) — Retention + polish:** P1, P2, P4, P8, UX1-UX8
**Sprint B+ — Athletic Brutalism redesign (parallelizable after AB-PR1):** AB-PR1 (foundation) → AB-PR2 (core loop), AB-PR3 (celebration), AB-PR4 (info surfaces) in parallel → AB-PR5 (polish + store screenshots). Sequencing hard-gate: AB-PR1 lands AFTER PR6 bulk upgrade; all AB-PR* land AFTER Sprint B retention work (P1-P8, UX1-UX8).
**Sprint C (1 week) — Resilience:** B6, W3, W3b, W6, W8 (B7 promoted to Phase 14)
**Deferred to v1.1:** P5 (1RM), W4 (push notifications), W5 (CSV export)

> **PO strategic note:** Consider shipping Phase 15a (XP overlay + level badge) alongside launch for competitive differentiation vs Strong/Hevy. Without it, GymBuddy is a feature-subset of established competitors.

---

## Phase 13a PR 6: Bulk Dependency Upgrade + Toolchain Refresh

> **Status:** PLANNED. Bridge PR between Sprint A (observability bundle in PR 5) and Sprint B (P1/P2/P4/P8/UX1-8). Pure plumbing — no user-visible changes. Cuts across the entire codebase. 0 features added.

### 1. Goal

Sweep 34 outdated direct + transitive dependencies (untouched since project scaffold) up to current stable lines — Riverpod 2.6 → 3, GoRouter 13 → 17, Freezed 2 → 3, codegen toolchain (`build_runner`/`json_serializable`/`source_gen`/`analyzer`) — so Sprint B can pull in modern packages (`fl_chart` for P1, expanded exercise content for P2) against a current toolchain instead of dragging four years of breaking changes into a feature PR.

### 2. Why now

- The forced `sentry_flutter 8.14.2 → 9.x` bump on the PR 5 branch surfaced **34 outdated packages** (`flutter pub outdated` ground truth, captured at 2026-04-11) — nobody has run a dep sweep since Step 1.
- Two transitive packages are **discontinued** on the current line: `build_resolvers` and `build_runner_core` (both consumed by `build_runner 2.4.13`). Newer `build_runner 4.x` replaces them.
- Two of three Sprint B "blocks retention" items add new packages: P1 (`fl_chart` or `syncfusion_flutter_charts`) and P2 (no new package, but bulk migrations). Doing the upgrade inside a feature PR would conflate breakage attribution.
- Phase 14 (Offline Support) adds `connectivity_plus` — also better landed on a fresh toolchain.

### 3. Scope table — outdated packages

Source: `flutter pub outdated` run on `feature/phase13a-sprintA-pr5-observability` @ 2026-04-11. Difficulty key: T = trivial (no API change), M = moderate (mechanical edits + codegen), H = hard (semantic changes, risk of behavioural drift).

| Package | Type | Current | Latest | Δ | Difficulty | Notes |
|---------|------|---------|--------|---|------------|-------|
| **flutter_riverpod** | dep | 2.6.1 | 3.3.1 | +1 major | H | Provider failures wrapped in `ProviderException`. `ProviderObserver` callback signature changed. New `Notifier`/`AsyncNotifier` superclasses. `FutureProvider` still supported but functional providers discouraged in favor of class-based notifiers. |
| **riverpod** (transitive) | dep | 2.6.1 | 3.2.1 | +1 major | H | Auto-bumped with `flutter_riverpod`. |
| **riverpod_annotation** | dep | 2.6.1 | 4.0.2 | +2 majors | T (for us) | **Unused in our codebase** — zero `@riverpod` annotations. Bump to keep pubspec coherent. |
| **riverpod_generator** | dev | 2.4.0 | 4.0.3 | +2 majors | T (for us) | **Unused in our codebase**. Bump in lockstep with `riverpod_annotation`. |
| **riverpod_analyzer_utils** (transitive) | dev | 0.5.1 | 0.5.10 | minor | T | Auto-bumped with generator. |
| **go_router** | dep | 13.2.5 | 17.2.0 | **+4 majors** | H | Migration guides for v14, v15, v16, v17 — must walk all four. `GoRouterRedirect` signature stable. `StatefulShellRoute` API stable (we don't even use it — see codebase impact below). `optionURLReflectsImperativeAPIs` static is the most likely behavioural drift point. |
| **freezed** | dev | 2.5.2 | 3.2.5 | +1 major | M | Union types now require `sealed class` keyword. `.map()` / `.when()` retained but discouraged in favor of Dart 3 pattern matching. **Affects exactly ONE file in our codebase** (`AnalyticsEvent`) — see assessment. |
| **freezed_annotation** | dep | 2.4.4 | 3.1.0 | +1 major | M | Bumps in lockstep with `freezed`. |
| **flutter_dotenv** | dep | 5.2.1 | 6.0.0 | +1 major | T | Surface unchanged (`dotenv.load()` / `dotenv.env['X']`). Risk: low. Verify `mergeWith` and `maybeGet` still exist. |
| **build_runner** | dev | 2.4.13 | 2.13.1 | minor (significant) | M | Newer runner replaces discontinued `build_resolvers`/`build_runner_core` 2.x with 3.x/9.x. Codegen output may shift slightly. |
| **build** (transitive) | dev | 2.4.1 | 4.0.5 | +2 majors | T | Auto-bumped with `build_runner`. |
| **build_resolvers** (transitive) | dev | 2.4.2 (discontinued) | 3.0.4 (discontinued) | +1 major | T | New runner pulls 3.x; both lines marked discontinued — Dart team replacement is in `build` itself. Monitor warnings post-bump. |
| **build_runner_core** (transitive) | dev | 7.3.2 (discontinued) | 9.3.2 (discontinued) | +2 majors | T | Same story as `build_resolvers`. |
| **build_config** (transitive) | dev | 1.1.2 | 1.3.0 | minor | T | |
| **source_gen** (transitive) | dev | 1.5.0 | 4.2.2 | **+3 majors** | M | Risk: codegen output diff. All `*.g.dart` and `*.freezed.dart` will regenerate; review the `make gen` diff carefully. |
| **source_helper** (transitive) | dev | 1.3.5 | 1.3.11 | patch | T | |
| **json_serializable** | dev | 6.8.0 | 6.13.1 | minor | T | No major bump — within 6.x line. Should be a clean bump. Re-runs codegen. |
| **json_annotation** | dep | 4.9.0 | 4.11.0 | minor | T | Lockstep with `json_serializable`. |
| **analyzer** (transitive) | dev | 6.4.1 | 12.1.0 | **+6 majors** | M | Pulled by `build_runner` and `riverpod_generator`. Likely the lever that forces the codegen toolchain bump. May surface new lints in `--fatal-infos` mode. |
| **_fe_analyzer_shared** (transitive) | dev | 67.0.0 | 99.0.0 | huge | T | Auto-bumped with analyzer. |
| **analyzer_plugin** (transitive) | dev | 0.11.3 | 0.14.8 | minor | T | |
| **dart_style** (transitive) | dev | 2.3.6 | 3.1.8 | +1 major | T | New formatter version may reformat large parts of the codebase. Run `dart format .` once and commit the diff in the same step. |
| **custom_lint_core** (transitive) | dev | 0.6.3 | 0.8.2 | minor | T | |
| **shelf_web_socket** (transitive) | dev | 2.0.1 | 3.0.0 | +1 major | T | Used only by `build_runner`'s dev server. |
| **test_api** (transitive) | dev | 0.7.10 | 0.7.11 | patch | T | |
| **package_info_plus** | dep | 9.0.1 | 10.0.0 | +1 major | **BLOCKED** | 10.0.0 requires Dart SDK newer than 3.11.4. Pin remains 9.0.1 unless we also bump the Flutter SDK — out of scope for this PR. Document gap. |
| **package_info_plus_platform_interface** (transitive) | dep | 3.2.1 | 4.0.0 | +1 major | **BLOCKED** | Same SDK constraint. |
| **mocktail** | dev | 1.0.4 | 1.0.5 | patch | T | |
| **jni** (transitive) | dep | 0.14.2 | 1.0.0 | +1 major | T | Pulled in by `wakelock_plus` — verify wakelock still works on Android. |
| **meta** (transitive) | dep | 1.17.0 | 1.18.2 | patch | T | Pinned by Flutter SDK; will not move until SDK bump. Document. |
| **path_provider_android** (transitive) | dep | 2.2.23 | 2.3.1 | minor | T | |
| **vector_math** (transitive) | dep | 2.2.0 | 2.3.0 | minor | T | Pinned by Flutter SDK; same as `meta`. |
| **win32** (transitive) | dep | 5.15.0 | 6.0.0 | +1 major | T | Windows desktop only — not in our build matrix. Will resolve naturally. |

`flutter_lints` is currently `^6.0.0` and **does not appear in `pub outdated`** — already at the latest 6.x. No bump needed.

### 4. Codebase impact assessment

Performed by grep on `feature/phase13a-sprintA-pr5-observability` @ 2026-04-11. **No code edited during this assessment — read-only enumeration.**

#### 4.1 Riverpod 2 → 3

- **Provider files affected:** 11 (`exercise_providers.dart`, `pr_providers.dart`, `auth_providers.dart`, `workout_history_providers.dart`, `workout_providers.dart`, `weekly_plan_provider.dart`, `week_review_stats_provider.dart`, `routine_list_notifier.dart`, `active_workout_notifier.dart`, `profile_providers.dart`, `crash_reports_enabled_provider.dart`).
- **Consumer files affected:** 40 files contain `ref.watch` / `ref.read` / `ref.listen` / `ref.invalidate` — total **243 call sites**.
- **Manual `Notifier` / `AsyncNotifier` subclasses:** 8 (`AuthNotifier`, `ProfileNotifier`, `WorkoutHistoryNotifier`, `RoutineListNotifier`, `RestTimerNotifier`, `ActiveWorkoutNotifier`, `WeeklyPlanNotifier`, `CrashReportsEnabledNotifier`).
- **Functional providers:** `FutureProvider` (15+ instances), `StreamProvider` (2 — `authStateProvider`, `elapsedTimerProvider`), `StateProvider` (5 — UI filters and UI flags), `Provider` (1 — `routerProvider`).
- **`@riverpod` annotation usage:** **ZERO**. No `part 'X.g.dart';` directives in any provider file. `riverpod_annotation` and `riverpod_generator` are pubspec dependencies but **unused** in the source tree.
- **What actually breaks:**
  - **`ProviderException` wrapping** — Riverpod 3 wraps any provider failure in a `ProviderException` whose `.exception` field is the original error. Per the migration guide: this is only an issue when code does `try { ref.read(p.future) } on SpecificException { ... }`. **Sites to audit:** every call site that catches non-`AsyncValue` errors from a provider read. `AsyncValue.error`, `ref.listen(..., onError: ...)`, and `ProviderObserver` are unaffected. Grep for `} on .*Exception` near `ref.read(...future)`.
  - **`ProviderObserver` API** — callbacks now take `ProviderObserverContext` instead of `(ProviderContainer, ProviderBase)`. We do **not** define a custom observer (only Sentry's `SentryNavigatorObserver`, which is unrelated). Risk: zero unless tests use a fake observer.
  - **`ref.state` / `ref.listenSelf` / `ref.future` removed from `Ref`** — moved to `Notifier`/`AsyncNotifier` instance methods. Our notifier classes already use the instance form (`state = ...`, never `ref.state = ...`). Grep confirms zero `ref.state` / `ref.future` in `lib/`.
  - **`AsyncNotifier.build()` signature** — unchanged. Existing 8 notifier classes should work as-is.
- **Migration difficulty for our codebase:** **MODERATE** despite the call-site count. The high count is `ref.watch`/`ref.read` (which are stable APIs); the actual breaks are narrow.

#### 4.2 GoRouter 13 → 17 (4 majors)

- **Files affected:** `lib/core/router/app_router.dart` (the entire router definition, ~360 lines), 20 UI files using `context.go()` / `context.push()` / `context.pop()` — total **71 call sites**.
- **Specific patterns we use** (from reading `app_router.dart` in full):
  - `GoRouter(initialLocation:, refreshListenable:, observers:, redirect:, routes:)` — top-level constructor.
  - `ShellRoute(builder:, routes:)` — **NOTE: we use `ShellRoute`, NOT `StatefulShellRoute`.** The PLAN.md "Tech Stack & Architecture" line referencing `StatefulShellRoute` is stale — actual code is `ShellRoute`. The new step does **not** need a `StatefulShellRoute` migration.
  - `GoRoute(path:, builder:, routes:, redirect:)` — nested.
  - `GoRouterState.of(context).matchedLocation` — used in `_ShellScaffold._currentIndex`.
  - `state.pathParameters['id']!` — used in 4 routes.
  - `state.extra` — used in 4 routes (workout active redirect, PR celebration, create routine, etc.).
  - Custom `_RouterRefreshListenable extends ChangeNotifier` wrapping `ref.listen(authStateProvider, ...)` + `ref.listen(needsOnboardingProvider, ...)`.
- **Likely breaking changes across v14-v17** (must read each migration guide individually before implementing — Context7 only surfaces the index, not the full diff):
  - **v14**: Likely changes to `GoRouterState` API, possibly `pathParameters`/`uri.queryParameters`. Verify with the official `flutter.dev/go/go-router-v14-breaking-changes` page.
  - **v15**: Likely `onException` callback changes, possibly `redirect` signature normalization. Verify.
  - **v16**: Likely `GoRouter.of(context)` / `.maybeOf(context)` static method tweaks. Verify.
  - **v17**: Latest. Spot-check the changelog for `ShellRoute` builder signature drift, `GoRouterState.matchedLocation` rename, or `state.extra` typing changes.
- **`optionURLReflectsImperativeAPIs`** is a static property that controls whether `context.push()` writes to the URL bar — important because we have a known bug (lessons.md) about `context.go()` vs `context.push()` on Flutter web. Verify behaviour after upgrade with the existing E2E suite.
- **Migration difficulty for our codebase:** **HARD** because four majors compound — but the surface area is bounded (1 router file + 20 callers).

#### 4.3 Freezed 2 → 3

- **`@freezed` classes in `lib/`:** 16 total. **15 are simple data classes** (single factory, only used for `.copyWith` + JSON serialization). **1 is a union type:** `lib/features/analytics/data/models/analytics_event.dart`.
- **`@freezed` classes in `test/`:** 0. Test fixtures use plain Dart classes.
- **`.when` / `.map` / `.maybeWhen` / `.maybeMap` total occurrences:** 90 across 31 files — but **the vast majority are `AsyncValue.when(...)` calls in widgets**, not Freezed union pattern matching. Confirmed by spot-check — `async_value_builder.dart`, `exercise_detail_screen.dart`, `profile_screen.dart`, `manage_data_screen.dart` all call `.when` on `AsyncValue<T>`. **`AsyncValue` is from Riverpod, not Freezed.** Freezed 3's `.when` deprecation does not affect these.
- **Actual Freezed `.when` / `.map` call sites:** ALL inside `analytics_event.dart` — used for `name` getter (`.map`) and `props` getter (`.when`). That single file is the entire Freezed 2→3 union-API migration surface.
- **What breaks for `AnalyticsEvent`:**
  - Must add `sealed` keyword: `class AnalyticsEvent` → `sealed class AnalyticsEvent`.
  - `.map` and `.when` are still supported in Freezed 3 (legacy methods retained per migration guide), so the existing getters can stay as-is during the bump. **Recommendation:** make the `sealed` keyword change in this PR, leave `.map` / `.when` migration to a follow-up if it's not forced. Keeping the diff small reduces blast radius.
- **What breaks for the 15 data classes:**
  - **NOTHING.** Single-factory data classes do not need `sealed`. `.copyWith` and JSON serialization are unchanged in Freezed 3.
- **Migration difficulty for our codebase:** **MODERATE → TRIVIAL once you realize only one file has union semantics.** The 90 `.when` matches are a red herring — they're `AsyncValue`.

#### 4.4 Codegen toolchain (build_runner / source_gen / analyzer)

- All `*.g.dart` files (9 — `Workout`, `Exercise`, `PersonalRecord`, `WorkoutExercise`, `Profile`, `ExerciseSet`, `ActiveWorkoutState`, `Routine`, `WeeklyPlan`) and all `*.freezed.dart` files (16) will regenerate.
- Risk: subtle codegen output differences (formatter, deprecated annotations, hash function changes) producing a noisy diff.
- Mitigation: commit the regenerated files in the same atomic commit as the toolchain bump. Reviewer reads `make gen` diff once, not per-file.

### 5. Skill workflow citations

Per the mandatory pre-spec skill consultation (read in full at planning time):

- **`.agents/skills/flutter-managing-state/SKILL.md`** — covers MVVM with `ChangeNotifier` + `provider` package, NOT Riverpod. Cited here for the **"Single Source of Truth"** principle (Architecture and Data Flow section): the Riverpod 3 migration must preserve our existing repository-as-SSOT pattern. The skill's "Workflow: Implementing MVVM with Provider" steps 1-5 (validation feedback loop) **do** apply directly to verifying each migrated `AsyncNotifier`: trigger → notifier → repository → emit → UI rebuild. Use that 5-step loop as the per-notifier verification protocol after Riverpod commits.
- **`.agents/skills/flutter-implementing-navigation-and-routing/SKILL.md`** — covers `Navigator` (imperative) and declarative routing via `go_router`. Most relevant section: **"Implementing Declarative Navigation"** + **"Workflow: Implementing Deep-Linkable Routing"** (lines 41-78). Cite the workflow checklist when reviewing whether each `context.go()` / `context.push()` call site still resolves correctly post-upgrade. The skill does NOT cover `StatefulShellRoute` (we don't use it anyway — see 4.2). The "Implementing Nested Navigation" section uses raw `Navigator` widgets and does NOT apply to our `ShellRoute`-based architecture.
- **`.agents/skills/flutter-theming-apps/SKILL.md`** — critical citation: **"Component Theme Normalization"** section (lines 42-51). The skill explicitly lists deprecated theme types: `CardTheme` → `CardThemeData`, `DialogTheme` → `DialogThemeData`, `TabBarTheme` → `TabBarThemeData`, `AppBarTheme` → `AppBarThemeData`, `BottomAppBarTheme` → `BottomAppBarThemeData`, `InputDecorationTheme` → `InputDecorationThemeData`. **Action: grep `lib/core/theme/` for any of these older types before the upgrade and convert in a dedicated commit if the new toolchain warns on them.** Also cite **"Workflow: Migrating Legacy Themes to Material 3"** (lines 71-81) as the per-warning checklist. The current `flutter_lints 6.0.0` may already warn on these — verify on the baseline first.
- **`.agents/skills/flutter-animating-apps/SKILL.md`** — only relevant section: **"Implementing Explicit Animations"** (line 54+) — reminds us to check `AnimationController.dispose()` is still called everywhere (no API change expected, just a hygiene re-check). We use explicit animations in the PR celebration screen and the rest timer overlay. Spot-check after the SDK-adjacent bumps land.

### 6. Order of operations (atomic commits)

Each commit must leave the build green and tests passing. **No "breaks here, fixed in next commit".** The reviewer can `git checkout` any single commit and run `make ci` cleanly.

| # | Commit | Files | Risk |
|---|--------|-------|------|
| 0 | `chore(deps): tag pre-upgrade baseline` | `.gitignore` (no diff — tag-only commit) + `git tag pre-13a-bulk-upgrade` | none |
| 1 | `chore(deps): bump low-risk transitive + dev patches` | `pubspec.yaml`, `pubspec.lock` | low — `mocktail`, `meta`-adjacent transitive minors only. Smoke test only. |
| 2 | `chore(deps): bump codegen toolchain (build_runner, json_serializable, analyzer)` | `pubspec.yaml`, `pubspec.lock`, **all** `*.g.dart`, **all** `*.freezed.dart` | M — regenerated artifacts. Run `make gen` and commit the full diff in one shot. **This is the longest-to-review commit because of the codegen blast radius.** |
| 3 | `chore(deps): bump freezed 2→3 + freezed_annotation 2→3` | `pubspec.yaml`, `pubspec.lock`, **`analytics_event.dart`** (`class` → `sealed class`), regenerated `analytics_event.freezed.dart` | M — focused on one file. The 15 data classes regenerate without source edits. |
| 4 | `chore(deps): bump riverpod 2→3 (flutter_riverpod, riverpod, riverpod_annotation, riverpod_generator)` | `pubspec.yaml`, `pubspec.lock`, **8 notifier files** + any consumer that catches a typed exception from `ref.read(p.future)` | **H** — biggest correctness risk. See per-package migration notes (§7). |
| 5 | `chore(deps): bump go_router 13→17` | `pubspec.yaml`, `pubspec.lock`, **`app_router.dart`**, 20 caller files | **H** — four majors compounded. Per-major migration walk required. |
| 6 | `chore(deps): bump flutter_dotenv 5→6` | `pubspec.yaml`, `pubspec.lock`, possibly `main.dart` and `sentry_init.dart` if any API removed | low — surface unchanged in skim, verify against changelog. |
| 7 | `chore(deps): theme component normalization (CardThemeData, AppBarThemeData, etc.)` | `lib/core/theme/*.dart` (whatever uses the old `*Theme` types) | low — mechanical rename, may be empty if we already use `*ThemeData`. |
| 8 | `chore(deps): document SDK-blocked upgrades + intentional pins` | `pubspec.yaml` (comments only) | none — just adds comments next to `package_info_plus: ^9.0.1` and `meta` pin notes. |

**Per-commit gate:** after each commit, run `make ci` locally. If a commit goes red, do NOT proceed to the next; root-cause and amend the same commit (or create a tightly-scoped follow-up commit before moving on). Never let the working tree drift between checkpoints.

### 7. Per-upgrade migration notes

#### 7.1 Codegen toolchain (commit 2)

- Bump `build_runner`, `json_serializable`, and let transitives (`source_gen`, `analyzer`, `_fe_analyzer_shared`, `dart_style`, `build`, `build_resolvers`, `build_runner_core`, `build_config`) follow the resolver.
- `dart pub upgrade --major-versions build_runner json_serializable` then `flutter pub get`.
- Run `make gen` (which is `dart run build_runner build --delete-conflicting-outputs`).
- Run `dart format .` — **the new `dart_style 3.x` will reformat code.** Commit the format diff together with the generated artifacts.
- Run `dart analyze --fatal-infos`. The newer `analyzer 12.x` may surface new info-level lints — fix them in the same commit (do not silence them).
- **Rollback trigger:** if `make gen` fails on more than one file due to source-gen incompatibility, abort. Pin `analyzer` to the previous major and retry — or revert and try freezed first.

#### 7.2 Freezed 2 → 3 (commit 3)

- Per the **Freezed migration guide** (Context7: `/rrousselgit/freezed`, file `packages/freezed/migration_guide.md`):
  - Union types **must** be marked `sealed class`. Action: `analytics_event.dart` line 12 — `class AnalyticsEvent with _$AnalyticsEvent` → `sealed class AnalyticsEvent with _$AnalyticsEvent`.
  - `.map(...)` and `.when(...)` are **still supported** as legacy methods (Context7 confirms in the README example). **Do not** rewrite the `name` and `props` getters in this PR — keep the diff minimal. Pattern-matching migration is a separate cleanup PR.
  - The 15 single-factory data classes (`Workout`, `Exercise`, `Profile`, etc.) need **no source edits**.
- Run `make gen` to regenerate `analytics_event.freezed.dart` against the new generator.
- Run the analytics-event unit tests (`test/unit/features/analytics/data/models/analytics_event_test.dart` if it exists, otherwise skip — they're covered by repository tests).
- **Expected diffs:** one source line in `analytics_event.dart` + 16 regenerated `*.freezed.dart` files (single line headers/comments may shift, otherwise stable).
- **Rollback trigger:** if `make gen` errors on a non-`AnalyticsEvent` freezed class, the data-class assumption is wrong — stop, regrep `@freezed` for multi-factory classes, and re-plan.

#### 7.3 Riverpod 2 → 3 (commit 4)

- Follow the **Riverpod 3.0 migration guide** (Context7: `/rrousselgit/riverpod`, file `website/docs/3.0_migration.mdx`).
- **Pre-flight grep:** find every `} on ` exception catch within ~20 lines after a `ref.read(...future)` or `await ref.read(...future)` call. These are the only sites that need editing. Expected count: low (we mostly handle `AsyncValue.error` in widgets).
- For each found site, wrap or unwrap per the migration guide:
  ```diff
  - } on NotFoundException catch (e) { ... }
  + } on ProviderException catch (e) {
  +   if (e.exception is NotFoundException) { ... }
  +   else rethrow;
  + }
  ```
- **`@riverpod` annotation usage:** zero in our codebase, so the `riverpod_generator` 2→4 bump is a pubspec-only change (commit it together with `riverpod_annotation` for atomicity even though we don't currently use either).
- **Custom `ProviderObserver`:** we don't define one. Skip.
- **`ref.state` / `ref.future` / `ref.listenSelf`:** zero matches in `lib/`. Skip.
- **AsyncNotifier subclasses:** spot-check each of the 8 to confirm `build()` still returns the correct shape. The base class signature is unchanged; existing code should work.
- **Run `flutter test`** after the bump, expect **all 959 tests pass**. Any new failure must be root-caused — do NOT modify a test to "match new behavior" without understanding why.
- **Rollback trigger:** if 5+ unit tests fail with `ProviderException`-related stack traces, the catch-site sweep was incomplete. Revert this commit, run a more thorough grep, retry. If 20+ tests fail, abort entirely and discuss.

#### 7.4 GoRouter 13 → 17 (commit 5)

- **Walk all four breaking-change pages** before editing code:
  1. https://flutter.dev/go/go-router-v14-breaking-changes
  2. https://flutter.dev/go/go-router-v15-breaking-changes
  3. https://flutter.dev/go/go-router-v16-breaking-changes
  4. https://flutter.dev/go/go-router-v17-breaking-changes
- Cite the **flutter-implementing-navigation-and-routing skill's "Workflow: Implementing Deep-Linkable Routing"** (lines 73-78) as the validation checklist.
- **Files to edit (estimated):**
  - `lib/core/router/app_router.dart` — primary surface. Verify `GoRouter(...)` constructor params, `ShellRoute(...)`, `GoRoute(...)` builders, `redirect:` signature, `state.matchedLocation`, `state.pathParameters`, `state.extra`, `_RouterRefreshListenable` integration with `refreshListenable:`.
  - 20 caller files using `context.go()` / `context.push()` / `context.pop()` — verify the stable API hasn't shifted.
  - **Lessons.md note:** `tasks/lessons.md` documents that `context.go()` → `context.push()` broke Flutter web reload in GoRouter 13.x. **Verify the lessons.md fix is still correct in 17.x** — re-test the workout discard flow on web after the bump.
- **Sanity test sequence after bump:**
  1. `flutter analyze --fatal-infos`
  2. `flutter test` — all 959 pass
  3. `flutter build web --release` — must build
  4. `flutter run -d chrome` — manually click through `splash → login → onboarding → home → exercises → /exercises/:id → back → routines → profile → /profile/manage-data → back → /records → /plan/week`. Verify no broken transitions.
  5. Run the full local Playwright smoke suite (`FLUTTER_APP_URL= npx playwright test --project=smoke`).
- **Rollback trigger:** if 3+ E2E smoke tests fail with route-related selectors, revert and walk the migration guides one more time. Do not band-aid by editing test selectors — the bug is in the router upgrade.

#### 7.5 flutter_dotenv 5 → 6 (commit 6)

- Read the v6.0.0 changelog (Context7's `/java-james/flutter_dotenv` snippets confirm the public surface — `dotenv.load()`, `dotenv.env['X']`, `dotenv.get()`, `dotenv.maybeGet()`, `mergeWith` — is unchanged).
- Files to verify: `lib/main.dart` (loads `.env` and reads `SUPABASE_URL`/`SUPABASE_ANON_KEY`), `lib/core/observability/sentry_init.dart` (reads `SENTRY_DSN`).
- **Rollback trigger:** if `flutter run` fails with a `LateInitializationError` on `dotenv.env`, the load API changed. Revert and pin to 5.x with a tracking issue.

#### 7.6 Theme normalization (commit 7)

- Grep `lib/core/theme/` for `CardTheme(`, `DialogTheme(`, `TabBarTheme(`, `AppBarTheme(`, `BottomAppBarTheme(`, `InputDecorationTheme(`. Replace with `*ThemeData` per the **flutter-theming-apps skill's "Component Theme Normalization"** section.
- This commit may be empty if `core/theme/` already uses the `*ThemeData` types — that's fine, skip the commit.
- **Rollback trigger:** never — this is a mechanical rename.

### 8. Bulletproof testing strategy — 7 gates

Every gate must be GREEN before merge. No exceptions, no "should pass" — only evidence.

#### Gate 1 — Static checks

- [ ] `dart format --set-exit-if-changed .` exits 0 (clean)
- [ ] `dart analyze --fatal-infos` reports **0 issues, 0 warnings, 0 infos**
- [ ] `make gen` runs to completion and produces **no diff** when re-run a second time (idempotent)
- [ ] `flutter pub outdated` shows zero direct deps with a `Resolvable` newer than `Current` (excluding intentionally pinned `package_info_plus`)

#### Gate 2 — Test suites

- [ ] `flutter test` reports **959 passing, 0 failing, 0 skipped** (must equal pre-upgrade count exactly — no silent skips)
- [ ] Snapshot test count diff: capture `flutter test --reporter compact 2>&1 | tail -1` before and after; numbers must match digit-for-digit
- [ ] If a test was deleted as part of the migration, it must be replaced with a coverage-equivalent test or PR description must explain why
- [ ] Any new test failure must be **root-caused with a written diagnosis in the PR body**, not deleted or marked `skip:`

#### Gate 3 — Build matrix

- [ ] `flutter build apk --debug` succeeds
- [ ] `flutter build apk --release` succeeds
- [ ] `flutter build apk --release` APK size: capture pre-upgrade `du -h build/app/outputs/flutter-apk/app-release.apk` and post-upgrade. Must be **within ±10%** of baseline. >10% growth requires investigation.
- [ ] `flutter build web --release` succeeds
- [ ] Web bundle size: capture pre-upgrade `du -sh build/web` and post-upgrade. Must be **within ±10%** of baseline.
- [ ] **iOS gap (open question for human):** `flutter build ios --debug --no-codesign` cannot run on the Windows dev box. We have no Mac CI runner. **Decision needed before this PR runs:** either (a) accept the gap and document "iOS not validated, will be tested when iOS is added in v1.1", or (b) spin up a Mac runner for one CI run. Recommend (a) since iOS is explicitly deferred per "Tech Stack & Architecture: Android-first, iOS deferred."

#### Gate 4 — E2E suite

- [ ] Local prerequisite: Supabase containers healthy (`docker ps | grep supa`), `build/web` rebuilt from current branch
- [ ] `FLUTTER_APP_URL= npx playwright test --project=smoke --reporter=list` — **all smoke tests pass**, no flaky retries
- [ ] `FLUTTER_APP_URL= npx playwright test --reporter=list` — **full regression suite passes** (smoke + full)
- [ ] No selector drift: `selectors.ts` should require zero edits for this PR (this is a plumbing PR — no UI text changes). If selectors.ts changes, PR description must justify why a dependency upgrade caused a UI text change.
- [ ] Visual regression: we currently have **no visual diff tests**. Document this as a gap to add later (Phase 13c-ish UX polish task) but do not block this PR.

#### Gate 5 — Manual QA smoke on real device

- [ ] Install `app-release.apk` on a physical Android device (or fully-booted emulator)
- [ ] Walk through the following flows, ticking each:
  - [ ] **Auth:** Cold launch → splash → login screen renders → email/password sign-in succeeds → lands on home
  - [ ] **Onboarding (new user path):** Sign up new test user → onboarding pages 1-2 → land on home with profile populated
  - [ ] **Exercises:** Tap Exercises tab → list loads → tap a category chip → list filters → tap an exercise → detail screen loads with image (or fallback icon) and form tips
  - [ ] **Workout flow (the hot path):** Home → tap a routine → workout starts pre-filled → log a working set → tap rest timer → adjust by +30s → tap Finish → Finish dialog → workout saves → routes back to home
  - [ ] **PR celebration:** Log a heavier set than the previous workout → finish → PR celebration screen renders → tap Continue → routes correctly
  - [ ] **Weekly plan:** Home → tap Edit on THIS WEEK section → Plan management screen loads → reorder a chip → save → home reflects new order
  - [ ] **Profile:** Tap profile → tap Workouts stat card → routes to history → back → tap PRs stat card → routes to records → back → tap Manage Data → screen loads → back
  - [ ] **Background → foreground:** Send app to background mid-workout → wait 30s → resume → active workout banner still present → resume to active workout → state preserved
- [ ] **Specific upgrade-impact spot checks:**
  - [ ] **GoRouter 17:** Hardware back button on every screen behaves identically to pre-upgrade (no jumps to wrong screen, no app exits from mid-stack)
  - [ ] **Riverpod 3:** After a workout finish, home stat cards update without manual refresh (verifies provider invalidation chain still works — Bug #2 from 12.2a regression)
  - [ ] **Freezed 3:** PR celebration screen renders correctly (`AnalyticsEvent` is the only union, but its consumer is the analytics repo, not this UI — UI tests cover it transitively)
  - [ ] **Sentry still captures errors:** force a deliberate crash via the dev menu (or temporarily uncomment a `throw` in a test build) and confirm the event lands in Sentry within 60s
  - [ ] **Crash reports opt-out toggle (PR 5):** Profile → Privacy → toggle OFF → trigger same test crash → confirm **nothing** lands in Sentry → toggle ON → trigger again → confirm event lands
  - [ ] **Analytics events still fire (PR 5):** finish a workout → check the `analytics_events` table in Supabase Studio for a `workout_finished` row with the expected `props` shape

#### Gate 6 — Performance sanity check

- [ ] **Cold start time:** measure 5 cold launches before AND after the upgrade on the same device. Log to a scratch file. Median post-upgrade must be **within ±15%** of pre-upgrade. >15% regression = investigate.
- [ ] **Workout screen rebuild count:** open Flutter DevTools → Performance tab → Rebuild Stats. Start a workout, log 3 sets, finish. Compare rebuild counts pre/post. **Must not exceed 1.5× the pre-upgrade count.** Riverpod 3's new internal change-detection could over-rebuild if we hit an edge case.
- [ ] **Jank check:** `flutter run --profile`, navigate to active workout screen, log 5 sets quickly. DevTools Timeline must show **0 dropped frames** during the interaction sequence.

#### Gate 7 — Observability regression (PR 5 backstop)

- [ ] **All 9 PR 5 analytics events still fire:** run one workout end-to-end (sign in fresh → finish onboarding → start workout from routine → log sets → finish → see PR celebration → respond to plan prompt → wait until next week → mark week complete). Query `analytics_events` and confirm a row exists for each of:
  - [ ] `onboarding_completed`
  - [ ] `workout_started`
  - [ ] `workout_finished`
  - [ ] `pr_celebration_seen`
  - [ ] `add_to_plan_prompt_responded`
  - [ ] `week_plan_saved`
  - [ ] `week_complete`
  - [ ] `account_deleted` (do this last on a throwaway test user — destructive)
- [ ] **Sentry crash reporting:** verify the smoke tests in Gate 5 landed events in the Sentry dashboard
- [ ] **Crash reports opt-out** still gates Sentry per Gate 5
- [ ] **Sentry navigation observer** still emits route breadcrumbs (verify on a captured error after walking 3+ screens — the breadcrumb panel should show the route trail with sanitized UUIDs)

### 9. Rollback plan

- **Pre-flight**: tag baseline `git tag pre-13a-bulk-upgrade` (commit 0). Push tag to remote. Capture `pubspec.lock` as `pubspec.lock.pre-bulk-upgrade.txt` artifact in the PR for explicit comparison.
- **Per-commit rollback**: each commit is atomic. `git revert <commit>` restores the previous green state without touching neighboring commits.
- **Full PR revert**: if CI is red and root cause is unclear after 3 fix attempts, `git revert` the entire merge commit cleanly (squash-merge makes this one revert).
- **Pubspec rollback**: copy `pubspec.lock.pre-bulk-upgrade.txt` back over `pubspec.lock`, run `flutter pub get`, force-resolution to baseline.
- **Codegen rollback**: after pubspec rollback, re-run `make gen` to regenerate against the old toolchain.

### 10. Acceptance criteria

- [ ] All 7 gates green (evidence in PR body, not "should pass")
- [ ] Snapshot test count digit-for-digit match (959 → 959)
- [ ] Zero new analyzer infos / warnings (current baseline is 0)
- [ ] All breaking changes documented in PR body with the affected file and the chosen fix
- [ ] Flutter skill citations included for each major migration (per §5)
- [ ] Rollback tag `pre-13a-bulk-upgrade` exists and is pushed
- [ ] PR body includes a "Lessons learned" section: what actually broke vs what this spec predicted. Feed surprises into `tasks/lessons.md`.
- [ ] APK size and web bundle size deltas reported in PR body (Gate 3)
- [ ] Cold start delta reported in PR body (Gate 6)
- [ ] iOS gap explicitly acknowledged in PR body (Gate 3)

### 11. Out of scope

- **No new features.** Zero functional changes that a user could see in screenshots.
- **No refactoring beyond what the upgrade forces.** Resist the urge to "while I'm here, clean up X" — that goes in a separate PR.
- **No new tests** unless a new test is needed to prove a specific migration didn't regress (e.g., a pin test for `ProviderException` wrapping if we hit a tricky catch site).
- **No Flutter SDK upgrade.** `environment: sdk: ^3.11.4` stays. If any required dep upgrade demands a newer SDK, **stop and surface to the user before proceeding.**
- **No `package_info_plus` 10.x** (blocked by SDK constraint — pinned at 9.0.1 with a comment).
- **No `pattern-matching migration`** for `AnalyticsEvent` — keep `.map`/`.when` calls intact, just add the `sealed` keyword. Pattern-matching cleanup is a separate trivial PR if we want it later.
- **No theme system rebuild.** Component normalization (commit 7) is a mechanical rename only; design tokens, color scheme, and typography stay frozen.
- **No CI matrix expansion.** No new workflow files, no new runners. Existing `ci.yml` and `e2e.yml` jobs run unchanged.
- **No iOS validation.** Acknowledged in Gate 3.
- **No Phase 14 prep.** `connectivity_plus` is NOT added in this PR — that's the first commit of Phase 14.

### 12. Time estimate (agent-hours, not wall clock)

| Phase | Effort | Notes |
|-------|--------|-------|
| Skill re-read + migration guide reading (4 go_router pages, riverpod 3 page, freezed migration guide) | 1.5h | Mandatory before any code edits |
| Commit 1 (low-risk patches) | 0.5h | Flush trivial bumps |
| Commit 2 (codegen toolchain) | **3-4h** | Largest blast radius. Codegen diff review + analyzer info fixes dominate. |
| Commit 3 (Freezed 2→3) | 0.5h | Surgical — one source line + regen |
| Commit 4 (Riverpod 2→3) | **2-3h** | Catch-site sweep + 8 notifier verification + full test run |
| Commit 5 (GoRouter 13→17) | **3-4h** | Four migration guides + router file edit + 20 caller spot-check + manual web walk + E2E suite |
| Commit 6 (flutter_dotenv 5→6) | 0.5h | Likely no-op edits |
| Commit 7 (theme normalization) | 0.5-1h | Mechanical rename, may be zero-diff |
| Commit 8 (pin documentation) | 0.25h | Comment-only |
| Gate 1-3 verification | 1h | Format + analyze + tests + 4 builds |
| Gate 4 (E2E full suite) | 0.5h wall + run time | Mostly waiting on the runner |
| Gate 5 (manual device QA) | 1.5h | Real device walk-through |
| Gate 6 (perf sanity) | 1h | DevTools + cold start measurements |
| Gate 7 (observability backstop) | 0.5h | Re-verify PR 5 events + Sentry |
| PR write-up + lessons.md update | 0.5h | |
| **Total** | **17-22 agent-hours** | Roughly 2-3 working sessions if fully focused. Spread across 2 days with verification gates between sessions. |

**The codegen toolchain bump (commit 2) is historically the longest part of any Flutter dep sweep** because it forces analyzer + dart_style updates that surface lint regressions across the whole codebase. Plan accordingly.

### 13. Open questions for the human (decide before execution starts)

1. **iOS gap in Gate 3:** confirm we accept "iOS not validated, will be tested in v1.1" given Android-first scope. (Recommended: yes.)
2. **Visual regression gap in Gate 4:** flag as a Sprint C / Phase 13c follow-up to add `playwright` snapshot tests, or accept the gap permanently for v1.0?
3. **Discontinued `build_resolvers` / `build_runner_core`:** the Dart team has marked these discontinued in BOTH our current AND target versions. The replacement (folded into `build` itself) may not be fully landed. Acceptable risk?
4. **`package_info_plus` 10.x SDK block:** acknowledge we pin to 9.0.1 indefinitely, OR plan a Flutter SDK bump as a separate PR right after this one to unblock 10.x?
5. **`AnalyticsEvent` pattern-matching cleanup:** keep `.map`/`.when` for now (recommended) or rewrite to `switch` expressions in this PR? (Recommended: keep for now to minimize blast radius.)
6. **Freezed 3 may emit deprecation warnings on `.when`/`.map`** even with the legacy methods retained. If `dart analyze --fatal-infos` flags these, we may be forced into the pattern-matching rewrite mid-PR. Decide pre-emptively: rewrite is in-scope OR add a targeted `// ignore_for_file: deprecated_member_use` for `analytics_event.dart` only.

---

## Phase 13a PR 7: Close local CI Android build gap

> **Status:** PLANNED. Tooling/process fix surfaced by the `sentry_flutter 8 → 9` upgrade on PR #46. Single-line Makefile change + a CLAUDE.md docs update. Independent of PR 6 — can ship before, after, or in parallel.

### Finding

`make ci` currently runs `format + analyze + gen + test`. It does **not** run any Android build step. The `sentry_flutter 8 → 9` upgrade on the PR 5 branch (PR #46) hit a Kotlin language-version compile error inside the bumped plugin's native Android code. `dart analyze` and `flutter test` are entirely Dart-side checks — they cannot detect Gradle/Kotlin/Java compile failures in plugin native code. The break only surfaced on GitHub Actions' `build` job, which means we pushed a broken branch and burned CI cycles to discover it.

This applies to any plugin with native Android code (`sentry_flutter`, `hive`, `cached_network_image`, `flutter_dotenv`, `package_info_plus`, `wakelock_plus`, anything FFI-based) — every dep upgrade that touches such a plugin can re-trigger the same class of failure.

### Fix options considered

1. **(Recommended) Add `flutter build apk --debug --no-shrink` to `make ci`.** Adds ~3 minutes to the local gate. Catches the failure before push every time. Downside: slower local iteration loop — `make ci` is no longer instant.
2. Add a separate `make ci-android` target invoked only when `pubspec.yaml` or `android/` files changed. Conditional gate, faster default path, but requires git-aware tooling and is more complex to maintain.
3. Keep `make ci` fast and document in `CLAUDE.md` that `flutter build apk --debug` MUST be run when `pubspec.yaml` or `android/` files change. Discipline-based — already failed us once on PR #46.

### Decision

**Option 1.** The 3-minute cost is the price of catching native plugin failures pre-push deterministically. Discipline-based gates have proven unreliable in this codebase.

### Implementation (single tiny PR)

**Files to touch:**

- `Makefile` — add `flutter build apk --debug --no-shrink` as the **last** step of the `ci` target (after `test`, so a unit test failure short-circuits before the slow build runs).
- `CLAUDE.md` — update the "Commands" section so the `make ci` line accurately reflects `format + analyze + gen + test + android-debug-build`. Add a one-line note that `make ci` now takes ~3-5 minutes due to the Android build step.

**Suggested Makefile diff (illustrative — implementer may adjust target ordering for parallelism):**

```makefile
ci: format analyze gen test build-android-debug

build-android-debug:
	flutter build apk --debug --no-shrink
```

**`--no-shrink` rationale:** the goal is "does Gradle/Kotlin compile cleanly", not "does R8 shrink correctly". Skipping shrink saves ~30s per run. R8 shrinking is exercised by the `release` build job in CI's `build.yml`, so we don't lose coverage.

### Acceptance criteria

- [ ] `make ci` includes a step that runs `flutter build apk --debug --no-shrink`
- [ ] `make ci` fails with a non-zero exit code if the Android debug APK build fails
- [ ] **Verification by deliberate breakage:** temporarily inject a Gradle syntax error in `android/app/build.gradle.kts`, run `make ci`, confirm it goes red on the new step. Revert the breakage. Re-run `make ci`, confirm it goes green. (Capture the red/green output in the PR body.)
- [ ] `CLAUDE.md` Commands section updated to reflect the new gate scope
- [ ] CI pipeline (`ci.yml`) is **NOT** modified — this PR only changes the local gate. CI's existing `build` job already covers this on the remote, so no parallel work is needed there.
- [ ] Wall-clock time for `make ci` post-change is documented in the PR body (expected: ~3-5 min, up from ~1-2 min)

### Testing strategy

This is a one-line Makefile change. The 7-gate strategy from PR 6 does not apply. Verification is:

1. Run `make ci` on a clean checkout — must pass
2. Inject a deliberate Gradle break (e.g., `applicationId "broken syntax"`), run `make ci` — must red on the new step
3. Revert the break, run `make ci` again — must green
4. Capture and paste both runs into the PR body as evidence

### Out of scope

- No CI workflow changes (`ci.yml` stays as-is)
- No iOS build added (no Mac CI runner; iOS deferred per project scope)
- No release-build added to `make ci` (too slow for local; CI handles it)
- No conditional build logic based on changed files (rejected as Option 2 above)
- No new tests — this is a Makefile change

### Time estimate

**0.5-1 agent-hour.** Single-line Makefile edit + verification by breakage + CLAUDE.md doc update + PR write-up.

### Sequencing relative to PR 6

PR 7 is **independent** of PR 6 — the Makefile change has zero overlap with the dep upgrade. Recommended order:

- **Ship PR 7 FIRST** (it's a 1-hour PR that protects PR 6). With the new `make ci` gate in place, PR 6's commits each get an Android build check before push, catching native plugin breakage from `flutter_dotenv 5→6`, `riverpod 2→3`, etc., at the local gate.
- Alternative: ship PR 6 first if the user prioritizes the dep sweep — but then PR 6's commits skip the Android build pre-push gate and rely on GitHub Actions to catch any plugin breakage.

---

## Phase 14: Offline Support

> Users are in gyms — basements, metal walls, dead zones. The app must let them finish a workout without a network. Phase 14 makes that a first-class experience without adopting a full offline-first sync engine.

**Scope shift:** Phase 13 B7 ("Offline workout save & retry") is absorbed into this phase. B7 scoped only the sync worker; Phase 14 is broader — read cache, sync service, PR reconciliation, UX indicators — because partial offline is worse than no offline (users don't know what's saved).

### Design Principles

- **Single-user app, no conflict resolution.** Workouts are append-only; profile and routines are last-write-wins with `updated_at`. Don't over-engineer for collaborative edits.
- **The active workout is sacred.** Once started, finishing it offline must succeed. Everything else (browsing, editing) can degrade gracefully.
- **Idempotent writes only.** Every queued mutation must be safe to replay. `save_workout` RPC is naturally replay-safe (delete-and-reinsert of `workout_exercises` + `sets` within a transaction) — verified in 14b preconditions.
- **Server is still the source of truth.** Local caches are read-through; the queue is a buffer, not a store. No merge logic, no vector clocks.
- **Instant UX over strict correctness.** Compute PR celebration locally from `pr_cache` for immediate dopamine; reconcile on sync drain. Rare divergence silently corrected.
- **Fail loud but recoverable.** Terminal failures surface in the sync indicator + Sentry breadcrumb; never silently drop.

### Preconditions (already in place)

- `HiveService` opens `active_workout`, `offline_queue`, `user_prefs` boxes (`lib/core/local_storage/hive_service.dart`). `offline_queue` is scaffolded but unused — Phase 14 wires it.
- `WorkoutLocalStorage` persists active workout state with schema-version guard — crash-safe in-progress workouts already work.
- `save_workout` is a single atomic Postgres RPC (`lib/features/workouts/data/workout_repository.dart`) that takes the whole payload and returns the saved `Workout` — trivially queueable as a single unit.
- **`PRDetectionService` is already a pure-function Dart service** at `lib/features/personal_records/domain/pr_detection_service.dart` — no extraction work needed for 14d.
- `PRRepository.upsertRecords` already uses `onConflict: 'user_id, exercise_id, record_type'` — replay-safe.
- All writes use client-generated UUIDs.
- Phase 13a Sprint A observability (Sentry + analytics) lands before this phase — Phase 14 leans on both for sync telemetry.

### Known constraints (IMPORTANT for scope)

- **`save_workout` RPC requires the `workouts` row to already exist on the server.** It does `UPDATE workouts ... WHERE id = v_workout_id` and raises `P0002` if the row is missing (see `supabase/migrations/00005_save_workout_rpc.sql`). The row is created earlier by `WorkoutRepository.createActiveWorkout()` — a regular insert.
  - **Consequence:** Phase 14 supports "workout started online, finished offline" (the common case). "Workout started fully offline" is **out of scope for v1 of this phase** unless a migration upgrades `save_workout` to upsert the `workouts` row itself. Track separately if needed later.
  - Replay of a `save_workout` call with the same `workout.id` IS safe — the RPC delete-and-reinserts `workout_exercises` and `sets` each call.

### 14a: Connectivity + Read-Through Cache Foundation

**Goal:** The app opens and functions (read-only) with zero network.

- Add `connectivity_plus` dependency (verified absent — zero matches across `lib/`).
- New `onlineStatusProvider` (Riverpod `StreamProvider<bool>`) exposing a debounced connectivity stream (500ms) to filter link-up flapping.
- New `OfflineBanner` widget (48dp top strip, `colorScheme.errorContainer`, "Offline — changes will sync when you're back online") — mounted app-wide via the shell route.
- Read-through cache on repos (new pattern — `BaseRepository` has no cache hook, so each repo gets its own cache helper):
  - `ExerciseRepository.getExercises({muscleGroup, equipmentType})` — cache to Hive box `exercise_cache`, keyed by composite filter (`"all"` / `"muscle=chest"` / `"equip=barbell"` / `"muscle=chest&equip=barbell"`).
  - `ExerciseRepository.searchExercises(query, …)` — when offline, fall back to in-memory filter over the `"all"` cache entry. Server-side `ilike` cannot be replicated offline, so cache the full list and filter in Dart.
  - `RoutineRepository.getRoutines(userId)` — cache to `routine_cache`. The repo hydrates each routine with an `Exercise` map via `_fetchExerciseMap` — the cache must snapshot **both** the routine rows **and** the resolved exercise map so `startFromRoutine()` works offline without a second query.
  - `PRRepository.getRecordsForUser(userId)` + `getRecordsForExercises(ids)` — cache to `pr_cache`. This powers 14d's local PR detection.
  - `WorkoutRepository.getWorkoutHistory(…)` — cache the most recent ~50 finished workouts for the history view.
  - `WorkoutRepository.getLastWorkoutSets(exerciseIds)` — cache to `last_sets_cache` so `startFromRoutine()` can pre-fill weights offline.
- Cache pattern: read cache first (emit immediately), network second, write fresh results back. On network error, fall back to cache silently. Stale-while-revalidate.
- Cache invalidation: `app_opened` triggers background refresh of all caches. Writes invalidate affected keys.
- New Hive boxes: `exercise_cache`, `routine_cache`, `pr_cache`, `workout_history_cache`, `last_sets_cache`. Register in `HiveService.init()` + `clearAll()` alongside the existing three boxes.
- `finishedWorkoutCount` — cache in `user_prefs` box, incremented locally on each offline finish, reconciled on sync drain. Needed by `PRDetectionService.detectPRs(totalFinishedWorkouts:)` for accurate first-workout flag.

**Not in scope for 14a:** writes. Still online-only.

### 14b: Offline Workout Capture + Queue

**Goal:** Finishing a workout offline persists locally and surfaces as "pending sync".

- **Precondition audit (first task of the phase):** Re-verify `save_workout` replay semantics against the migration (`00005_save_workout_rpc.sql`). Current state: replay-safe **given the `workouts` row exists on server**. Document this in a test fixture so it can't regress silently.
- New Freezed model `PendingWorkoutSave` — full RPC payload (`workout`, `exercises`, `sets`) + `queued_at` + `retry_count` + `last_error?`.
- Refactor `WorkoutRepository.saveWorkout()` — always write to `offline_queue` first, then attempt network. On success, delete from queue and return the server `Workout`. On network failure, leave in queue and return a locally-constructed `Workout` (copy of the input with `isActive=false`, `finishedAt` set) so the UI can proceed.
- `ActiveWorkoutNotifier.finishWorkout()` — unchanged at the caller level. Semantics become "may be locally-committed, may be server-committed". Downstream (`prRepo.getRecordsForExercises`, `_repo.getFinishedWorkoutCount`, `prRepo.upsertRecords`, `weeklyPlanProvider.markRoutineComplete`) all need to handle offline:
  - `getRecordsForExercises` → read through `pr_cache` (14a covers the cache).
  - `getFinishedWorkoutCount` → read from cached counter in `user_prefs`, increment locally.
  - `upsertRecords` → enqueue in `offline_queue` as a separate item type.
  - `markRoutineComplete` → enqueue in `offline_queue`; accept "best-effort" semantics on drain (current code already tolerates failure).
- "Pending sync" badge in the home stat strip (amber, "1 workout pending sync"). Tap → list view with manual retry per item.

### 14c: Sync Service + Backoff + Observability

**Goal:** When connectivity returns, the queue drains reliably and visibly.

- New `SyncService` (Riverpod `AsyncNotifier`):
  - Watches `onlineStatusProvider`.
  - On offline→online transition, drains `offline_queue` FIFO.
  - Exponential backoff: 1s → 2s → 4s → 8s → max 30s, max 6 attempts per item.
  - Distinguish transient (5xx, network, timeout) from terminal (4xx, auth) — terminal items move to `failed_queue` box with captured error.
  - `SentryReport.addBreadcrumb()` per retry attempt.
  - Analytics events: `workout_sync_queued`, `workout_sync_succeeded`, `workout_sync_failed` (with `retry_count`, `elapsed_seconds_in_queue`, `error_class`). Emitted via the existing `AnalyticsRepository.insertEvent()` pipeline that Phase 13a PR 5 establishes.
- UX:
  - Home header pill: "Syncing 2 workouts…" → "All synced ✓" → auto-hide after 3s.
  - Tap pending badge → details list with "Retry now" per item.
  - Terminal failures: persistent warning banner + "Contact support" CTA.

### 14d: Local PR Detection + Reconciliation

**Goal:** Celebrate PRs immediately on finish, even offline, without getting them wrong on reconnect.

- **No service extraction needed** — `PRDetectionService.detectPRs(...)` is already a pure-function Dart service. Phase 14d is purely about routing its inputs through caches and deferring its outputs through the queue.
- Reroute `ActiveWorkoutNotifier.finishWorkout()` PR block:
  - `existingRecords` ← read from `pr_cache` (14a) instead of live `prRepo.getRecordsForExercises()`.
  - `totalFinishedWorkouts` ← read from cached `user_prefs.finishedWorkoutCount`, then increment.
  - Run `PRDetectionService.detectPRs(...)` → show celebration immediately.
  - `prRepo.upsertRecords(newRecords)` → enqueue in `offline_queue`.
  - Update `pr_cache` optimistically with `newRecords` so subsequent offline finishes see them.
- On sync drain success, refresh `pr_cache` from the server (`prRepo.getRecordsForUser`) to pick up any server-side corrections. Compare against optimistic cache state:
  - Drift is expected to be near-zero in single-user single-device usage (detection is deterministic). Log any divergence as a Sentry breadcrumb (not an error).
  - Do NOT re-celebrate server-only PRs; accept rare false-positive client PRs as cost of instant feedback.

### 14e: Polish + Edge Cases

- Offline app open: skip network auth refresh, use last-known-good session, show offline banner.
- Starting a workout from a cached routine offline: works as long as `createActiveWorkout` succeeded online previously — but `createActiveWorkout` is itself a network call. **For full offline-start to work, `createActiveWorkout` must also be queued OR the `save_workout` RPC must be upgraded to upsert the workout row.** v1 scope: starting a workout requires connectivity; finishing does not. Show a clear snackbar when `startWorkout`/`startFromRoutine` fails offline.
- Starting from an uncached routine: snackbar "This routine is not cached — open it online first."
- Queue persists across restarts (Hive is disk-backed — free).
- Sign-out cascades cache clear through `HiveService.clearAll()` — update `clearAll()` to include the new caches.
- Test coverage:
  - Unit: `SyncService` backoff/retry, queue model serialization, cache read-through fallback, `finishWorkout` offline path through `PRDetectionService`.
  - Widget: `OfflineBanner`, pending-sync badge states, failed-sync banner, celebration with local detection + cached records.
  - E2E: Playwright network-offline simulation (`context.setOffline(true)`) → start workout online → go offline → finish → restore network → verify queue drains + workout appears in history.

### Out of Scope (defer)

- **Fully offline workout start** (requires `save_workout` RPC upgrade to upsert workout row, OR queueing `createActiveWorkout`).
- Offline edits to routines, profile, or weekly plan — single-user, low-value, high-complexity.
- Full offline-first via PowerSync or Brick — oversized for current product stage.
- Cross-device sync conflict resolution — single-device assumed.

### Risks

| Risk | Mitigation |
|------|------------|
| `save_workout` RPC semantics change (loses replay-safety) | Pin with a migration test + `save_workout` unit test that re-calls with the same payload twice. |
| User assumes offline-start works | Clear messaging on `startWorkout` failure + explicit banner copy. |
| Local PR detection drifts from server | Detection is already deterministic; `pr_cache` is refreshed every `app_opened` + on drain. Drift is narrow. |
| Sync storm after long offline | FIFO + backoff naturally throttles. |
| Cache staleness | `app_opened` refresh + pull-to-refresh escape hatch. |
| Users don't trust "pending sync" | Prominent amber badge + count + tap-to-details. Terminal failure = loud banner. |
| Terminal-failed queue items accumulate | `failed_queue` + support CTA + manual clearance via profile. |
| `finishedWorkoutCount` drifts from server | Reconcile on drain via `_repo.getFinishedWorkoutCount(userId)`. |

### Dependencies on Earlier Phases

- **Phase 13a (observability):** Sentry breadcrumbs + analytics pipeline. Phase 14 emits events through the same plumbing.
- **Phase 12.x (weekly plan):** `WeeklyPlanNotifier` state must remain network-cached for offline plan display; `markRoutineComplete` becomes a queueable action.
- **Phase 7 (personal records):** `PRRepository` reads + `PRDetectionService` power local PR detection.
- **Phase 5 (workout logging):** `save_workout` RPC, `ActiveWorkoutNotifier`, `WorkoutLocalStorage` are the core surface.

### Effort Estimate

- 14a: ~3-4 days (connectivity + 5 read caches + banner + count cache)
- 14b: ~2-3 days (queue model + repo refactor + pending-sync UI + PR/plan enqueue rewiring)
- 14c: ~3-4 days (sync service + backoff + UX + analytics)
- 14d: ~1-2 days (smaller than originally scoped — no extraction, just rewiring)
- 14e: ~2-3 days (edge cases + E2E)

**Total: ~2 weeks, shippable as 3-5 PRs.**

---

## Phase 15: Gamification Foundation

> Adapted from GAMIFICATION.md. RPG layer tightly coupled to real training data — "your strength IS your character."

### Design Principles

- Every game mechanic must be defensible with real training logic
- Gamification only in post-workout overlay and profile — never interrupts logging
- No punishment for rest days, no streak anxiety, no confetti
- Beginners see only XP bar + level for first 30 days
- Stats normalized to personal best (0-100 scale), not population norms

### 15a: PR Celebration Overlay (Phase 1)

Full-screen overlay (not dialog). Background `#0F0F23` at 0.96 opacity. Dismissible with tap.
- XP animation: `+N XP` tween from 0 to final over 600ms, color `#FFFFFF60` -> `#00E676`
- Stat bumps: staggered cascade below XP
- PR section: amber `#FFD54F` band, `NEW RECORD` label, exercise name + new value
- Level up: green vignette glow, scale punch animation, `LEVEL UP` label

### 15b: XP & Level System (Phase 2)

**XP formula:** `Base(50) + Volume(floor(kg/500)) + Intensity((rpe-5)*10) + PR(+100/+50) + Quest(+75)`
**Level curve:** `XP for Level N = 500 * N^1.5` (fast early, meaningful later)
**Ranks:** Rookie(0) -> Iron(2.5K) -> Bronze(10K) -> Silver(25K) -> Gold(60K) -> Platinum(125K) -> Diamond(250K)

Computed from existing data — retroactive for existing users. Never decreases, never paywalled.

### 15c: Weekly Streak (Phase 1)

- Weekly consistency meter: 7 segments (Mon-Sun), trained=green, not-trained=neutral (NOT red)
- Streak: consecutive weeks meeting training frequency goal. Resets only if entire week missed
- Comeback bonus (2x XP) instead of shame on miss
- Lives on Profile screen (character sheet)

### 15d: Profile -> Character Sheet

Same `/profile` URL. Identity block with `LVL N` badge, XP bar (6dp height, `#00E676`), weekly consistency band.

### 15e: Home Screen Integration

One line replacing date subtitle: `[LVL 12] . [14d streak] . [Mon, Apr 7]`
Daily quest chip (44dp, dismissible) between stat cards and routine list.

---

## Phase 16: Gamification Advanced

### 16a: Weekly Smart Quests (Phase 3)

3 auto-generated per week: one improvement, one exploration, one consistency. Never expire with failure state. Completion gives bonus XP, never access to core features.

New schema: `quests` table (`user_id`, `week`, `type`, `target`, `completed_at`).

### 16b: Training Stats Panel (Phase 4)

Six stats computed from real workout data:
- Strength (`#FF6B6B`), Endurance (`#40C4FF`), Power (`#FF9F43`), Consistency (`#00E676`), Volume (`#9B8DFF`), Mobility (`#26C6DA`)

Hexagonal radar chart on profile (`CustomPaint`). Animates once on mount. Below chart: 2x3 grid of stat chips.

### Anti-Patterns (Explicitly Banned)

Confetti, streak flames/emoji, badge walls, multiple progress bars on home, level-gated features, push notification streak anxiety, XP in persistent header, animated badges, global leaderboards, punitive daily streaks, class XP multipliers, social infrastructure.

---

## Phase 17: Nice-to-Have (v2.0+)

| Feature | Notes |
|---------|-------|
| Character classes | Powerlifter/Athlete/Warrior — cosmetic + stat-weighting only |
| Light social (opt-in) | Friends list, ranks, monthly challenges. No global feeds |
| Achievement milestones | Timeline entries, NOT badge collections |
| Plate calculator | Intermediate lifters think in plates |
| Body weight tracking | Correlate volume with weight changes |
| Dark/Light mode toggle | Some users prefer light in bright gyms |
| WearOS integration | Not critical for launch |
| Localization (i18n) | English-only for launch |
| App review prompt | Ask happy users for store review |
| Seasonal content | Battle passes, dungeon/boss — only if v1.0 research shows demand |

### Monetization Path

**Free forever:** Core logging, routines, exercise library, XP/level, PR tracking, streaks, 3 weekly quests.
**Pro ($5-8/month):** Training stats panel + charts, expanded quests, class selection, PR history with e1RM, CSV export.
**Cosmetic (one-time):** Avatar items, rank icons, XP bar themes.
**Never paywalled:** Historical data, personal records, core progression.

---

## QA Status (as of 2026-04-08)

> Full manual QA plan: `tasks/manual-qa-testplan.md` (89 cases, 29 automated).

**All Critical and High bugs resolved** (52+ items across PRs #24-#32). See git history for full audit trails.

### Open

| ID | Severity | Issue | Notes |
|----|----------|-------|-------|
| QA-005 | High | Exercise image URLs return 404 from GitHub | DEFERRED to Phase 13 (P4). Fallback icon works |

### Feature Gaps (v1.1+)

Edit custom exercises, per-exercise notes in workout, RPE tracking (widget exists, hidden), reorder exercises in routine builder, edit workout post-hoc, PRs in bottom nav. (~~offline caching beyond active workout~~ — covered by Phase 14.)

---

## Verification & Testing

### CI Pipeline (GitHub Actions)

- `ci.yml`: 3 parallel jobs — `analyze` (format + lint + secret scan), `test` (flutter test --coverage), `build` (APK + web). Gate job `ci` depends on all three.
- `e2e.yml`: Flutter web build -> Playwright. Smoke on PRs (<3 min), full on merge (<10 min).
- `release.yml`: `v*` tags -> split APKs -> GitHub Release.

### Test Layers

- **Unit** (`flutter_test` + `mocktail`): Models, repositories, business logic, providers. Target 80%+ on business logic.
- **Widget** (`flutter_test`): Screen states (loading/data/error/empty), interactions, form validation, conditional UI.
- **E2E** (Playwright on Flutter web): Critical journeys — auth, workout, PRs, routines, crash recovery. `flt-semantics[aria-label="..."]` selectors.

### E2E Structure

```
test/e2e/
  playwright.config.ts, global-setup.ts, global-teardown.ts
  helpers/  auth.ts, workout.ts, navigation.ts, selectors.ts
  fixtures/ test-users.ts, test-exercises.ts
  smoke/    auth, workout, pr, routine-start, workout-restore, exercise-form-tips, routine-error,
            weekly-plan, onboarding, routine-management, pr-display, weekly-plan-review, profile-weekly-goal
  full/     auth, exercise-library, workout-logging, routines, personal-records,
            home-navigation, crash-recovery, routine-regression, exercise-detail-sheet, manage-data
```

Test users created via Supabase Admin API in `global-setup.ts`. Unique user per test — parallel-safe.

---

## UX Design Direction

- **Typography:** Body at w500. Weight/reps/timer at 28-32sp (hero content). Condensed font for numbers.
- **Colors:** Gradient accents for primary actions (`#00E676` -> `#00BFA5`). Destructive gradient (`#FF5252` -> `#D32F2F`). PR amber `#FFD54F`.
- **Cards:** Subtle 1dp top border with primary green at 15% opacity.
- **Spacing:** Tight within set rows (8dp), generous between exercises (24dp). Not uniform.
- **Icons:** Filled/bold variants (Material Symbols weight 600+).
- **Touch targets:** 48dp+ interactive, 56dp+ for workout logging primary actions. One-handed thumb-reachable.
- **Anti-patterns:** No pastel colors, no thin-line icons, no uniform padding, no generic Material Design.

### Competitive Position

| Feature | Strong | Hevy | GymBuddy |
|---------|--------|------|----------|
| Progress charts | Yes | Yes | **No** (Phase 13) |
| 1RM estimation | Yes | Yes | **No** (Phase 13) |
| Exercise library | ~350 | ~650 | **~60** (Phase 13) |
| RPG gamification | No | No | **Planned** (Phase 15-16) |
| Offline support | Yes | Yes | **Planned** (Phase 14) |
| Rest timer | Yes | Yes | Yes |
| Routines | Yes | Yes | Yes |
| PR detection | Yes | Yes | Yes |
| Weekly planning | No | No | Yes (Step 12) |
