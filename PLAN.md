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
| 13a-PR6 | Bulk Dependency Upgrade + Toolchain Refresh (Riverpod 3, GoRouter 17, Freezed 3) | DONE | #49 |
| 13a-PR7 | Close local CI Android build gap (`make ci` runs `flutter build apk --debug`) | DONE | #47 |
| 13a-PR8 | E2E overhaul: Flutter 3.41.6 AOM selectors, bug fixes, restructure to feature files | DONE | #50 |
| 13 | Launch — last phase before Play Store (Sprint B Retention + Sprint C Resilience remaining) | IN PROGRESS | - |
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
| Phase 13: Launch | Final work before Play Store submission |
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
- **State:** Riverpod `^3.3.1` (AsyncNotifier pattern)
- **Local:** Hive (active workout cache, offline queue)
- **Models:** Freezed `^3.0.0` + json_serializable
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

## 13a-PR8: E2E Overhaul — AOM Selectors, Bug Fixes, Feature-Based Restructure (DONE — PR #50)

- **Flutter 3.41.6 AOM migration:** Replaced all `flt-semantics[aria-label="..."]` CSS selectors with `role=TYPE[name*="..."]` Playwright selectors. Flutter no longer sets `aria-label` as DOM attributes — accessible names are communicated via the browser's Accessibility Object Model.
- **App bug fixes:** Exercise delete navigation (captured GoRouter before async gap, `router.go('/exercises')` instead of `context.pop()`). RLS policy `exercises_select_own_deleted` for soft-delete visibility. Hive saves awaited in `ActiveWorkoutNotifier` (prevent data loss on web reload).
- **Strict mode fixes:** `.first()` / `.last()` on SnackBar text and search input locators where Flutter renders dual DOM elements.
- **Restructure:** Flattened `smoke/` (16 files) + `full/` (11 files) into `specs/` (11 feature-based files). Replaced directory-based organization with Playwright `{ tag: '@smoke' }` on describe blocks. Standardized naming: `test('should ...')`, bug IDs parenthesized.
- **Removed:** 2 tests for unimplemented RECENT RECORDS feature. Unskipped 6 previously-skipped tests (delete nav, EX-003, BUG-003 smoke + full).
- **Result:** 145 passed, 0 failed, 0 skipped. 994 unit/widget tests. Key files: `specs/*.spec.ts`, `helpers/selectors.ts`, `playwright.config.ts`, `exercise_detail_screen.dart`, `active_workout_notifier.dart`, `supabase/migrations/00017_fix_exercise_soft_delete_rls.sql`.

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

## Phase 13: Launch

> Final phase before Play Store submission. Everything after this (Phase 14 Offline Support, Phase 15-16 Gamification) is post-launch.
> Structure: **Sprint A — Store Blockers** (complete) → **Toolchain Bridge** (complete) → **Sprint B — Retention** (next) → **Sprint C — Resilience** → submit.

### Completed

**Sprint A — Store blockers**
- PR #42: Account deletion, volume unit display, OAuth deep link
- PR #43: Release signing, branding strings, privacy policy + ToS
- PR #44: Sprint A QA follow-ups (legal polish, PWA theme, live delete E2E)
- PR #45: Wakelock during active workout
- PR #46: Observability — Sentry crash reporting (PII-scrubbed) + first-party `analytics_events` table with 8 ratified events

**Toolchain bridge**
- PR #47: `make ci` gained `flutter build apk --debug --no-shrink` to catch native plugin breakage pre-push
- PR #49: Bulk dependency upgrade — Riverpod 3, GoRouter 17, Freezed 3 (34 deps swept, 994/994 tests pass, APK/Web size unchanged)
- PR #50: E2E overhaul — Flutter 3.41.6 AOM selectors, feature-based restructure (11 spec files, 145 tests with @smoke tags), exercise soft-delete RLS fix
- PR #51: Phase 13c removed from plan (Athletic Brutalism redesign conflicted with RPG gamification direction)

### Remaining — Sprint B: Retention (~5-6 days, PO-refined 2026-04-13)

Order is deliberate: visible trust fixes → shortest standalone → content foundation → highest-retention feature on clean foundations.

| Slot | ID | Item | Effort | Rationale |
|------|----|------|--------|-----------|
| 1 | P4 | Exercise images fix (404s) | 3-4h | Broken images on every tile. Migrate from GitHub URLs to Supabase Storage or CDN. Unblocks P9 visually. |
| 2 | P8 | New-user empty-state CTA + beginner routine recommendation | 2-3h | First-run users currently hit a dead end. CTA points to a routine produced in P9. |
| 3 | P9 | Exercise description + form_tips standard (absorbs P2) | 1.5 days | Backfills 32 content-less exercises from migration `00014` AND ships the 150+ library expansion in one PR. No exercise ships without description + form_tips. PR adds the CLAUDE.md convention: exercise-insert migrations must pair with a descriptions migration. |
| 4 | P1 | Progress charts per exercise | 2-3 days | #1 retention driver. `fl_chart` line chart of weight-over-time per exercise. Handles zero/one-data-point states without crash. |

**P2** (count-only library expansion) is absorbed into P9 — shipping 150 exercises with 50+ empty detail sheets is worse UX than today's 92 with 60% coverage.

### Remaining — Sprint C: Resilience (~3-4 days)

| ID | Item | Effort | Notes |
|----|------|--------|-------|
| B6 | ProGuard/R8 optimization | 2-3h | No minify/shrink today (19.7MB → ~12-14MB target). Needs keep rules for Supabase + Hive reflection. |
| W3 | Stale workout timeout UX | 2-3h | When `startedAt` >6h ago on app open, show "Workout from [date] still open — Resume or Discard?" modal. |
| W3b | Input length limits (TextField + server CHECK) | 1-2h | Prevents DB bloat and UI overflow on long free-text inputs. |
| W6 | Direct Supabase access in UI (bypass repo pattern) | 30min | Cleanup of residual `supabase.from()` calls outside repositories. |
| W8 | HomeScreen `SingleChildScrollView` → `CustomScrollView` | 2-3h | Performance fix for long history lists. |

### Deferred to v1.1+

- **P5** — 1RM estimation (Epley formula on exercise detail + PR cards)
- **W4** — Push notifications (workout reminders)
- **W5** — Data export (CSV/JSON)
- **W7** — Supabase free-tier monitoring (ongoing ops task, not a ship gate)
- **App icon redesign** — awaits post-launch direction decision

### Out of Scope for Phase 13

- **Gamification (Phase 15-16).** No XP, levels, streaks, quests, or badges land in Phase 13 — the format is still being decided. Code written in this phase must remain scalable to a future gamification layer (clean data/UI separation, no hard-coded assumptions that would block later hooks), but no gamification features ship here.
- **Offline (Phase 14).** The original B7 scope ("offline workout save & retry") is superseded by the broader Phase 14 work.
- **iOS.** Android-first; iOS deferred.

### Exit Criteria — Ready to Submit to Play Store

1. `SELECT COUNT(*) FROM exercises WHERE is_default = true AND (description IS NULL OR form_tips IS NULL)` returns `0` on hosted Supabase
2. Zero image 404s on default exercise tiles (QA walkthrough against production storage)
3. New user sign-up → home shows "Start your first workout" CTA with beginner routine, not a blank list (E2E verified)
4. Any exercise with ≥2 logged sets shows a weight-over-time chart; zero/single-data-point states handled without crash (unit + QA)
5. All Sprint C items merged
6. APK size reduced via R8 (19.7MB → ~12-14MB target, documented in PR body)
7. Full CI green, 145/145 E2E pass, no critical open bugs in QA Status

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

## QA Status (as of 2026-04-13)

> Full manual QA plan: `tasks/manual-qa-testplan.md` (89 cases, 29 automated).

**All Critical and High bugs resolved** (52+ items across PRs #24-#32, plus PR #50 E2E overhaul). See git history for full audit trails.

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
- `e2e.yml`: Flutter web build -> Playwright. Full regression on every PR (~16 min, 145 tests).
- `release.yml`: `v*` tags -> split APKs -> GitHub Release.

### Test Layers

- **Unit** (`flutter_test` + `mocktail`): Models, repositories, business logic, providers. Target 80%+ on business logic. **994 tests.**
- **Widget** (`flutter_test`): Screen states (loading/data/error/empty), interactions, form validation, conditional UI.
- **E2E** (Playwright on Flutter web): Critical journeys — auth, exercises, workouts, routines, PRs, home, crash recovery, manage data, weekly plan, onboarding, profile. **145 tests (61 @smoke, 84 regression).**

### E2E Structure

```
test/e2e/
  playwright.config.ts, global-setup.ts, global-teardown.ts
  helpers/  auth.ts, app.ts, workout.ts, selectors.ts
  fixtures/ test-users.ts, test-exercises.ts
  specs/    auth, exercises, workouts, routines, home, crash-recovery,
            personal-records, profile, manage-data, weekly-plan, onboarding
```

**Organization:** Feature-based files in `specs/`. Smoke tests tagged with `{ tag: '@smoke' }` on their describe blocks. Run `--grep @smoke` for quick CI gate, no filter for full regression.

**Selectors:** `role=TYPE[name*="..."]` selectors (Playwright accessibility protocol). Flutter 3.41.6 uses AOM — `aria-label` is no longer a DOM attribute on most elements. All selectors centralized in `helpers/selectors.ts`.

**Naming convention:** `test.describe('Feature Name')` + `test('should ...')`. Bug IDs parenthesized at end: `test('should show error snackbar (BUG-003)')`.

**User isolation:** Unique test user per describe block, created in `global-setup.ts` via Supabase Admin API. No shared mutable state between test files. Inline `TEST_USERS.xxx` in `beforeEach` (no `const USER` aliases).

**Adding new E2E tests:** Place in the appropriate feature file in `specs/`. Tag with `{ tag: '@smoke' }` if it should run in the quick CI gate. Add a new test user in `fixtures/test-users.ts` + `global-setup.ts` if the test needs isolated state.

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
