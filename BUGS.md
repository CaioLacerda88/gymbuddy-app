# Bugs — Manual QA (2026-04-08)

Found during physical device testing against hosted Supabase. Investigated by QA engineer, reviewed by PO and UX.

**Priority order: BUG-4 > BUG-1 > BUG-2 > BUG-3** (PRs are the primary retention hook — fixing them is most critical)

---

## BUG-1: Back button on Records screen exits the app (P0)

**Reported:** Pressing Android back on the Personal Records screen closes the app instead of returning to Home.

**Root cause:** `home_screen.dart:232` uses `context.go('/records')` which replaces the navigation stack. Since `/records` is a direct child of `ShellRoute` (not a tab destination), GoRouter has no parent to pop back to.

**Agreed fix:**
- Change `context.go('/records')` to `context.push('/records')` in `home_screen.dart`
- Audit all other Home stat card navigations for the same issue (history, etc.)
- Verify AppBar renders a back arrow automatically on the pushed route

**Complexity:** Trivial

**Files:** `lib/features/workouts/ui/home_screen.dart`, `lib/core/router/app_router.dart`

---

## BUG-2: "Add Set" copies reps but not weight (P1)

**Reported:** Adding a new set during a workout preserves the previous set's reps but shows 0 for weight.

**Root cause:** `ExerciseSet.weight` is `double?` (nullable). When the previous set has `null` weight, `prevSet.weight ?? 0` produces 0 instead of copying the value. The copy chain in `active_workout_screen.dart:706-712` doesn't guard against null.

**Agreed fix:**
- Guard null weight when copying: treat `null` as 0 only for bodyweight exercises
- First set: use `defaultSetValues` (existing smart defaults from equipment type — Step 11 logic)
- Subsequent sets: always copy BOTH weight AND reps from the last set in the list (not just last completed)
- Never fall back to 0 for weighted exercises

**Complexity:** Trivial

**Files:** `lib/features/workouts/ui/active_workout_screen.dart` (lines 693-743)

---

## BUG-3: "Fill" button is unclear and appears to do nothing (P2)

**Reported:** Users don't understand what "Fill" does. When sets are completed in order, it does nothing visible.

**Root cause:** `fillRemainingSets` only fills incomplete sets with a `setNumber` higher than the last completed set. If user completes sets in sequence, no fillable sets remain — the button shows but does nothing. The label "Fill" is not self-explanatory.

**Agreed fix (PO + UX consensus):**
- **Hide the button** when no incomplete sets exist after the last completed set
- **Rename** from "Fill" to "Copy to remaining" (PO) or make it a long-press action on "Add Set" with tooltip hint (UX alternative)
- Simplest path: rename to "Fill remaining" + add visibility guard: `sets.any((s) => !s.isCompleted && s.setNumber > lastCompletedSetNumber)`
- Button should only appear when it would actually do something

**Complexity:** Small

**Files:** `lib/features/workouts/ui/active_workout_screen.dart` (lines 776-791, 505-515)

---

## BUG-4: PR records max reps instead of max weight for weighted exercises (P0)

**Reported:** Personal Records show reps-based records for exercises where users expect to see max weight lifted.

**Root cause:** In `pr_detection_service.dart:51-53`, if `weight` is `null` (not 0), the check `(s.weight ?? 0) == 0` evaluates true, routing weighted exercises into the bodyweight branch which only tracks `maxReps`. This means any exercise with null weight data gets reps-only PRs.

**Agreed fix (PO + UX consensus):**
- **Guard null weight** in PR detection — treat null as 0 explicitly, ensure weighted exercises always hit the `maxWeight` detection branch
- **Display format:** Show weight PRs as `100 kg x 5` (weight + reps at which it was achieved), not just raw weight. The `PersonalRecord` model stores `setId`, so reps can be retrieved from the linked set
- **Visual hierarchy:** Weight PR should be visually dominant (larger type, primary color). Volume and maxReps are secondary
- **Data integrity:** Check if bad PR rows were already persisted with wrong `record_type`. May need a "recalculate PRs" function or one-time backfill
- For bodyweight exercises: `maxReps` remains the primary PR (correct behavior)

**Complexity:** Small (detection fix) + Medium (display format + backfill)

**Files:** `lib/features/personal_records/domain/pr_detection_service.dart` (lines 51-53, 65-91), `lib/features/personal_records/ui/pr_list_screen.dart` (display format)
