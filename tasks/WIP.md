# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## W3 — Stale workout timeout UX (Sprint C)

**Branch:** `feature/w3-stale-workout-timeout-ux`
**Source:** PLAN.md Phase 13 Sprint C, row W3 ("Stale workout timeout UX") and the deferred spec on PLAN.md:531 ("When app opens and `startedAt` is >6 hours ago, show prominent modal… Already handled partially by `ResumeWorkoutDialog`. Enhancement goes into Phase 13 production readiness.")

**Intent:** Today `ResumeWorkoutDialog` fires on every app-open with an in-progress workout and shows only the workout name + Resume/Discard. When the workout is stale (`startedAt` ≥ 6h ago) the user needs more context ("when did I start this?") to decide. This adds a stale branch with a human-readable age, reworded copy, and a clearer primary action. No threshold change to the trigger — the dialog still shows for any in-progress workout; only the content differs.

### Design direction (from product-owner + ui-ux-critic)

- **Threshold:** 6h (`DateTime.now().difference(startedAt) >= Duration(hours: 6)`) → stale branch. Deterministic, matches PLAN.md spec.
- **Age formatting rule:**
  - `< 1h` → `"less than an hour ago"` (should not trigger stale branch, included for completeness)
  - `1h ≤ age < 24h` and same calendar day → `"$N hours ago"`
  - `age < 48h` and on previous calendar day → `"yesterday at $H:MM $AM/PM"`
  - `age < 7d` → `"$WEEKDAY at $H:MM $AM/PM"` (e.g. "Monday at 9:30 AM")
  - `age ≥ 7d` → `"$N days ago"`
- **Copy (fresh, <6h):** title `Resume workout?` / body `"$workoutName" is still in progress.`
- **Copy (stale, ≥6h):** title `Pick up where you left off?` / body is two lines via `Text.rich`:
  - Line 1: `"$workoutName"` styled as `titleMedium` (matches data-first typography elsewhere)
  - Line 2: `was interrupted $age.` in `bodyMedium` at `onSurface.withValues(alpha: 0.6)` (muted secondary)
- **Buttons:**
  - Fresh: `Discard` (TextButton, `foregroundColor: colorScheme.error`) | `Resume` (FilledButton)
  - Stale: `Discard` (same) | `Resume anyway` (FilledButton) — "anyway" acknowledges the user is consciously choosing to continue old data
- **Anti-generic rules:**
  - NO clock/warning icon (this is not an error state; workout data is safe)
  - NO centered body text (default left-align stays)
  - NO chip/pill for age (plain muted text line)
  - NO change to `AlertDialog` widget type or barrier behavior

### Implementation plan

Pure UI-layer change. No DB/migration/repository changes.

- [ ] `lib/features/workouts/ui/widgets/resume_workout_dialog.dart`
  - Add `DateTime startedAt` param to the dialog (required). The notifier already has this on `state.workout.startedAt`.
  - Add a pure `_formatAge(DateTime startedAt, DateTime now)` helper (package-private, top-level) implementing the 5-rule ladder above. `now` injected for testability.
  - Add a pure `_isStale(Duration age)` helper → `age >= Duration(hours: 6)`.
  - Branch the `AlertDialog` body:
    - Fresh: existing `Text('"$workoutName" is still in progress.')` (keep current minimal shape, retitle to `Resume workout?` — current has no explicit title, add one).
    - Stale: `Text.rich` with two `TextSpan`s (name in titleMedium, age line in muted bodyMedium).
  - Relabel primary FilledButton to `Resume anyway` in the stale branch.
  - Keep `barrierDismissible: false`, keep `ResumeWorkoutResult` enum and return values.
- [ ] Update the two call sites of `ResumeWorkoutDialog.show` (per Explore report):
  - `lib/features/workouts/ui/home_screen.dart:118` (_startEmptyWorkout)
  - `lib/features/routines/ui/start_routine_action.dart:15` (routine-resume path)
  - Both already have access to the active workout state (via `activeWorkoutProvider.value`) — pass `state.workout.startedAt` through.
- [ ] No analytics change. `discardWorkout()` already tracks elapsed seconds (noted in Explore report); that instrumentation is unchanged.

### Tests

- [ ] Unit tests for `_formatAge` covering all 5 branches (fresh <1h, same-day hours, yesterday, weekday, >7d) + the boundary minute cases. Fixed `now` to make assertions deterministic.
- [ ] Unit test for `_isStale` at the 5h59m / 6h00m boundary (off-by-one check).
- [ ] Widget test for `ResumeWorkoutDialog`:
  - Fresh branch: title = `Resume workout?`, body contains name, primary button = `Resume`.
  - Stale branch: title = `Pick up where you left off?`, body contains name + age string, primary button = `Resume anyway`.
  - Discard tap returns `ResumeWorkoutResult.discard`; Resume tap returns `.resume`.
- [ ] No new E2E — dialog already exists; existing Playwright tests (if any cover resume flow) get a selector-impact scan. Button label change `Resume` → `Resume anyway` in stale branch is the only risk.

### Out of scope

- Not changing when the dialog shows (trigger stays: any in-progress workout on app open).
- Not changing `discardWorkout()` semantics or analytics.
- Not auto-discarding stale workouts (explicit PLAN.md:533 decision: "Not auto-discard").
- Not adding a "Discard" confirmation step (product-owner: cognitive check already provided by the date copy).
- No new theme tokens; reuse `colorScheme.error`, `onSurface` with alpha, `titleMedium`/`bodyMedium`.

### Verification

- [ ] `make ci` green (format + gen + analyze + test + android-debug-build).
- [ ] E2E: selector impact scan on `helpers/selectors.ts` — check for any matcher on the literal `"Resume"` button text that could now hit both `"Resume"` (fresh) and `"Resume anyway"` (stale). Update if found.
- [ ] No flow change → skip full E2E suite run per CLAUDE.md E2E conventions (visual-only change, no navigation/routing/provider logic change).

### QA gate

- `qa-engineer` reviews unit + widget coverage, flags gaps.
- Selector impact review.
- New E2E only required if selector scan finds an ambiguous match that can't be disambiguated.
