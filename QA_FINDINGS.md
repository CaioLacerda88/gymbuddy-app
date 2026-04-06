# QA Findings — Manual Testing & Code Review

**Date:** 2026-04-05
**Branch:** `fix/remove-web-renderer-flag`
**Reviewed by:** QA Engineer (browser testing), Product Owner (code analysis), UI/UX Critic (design review)
**App URL:** http://localhost:4200 → Production Supabase (`dgcueqvqfyuedclkxixz.supabase.co`)

---

## How to read this document

Each finding has:
- **ID** — prefixed by source: `QA-` (browser testing), `PO-` (product/code analysis), `UX-` (design review)
- **Severity** — Critical / High / Medium / Low
- **Category** — Functional, UX, Visual, Accessibility, Performance, Data Integrity
- **File(s)** — where the fix goes
- **Cross-refs** — related findings from other reviewers

Findings are grouped by severity, then by area.

---

## Critical (Blocks core usage)

### QA-001: Workout save fails silently — `save_workout` RPC returns 404

**Category:** Functional
**File:** Supabase migration / `supabase/migrations/`
**Steps to reproduce:**
1. Log in, start empty workout, add exercise, set weight/reps, mark set done
2. Click "Finish Workout" → confirm in dialog

**Expected:** Workout saves, app navigates to PR celebration or home.
**Actual:** App stays on `#/workout/active`. Console shows `404 @ /rest/v1/rpc/save_workout`. No error shown. Workout data is silently lost.
**Impact:** The primary user journey is completely broken. No workouts can be saved, no PRs detected, no history accumulates.
**Root cause:** The `save_workout` RPC function likely does not exist in the production database, or was not included in migrations.

---

### QA-002: Blank home screen after routing from `/workout/active` with no active workout

**Category:** Functional
**File:** `lib/core/router/app_router.dart`, `lib/features/workouts/ui/active_workout_screen.dart`
**Steps to reproduce:**
1. Log in
2. Navigate directly to `http://localhost:4200/#/workout/active` (e.g. browser back button) when no workout is active
3. App redirects to `#/home`

**Expected:** Home screen renders normally.
**Actual:** Home screen is completely blank (black) — only the bottom nav bar renders. Console shows `Multiple widgets used the same GlobalKey [GlobalObjectKey int#98d5f]`.
**Impact:** Any browser history navigation, bookmarks, or deep links to the workout screen causes the app to become unusable without a full page reload.

---

### PO-026: Workout history detail navigation is broken — wrong route path

**Category:** Functional
**File:** `lib/features/workouts/ui/workout_history_screen.dart:84`
**Details:** `onTap` navigates to `context.go('/history/${workouts[index].id}')` but the router defines the detail route as `/home/history/:id` (nested under shell). The path `/history/:id` does not exist in the route table.
**Impact:** Tapping any row in workout history crashes or shows a blank screen. History is completely non-functional.

---

### PO-017 / PO-018: Starting a new workout silently abandons any in-progress workout

**Category:** Data Integrity
**File:** `lib/features/workouts/providers/notifiers/active_workout_notifier.dart:60-75`, `lib/features/workouts/ui/home_screen.dart:152-155`
**Details:** The "Start Empty Workout" button calls `startWorkout()` without checking if a workout is already in progress (saved in Hive from crash recovery). The new workout overwrites the Hive data, silently losing the previous workout. `ResumeWorkoutDialog` exists in the codebase but is never shown at this entry point.
**Impact:** Users who had an in-progress workout (e.g., app crash, phone call) lose all their data when starting a new workout.

---

### PO-001: `needsOnboardingProvider` set to true before signup completes

**Category:** Functional
**File:** `lib/features/auth/ui/login_screen.dart:54-56`
**Details:** The onboarding flag is set before `signUpWithEmail` is awaited. If signup fails (e.g., email already registered), the flag stays `true`. Next login attempt redirects to onboarding instead of home.
**Impact:** Users can get stuck in onboarding after a failed signup attempt.

---

### UX-V01: Exercise name in active workout is too small to read mid-workout

**Category:** Visual
**File:** `lib/features/workouts/ui/active_workout_screen.dart`, `_ExerciseCard`
**Details:** Exercise name uses `titleMedium` (16sp, w600). Under gym lighting, mid-rep, users cannot quickly identify which exercise they're on. Should be `headlineMedium` (24sp, w700) minimum — it's the most important text on the card.

---

### UX-U02: Swipe-to-delete a set has no undo — data loss risk

**Category:** UX / Data Integrity
**File:** `lib/features/workouts/ui/widgets/set_row.dart:76-89`
**Details:** `Dismissible.onDismissed` immediately calls `notifier.deleteSet`. The SnackBar shows "Set N deleted" but has no "Undo" action. With sweaty gym hands, accidental swipes are common.
**Impact:** Users lose completed set data with no recovery path.

---

## High

### QA-003: Custom exercise deletion fails with 403 Forbidden

**Category:** Functional
**File:** Supabase RLS policies on `exercises` table
**Steps to reproduce:**
1. Create a custom exercise
2. Open its detail screen → Delete Exercise → Confirm

**Expected:** Exercise is deleted.
**Actual:** Console shows `403 Forbidden @ /rest/v1/exercises?id=eq.{uuid}&user_id=eq.{uuid}`. No error shown to user.
**Root cause:** RLS policy on `exercises` table does not allow DELETE for the exercise owner.

---

### QA-004: Profile update (weight unit toggle) fails with 400 Bad Request

**Category:** Functional
**File:** `lib/features/profile/ui/profile_screen.dart`, Supabase `profiles` table schema
**Steps to reproduce:**
1. Log in, navigate to Profile tab
2. Click "lbs" weight unit button

**Expected:** Weight unit changes to lbs.
**Actual:** Console shows `400 Bad Request @ /rest/v1/profiles?id=eq.{uuid}`. Profile card changes to "Gym User" with no email.
**Cross-ref:** PO-038 (no loading/error handling on toggle), PO-037 (weight unit not wired to workout UI anyway)

---

### QA-005: Exercise images return 404 from GitHub

**Category:** Functional / Visual
**File:** `lib/features/exercises/` (image URL construction)
**Details:** Multiple 404 errors for exercise images:
- `https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Bench_Press/0.jpg` → 404
- `https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Push-Ups/0.jpg` → 404

**Root cause:** The GitHub repository folder structure uses different naming conventions than what the app constructs.
**Impact:** All exercise images are broken throughout the app.

---

### QA-006: "Forgot password?" triggers reset immediately with no confirmation

**Category:** UX
**File:** `lib/features/auth/ui/login_screen.dart`
**Details:** Clicking "Forgot password?" immediately sends a reset email using whatever is in the email field. If rate-limited (429), the error appears in the login error banner, misleading users into thinking their login failed.
**Cross-ref:** PO-003 (no follow-up screen after reset email sent)

---

### QA-007: "Create Exercise" form shows no validation errors when submitted empty

**Category:** UX
**File:** `lib/features/exercises/ui/create_exercise_screen.dart`
**Steps to reproduce:** Open create exercise form → click CREATE EXERCISE without filling any field
**Expected:** Validation errors on required fields.
**Actual:** Nothing happens. No feedback whatsoever.

---

### QA-008: "Start Empty Workout" button hidden below fold on home screen

**Category:** UX / Visual
**File:** `lib/features/workouts/ui/home_screen.dart:150-160`
**Details:** The button is a low-prominence `TextButton.icon` positioned below 4-5 routine cards, hidden behind the bottom nav bar. Users must scroll to find the primary action.
**Cross-ref:** UX-V03 (same finding from design review — should be at minimum `OutlinedButton` or secondary FAB, pinned above fold)

---

### PO-012: Exercise picker → Create Exercise → return flow is broken

**Category:** Functional
**File:** `lib/features/workouts/ui/widgets/exercise_picker_sheet.dart:175-179`
**Details:** "Create Exercise" button does `Navigator.pop(context)` then `router.push('/exercises/create')`. When user returns from create screen, the picker sheet is gone. They must re-open it and find the exercise they just created.

---

### PO-006: Onboarding completion has no error handling

**Category:** Functional
**File:** `lib/features/auth/ui/onboarding_screen.dart:41-49`
**Details:** `_finishOnboarding()` has no try/catch. If `saveOnboardingProfile` throws (network error, RLS violation), the function still calls `context.go('/home')` and sets `needsOnboardingProvider = false`. User goes to home with no profile saved and is never asked to complete onboarding again.

---

### PO-019: Discard workout order-of-operations creates orphaned state risk

**Category:** Data Integrity
**File:** `lib/features/workouts/providers/notifiers/active_workout_notifier.dart:460-469`
**Details:** `discardWorkout()` calls Supabase DELETE first, then `clearActiveWorkout()` on Hive. If the app crashes between the two operations, Hive retains orphaned workout data that can never be saved to the server.
**Fix:** Clear Hive first (local, fast), then delete the server record.

---

### PO-032: Routine save has no error handling

**Category:** Functional
**File:** `lib/features/routines/ui/create_routine_screen.dart:87-90`
**Details:** `_save()` calls `createRoutine()`/`updateRoutine()` then immediately `context.pop()` without checking success. If the Supabase call throws, user is sent back to list with no error message and the routine is not saved.

---

### PO-036: Logout bypasses authNotifierProvider

**Category:** Functional
**File:** `lib/features/profile/ui/profile_screen.dart:187`
**Details:** Logout calls `ref.read(authRepositoryProvider).signOut()` directly on the repository instead of `ref.read(authNotifierProvider.notifier).signOut()`. The `authNotifierProvider` state is never updated from this call path.

---

### PO-037: Weight unit preference is completely non-functional

**Category:** Functional
**File:** `lib/features/profile/ui/profile_screen.dart`, workout UI files
**Details:** The kg/lbs toggle saves to the profile table, but the active workout's weight steppers, "Last:" hints, and PR values never read `profileProvider.weightUnit`. The entire feature is UI-only with no effect.
**Cross-ref:** PO-021 (`SetRow` line 98 hardcodes `kg`), QA-004 (toggle fails with 400 anyway)

---

### PO-044: PR detection failure silently skips saving records

**Category:** Data Integrity
**File:** `lib/features/workouts/providers/notifiers/active_workout_notifier.dart:528-534`
**Details:** PR detection failure is caught and logged, but `finishWorkout()` returns `null` instead of a `PRDetectionResult`. The records are not persisted because `upsertRecords` is inside the try block. User gets no celebration and their PRs are lost.

---

### UX-I01: Weight/reps stepper repeat interval of 100ms is too fast

**Category:** UX / Interaction
**File:** `lib/shared/widgets/weight_stepper.dart:38-40`, `reps_stepper.dart`
**Details:** `Timer.periodic(100ms)` = 10 increments/second. Holding `+` for 2 seconds jumps 25kg. Impossible to land on a target weight.
**Fix:** Start delay 400ms, begin at 200ms repeat, accelerate to 80ms after 10 repeats (progressive acceleration).

---

### UX-V02: Weight and reps values have identical visual treatment — no hierarchy

**Category:** Visual
**File:** `lib/features/workouts/ui/widgets/set_row.dart`
**Details:** Both weight and reps are 28sp, w800, primary green. Identical twins. The eye has nowhere to land first. They need visual separation — different scale or unit labels ("kg", "reps") for context.

---

### UX-U04: "Finish Workout" button disabled with no explanation

**Category:** UX
**File:** `lib/features/workouts/ui/active_workout_screen.dart:275-287`
**Details:** `onPressed: _hasCompletedSet ? _onFinish : null` — disabled with no tooltip. New users who enter weight/reps but don't check the checkbox stare at an unresponsive button with no guidance.
**Cross-ref:** PO-020 (same finding — users who uncheck all sets get stuck)

---

### UX-D01: Two primary button widgets (`AppButton` and `GradientButton`) used inconsistently

**Category:** Design System
**File:** `lib/shared/widgets/app_button.dart`, `lib/shared/widgets/gradient_button.dart`
**Details:** Some screens use `AppButton`, some raw `FilledButton`, some `ElevatedButton`, some `GradientButton`. No single source of truth for primary CTAs. Visual inconsistency across the app.

---

### UX-A01: Google sign-in button uses wrong icon (`Icons.g_mobiledata`)

**Category:** Accessibility / Visual
**File:** `lib/features/auth/ui/login_screen.dart:266-281`
**Details:** `Icons.g_mobiledata` is a mobile data icon that happens to start with "G". It is NOT the Google logo. Confuses users expecting the branded Google button.

---

## Medium

### QA-011: Navigation tooltip labels appear persistently on bottom nav bar

**Category:** Visual
**File:** `lib/core/router/app_router.dart`, `_ShellScaffold`
**Details:** After clicking tabs, tooltip labels ("Exercises", "Routines") appear floating above the nav bar as separate elements, creating duplicate labels.

---

### QA-012: Exercise detail screen shows broken/empty chart area

**Category:** Visual
**File:** `lib/features/exercises/ui/exercise_detail_screen.dart`
**Details:** Chart area shows "Start" and "End" labels but no chart content — just a blank dark area above "No records yet". Widget renders but with no meaningful content.

---

### PO-002: Email confirmation screen shows blank email after app restart

**Category:** Functional
**File:** `lib/features/auth/ui/email_confirmation_screen.dart:44`
**Details:** `signupPendingEmailProvider` is in-memory `StateProvider`. If user closes app after signup but before confirming email, the provider resets to `null`. The confirmation screen shows a blank email address.

---

### PO-005: Onboarding allows empty display name

**Category:** Functional
**File:** `lib/features/auth/ui/onboarding_screen.dart:41-49`
**Details:** `_finishOnboarding()` accepts empty string for display name. No validation. Profile screen falls back to "Gym User".

---

### PO-008: Home screen has layout shift when workout history loads

**Category:** UX / Performance
**File:** `lib/features/workouts/ui/home_screen.dart:119-121`
**Details:** `historyAsync` loading shows `SizedBox.shrink()`. Routines load first, then recent workouts section appears, shifting "Start Empty Workout" button down. Needs skeleton placeholders.

---

### PO-009: Home screen may render duplicate "STARTER ROUTINES" sections

**Category:** Functional
**File:** `lib/features/workouts/ui/home_screen.dart:56-114`
**Details:** Logic at line 98 re-renders starter routines when user has their own routines, potentially duplicating the section.

---

### PO-013: Exercise detail screen uses raw Future, never refetches

**Category:** Functional / Stale Data
**File:** `lib/features/exercises/ui/exercise_detail_screen.dart:30-33`
**Details:** Uses `_exerciseFuture` from `initState` that never re-fires. Should use `FutureProvider.family` to participate in the invalidation graph.

---

### PO-029: "First Workout" celebration triggers for veteran users trying new exercises

**Category:** Functional
**File:** `lib/features/personal_records/domain/pr_detection_service.dart:90-92`
**Details:** `isFirstWorkout` is inferred from per-exercise record state, not user profile. A veteran user who picks a new exercise sees the first-workout celebration incorrectly.

---

### PO-030: PR volume displayed as "kg" instead of "kg-reps" or "Volume"

**Category:** UX
**File:** `lib/features/personal_records/ui/pr_list_screen.dart:108-109`
**Details:** `RecordType.maxVolume` formats as `'$value kg'`. A 100kg x 5 set shows as "500 kg" which looks like a weight, not a volume.

---

### PO-033: Routine action sheet (edit/delete) is copy-pasted between two files

**Category:** Code Quality
**File:** `lib/features/workouts/ui/home_screen.dart`, `lib/features/routines/ui/routine_list_screen.dart`
**Details:** `_showRoutineActions` is duplicated. Any fix needs to be applied in two places.

---

### PO-041: `/pr-celebration` route has no guard — crashes on missing `state.extra`

**Category:** Functional
**File:** `lib/core/router/app_router.dart:88-90`
**Details:** Route immediately casts `state.extra` as `Map<String, dynamic>`. If navigated to without extra data (deep link, developer mistake), the app throws `TypeError`.

---

### UX-V04: Routine cards have no visual affordance that they launch workouts

**Category:** Visual
**File:** `lib/features/routines/ui/widgets/routine_card.dart`
**Details:** No play icon, no "Start" label, no gradient accent. Looks like a list entry, not a workout launcher.

---

### UX-V06: PR celebration screen is visually flat for an emotional moment

**Category:** Visual
**File:** `lib/features/personal_records/ui/pr_celebration_screen.dart`
**Details:** Green flash fades in 200ms. First-workout path shows a default `Icon(Icons.emoji_events, size: 64)`. The moment deserves more visual energy.

---

### UX-V07: Section headers at 50% opacity may fail WCAG contrast

**Category:** Accessibility
**File:** `lib/features/workouts/ui/home_screen.dart`, `_SectionHeader`
**Details:** `alpha: 0.5` on white over `#0F0F1A` is borderline. WCAG AA requires 4.5:1 for normal text. Raise to at least 0.65.

---

### UX-V08: Bottom navigation bar is completely unstyled Material 3 defaults

**Category:** Visual / Design System
**File:** `lib/core/router/app_router.dart:191-212`
**Details:** No custom indicator color, background, or selected/unselected icon distinction. "Routines" uses `Icons.calendar_today` (looks like scheduling, not fitness). Telegraphs "generated app."

---

### UX-U03: Long-press to swap exercise in active workout is completely invisible

**Category:** UX
**File:** `lib/features/workouts/ui/active_workout_screen.dart:516-525`
**Details:** `GestureDetector(onLongPress: _swapExercise)` with zero visual cue. No underline, no trailing icon, no haptic on start. Users must discover this by accident.

---

### UX-U05: Copy-last-set interaction (tap set number) is undiscoverable

**Category:** UX
**File:** `lib/features/workouts/ui/widgets/set_row.dart:110-163`
**Details:** Tapping the set number to copy previous session values is a hidden gesture. The "last set" hint is at 0.4 alpha and barely visible. Needs a visible "copy" affordance.

---

### UX-U06: Profile screen has almost no content — no stats, no streaks, no PR count

**Category:** UX
**File:** `lib/features/profile/ui/profile_screen.dart`
**Details:** Shows only: display name, email, kg/lbs toggle, logout. No lifetime stats, no streak indicator, no account management. Users open profile to feel progress — currently it's a settings stub.

---

### UX-U09: Rest timer overlay blocks entire workout — cannot check next set during rest

**Category:** UX
**File:** `lib/features/workouts/ui/widgets/rest_timer_overlay.dart`
**Details:** `Material(color: Colors.black87)` overlay blocks everything. User must skip timer to check or edit their next set. Need a minimized/collapsed state or semi-transparent overlay.

---

### UX-I05: Set type cycling (long-press set number: W → WU → D → F) is completely hidden

**Category:** UX / Interaction
**File:** `lib/features/workouts/ui/widgets/set_row.dart:46-51`
**Details:** Four set types cycling on long-press of a tiny number badge. No user will ever discover this. Needs a visible tap-to-expand pill or long-press indicator.

---

## Low

### PO-004: Password field retains value when toggling login/signup modes

**Category:** UX
**File:** `lib/features/auth/ui/login_screen.dart:36`
**Details:** Error clears on toggle but password field persists. Minor security concern on shared devices.

---

### PO-007: Onboarding has no back navigation from page 2 to page 1

**Category:** UX
**File:** `lib/features/auth/ui/onboarding_screen.dart:85-86`
**Details:** `NeverScrollableScrollPhysics()` prevents swipe-back. No back button exists. User is stuck on page 2 if they want to re-read the welcome screen.

---

### PO-010: Home screen routines error state has no retry button

**Category:** UX
**File:** `lib/features/workouts/ui/home_screen.dart:51-52`
**Details:** Shows static "Failed to load routines" text with no retry action.

---

### PO-016: Exercise list has no pull-to-refresh

**Category:** UX
**File:** `lib/features/exercises/ui/exercise_list_screen.dart`
**Details:** Only way to refresh is navigate away and back.

---

### PO-028: History screen "load more" has no loading indicator

**Category:** UX
**File:** `lib/features/workouts/ui/workout_history_screen.dart`
**Details:** Scrolling to bottom triggers `loadMore()` but shows no visual indicator.

---

### PO-031: PR cards are not tappable — no link to source workout or exercise

**Category:** UX
**File:** `lib/features/personal_records/ui/pr_list_screen.dart`

---

### PO-039: No way to change display name after onboarding

**Category:** Missing Feature
**File:** `lib/features/profile/ui/profile_screen.dart`

---

### UX-V05: Login screen icon `Icons.fitness_center` reads as placeholder art

**Category:** Visual
**File:** `lib/features/auth/ui/login_screen.dart:131-136`

---

### UX-V10: Shell `_ActiveWorkoutBanner` and home `ResumeWorkoutBanner` are redundant

**Category:** Visual
**File:** `lib/core/router/app_router.dart:216-282`, `lib/features/workouts/ui/widgets/resume_workout_banner.dart`
**Details:** Both show when workout is active on home screen, stacked with different padding/height.

---

### UX-D03: Border radius inconsistency — 8, 12, 16 used with no documented rule

**Category:** Design System
**File:** Multiple files
**Details:** Card theme uses 16, buttons use 12, chips use 8, FABs use 24-28. No spatial scale documented.

---

### UX-D05: `_SectionHeader` widget duplicated in home_screen.dart and routine_list_screen.dart

**Category:** Code Quality
**File:** `lib/features/workouts/ui/home_screen.dart`, `lib/features/routines/ui/routine_list_screen.dart`
**Details:** Identical widget defined in two places. Extract to `lib/shared/widgets/section_header.dart`.

---

## Missing Features (Product gaps worth noting)

| Feature | Current State | Competitor Reference |
|---------|--------------|---------------------|
| Edit custom exercises | Not implemented | Strong, Hevy both support |
| Per-exercise notes in workout | Model exists, no UI | Strong, Hevy ship this |
| RPE tracking | Widget exists but disabled | Hevy, Strong have this |
| Reorder exercises in routine builder | Not implemented (active workout has it) | Strong, Hevy support |
| Edit workout name/notes post-hoc | Read-only detail screen | Hevy allows this |
| Offline caching (exercises, history) | Only active workout (Hive) | Strong, Hevy cache locally |
| Dark/Light mode toggle | Dark only | Most apps support system preference |
| Personal records in bottom nav | Only accessible via home "View All" | Strong, Hevy, JEFIT put it in nav |

---

## Recommended Priority for Tech Lead

### Fix immediately (blocks real usage)
1. ~~**QA-001** — `save_workout` RPC 404~~ **FIXED** — migration pushed to prod
2. ~~**PO-026** — History detail route~~ **FIXED** — path corrected
3. ~~**PO-017/018** — Gate "Start Workout"~~ **FIXED** — resume/discard dialog added
4. ~~**QA-003** — Fix RLS policy for exercise DELETE~~ **FIXED** — migration 00006
5. ~~**QA-004** — Fix profiles table schema~~ **FIXED** — migration 00006

### Fix next (causes churn after day 3)
6. ~~**PO-001** — Move `needsOnboardingProvider`~~ **FIXED**
7. ~~**PO-006** — Add error handling to onboarding~~ **FIXED**
8. ~~**PO-032** — Wrap routine save in try/catch~~ **FIXED**
9. ~~**PO-036** — Route logout through authNotifier~~ **FIXED**
10. ~~**PO-037** — Wire `weightUnit` preference to workout UI~~ **FIXED** — reads from profileProvider
11. **QA-005** — Fix exercise image URLs (need migration) — **DEFERRED** — fallback icon works
12. ~~**QA-002** — Fix GlobalKey conflict~~ **FIXED** — route guard + in-memory check
13. ~~**UX-I01** — Fix stepper repeat rate~~ **FIXED** — 400ms delay + 150ms repeat
14. ~~**UX-U02** — Add undo to swipe-to-delete~~ **FIXED**

### Fix in next sprint (polish)
15. ~~**QA-008 / UX-V03** — Elevate "Start Empty Workout" button prominence~~ **FIXED** — OutlinedButton full-width
16. ~~**UX-U04 / PO-020** — Explain why "Finish Workout" is disabled~~ **FIXED** — helper text
17. ~~**QA-007** — Add validation to create exercise form~~ **FIXED**
18. ~~**PO-012** — Fix exercise picker → create → return flow~~ **FIXED** — push over picker
19. ~~**PO-041** — Guard `/pr-celebration` route~~ **FIXED**
20. ~~**PO-029** — Fix false "First Workout" celebration~~ **FIXED**

---

## Verification Sweep #2 (2026-04-05)

### Fix verification results

| Fix | Status | Notes |
|-----|--------|-------|
| QA-001 save_workout RPC | **PASS** | Migration 00005 pushed, RPC exists |
| QA-003 exercise delete 403 | **PASS** | Migration 00006 fixed RLS USING/WITH CHECK |
| QA-004 weight unit toggle | **PASS** | Toggle switches correctly, no 400 error |
| QA-007 create exercise validation | **PASS** | "Name is required" shows on empty submit |
| PO-026 history route | Needs workout save to verify |
| PO-029 first workout false positive | **FIXED** in code, needs e2e verify |
| UX-I01 stepper rate | **FIXED** — 400ms delay + 150ms repeat |
| UX-U02 set delete undo | **FIXED** — SnackBar with 4s undo action |

### New issues found during verification

**NEW-001 CRITICAL (FIXED): Active workout route race condition**
Route guard for `/workout/active` read Hive synchronously but `_saveToHive()` was `unawaited`. Fixed: guard now checks in-memory `activeWorkoutProvider.valueOrNull` first, falls back to Hive.

**NEW-002 HIGH: Production database not seeded with exercises**
The `SEED_EXERCISES` constants (Barbell Bench Press, Squat, etc.) reference exercises from `supabase/seed.sql` that were never loaded into production. Exercise list is empty for new users.
**Fix:** Run `supabase db reset --linked` or manually seed via SQL.

**NEW-003 MEDIUM: Duplicate workout banner on Home screen**
Home shows TWO workout banners: `ResumeWorkoutBanner` (in scroll content) and `_ActiveWorkoutBanner` (in shell). Redundant chrome.
**Fix:** Hide `ResumeWorkoutBanner` on home screen since shell banner is always visible.

**NEW-004 MEDIUM: DartError on login→home focus traversal**
`Cannot get renderObject of inactive element` during login→home transition. Focus system accesses login TextField after screen disposal.

**NEW-005 LOW: Validation error persists after typing in exercise name**
"Name is required" doesn't clear while typing. Need `autovalidateMode: AutovalidateMode.onUserInteraction`.

**NEW-006 LOW: Forgot password SnackBar disappears too quickly**
Success feedback visible for ~1-2 seconds. Need longer duration.

**NEW-007 LOW: "Discard" in resume dialog immediately starts new workout**
May not be user intent. Consider just discarding and returning to home.

### Remaining open items (prioritized for next sprint)

**All "Must fix" and "Should fix" items resolved in this PR.** Remaining:

1. **QA-005** — Fix exercise image URLs (external GitHub repo naming mismatch, fallback icon works) — **DEFERRED**
2. **NEW-004** — DartError on login→home focus traversal — **LOW**
3. **NEW-005** — Validation error persists after typing in exercise name — **LOW**
4. **NEW-006** — Forgot password SnackBar disappears too quickly — **LOW**
5. **NEW-007** — "Discard" in resume dialog immediately starts new workout — **LOW**

**Fixes applied in this round:**
- ~~NEW-002~~ **FIXED** — Migration 00007 seeds default exercises idempotently
- ~~PO-037~~ **FIXED** — Weight unit reads from profileProvider, displays in set_row + stepper
- ~~PO-019~~ **FIXED** — Hive cleared before server delete
- ~~PO-012~~ **FIXED** — Create exercise pushed over picker (picker stays visible)
- ~~QA-008~~ **FIXED** — OutlinedButton, full-width, 52px height
- ~~UX-U04~~ **FIXED** — Helper text: "Complete at least one set to finish"
- ~~NEW-003~~ **FIXED** — Removed duplicate ResumeWorkoutBanner from home
- ~~PO-005~~ **FIXED** — Empty display name validation in onboarding
- ~~PO-044~~ **FIXED** — PR persistence wrapped in inner try/catch
- Profile monogram avatar (replaced generic person icon)
- Rest timer shows exercise name instead of "Rest"

### E2E test enrichments added

| File | Tests Added |
|------|-------------|
| `test/e2e/smoke/exercise.smoke.spec.ts` (NEW) | 6 tests: list loads, validation, create, search, delete, muscle filter |
| `test/e2e/smoke/workout.smoke.spec.ts` | 1 test: full save journey verification |
| `test/e2e/smoke/auth.smoke.spec.ts` | 1 test: forgot password flow |
| `test/e2e/fixtures/test-users.ts` | Added `smokeExercise` user |
| `test/e2e/global-setup.ts` | Added user to creation list |
| **Total** | 76 tests in 12 files (was 68 in 11) |
