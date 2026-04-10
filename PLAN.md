# GymBuddy — Master Plan

## Quick Reference

Gym training app for logging workouts, tracking personal records, and managing exercises. Flutter + Supabase + Riverpod. Android-first, iOS deferred. Dark bold theme, gym-floor UX (one-handed, glanceable, sweat-proof).

**Market context:** $12B+ fitness app market, 70% abandoned within 90 days. Core differentiator: RPG gamification tightly coupled to real training data (see Phase 14-15).

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
| 13 | Production Readiness (remaining Sprint A: B1, P6, B4, B2, B3, W2) | IN PROGRESS | - |
| 14 | Gamification Foundation (XP, Levels, Streaks) | TODO | - |
| 15 | Gamification Advanced (Quests, Stats Panel) | TODO | - |
| 16 | Nice-to-Have (v2.0+) | BACKLOG | - |

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
| Phase 14-15: Gamification | Implementing RPG system |
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

**Gamification hooks (Phase 14+):** Consistency stat delta, quest XP — hidden until gamification system is built.

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
- No streak counter until Phase 14 (broken streaks demoralize)

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
| B1 | Release signing | 1-2h | `build.gradle.kts` uses debug signing. Create release keystore, wire into Gradle, store password in GitHub Secrets |
| B2 | Crash reporting | 2-3h | Sentry Flutter SDK. Wire into `AppException` hierarchy. Breadcrumbs for key user actions |
| B3 | Analytics (basic events) | 3-4h | `signup`, `login`, `first_workout_completed`, `workout_finished`, `routine_started`, `pr_broken`, `app_opened`. Options: PostHog, Amplitude, Mixpanel free tier |
| B4 | Privacy Policy & ToS | 1 day | Hosted URL required by Play Store. Cover data collected, storage, retention, user rights. Link from Profile + store listing |
| ~~B5~~ | ~~Account deletion~~ | DONE (#42) | Edge Function `delete-user` + AuthRepository.deleteAccount + Manage Data UI with type-DELETE confirmation. Cascade via existing FKs. |
| B6 | ProGuard/R8 optimization | 2-3h | No minify/shrink today (19.7MB → ~12-14MB). Need keep rules for Supabase + Hive reflection |
| B7 | Offline workout save & retry | 1-2 days | Hive queue exists but no sync worker. Detect connectivity failure on `finishWorkout()` → queue → retry. `connectivity_plus` package |

### 13b: Product Gaps (blocks retention, not submission)

| ID | Item | Effort | Notes |
|----|------|--------|-------|
| P1 | Progress charts per exercise | 2-3 days | **#1 retention driver.** Line chart: weight over time. `fl_chart` or `syncfusion_flutter_charts`. Query sets+workouts by exercise_id. Without this, no "am I getting stronger?" feedback loop. |
| P2 | Exercise library expansion to 150+ | 1 day | Currently ~92. Users lose confidence when searches return 2-3 results. Priority: compound movements, isolation staples, sport-specific |
| ~~P3~~ | ~~Forgot password flow~~ | ~~done~~ | ~~Already implemented in `login_screen.dart:92-115`~~ |
| P4 | Exercise images fix (QA-005) | 3-4h | GitHub URLs return 404. Migrate to Supabase Storage or CDN. Broken images signal abandoned product. |
| P5 | 1RM estimation | 2-3h | Epley formula. Display on exercise detail + PR cards |
| P6 | App branding | 1 day | App label "gymbuddy_app" → "GymBuddy". Custom launcher icon + splash. Play Store assets |
| ~~P7~~ | ~~Volume unit display~~ | DONE (#42) | `formatVolume()` takes weightUnit; threaded through home_screen + workout_detail_screen (per-set rows + totals). |
| P8 | New-user empty-state CTA | 2-3h | When no workouts logged and no plan: show "Start your first workout" hero + beginner routine recommendation on home screen. Currently drops user at empty state with no guidance. **(PO finding)** |

### 13c: UX Polish (pre-launch quality bar)

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

### 13d: Warnings (fix before or shortly after launch)

| ID | Item | Effort |
|----|------|--------|
| ~~W1~~ | ~~OAuth deep link registration~~ | DONE (#42) — AndroidManifest intent-filter for `io.supabase.gymbuddy` |
| W2 | Wakelock during active workout | 1h |
| W3 | Stale workout timeout UX | 2-3h | When `startedAt` >6h ago on app open, show prominent modal: "Workout from [date] still open — Resume or Discard?" (deferred from Step 12.3) |
| W3b | Input length limits (TextField + server CHECK) | 1-2h |
| W4 | Push notifications (workout reminders) | 1-2 days |
| W5 | Data export (CSV/JSON) | 3-4h |
| W6 | Direct Supabase access in UI (bypass repo pattern) | 30min |
| W7 | Supabase free tier monitoring (500MB DB, upgrade at 500 DAU) | - |
| W8 | HomeScreen `SingleChildScrollView` → `CustomScrollView` | 2-3h |

### Suggested Sprint Order

**Sprint A — Store-ready:** ~~B5~~ ~~P7~~ ~~W1~~ (PR #42), remaining: B1, B4, P6 (PR 2), B2, B3, W2 (PR 3)
**Sprint B (1 week) — Retention + polish:** P1, P2, P4, P8, UX1-UX8
**Sprint C (1 week) — Resilience:** B6, B7, W3, W3b, W6, W8
**Deferred to v1.1:** P5 (1RM), W4 (push notifications), W5 (CSV export)

> **PO strategic note:** Consider shipping Phase 14a (XP overlay + level badge) alongside launch for competitive differentiation vs Strong/Hevy. Without it, GymBuddy is a feature-subset of established competitors.

---

## Phase 14: Gamification Foundation

> Adapted from GAMIFICATION.md. RPG layer tightly coupled to real training data — "your strength IS your character."

### Design Principles

- Every game mechanic must be defensible with real training logic
- Gamification only in post-workout overlay and profile — never interrupts logging
- No punishment for rest days, no streak anxiety, no confetti
- Beginners see only XP bar + level for first 30 days
- Stats normalized to personal best (0-100 scale), not population norms

### 14a: PR Celebration Overlay (Phase 1)

Full-screen overlay (not dialog). Background `#0F0F23` at 0.96 opacity. Dismissible with tap.
- XP animation: `+N XP` tween from 0 to final over 600ms, color `#FFFFFF60` -> `#00E676`
- Stat bumps: staggered cascade below XP
- PR section: amber `#FFD54F` band, `NEW RECORD` label, exercise name + new value
- Level up: green vignette glow, scale punch animation, `LEVEL UP` label

### 14b: XP & Level System (Phase 2)

**XP formula:** `Base(50) + Volume(floor(kg/500)) + Intensity((rpe-5)*10) + PR(+100/+50) + Quest(+75)`
**Level curve:** `XP for Level N = 500 * N^1.5` (fast early, meaningful later)
**Ranks:** Rookie(0) -> Iron(2.5K) -> Bronze(10K) -> Silver(25K) -> Gold(60K) -> Platinum(125K) -> Diamond(250K)

Computed from existing data — retroactive for existing users. Never decreases, never paywalled.

### 14c: Weekly Streak (Phase 1)

- Weekly consistency meter: 7 segments (Mon-Sun), trained=green, not-trained=neutral (NOT red)
- Streak: consecutive weeks meeting training frequency goal. Resets only if entire week missed
- Comeback bonus (2x XP) instead of shame on miss
- Lives on Profile screen (character sheet)

### 14d: Profile -> Character Sheet

Same `/profile` URL. Identity block with `LVL N` badge, XP bar (6dp height, `#00E676`), weekly consistency band.

### 14e: Home Screen Integration

One line replacing date subtitle: `[LVL 12] . [14d streak] . [Mon, Apr 7]`
Daily quest chip (44dp, dismissible) between stat cards and routine list.

---

## Phase 15: Gamification Advanced

### 15a: Weekly Smart Quests (Phase 3)

3 auto-generated per week: one improvement, one exploration, one consistency. Never expire with failure state. Completion gives bonus XP, never access to core features.

New schema: `quests` table (`user_id`, `week`, `type`, `target`, `completed_at`).

### 15b: Training Stats Panel (Phase 4)

Six stats computed from real workout data:
- Strength (`#FF6B6B`), Endurance (`#40C4FF`), Power (`#FF9F43`), Consistency (`#00E676`), Volume (`#9B8DFF`), Mobility (`#26C6DA`)

Hexagonal radar chart on profile (`CustomPaint`). Animates once on mount. Below chart: 2x3 grid of stat chips.

### Anti-Patterns (Explicitly Banned)

Confetti, streak flames/emoji, badge walls, multiple progress bars on home, level-gated features, push notification streak anxiety, XP in persistent header, animated badges, global leaderboards, punitive daily streaks, class XP multipliers, social infrastructure.

---

## Phase 16: Nice-to-Have (v2.0+)

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

Edit custom exercises, per-exercise notes in workout, RPE tracking (widget exists, hidden), reorder exercises in routine builder, edit workout post-hoc, offline caching beyond active workout, PRs in bottom nav.

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
| RPG gamification | No | No | **Planned** (Phase 14-15) |
| Offline support | Yes | Yes | Partial (Phase 13) |
| Rest timer | Yes | Yes | Yes |
| Routines | Yes | Yes | Yes |
| PR detection | Yes | Yes | Yes |
| Weekly planning | No | No | Yes (Step 12) |
