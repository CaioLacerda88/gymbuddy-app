# GymBuddy Manual QA Test Plan

**Version:** 1.0  
**Date:** 2026-04-06  
**Scope:** All 9 implementation steps complete. Full regression + open bug verification.  
**Platform strategy:** Android-first. iOS not tested until infrastructure is available.

---

## 1. Test Environment Setup

### 1.1 Required Devices / Browsers

| Environment | Minimum Spec | Notes |
|-------------|-------------|-------|
| Physical Android device | Android 10+, 360dp screen width | Primary QA target — screen size stress-tests overflow bugs |
| Android emulator | Pixel 4 API 33 (or newer) | Fast iteration, not a substitute for physical device |
| Chrome (desktop) | Latest stable | Flutter Web — required for Playwright e2e path validation |

### 1.2 Backend Prerequisites

- Supabase project running (cloud or local Docker with `supabase start`)
- `.env` file at project root containing `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- Google OAuth redirect URLs configured in Supabase Auth dashboard (`com.gymbuddy.app://login-callback` for Android, `http://localhost:xxxx` for web)
- Seed data applied: `supabase/seed.sql` — 60 exercises + 4 starter routines with `is_default = true`
- At least one test user account that has completed onboarding (for regression passes)

### 1.3 Build Commands

```bash
export PATH="/c/flutter/bin:$PATH"

# Install dependencies
flutter pub get

# Android physical device or emulator
flutter run -d android

# Chrome (web)
flutter run -d chrome

# Release APK (for final physical device pass)
flutter build apk --split-per-abi
```

### 1.4 Test Account Setup

Create two test accounts before starting:

- **Account A** (`qa-tester-a@gymbuddy.test`): fresh account, no workout history — used to verify empty states and onboarding
- **Account B** (`qa-tester-b@gymbuddy.test`): seeded account with 5+ completed workouts, existing PRs, at least one custom exercise, and at least one custom routine — used for history, PR, and regression tests

### 1.5 Priority Definitions

| Priority | Definition |
|----------|-----------|
| P0 | Crash, data loss, or completely broken core flow. Must block release. |
| P1 | Major functional regression or significant UX failure. Should block release. |
| P2 | Minor UX issue, cosmetic, or low-frequency edge case. Track but does not block. |

---

## 2. Auth Flows

### AUTH-001 — Email signup (happy path)
**Priority:** P0  
**Steps:**
1. Open app on a fresh install (no cached session).
2. On login screen, tap "Create Account" or equivalent toggle.
3. Enter a valid new email and a password with 8+ characters.
4. Tap "Sign Up".

**Expected:** App transitions to email confirmation screen showing the entered email address. A "Resend" option is visible. No navigation to home yet.

---

### AUTH-002 — Email confirmation deep link (Android)
**Priority:** P0  
**Steps:**
1. Complete AUTH-001 above. Open email client on the same Android device.
2. Tap the verification link in the confirmation email.
3. Observe app behavior.

**Expected:** App opens (or foregrounds), detects the PKCE callback URL via `uriLinkStream`, confirms the session, and proceeds to onboarding flow. No blank screen or error dialog.

---

### AUTH-003 — Email login (returning user) `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P0  
**Steps:**
1. Log out of any active session (Profile tab → Logout).
2. On login screen, enter valid credentials for Account B.
3. Tap "Log In".

**Expected:** Brief loading indicator, then navigate to home screen. Bottom nav shows Home | Exercises | Routines | Profile.

---

### AUTH-004 — Login with wrong password `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P1  
**Steps:**
1. On login screen, enter valid email + intentionally wrong password.
2. Tap "Log In".

**Expected:** Error message shown inline or as a SnackBar. Message is readable (not raw Supabase error code). Button re-enables after error. No crash.

---

### AUTH-005 — Signup with existing email `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P1  
**Steps:**
1. Attempt to sign up using the email of Account B (already exists).
2. Tap "Sign Up".

**Expected:** Clear error message ("An account with this email already exists" or equivalent). No duplicate account created.

---

### AUTH-006 — Form validation on login screen `[AUTOMATED]`
**Priority:** P1  
**Steps:**
1. Tap "Log In" with empty email field.
2. Tap "Log In" with valid email but empty password field.
3. Enter an email without `@` and attempt to submit.

**Expected:** Inline validation errors appear for each case. Submit button is blocked or shows validation messages. No crash.

---

### AUTH-007 — Google sign-in (happy path)
**Priority:** P1  
**Steps:**
1. Tap the Google sign-in button on the login screen.
2. Select a Google account from the account picker.
3. Complete OAuth flow.

**Expected:** App returns to home or onboarding (if first login). Note: verify the Google button shows proper Google branding — known open bug UX-A01 (currently uses wrong icon `Icons.g_mobiledata`).

---

### AUTH-008 — Forgot password flow
**Priority:** P1  
**Steps:**
1. On login screen, tap "Forgot Password" link.
2. Observe what happens next.

**Expected:** A confirmation step or dedicated screen is shown before sending the reset email. Known open bug QA-006: currently the reset triggers immediately without confirmation. Verify current behavior and record if the confirmation step exists.

---

### AUTH-009 — Logout `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P0  
**Steps:**
1. Navigate to Profile tab.
2. Tap "Logout".
3. Confirm the action if a dialog appears.

**Expected:** Session is cleared. App redirects to login screen. Navigating back (Android back button) does not return to the authenticated home screen.

---

### AUTH-010 — Email confirmation screen after app restart
**Priority:** P1  
**Steps:**
1. Complete email signup (AUTH-001) so the confirmation screen is showing.
2. Kill the app completely.
3. Relaunch the app.

**Expected:** App should return to a sensible state (login screen or confirmation screen). Known open bug PO-002: confirmation screen may show blank email after restart. Record actual behavior.

---

### AUTH-011 — Session persistence (token refresh)
**Priority:** P0  
**Steps:**
1. Log in as Account B.
2. Navigate to Home, confirm data loads.
3. Put the app in background for several minutes (test token refresh if possible — simulate by waiting or using a debug build with shortened token expiry).
4. Foreground the app.

**Expected:** User remains logged in. Data still loads. No unexpected logout or error screen.

---

### AUTH-012 — Password retained across login/signup toggle
**Priority:** P2  
**Steps:**
1. On login screen, type a password into the password field.
2. Toggle to the signup form.
3. Observe the password field.

**Expected:** Ideally, the password field clears when toggling mode. Known low-priority bug PO-004: password is currently retained. Record actual behavior.

---

## 3. Onboarding

### ONBOARD-001 — Two-screen onboarding flow (new user)
**Priority:** P0  
**Steps:**
1. Sign up with a fresh email (no existing profile).
2. After email verification (or Google OAuth), observe the onboarding flow.

**Expected:** Exactly two screens:
- Screen 1: Welcome page with value prop text.
- Screen 2: Profile setup with "Display Name" text field and fitness level selector (Beginner / Intermediate / Advanced).
No page 3 with workout choice (removed in Step 5e).

---

### ONBOARD-002 — Profile data saved to Supabase
**Priority:** P0  
**Steps:**
1. Complete onboarding: enter display name "Test User QA" and select fitness level "Intermediate".
2. Tap the completion/continue button.
3. Navigate to Profile tab.

**Expected:** Profile tab shows "Test User QA" as the display name and "Intermediate" as fitness level. Data was upserted to Supabase `profiles` table (was bug C4 in Step 5e — previously silently discarded).

---

### ONBOARD-003 — Back navigation on onboarding
**Priority:** P2  
**Steps:**
1. Reach page 2 of onboarding.
2. Tap the Android back button or any visible back control.

**Expected:** Returns to page 1. Known low-priority bug PO-007: no back navigation from page 2. Record actual behavior.

---

### ONBOARD-004 — Onboarding not shown to returning users
**Priority:** P0  
**Steps:**
1. Log in as Account B (has completed onboarding).
2. Observe navigation after login.

**Expected:** Goes directly to home screen. Onboarding is NOT shown again.

---

## 4. Exercise Library

### EX-001 — Browse exercises by muscle group
**Priority:** P1  
**Steps:**
1. Navigate to Exercises tab.
2. Tap the "Chest" muscle group category button.
3. Observe the list.

**Expected:** List filters to chest exercises only. Muscle group buttons have large touch targets (min 64dp height). Filter chips are visible and selectable.

---

### EX-002 — Search exercises `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P1  
**Steps:**
1. On Exercises tab, tap the search field.
2. Type "bench".

**Expected:** List updates to show exercises matching "bench" (e.g., Bench Press, Incline Bench Press). Search is case-insensitive.

---

### EX-003 — Search does not return soft-deleted exercises `[AUTOMATED]`
**Priority:** P0  
**Steps:**
1. Create a custom exercise named "TestDeleteMe".
2. Delete that exercise (see EX-008).
3. Search for "TestDeleteMe".

**Expected:** No results. Soft-deleted exercises must not appear in search results.

---

### EX-004 — Filter by equipment type
**Priority:** P1  
**Steps:**
1. On Exercises tab, open the equipment filter.
2. Select "Barbell".

**Expected:** List shows only barbell exercises. Combine with a muscle group to verify AND-filter behavior.

---

### EX-005 — Filter combination zero results `[AUTOMATED]`
**Priority:** P1  
**Steps:**
1. Select muscle group "Core" + equipment "Kettlebell" (combination unlikely to have many exercises).
2. Observe result.

**Expected:** If no matches, empty state shows "No exercises match your filters" with a "Clear Filters" action button. No crash.

---

### EX-006 — Create custom exercise `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P1  
**Steps:**
1. Tap "Create Exercise" (from Exercises tab empty state or FAB).
2. Enter name "QA Custom Bench", select muscle group "Chest", equipment "Dumbbell".
3. Tap "Save".

**Expected:** Exercise appears in the list (in user's custom exercises section). Name matches exactly.

---

### EX-007 — Duplicate exercise name prevention `[AUTOMATED]`
**Priority:** P1  
**Steps:**
1. Attempt to create an exercise with the same name as an existing exercise for the same muscle group and equipment type (case-insensitive, e.g., "qa custom bench").
2. Tap "Save".

**Expected:** Validation error shown ("An exercise with this name already exists" or equivalent). No duplicate created.

---

### EX-008 — Soft delete custom exercise `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P1  
**Steps:**
1. Long-press or swipe on a custom exercise to reveal delete option.
2. Confirm deletion.

**Expected:** Exercise disappears from library and search results. Exercise is NOT permanently deleted from Supabase (soft delete — `deleted_at` is set). Past workouts referencing this exercise should still show the exercise name in history.

---

### EX-009 — Exercise detail screen
**Priority:** P1  
**Steps:**
1. Tap any exercise in the list to open the detail screen.

**Expected:** Detail screen shows exercise name, muscle group, equipment type. PR section renders conditionally (shows PRs if Account B has any for this exercise, hides if none). No crash or empty/broken chart area (known open bug QA-012).

---

### EX-010 — Exercise images (start/end position)
**Priority:** P2  
**Steps:**
1. Open the detail screen for an exercise that has seed images (e.g., Bench Press, Squat).
2. Observe image loading.
3. Open detail screen for an exercise without images.

**Expected:** For exercises with images: start/end images appear side-by-side (160dp row). Loading indicator shown while fetching. Tapping an image opens fullscreen overlay with close button. For exercises without images (or 404 responses): image section collapses entirely — no broken placeholder visible. Note: Known open bug QA-005 — GitHub-hosted image URLs return 404. Verify fallback behavior works correctly.

---

### EX-011 — Exercise list pull-to-refresh
**Priority:** P2  
**Steps:**
1. Navigate to Exercises tab.
2. Pull down to refresh.

**Expected:** List refreshes. Known low-priority bug PO-016: pull-to-refresh may not be implemented. Record actual behavior.

---

## 5. Workout Logging

### WK-001 — Start empty workout (no routine) `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P0  
**Steps:**
1. From Home screen, tap "Start Empty Workout".
2. Observe the workout screen.

**Expected:** Active workout screen opens. Workout is auto-named "Workout — [Day Mon DD]" (e.g., "Workout — Mon Apr 6"). No dialog or keyboard interaction required. Elapsed timer starts counting up.

---

### WK-002 — Add exercise to workout `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P0  
**Steps:**
1. In an active workout, tap "Add Exercise".
2. In the exercise picker bottom sheet, search for "Squat".
3. Tap "Squat" to select it.

**Expected:** Exercise card appears in the workout with at least one empty set row pre-populated. Exercise picker dismisses. Tap count: 3 taps maximum to reach the set row.

---

### WK-003 — Log a set (stepper interaction)
**Priority:** P0  
**Steps:**
1. On a set row, tap the "+" button on the weight stepper to increment weight to 60.
2. Tap the "+" button on the reps stepper to increment reps to 10.
3. Tap the set completion checkbox.

**Expected:** Weight and reps values update correctly. Stepper numbers are legible (28-32sp minimum as per Step 5e redesign). Checkbox marks the set as complete. Rest timer overlay appears after completion. Haptic feedback fires on set completion.

---

### WK-004 — Long-press stepper repeat rate
**Priority:** P1  
**Steps:**
1. Long-press the "+" button on the weight stepper.
2. Hold for 2 seconds.

**Expected:** Weight increments rapidly (repeat rate). Values do not jump erratically. Releasing the button stops incrementing. (Was bug UX-I01 — resolved, verify no regression.)

---

### WK-005 — Tap-to-type weight and reps `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P1  
**Steps:**
1. Tap directly on the weight number display in a set row.
2. A numpad or input overlay appears.
3. Type "37.5" and confirm.

**Expected:** Weight field accepts decimal input (37.5). Value updates correctly in the set row. Overlay dismisses cleanly.

---

### WK-006 — Pre-fill from last session
**Priority:** P1  
**Steps:**
1. Complete a workout with Bench Press: 80kg × 5.
2. Start a new empty workout.
3. Add Bench Press.

**Expected:** The first set row shows previous session data as hint/ghost text ("Last: 80kg × 5") or pre-fills the weight/reps fields with those values.

---

### WK-007 — Add set to exercise `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P0  
**Steps:**
1. With an exercise card in the active workout, tap "Add Set".

**Expected:** A new set row appears below the existing rows. "Add Set" button is full-width, 48dp height (min), and visually distinct (not a small TextButton). (Was fix I3 in Step 5e.)

---

### WK-008 — Rest timer
**Priority:** P1  
**Steps:**
1. Complete a set (tap checkbox). Rest timer overlay appears.
2. Observe the countdown.
3. Tap "Skip" to dismiss early.
4. Complete another set. When timer is running, tap "+30s" and "-30s".

**Expected:** Timer counts down from the configured rest duration (default 90s). Countdown is visible in large text. "+30s" and "-30s" buttons adjust the remaining time. "Skip" dismisses the overlay. Heavy haptic fires when timer completes. Screen stays awake during rest (wakelock — note: wakelock was deferred, verify current behavior).

---

### WK-009 — Copy last set
**Priority:** P2  
**Steps:**
1. Log one set with weight 100kg and reps 5 (mark as complete).
2. Tap the set number badge on that row.

**Expected:** A new set row is added below, pre-filled with the same weight (100kg) and reps (5). Known open bug UX-U05: this interaction is undiscoverable. Record whether it works functionally.

---

### WK-010 — Swipe to delete set with undo
**Priority:** P1  
**Steps:**
1. Swipe a set row to the left or right to reveal delete.
2. Confirm or complete the swipe deletion.
3. Tap "Undo" in the SnackBar that appears.

**Expected:** Set row is removed after swipe. SnackBar with "Undo" appears. Tapping "Undo" restores the set row. (Was bug UX-U02 — resolved, verify no regression.)

---

### WK-011 — Reorder exercises
**Priority:** P1  
**Steps:**
1. Add two exercises to the workout (e.g., Bench Press and Squat).
2. Use the reorder controls (up/down arrows on exercise card) to move Squat above Bench Press.

**Expected:** Exercise order updates correctly. Exercises maintain their set data after reordering.

---

### WK-012 — Swap exercise
**Priority:** P1  
**Steps:**
1. With at least one exercise in the workout, tap the swap icon (`swap_horiz`) on the exercise card header.
2. Select a different exercise from the picker.

**Expected:** The exercise is replaced. Sets are preserved (weight/reps carry over). Swap icon must be visible on the card (was fix in PR #14 — verify not regressed).

---

### WK-013 — Responsive set row at 360dp
**Priority:** P1  
**Steps:**
1. Test on a 360dp-width physical device (or emulator with 360dp viewport).
2. Open an active workout with a set row containing weight, reps, and the set badge.

**Expected:** No horizontal overflow. All elements (set badge, weight stepper, reps stepper, checkbox) fit within the row. (Was layout overflow bug — resolved with Flexible+FittedBox.)

---

### WK-014 — Long-press to set type cycle
**Priority:** P2  
**Steps:**
1. Long-press on the set number badge in a set row.

**Expected:** Set type cycles (Working → Warmup → Dropset → Failure → Working). Badge updates to reflect the current type. Known open bug UX-I05: this interaction is hidden/undiscoverable. Record whether it works functionally.

---

### WK-015 — Long-press exercise card to swap (undiscoverable)
**Priority:** P2  
**Steps:**
1. Long-press on the exercise card header (not the swap icon).

**Expected:** Either the swap flow triggers or a context menu appears. Known open bug UX-U03: long-press swap is invisible/undiscoverable. Record whether the gesture does anything.

---

### WK-016 — Add exercise from picker when no search results
**Priority:** P1  
**Steps:**
1. In an active workout, tap "Add Exercise".
2. In the exercise picker, search for a term that returns no results (e.g., "ZZZnonexistent").

**Expected:** "Create [search query]" button appears in the empty search results. Tapping it opens the create exercise flow. After creating, the new exercise is auto-selected and added to the workout. (Fix I2 from Step 5e.)

---

### WK-017 — Finish workout (happy path) `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P0  
**Steps:**
1. Complete all sets in a workout (all checkboxes checked).
2. Tap the "Finish" button (should be in thumb zone — bottom bar or FAB, not AppBar top-right).
3. In the finish dialog, optionally add a note.
4. Confirm finish.

**Expected:** Dialog appears with optional notes field. "Finish" button is in the lower portion of the screen (thumb-zone). Notes field does NOT auto-focus (no keyboard popup at completion moment). Workout is saved. App navigates to PR celebration screen (if PRs were broken) or home. Workout appears in history.

---

### WK-018 — Finish workout with incomplete sets warning `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P1  
**Steps:**
1. Add an exercise with 3 sets. Complete only 1.
2. Tap "Finish".

**Expected:** Dialog shows a warning indicating there are incomplete sets. User can still confirm finish or cancel. Warning is informational, not blocking.

---

### WK-019 — Discard workout `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P1  
**Steps:**
1. Start a workout with some exercises and sets.
2. Tap the discard/close action (AppBar leading icon).
3. In the confirmation dialog, tap "Discard".

**Expected:** Workout is discarded. App returns to home. `is_active` flag is cleared. Data is NOT saved to history. (Was bug PO-019 — discard order-of-operations — verify no regression.)

---

### WK-020 — Finish button is in thumb zone
**Priority:** P1  
**Steps:**
1. Open an active workout on a physical device.
2. Observe where the "Finish" button is located.

**Expected:** "Finish" button is in a persistent bottom bar or FAB (bottom of screen), not in the AppBar top-right. (Fix C6 from Step 5e.)

---

### WK-021 — Active workout banner visible in bottom nav
**Priority:** P1  
**Steps:**
1. Start an active workout.
2. Without finishing, navigate using bottom nav tabs.

**Expected:** A banner (full-width, primary color background, 56dp height) is visible above the bottom nav on all other tabs. Banner shows elapsed time. Tapping the banner returns to the active workout screen. Banner should have a subtle pulsing animation. (Fix I5 from Step 5e — was previously nearly invisible at 15% opacity.)

---

### WK-022 — Weight unit preference respected during logging
**Priority:** P1  
**Steps:**
1. In Profile tab, set unit preference to "lbs".
2. Start a workout and observe the weight stepper label.
3. Switch back to "kg" and verify.

**Expected:** Weight stepper displays "lbs" or "kg" label matching the profile preference. Values stored and displayed correctly. (Was bug PO-037 — weight unit wiring — resolved, verify no regression.)

---

### WK-023 — Weight decimal input (22.5kg) `[AUTOMATED]`
**Priority:** P1  
**Steps:**
1. Set a weight value of 22.5 in a set row (via stepper or tap-to-type).
2. Complete the set.
3. Finish the workout.
4. View the workout in history.

**Expected:** Weight 22.5 is stored and displayed correctly throughout (not rounded to 22 or 23). Decimal values survive save, reload, and display.

---

## 6. Routines

### RT-001 — View starter routines (new user)
**Priority:** P0  
**Steps:**
1. Log in as Account A (fresh, no custom routines).
2. Navigate to Routines tab and observe the Home screen.

**Expected:** Starter routines section is shown (Push Day, Pull Day, Leg Day, Full Body — seeded with `is_default = true`). Home screen shows "STARTER ROUTINES" section with 72dp full-width cards. No blank empty state. No duplicate "STARTER ROUTINES" sections rendered (known open bug PO-009 — verify on this flow).

---

### RT-002 — Start workout from routine card `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P0  
**Steps:**
1. On Home screen, tap a routine card (e.g., "Push Day").
2. Observe the active workout screen.

**Expected:** Active workout screen opens immediately (no preview screen). Workout is pre-filled with exercises from the routine. Sets are pre-populated. Workout name matches the routine name. Tap count from app open to first set logged: 2 taps (routine card + set checkbox).

---

### RT-003 — Start routine pre-fills with last session weights
**Priority:** P1  
**Steps:**
1. Using Account B, complete a Push Day workout with Bench Press 90kg × 5.
2. Start Push Day routine again from the Home screen.
3. Inspect the Bench Press sets in the new workout.

**Expected:** Bench Press sets are pre-filled with 90kg weight (last session data via `lastWorkoutSetsProvider`). Not 0/0.

---

### RT-004 — Create custom routine
**Priority:** P1  
**Steps:**
1. Navigate to Routines tab.
2. Tap "+ Create Routine" (or "+ Create Your First Routine" on home).
3. Enter name "My Back Day".
4. Add exercises: Deadlift (4 sets), Barbell Row (3 sets).
5. Tap "Save".

**Expected:** Routine appears in "My Routines" section of both Routines tab and Home screen. Routine shows name + exercise count + muscle group summary.

---

### RT-005 — Edit routine
**Priority:** P1  
**Steps:**
1. Long-press a custom routine card.
2. Select "Edit" from the context menu.
3. Change the routine name or add an exercise.
4. Save.

**Expected:** Context menu appears on long-press (not swipe — swipe is too dangerous on gym floor). Changes are saved. Updated routine is shown in the list.

---

### RT-006 — Delete routine
**Priority:** P1  
**Steps:**
1. Long-press a custom routine card.
2. Select "Delete" from the context menu.
3. Confirm deletion.

**Expected:** Routine is removed from the list. No crash. Past workouts started from this routine are NOT deleted from history.

---

### RT-007 — Deleted exercise handling in routine
**Priority:** P1  
**Steps:**
1. Create a routine containing custom exercise "TestDelete".
2. Delete "TestDelete" from the exercise library (EX-008).
3. Start a workout from that routine.

**Expected:** A banner at the top of the active workout screen warns "1 exercise is no longer available". The deleted exercise is omitted from the pre-filled workout. User can manually add a substitute.

---

### RT-008 — Routines error state
**Priority:** P2  
**Steps:**
1. Simulate a network failure (disable wifi) and navigate to Routines tab.

**Expected:** An error state is shown. Known low-priority bug PO-010: error state may have no retry button. Record actual behavior.

---

### RT-009 — Action sheet not duplicated
**Priority:** P2  
**Steps:**
1. Access the routine action sheet from the Home screen.
2. Access it from the Routines tab.

**Expected:** Same sheet shown, not duplicated (known open bug PO-033 — verify whether this is still an issue).

---

## 7. Home Screen

### HOME-001 — Home screen with routines (returning user)
**Priority:** P0  
**Steps:**
1. Log in as Account B.
2. Observe the home screen layout.

**Expected:** Screen shows: "MY ROUTINES" section with Account B's routines (72dp cards), "RECENT WORKOUTS" section (compact rows, last 3), "RECENT PRs" section if PRs exist, and "Start Empty Workout" secondary button. No layout shift while data loads (known open bug PO-008 — skeleton loading).

---

### HOME-002 — Home screen for new user (no routines)
**Priority:** P0  
**Steps:**
1. Log in as Account A (fresh account).
2. Observe the home screen.

**Expected:** "STARTER ROUTINES" section with seeded defaults shown immediately. "+ Create Your First Routine" primary green card visible. "Start Empty Workout" secondary button below. No blank/empty state.

---

### HOME-003 — Resume banner for active workout `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P0  
**Steps:**
1. Start a workout, then navigate away (Home tab) without finishing.
2. Observe the home screen.

**Expected:** A full-width resume banner appears prominently above the routine cards, with pulsing border/animation. Banner shows the workout name and elapsed time. Tapping it returns to the active workout screen. (Was duplicate resume banner bug NEW-003 — resolved, verify only ONE banner is shown.)

---

### HOME-004 — Resume banner disappears after finish `[AUTOMATED]`
**Priority:** P0  
**Steps:**
1. Have an active workout in progress (home shows resume banner).
2. From the active workout screen, finish the workout.
3. Return to home.

**Expected:** Resume banner is gone. Recent workouts section updates to show the completed workout.

---

### HOME-005 — Recent workouts summary shows exercise names
**Priority:** P1  
**Steps:**
1. Log in as Account B.
2. Observe recent workout rows on home.

**Expected:** Each recent workout row shows a summary line of top 3 exercise names (e.g., "Bench Press, Squat, Deadlift +2"). Users should be able to distinguish workouts without tapping in. (Fix I6 from Step 5e.)

---

### HOME-006 — Start Empty Workout from home `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P0  
**Steps:**
1. Tap "Start Empty Workout" button on home.

**Expected:** Active workout screen opens with auto-named workout. No dialog/keyboard required.

---

### HOME-007 — Section header contrast
**Priority:** P2  
**Steps:**
1. On home screen, observe section headers ("MY ROUTINES", "RECENT WORKOUTS", "RECENT PRs").

**Expected:** Section headers are legible against the dark background. Known open bug UX-V07: headers at 50% opacity may fail WCAG contrast. Record contrast perception.

---

## 8. Personal Records

### PR-001 — PR detection on workout finish (max weight) `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P0  
**Steps:**
1. Log in as Account B with an existing Bench Press PR of 80kg × 5.
2. Complete a workout with Bench Press 85kg × 5 (heavier than previous PR).
3. Tap "Finish".

**Expected:** After finishing, PR celebration screen appears showing "NEW PR" for Bench Press max weight with "+5kg" delta. Heavy haptic feedback fires. Screen flash (green overlay, 200ms).

---

### PR-002 — PR detection — max reps `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P1  
**Steps:**
1. Complete a workout where reps exceed the previous max reps PR for an exercise.

**Expected:** Max reps PR is detected and shown on celebration screen.

---

### PR-003 — PR detection — max volume
**Priority:** P1  
**Steps:**
1. Complete a workout where weight × reps exceeds the previous max volume PR for a single set.

**Expected:** Max volume PR is detected and shown on celebration screen. Volume is displayed with correct unit (not "kg" — known open bug PO-030, verify current behavior).

---

### PR-004 — First workout consolidated message `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P1  
**Steps:**
1. Log in as Account A (no prior workouts).
2. Complete the first workout with any exercises and sets.
3. Tap "Finish".

**Expected:** Celebration screen shows ONE consolidated message: "First workout logged! These are your starting benchmarks." Individual PR celebrations are NOT fired for every set. (Was bug PO-029 — first workout false positive — resolved, verify no regression.)

---

### PR-005 — PR tie is not a new PR
**Priority:** P1  
**Steps:**
1. Using Account B, note an existing max weight PR (e.g., 80kg × 5).
2. Complete a workout with the exact same weight (80kg × 5).
3. Tap "Finish".

**Expected:** No PR celebration appears for max weight (ties are NOT new PRs per spec). Other PRs may still appear if genuinely exceeded.

---

### PR-006 — Bodyweight exercise PRs (no weight)
**Priority:** P1  
**Steps:**
1. Log a bodyweight exercise (e.g., Push-up) with weight = 0 and reps = 20.
2. Complete and finish the workout.

**Expected:** Only `max_reps` PR is tracked for this set (weight = 0 bodyweight). No "Max Weight" card shown on celebration screen for this exercise. (Was edge case in PR detection spec.)

---

### PR-007 — Warmup sets excluded from PR detection
**Priority:** P1  
**Steps:**
1. Log a warmup set (set type = Warmup) with weight higher than the existing PR.
2. Log a working set at a lower weight.
3. Finish the workout.

**Expected:** No PR triggered by the warmup set. Only working sets count toward PRs.

---

### PR-008 — PR list screen
**Priority:** P1  
**Steps:**
1. Navigate to the PR list screen (via Home "View All" link from Recent PRs section).
2. Observe the content.

**Expected:** All-time records per exercise displayed. Empty state shows "Complete a workout to start tracking records" with CTA. PR cards are displayed — note known open bug PO-031: PR cards may not be tappable. Record whether tapping a PR card does anything.

---

### PR-009 — Multiple PRs in one workout — batch celebration
**Priority:** P1  
**Steps:**
1. Complete a workout that breaks PRs for multiple exercises (e.g., Bench Press + Squat + Deadlift all new records).
2. Finish the workout.

**Expected:** Single celebration screen lists ALL broken PRs in one summary view. No individual pop-up per PR.

---

## 9. Profile

### PROF-001 — Profile screen displays user data
**Priority:** P1  
**Steps:**
1. Navigate to Profile tab.
2. Observe the displayed information.

**Expected:** Shows display name (from onboarding/Supabase), email address, and fitness level. Data matches what was entered during onboarding.

---

### PROF-002 — Weight unit toggle (kg ↔ lbs)
**Priority:** P1  
**Steps:**
1. On Profile tab, observe the unit toggle (should show current preference).
2. Tap to switch from kg to lbs.
3. Navigate to an active workout and observe weight labels.
4. Switch back to kg.

**Expected:** Toggle updates the preference. Workout weight labels reflect the new unit immediately. Preference persists across app restarts.

---

### PROF-003 — Logout from profile `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P0  
**Steps:**
1. Tap "Logout" on Profile tab.
2. Confirm if prompted.

**Expected:** See AUTH-009. Session cleared, redirected to login screen.

---

### PROF-004 — Profile is not sparse (regression)
**Priority:** P2  
**Steps:**
1. Log in as Account B and open Profile tab.

**Expected:** Profile screen shows name, email, fitness level, and weight unit toggle. Not a blank placeholder screen. Known low-priority bug UX-U06: profile is sparse with no stats/streaks/PR count. Record current state.

---

### PROF-005 — No way to change display name post-onboarding
**Priority:** P2  
**Steps:**
1. Log in as Account B.
2. Navigate to Profile tab.
3. Attempt to edit the display name.

**Expected:** Known low-priority bug PO-039: no way to change display name post-onboarding. Record whether an edit action exists.

---

## 10. History

### HIST-001 — Workout history list
**Priority:** P1  
**Steps:**
1. Log in as Account B.
2. Navigate to history (via Home "View All" → history screen, or any history entry point).

**Expected:** List of past workouts sorted by most recent first. Each card shows: workout name, date, duration, total volume, and exercise summary (top 3 exercise names). (Fix I6 from Step 5e.)

---

### HIST-002 — Pagination (infinite scroll)
**Priority:** P1  
**Steps:**
1. Using Account B (with 5+ workouts), scroll to the bottom of the history list.

**Expected:** More workouts load automatically (infinite scroll / load-more). No crash. Known low-priority bug PO-028: load-more may have no loading indicator. Record actual behavior.

---

### HIST-003 — Pull to refresh history
**Priority:** P1  
**Steps:**
1. On the history screen, pull down to refresh.

**Expected:** History list refreshes and shows up-to-date data.

---

### HIST-004 — Workout detail screen
**Priority:** P1  
**Steps:**
1. Tap a workout in the history list.

**Expected:** Detail screen shows: workout name, date/time, duration, total volume, all exercises with their sets (weight, reps), and any notes. Read-only — no editing. PR badges should appear on sets that were records at time of completion (Step 8 feature).

---

### HIST-005 — Empty history state `[AUTOMATED]`
**Priority:** P1  
**Steps:**
1. Log in as Account A (no completed workouts).
2. Navigate to the history section.

**Expected:** Empty state is shown with a clear CTA ("Start your first workout" or equivalent). No crash.

---

## 11. Cross-Cutting Concerns

### CC-001 — Touch targets minimum 48dp
**Priority:** P1  
**Steps:**
1. Throughout the app, identify all interactive elements (buttons, icons, chips, links).
2. Visually or using Android developer options (Show touch areas) verify target sizes.

**Expected:** All interactive elements have touch targets of at least 48×48dp. Workout logging primary actions (checkbox, steppers) must be 56dp minimum. Pay particular attention to: rest timer skip/adjust buttons, set type badge, RPE control, reorder arrows.

---

### CC-002 — One-handed usability (thumb zone)
**Priority:** P1  
**Steps:**
1. Hold the phone in one hand (right hand, typical grip).
2. Attempt to perform core actions: start workout, add exercise, log set, finish workout.

**Expected:** All core actions are reachable by the right thumb without shifting grip. "Finish" button is in the bottom half of the screen. Filter chips on exercise screen are reachable from bottom. Exercise picker opens from the bottom.

---

### CC-003 — Dark theme consistency
**Priority:** P1  
**Steps:**
1. Navigate through every screen: login, onboarding, home, exercises, exercise detail, active workout, rest timer, finish dialog, PR celebration, routines, profile, history, history detail.

**Expected:** Dark theme applied consistently on all screens. No white/light backgrounds that don't belong. No text with insufficient contrast on dark backgrounds. Primary green (#00E676) used only for headings (20sp+), icons, and buttons — NOT as body text on dark cards (per PLAN.md contrast rules).

---

### CC-004 — Haptic feedback
**Priority:** P1  
**Steps:**
1. Complete a set (checkbox) — verify haptic.
2. Trigger a PR celebration — verify haptic.
3. Rest timer completes — verify haptic.
4. Swipe-delete a set — verify haptic.

**Expected:** Haptic feedback fires on each of these actions. Heavy haptic on PR. Rest timer completion uses a distinct pattern. No haptic on non-interactive elements.

---

### CC-005 — Empty states with clear CTAs on all screens
**Priority:** P1  
**Steps:**
1. Visit each screen with Account A (no data): Exercises (no custom exercises), History, PRs, Routines (My Routines section).

**Expected:**
- Exercises: "Your exercises will appear here" with "Create Exercise" button.
- History: CTA to start first workout.
- PRs: "Complete a workout to start tracking records" with CTA.
- Routines (My Routines): "Your routines appear here. Start from a Starter Routine or create your own."

---

### CC-006 — Crash recovery — kill app mid-workout `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P0  
**Steps:**
1. Start an active workout. Add 2 exercises. Complete 3 sets with specific weights.
2. Force-kill the app (swipe away from recents).
3. Relaunch the app.

**Expected:** Resume dialog appears: "You have an active workout. Continue or discard?" Tapping "Continue" restores the exact workout state (exercises, completed sets, weight/reps values). Data loss must be zero.

---

### CC-007 — Crash recovery — resume dialog then discard
**Priority:** P1  
**Steps:**
1. Force-kill mid-workout (CC-006 step 1-2).
2. Relaunch, tap "Discard" in the resume dialog.

**Expected:** App discards the workout and goes to home screen. Does NOT immediately start a new workout (known low-priority bug NEW-007 — verify whether discard in resume dialog starts new workout).

---

### CC-008 — Concurrent session prevention
**Priority:** P0  
**Steps:**
1. Start an active workout on Device A (or tab).
2. Open the same account on Device B (or another Chrome tab).
3. Attempt to start another workout on Device B.

**Expected:** Second start is blocked or a warning is shown. `is_active` partial index constraint prevents two concurrent active workouts per user.

---

### CC-009 — Atomic workout save — no partial data
**Priority:** P0  
**Steps:**
1. Complete a full workout with 3 exercises and multiple sets.
2. Disable network just before tapping "Finish".
3. Attempt to finish.

**Expected:** Error state shown. Workout data is NOT partially saved (Postgres RPC `save_workout` is atomic — all or nothing). When network is restored and user retries, full workout saves correctly.

---

### CC-010 — Double-tap Finish Workout is idempotent `[AUTOMATED - deprioritize in manual pass]`
**Priority:** P0  
**Steps:**
1. Complete a workout and rapidly tap "Finish" twice.

**Expected:** Only one workout is saved in history. No duplicate entries. No crash.

---

### CC-011 — Bottom nav tooltip persistence
**Priority:** P2  
**Steps:**
1. Long-press a bottom nav tab icon.
2. Navigate away.

**Expected:** Tooltip labels do not persist / float on the screen after the long-press. Known open bug QA-011.

---

### CC-012 — Bottom nav visual style
**Priority:** P2  
**Steps:**
1. Observe the bottom navigation bar across all screens.

**Expected:** Bottom nav should not be unstyled Material 3 defaults. Known open bug UX-V08: currently uses Material 3 defaults without custom styling. Record current state.

---

---

## 12. Known Open Bugs — Verification Checklist

Use this section to record the current state of each open bug during the QA pass. For each item, mark: **Confirmed** (bug still present), **Fixed** (resolved since last tracking), or **Cannot Reproduce**.

### High Priority Open Bugs

| ID | Area | Issue | Test Case Reference | Status |
|----|------|-------|---------------------|--------|
| QA-005 | Exercises | Image URLs return 404 from GitHub — fallback icon should work | EX-010 | |
| QA-006 | Auth | Forgot password triggers immediately, no confirmation step | AUTH-008 | |
| UX-A01 | Auth | Google sign-in uses wrong icon (`Icons.g_mobiledata`) | AUTH-007 | |
| UX-D01 | Design | Two primary button widgets used inconsistently (`AppButton` / `GradientButton`) | Spot-check across screens | |

### Medium Priority Open Bugs

| ID | Area | Issue | Test Case Reference | Status |
|----|------|-------|---------------------|--------|
| BUG-002 | Shared | `AppButton` label lost during loading state (no accessible name) | Any loading button interaction | |
| BUG-007 | Workout | `FinishWorkoutDialog` button label ambiguous with bottom bar | WK-017 | |
| QA-011 | Nav | Tooltip labels persist on bottom nav bar | CC-011 | |
| QA-012 | Exercises | Detail screen chart area broken/empty | EX-009 | |
| PO-002 | Auth | Email confirmation shows blank email after app restart | AUTH-010 | |
| PO-008 | Home | Layout shift when workout history loads (needs skeleton) | HOME-001 | |
| PO-009 | Home | May render duplicate STARTER ROUTINES sections | RT-001 | |
| PO-013 | Exercises | Detail screen uses raw `Future`, never refetches | EX-009 | |
| PO-030 | PRs | Volume displayed as "kg" instead of correct volume unit | PR-003 | |
| PO-033 | Routines | Action sheet duplicated between home and routine list | RT-009 | |
| UX-V02 | Workout | Weight/reps have identical visual treatment — no hierarchy | WK-003 | |
| UX-V04 | Routines | Cards have no visual affordance for launching workouts | RT-002 | |
| UX-V06 | PRs | Celebration screen visually flat for an emotional moment | PR-001 | |
| UX-V07 | Home | Section headers at 50% opacity may fail WCAG contrast | HOME-007 | |
| UX-V08 | Nav | Bottom nav is unstyled Material 3 defaults | CC-012 | |
| UX-U03 | Workout | Long-press to swap exercise is invisible | WK-015 | |
| UX-U05 | Workout | Copy-last-set (tap set number) is undiscoverable | WK-009 | |
| UX-U06 | Profile | Profile screen sparse — no stats, streaks, or PR count | PROF-004 | |
| UX-U09 | Workout | Rest timer overlay blocks entire screen | WK-008 | |
| UX-I05 | Workout | Set type cycling (long-press) is hidden | WK-014 | |

### Low Priority Open Bugs

| ID | Issue | Status |
|----|-------|--------|
| NEW-004 | DartError on login→home focus traversal | |
| NEW-005 | Exercise validation error persists while typing | |
| NEW-006 | Forgot password SnackBar disappears too quickly | |
| NEW-007 | Discard in resume dialog immediately starts new workout | CC-007 |
| PO-004 | Password retained when toggling login/signup | AUTH-012 |
| PO-007 | Onboarding has no back from page 2 | ONBOARD-003 |
| PO-010 | Routines error state has no retry button | RT-008 |
| PO-016 | Exercise list has no pull-to-refresh | EX-011 |
| PO-028 | History load-more has no loading indicator | HIST-002 |
| PO-031 | PR cards not tappable (no link to source workout) | PR-008 |
| PO-039 | No way to change display name post-onboarding | PROF-005 |
| UX-V05 | Login icon `Icons.fitness_center` reads as placeholder | Login screen visual check |
| UX-D03 | Border radius inconsistency (8/12/16 with no rule) | Spot-check across screens |
| UX-D05 | `_SectionHeader` widget duplicated in two files | Code-level only |

---

## 13. Regression Checks — Resolved Bugs Spot-Check

These bugs were fixed during development. Spot-check each to confirm no regression.

| Bug ID | What Was Fixed | Regression Test |
|--------|---------------|-----------------|
| QA-001 | `save_workout` RPC 404 | Finish a workout → verify workout appears in history (WK-017) |
| QA-002 | Blank home screen on bad route | Log in → home loads with correct content (HOME-001) |
| QA-003 | Exercise DELETE RLS blocked | Delete a custom exercise → no 403 error (EX-008) |
| QA-004 | Profile update 400 error | Complete onboarding → profile saves (ONBOARD-002) |
| QA-007 | Exercise name validation missing | Create exercise with duplicate name → error shown (EX-007) |
| QA-008 | Start workout button not working | Tap routine card → workout starts (RT-002) |
| PO-001 | Onboarding flag race condition | Onboarding not shown to returning users (ONBOARD-004) |
| PO-005 | Empty display name allowed in onboarding | Submit onboarding with empty name → validation error shown |
| PO-012 | Exercise picker → create flow broken | Add exercise from picker when no results → create flow opens (WK-016) |
| PO-017/018 | Silent workout data loss on restart | Kill app mid-workout → resume → data intact (CC-006) |
| PO-019 | Discard order-of-operations bug | Discard workout → goes to home, not another workout (WK-019) |
| PO-029 | First workout fires individual PR celebrations | First workout → single consolidated message (PR-004) |
| PO-036 | Auth logout path broken | Log out → redirected to login screen (AUTH-009) |
| PO-037 | Weight unit wiring broken | Toggle lbs/kg → workout respects preference (WK-022) |
| PO-041 | PR celebration route guard missing | Finish workout without PRs → no celebration screen shown |
| PO-044 | PR not persisted to database | Finish workout with PR → PR appears in list (PR-001, PR-008) |
| UX-I01 | Stepper long-press repeat rate erratic | Long-press stepper → smooth repeat rate (WK-004) |
| UX-U02 | Swipe-to-delete undo broken | Swipe delete set → undo restores it (WK-010) |
| UX-U04 | Finish button guidance missing | Finish button is visible and in thumb zone (WK-020) |
| NEW-001 | Active workout route race condition | Navigate back to active workout → no black screen |
| NEW-002 | Production exercise seed missing | Exercises tab shows seeded exercises (EX-001) |
| NEW-003 | Duplicate resume banner on home | One active workout → only ONE banner on home (HOME-003) |
| BUG-001 | Login error had no accessible live region | Login with wrong password → screen reader announces error |
| BUG-003/004 | Weight/reps stepper accessibility labels missing | Stepper buttons have meaningful labels (accessibility audit) |
| BUG-005/006 | Workout AppBar missing accessibility labels | AppBar actions are labeled for screen readers |

---

## 14. Test Execution Notes

### Running Order Recommendation

For a full QA pass on both devices, execute in this order to minimize account/state setup overhead:

1. Environment Setup (Section 1)
2. Auth Flows with Account A fresh account (AUTH-001 through AUTH-012)
3. Onboarding (ONBOARD-001 through ONBOARD-004) — Account A continues from auth
4. Exercise Library (EX-001 through EX-011) — use Account A
5. Workout Logging basics (WK-001 through WK-010) — Account A
6. Switch to Account B for logged-history tests
7. Workout Logging continued (WK-011 through WK-023)
8. Routines (RT-001 through RT-009)
9. Home Screen (HOME-001 through HOME-007)
10. Personal Records (PR-001 through PR-009) — may need to set up specific workout history
11. Profile (PROF-001 through PROF-005)
12. History (HIST-001 through HIST-005)
13. Cross-Cutting Concerns (CC-001 through CC-012)
14. Open Bug Verification Checklist (Section 12)
15. Regression Spot-Checks (Section 13)

### Recording Results

For each test case, record:
- Pass / Fail / Blocked / Skipped
- Device/browser where tested
- If fail: brief description of actual behavior
- Screenshot or screen recording for any P0/P1 failure

### Blocking Criteria for Release

A build should NOT ship if any of the following are true:
- Any P0 test fails
- Crash occurs during any P0 or P1 test
- Data loss occurs (workout data, PR data)
- Two or more new P1 failures not present in the open bugs list (i.e., regressions)

---

## 15. E2E Coverage Cross-Reference

**Analysis date:** 2026-04-06 (updated 2026-04-06 after Part 1 automation)
**E2E suite location:** `test/e2e/`  
**Manual test cases analysed:** 97  
**E2E spec files read:** 9 files (7 full specs + 2 smoke specs; `exercise-library.smoke.spec.ts` is marked `test.skip` and does not run in CI)

### 15.1 Summary Statistics

**45 of 97 manual test cases have full or partial E2E automation.**  
(7 new cases automated in the Part 1 pass: EX-003, EX-005, EX-007, HOME-004, HIST-005, WK-023, AUTH-006.)

- Full coverage (E2E matches every step and assertion): **29 cases** (was 22)
- Partial coverage (E2E covers the happy path but not the specific error/edge condition, or covers a related flow but not all steps): **16 cases** (was 17 — AUTH-006 promoted to Full)
- No automation (manual only): **52 cases** (was 58)

### 15.2 Coverage Table

| Manual ID | Description | E2E Status | E2E Spec File(s) | Notes |
|-----------|-------------|------------|------------------|-------|
| AUTH-001 | Email signup (happy path) | None | — | E2E cannot verify the email confirmation screen itself; the suite uses pre-created users and skips the signup UI entirely |
| AUTH-002 | Email confirmation deep link (Android) | None | — | Deep-link / PKCE callback is an Android-only flow; no web E2E analog |
| AUTH-003 | Email login (returning user) | Full | `smoke/auth.smoke.spec.ts`, `full/auth.full.spec.ts` | "login with valid credentials lands on home screen with bottom nav" covers every step and assertion |
| AUTH-004 | Login with wrong password | Full | `smoke/auth.smoke.spec.ts`, `full/auth.full.spec.ts` | Both files contain "login with wrong password shows an error message"; full spec also asserts page stays on login |
| AUTH-005 | Signup with existing email | Full | `full/auth.full.spec.ts` | "signing up with an already-registered email shows an error" uses an already-created user to trigger the Supabase "User already registered" error |
| AUTH-006 | Form validation on login screen | Full | `full/auth.full.spec.ts` | "submitting with empty email and password shows an error" covers the empty-field case; "AUTH-006: malformed email (missing @) shows a validation error" covers the malformed-email subcase added in Part 1 |
| AUTH-007 | Google sign-in (happy path) | None | — | OAuth flow requires browser popup interaction; no E2E test. The button presence is not even asserted. |
| AUTH-008 | Forgot password flow | Partial | `smoke/auth.smoke.spec.ts` | "forgot password with valid email shows success feedback" covers the trigger; the specific "no confirmation step" assertion (known bug QA-006) is not verified |
| AUTH-009 | Logout | Full | `smoke/auth.smoke.spec.ts`, `full/auth.full.spec.ts` | "logout returns to login screen" and "full journey: login → navigate all tabs → logout" both cover this; full spec also asserts bottom nav is gone after logout |
| AUTH-010 | Email confirmation screen after app restart | None | — | Requires actual email signup flow + kill/relaunch cycle; not covered in E2E |
| AUTH-011 | Session persistence (token refresh) | None | — | No E2E test simulates token expiry or background/foreground cycle |
| AUTH-012 | Password retained across login/signup toggle | None | — | Toggle behaviour is tested in smoke/full auth, but password field value retention is not asserted |
| ONBOARD-001 | Two-screen onboarding flow (new user) | None | — | All E2E users are pre-created; onboarding is never triggered. The `ONBOARDING` selectors exist in `helpers/selectors.ts` but no spec uses them. |
| ONBOARD-002 | Profile data saved to Supabase | None | — | Same as above — profile setup never exercised in E2E |
| ONBOARD-003 | Back navigation on onboarding | None | — | Not covered |
| ONBOARD-004 | Onboarding not shown to returning users | None | — | Pre-created users always skip onboarding; the absence of onboarding is implicit but not explicitly asserted |
| EX-001 | Browse exercises by muscle group | Partial | `smoke/exercise.smoke.spec.ts`, `full/exercise-library.spec.ts` | "muscle group filter narrows the exercise list" and "Chest muscle group filter shows only chest exercises" cover this; touch target size (64dp) is not verified in E2E |
| EX-002 | Search exercises | Full | `smoke/exercise.smoke.spec.ts`, `full/exercise-library.spec.ts` | "search filters exercise list by name" (smoke) and "search for 'bench' narrows results" (full) cover case-insensitive search by partial name |
| EX-003 | Search does not return soft-deleted exercises | Full | `full/exercise-library.spec.ts` | "EX-003: deleted exercise does not appear in search results" creates, deletes, and then searches for the deleted exercise — asserting zero matching cards |
| EX-004 | Filter by equipment type | Partial | `full/exercise-library.spec.ts` | "Barbell equipment filter narrows results" covers the filter; AND-filter combination with muscle group is tested in "combined muscle group + search filter" but uses text search, not equipment filter |
| EX-005 | Filter combination zero results | Full | `full/exercise-library.spec.ts` | "EX-005: filter combination with zero results shows filtered empty state" applies Core + Kettlebell (and a fallback nonsense search term) and asserts `EXERCISE_LIST.emptyStateFiltered` and the Clear Filters button |
| EX-006 | Create custom exercise | Full | `smoke/exercise.smoke.spec.ts`, `full/exercise-library.spec.ts` | "create custom exercise successfully navigates back to list" (smoke) and "create a custom exercise and verify it appears in the list" (full) cover all steps |
| EX-007 | Duplicate exercise name prevention | Full | `full/exercise-library.spec.ts` | "EX-007: submitting a duplicate exercise name shows a validation error" creates an exercise then attempts to create another with the same name, asserting a validation error and no navigation away from the create screen |
| EX-008 | Soft delete custom exercise | Partial | `smoke/exercise.smoke.spec.ts`, `full/exercise-library.spec.ts` | "delete custom exercise removes it from the list" covers deletion and absence from the list. The soft-delete (not hard-delete) and the "past workouts still show the name" assertions are not verified in E2E |
| EX-009 | Exercise detail screen | None | — | `exercise-library.smoke.spec.ts` (which is `test.skip`) has a detail screen test; the active specs do not navigate to exercise detail. `EXERCISE_DETAIL.prPlaceholder` selector exists but no active spec asserts it |
| EX-010 | Exercise images (start/end position, 404 fallback) | None | — | Not covered. Image loading and 404 fallback are not tested anywhere |
| EX-011 | Exercise list pull-to-refresh | None | — | Not tested in E2E |
| WK-001 | Start empty workout (no routine) | Full | `smoke/workout.smoke.spec.ts`, `full/workout-logging.spec.ts` | "home screen is visible with start workout option" and "start empty workout shows Finish Workout and Add Exercise buttons" both cover this precisely |
| WK-002 | Add exercise to workout | Full | `smoke/workout.smoke.spec.ts`, `full/workout-logging.spec.ts` | `addExercise()` helper drives the exact tap sequence (Add Exercise FAB → search → tap tile); exercised in every workout test |
| WK-003 | Log a set (stepper interaction) | Partial | `smoke/workout.smoke.spec.ts`, `full/workout-logging.spec.ts` | `setWeight()` and `setReps()` helpers use the dialog entry path; the stepper "+/-" button path is not tested (E2E always uses tap-to-type). Checkbox completion and rest timer are not verified in E2E. Haptic feedback is untestable in web. |
| WK-004 | Long-press stepper repeat rate | None | — | Long-press gesture on stepper is not tested; web E2E cannot simulate the repeat-rate UX |
| WK-005 | Tap-to-type weight and reps | Full | `smoke/workout.smoke.spec.ts`, `full/workout-logging.spec.ts` | The `setWeight()` and `setReps()` helpers directly exercise the tap-to-type dialog path; decimal input (37.5) is not specifically tested but the mechanism is verified |
| WK-006 | Pre-fill from last session | None | — | No E2E test starts a second workout with the same exercise and checks for pre-fill ghost text |
| WK-007 | Add set to exercise | Full | `full/workout-logging.spec.ts` | "add multiple sets to an exercise" clicks Add Set and counts the resulting rows |
| WK-008 | Rest timer | None | — | Rest timer overlay is not verified in E2E; completing a set does trigger the overlay but the spec only waits for the completed checkbox state, not the timer |
| WK-009 | Copy last set (tap set badge) | None | — | Not covered |
| WK-010 | Swipe to delete set with undo | None | — | Swipe gesture and SnackBar undo not tested in E2E |
| WK-011 | Reorder exercises | None | — | Drag-to-reorder and up/down arrows not tested |
| WK-012 | Swap exercise | None | — | Swap icon not tested |
| WK-013 | Responsive set row at 360dp | None | — | Viewport size testing not covered in E2E |
| WK-014 | Long-press to set type cycle | None | — | Not covered |
| WK-015 | Long-press exercise card to swap | None | — | Not covered |
| WK-016 | Add exercise from picker when no search results | None | — | "Create [query]" button in the picker empty state is not tested |
| WK-017 | Finish workout (happy path) | Full | `smoke/workout.smoke.spec.ts`, `full/workout-logging.spec.ts` | `finishWorkout()` helper drives this; "finish workout with completed sets navigates away" asserts completion. Notes field auto-focus and thumb zone position are not E2E-verifiable. |
| WK-018 | Finish with incomplete sets warning | Full | `full/workout-logging.spec.ts` | "finish with incomplete sets shows 'incomplete sets' warning dialog" covers the warning dialog and the "Keep Going" cancel path |
| WK-019 | Discard workout | Full | `smoke/workout.smoke.spec.ts`, `full/workout-logging.spec.ts` | "discarding a workout returns to home without saving" (smoke) and "discard workout shows confirmation dialog and returns to home" (full) cover all steps |
| WK-020 | Finish button is in thumb zone | Partial | `full/workout-logging.spec.ts` | "start empty workout shows Finish Workout and Add Exercise buttons" asserts the button is visible, but position (thumb zone) cannot be verified programmatically in web E2E |
| WK-021 | Active workout banner visible in bottom nav | Partial | `full/crash-recovery.spec.ts` | "navigating to another tab and back still shows the resume banner" covers banner persistence; pulsing animation and 56dp banner height are not E2E-verifiable |
| WK-022 | Weight unit preference respected during logging | Partial | `full/home-navigation.spec.ts` | "profile weight unit toggle shows kg and lbs options" verifies the toggle renders and clicking lbs doesn't crash, but does NOT verify that the weight label in the workout screen changes to "lbs" |
| WK-023 | Weight decimal input (22.5kg) | Full | `full/workout-logging.spec.ts` | "WK-023: decimal weight 22.5 survives the full save and display round-trip" calls `setWeight(page, '22.5')`, completes the workout, and asserts "22.5" is visible in the history detail screen |
| RT-001 | View starter routines (new user) | Partial | `full/routines.spec.ts` | "all four starter routines from seed data are visible" covers the starter routines content; the duplicate STARTER ROUTINES bug (PO-009) is not asserted, and the Home screen STARTER ROUTINES section is tested in `full/home-navigation.spec.ts` |
| RT-002 | Start workout from routine card | Full | `full/routines.spec.ts` | "tapping a starter routine card navigates to the active workout screen" covers all steps including pre-filled exercises (asserts "Barbell Bench Press" is visible) |
| RT-003 | Start routine pre-fills with last session weights | None | — | No E2E test starts a routine twice and checks weight pre-fill |
| RT-004 | Create custom routine | None | — | `CREATE_ROUTINE` selectors exist in `helpers/selectors.ts` but no spec exercises the create-routine flow |
| RT-005 | Edit routine | None | — | Not covered |
| RT-006 | Delete routine | None | — | Not covered; `ROUTINE.deleteOption` selector exists but is never used in any spec |
| RT-007 | Deleted exercise handling in routine | None | — | Not covered |
| RT-008 | Routines error state | None | — | Not covered |
| RT-009 | Action sheet not duplicated | None | — | Not covered |
| HOME-001 | Home screen with routines (returning user) | Partial | `full/home-navigation.spec.ts` | "home tab shows a routines section (STARTER or MY ROUTINES)" covers this; layout shift / skeleton loading (bug PO-008) is not verified |
| HOME-002 | Home screen for new user (no routines) | Partial | `full/home-navigation.spec.ts` | Same test handles both cases with the `hasStarter || hasMy` assertion; "+ Create Your First Routine" button presence is not specifically asserted |
| HOME-003 | Resume banner for active workout | Full | `full/crash-recovery.spec.ts` | "navigating to another tab and back still shows the resume banner" covers the banner appearance; duplicate-banner check (bug NEW-003) is verified implicitly because only one banner is tested for |
| HOME-004 | Resume banner disappears after finish | Full | `full/crash-recovery.spec.ts` | "HOME-004: resume banner disappears from home after finishing the workout" starts a workout, verifies the banner, finishes the workout, returns to home, and asserts `HOME.activeBanner` is not visible |
| HOME-005 | Recent workouts summary shows exercise names | Partial | `smoke/workout.smoke.spec.ts`, `full/home-navigation.spec.ts` | "finished workout appears in the recent section" asserts the RECENT section appears, but does not verify exercise names appear in the row summary |
| HOME-006 | Start Empty Workout from home | Full | `smoke/workout.smoke.spec.ts`, `full/home-navigation.spec.ts` | Both "home screen is visible with start workout option" and "home tab shows Start Empty Workout button" confirm button presence; `startEmptyWorkout()` helper exercises the tap |
| HOME-007 | Section header contrast | None | — | Visual contrast checks are not automatable in E2E |
| PR-001 | PR detection on workout finish (max weight) | Full | `full/personal-records.spec.ts` | "second workout with higher weight triggers NEW PR celebration" covers the exact scenario; delta display and haptic/screen-flash are not verifiable in web E2E |
| PR-002 | PR detection — max reps | Full | `full/personal-records.spec.ts` | "second workout with more reps at the same weight triggers NEW PR" covers this exactly |
| PR-003 | PR detection — max volume | None | — | Volume PR is not specifically tested; E2E tests only verify weight and reps PRs |
| PR-004 | First workout consolidated message | Full | `smoke/pr.smoke.spec.ts`, `full/personal-records.spec.ts` | "first completed workout shows 'First Workout Complete!' celebration" explicitly asserts the `PR.firstWorkoutHeading` selector, confirming the single consolidated message (not per-set PRs) |
| PR-005 | PR tie is not a new PR | None | — | No E2E test repeats the exact same weight/reps to verify no false PR |
| PR-006 | Bodyweight exercise PRs (no weight) | None | — | Not tested in E2E |
| PR-007 | Warmup sets excluded from PR detection | None | — | Set type cycling is not exercised in E2E |
| PR-008 | PR list screen | None | — | `PR.recentRecordsSection` is asserted to be visible on the home screen, but the full PR list screen (via "View All") is not navigated to in any PR spec |
| PR-009 | Multiple PRs in one workout — batch celebration | Partial | `full/personal-records.spec.ts` | "two exercises in one workout each get their own PR detection" uses a two-exercise workout and asserts the NEW PR heading appears; it does not assert a single summary screen versus multiple pop-ups |
| PROF-001 | Profile screen displays user data | Partial | `full/home-navigation.spec.ts` | "profile tab shows the user email and Log Out button" asserts email and logout button; display name and fitness level are not verified |
| PROF-002 | Weight unit toggle (kg ↔ lbs) | Partial | `full/home-navigation.spec.ts` | "profile weight unit toggle shows kg and lbs options" verifies the toggle renders; it clicks lbs but does NOT navigate to an active workout to verify the label changes |
| PROF-003 | Logout from profile | Full | `smoke/auth.smoke.spec.ts`, `full/auth.full.spec.ts` | Covered by every logout test; the `logout()` helper navigates Profile → Log Out → dialog confirm |
| PROF-004 | Profile is not sparse (regression) | None | — | No assertion on whether stats/streaks/PR count are shown |
| PROF-005 | No way to change display name post-onboarding | None | — | Known bug only; no E2E assertion either way |
| HIST-001 | Workout history list | None | — | History screen is navigated to via "View All" in `full/home-navigation.spec.ts` which asserts the heading, but content (sort order, card fields) is not verified |
| HIST-002 | Pagination (infinite scroll) | None | — | Not covered |
| HIST-003 | Pull to refresh history | None | — | Not covered |
| HIST-004 | Workout detail screen | None | — | Not covered |
| HIST-005 | Empty history state | Full | `full/history.spec.ts` | "HIST-005: history screen shows empty state for a user with no completed workouts" navigates to /home/history with a fresh user and asserts `HISTORY.emptyState`, `HISTORY.emptyStateCta`, and that `HISTORY.retryButton` is NOT visible |
| CC-001 | Touch targets minimum 48dp | None | — | Not automatable in web E2E |
| CC-002 | One-handed usability (thumb zone) | None | — | Physical device only |
| CC-003 | Dark theme consistency | None | — | Visual regression testing not implemented |
| CC-004 | Haptic feedback | None | — | Not testable in browser |
| CC-005 | Empty states with clear CTAs on all screens | None | — | Individual empty states are not asserted in any spec |
| CC-006 | Crash recovery — kill app mid-workout | Full | `full/crash-recovery.spec.ts` | "active workout persists across a full page reload — resume banner appears" simulates this via `page.reload()`; exact exercise/set data integrity is tested in the second crash spec |
| CC-007 | Crash recovery — resume dialog then discard | Partial | `full/crash-recovery.spec.ts` | The crash recovery spec handles the discard path as cleanup in its tests, but there is no dedicated test that asserts "discard from resume dialog does NOT start a new workout" (the specific bug NEW-007) |
| CC-008 | Concurrent session prevention | None | — | Multi-tab/device concurrency is not tested |
| CC-009 | Atomic workout save — no partial data | None | — | Network failure simulation not implemented in E2E |
| CC-010 | Double-tap Finish Workout is idempotent | Full | `full/crash-recovery.spec.ts` | "rapid double-tap on Finish does not create duplicate workouts" uses `dblclick()` on the confirm button and asserts no error state and clean home screen |
| CC-011 | Bottom nav tooltip persistence | None | — | Not covered |
| CC-012 | Bottom nav visual style | None | — | Visual check only |

### 15.3 Gaps Analysis — Highest-Priority Automation Candidates

The following manual-only test cases carry P0/P1 priority AND involve flows that are technically automatable in web E2E. They represent the most impactful gaps to close next.

**Tier 1 — High value, straightforward to automate:** _(all 7 implemented — see Section 15.4)_

1. ~~**HIST-005 — Empty history state** (P1)~~ **DONE** — `full/history.spec.ts`

2. ~~**EX-005 — Filter combination zero results + empty state** (P1)~~ **DONE** — `full/exercise-library.spec.ts`

3. ~~**EX-003 — Search does not return soft-deleted exercises** (P0)~~ **DONE** — `full/exercise-library.spec.ts`

4. ~~**EX-007 — Duplicate exercise name prevention** (P1)~~ **DONE** — `full/exercise-library.spec.ts`

5. ~~**HOME-004 — Resume banner disappears after finish** (P0)~~ **DONE** — `full/crash-recovery.spec.ts`

6. ~~**WK-023 — Weight decimal input (22.5kg)** (P1)~~ **DONE** — `full/workout-logging.spec.ts`

7. ~~**AUTH-006 partial gap — malformed email validation** (P1)~~ **DONE** — `full/auth.full.spec.ts`

**Tier 2 — Medium value, requires some new helper work:**

8. **WK-022 partial gap — unit toggle reflects in workout** (P1): Extend the weight unit test in `full/home-navigation.spec.ts` to navigate to the active workout after toggling lbs and assert the weight stepper label reads "lbs".

9. **PR-005 — PR tie is not a new PR** (P1): Add a test to `full/personal-records.spec.ts` that logs the exact same weight/reps twice and asserts the `PR.newPRHeading` does NOT appear.

10. **PROF-001 partial gap — display name and fitness level shown** (P1): Extend the profile test in `full/home-navigation.spec.ts` to assert `USER.email`, display name, and fitness level are all visible.

11. **RT-004 — Create custom routine** (P1): `CREATE_ROUTINE` selectors exist but no spec uses them. A full routine creation test (name → add exercise → save → verify in list) would close a significant flow gap.

12. **RT-006 — Delete routine** (P1): Follows the same pattern as exercise deletion; `ROUTINE.deleteOption` and `ROUTINE.deleteConfirmButton` selectors are defined and ready.

13. **CC-008 — Concurrent session prevention** (P0): Use two Playwright browser contexts for the same user, start a workout in context A, then try to start one in context B and assert a block/warning appears.

**Tier 3 — Lower value or technically constrained:**

14. **WK-006 — Pre-fill from last session** (P1): Requires completing one workout, then starting a second with the same exercise and asserting the ghost/pre-fill text. Doable but needs an assertion on hint text, which requires a new selector.

15. **PR-003 — Max volume PR detection** (P1): The calculation is weight × reps. A dedicated test can be added to `full/personal-records.spec.ts` with a volume-exceeding workout (same weight, more reps in a single set).

### 15.4 Already Automated — Deprioritize During Manual Passes

The following test cases are fully covered by E2E automation. During manual regression passes, these can be skipped unless a test failure has been reported or a related file was changed.

| Manual ID | Description | E2E Spec | Rationale |
|-----------|-------------|----------|-----------|
| AUTH-003 | Email login (returning user) | `smoke/auth.smoke.spec.ts`, `full/auth.full.spec.ts` | Covered by two independent specs on every CI run |
| AUTH-004 | Login with wrong password | `smoke/auth.smoke.spec.ts`, `full/auth.full.spec.ts` | Covered by two independent specs; error message and page-not-left assertions both present |
| AUTH-005 | Signup with existing email | `full/auth.full.spec.ts` | Full error message assertion |
| AUTH-006 | Form validation (empty fields + malformed email) | `full/auth.full.spec.ts` | Empty-field case + malformed-email (no `@`) both covered; empty-password sub-case still manual |
| AUTH-009 | Logout | `smoke/auth.smoke.spec.ts`, `full/auth.full.spec.ts` | Multiple specs confirm session cleared and login screen returned |
| EX-002 | Search exercises | `smoke/exercise.smoke.spec.ts`, `full/exercise-library.spec.ts` | Two-level coverage including result count validation |
| EX-003 | Search does not return soft-deleted exercises | `full/exercise-library.spec.ts` | Create → delete → search → assert zero results |
| EX-005 | Filter combination zero results | `full/exercise-library.spec.ts` | Core + Kettlebell filters with fallback search; asserts empty state text and Clear Filters button |
| EX-006 | Create custom exercise | `smoke/exercise.smoke.spec.ts`, `full/exercise-library.spec.ts` | Happy path fully covered including navigation back and list appearance |
| EX-007 | Duplicate exercise name validation | `full/exercise-library.spec.ts` | Two creates with same name; asserts validation error and no navigation |
| EX-008 | Soft delete custom exercise (happy path) | `smoke/exercise.smoke.spec.ts`, `full/exercise-library.spec.ts` | Card removed from list; note the soft-delete and history-preservation assertions remain manual |
| WK-001 | Start empty workout | `smoke/workout.smoke.spec.ts`, `full/workout-logging.spec.ts` | Both FAB and Finish button asserted |
| WK-002 | Add exercise to workout | Every workout spec | `addExercise()` helper exercised in every workout test across all specs |
| WK-005 | Tap-to-type weight and reps | Every workout spec | `setWeight()` and `setReps()` helpers drive this in every workout test |
| WK-007 | Add set to exercise | `full/workout-logging.spec.ts` | Row count before/after assertion |
| WK-017 | Finish workout (happy path) | `smoke/workout.smoke.spec.ts`, `full/workout-logging.spec.ts` | Core save path exercised in every workout spec with celebration/home assertion |
| WK-018 | Finish with incomplete sets warning | `full/workout-logging.spec.ts` | Dialog text, Keep Going button, and return-to-workout all asserted |
| WK-019 | Discard workout | `smoke/workout.smoke.spec.ts`, `full/workout-logging.spec.ts` | Confirmation dialog and return-to-home both asserted |
| WK-023 | Weight decimal input (22.5 kg) | `full/workout-logging.spec.ts` | `setWeight('22.5')`, full finish, history detail asserts "22.5" visible |
| RT-002 | Start workout from routine card | `full/routines.spec.ts` | Starter routine tap, active workout screen, and pre-filled exercise all verified |
| HOME-003 | Resume banner for active workout | `full/crash-recovery.spec.ts` | Tab navigation away and back verifies banner persistence |
| HOME-004 | Resume banner disappears after finish | `full/crash-recovery.spec.ts` | Start workout → verify banner → finish → return home → assert banner absent |
| HOME-006 | Start Empty Workout from home | `smoke/workout.smoke.spec.ts`, `full/home-navigation.spec.ts` | Button presence and tap both exercised |
| PR-001 | PR detection — max weight | `full/personal-records.spec.ts` | Two workouts with increasing weight, NEW PR heading asserted |
| PR-002 | PR detection — max reps | `full/personal-records.spec.ts` | Two workouts same weight, more reps, NEW PR heading asserted |
| PR-004 | First workout consolidated message | `smoke/pr.smoke.spec.ts`, `full/personal-records.spec.ts` | `firstWorkoutHeading` asserted explicitly |
| PROF-003 | Logout from profile | `smoke/auth.smoke.spec.ts`, `full/auth.full.spec.ts` | `logout()` helper used in multiple specs |
| HIST-005 | Empty history state | `full/history.spec.ts` | Fresh user → /home/history → asserts empty state text and CTA; asserts no error/retry state |
| CC-006 | Crash recovery — kill app mid-workout | `full/crash-recovery.spec.ts` | `page.reload()` simulation, resume banner assertion, and data integrity after tap-resume all covered |
| CC-010 | Double-tap Finish is idempotent | `full/crash-recovery.spec.ts` | `dblclick()` and no-error-state assertion |
