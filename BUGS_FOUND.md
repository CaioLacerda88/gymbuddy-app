# Bugs Found — E2E Infrastructure Review

Identified during the Step 9 E2E cleanup (branch `fix/remove-web-renderer-flag`).
These are issues in the Flutter app code that make testing fragile or unreliable.
They are not test bugs — they are app bugs that the tech lead should address.

---

## BUG-001: Error container on LoginScreen has no `role="alert"` Semantics

**Severity:** Medium — test reliability  
**File:** `lib/features/auth/ui/login_screen.dart`

The inline error message container rendered on auth failure is a plain `Container`
with no `Semantics` widget wrapping it. The selector `flt-semantics[role="alert"]`
used in `helpers/selectors.ts` (`AUTH.errorMessage`) relies on Flutter exposing
a `role="alert"` attribute, which only happens when a `Semantics(label: ..., liveRegion: true)` or equivalent widget is present.

Without this, the test selector `flt-semantics[role="alert"]` will never match,
causing every auth error test to fail when run against a real browser.

**Expected fix:** Wrap the error container in `Semantics` with `liveRegion: true`
so assistive technology (and Playwright) can detect errors:

```dart
Semantics(
  liveRegion: true,
  child: Container(
    // existing error container
  ),
),
```

---

## BUG-002: `AppButton` label prop is not exposed as an ARIA label

**Severity:** Medium — selector fragility  
**File:** `lib/shared/widgets/app_button.dart`

`AppButton` uses `ElevatedButton` (or `ElevatedButton.icon`) with a `Text(label)`
child. Flutter's semantics system correctly picks up the button text as the
accessible name, so `flt-semantics[aria-label="LOG IN"]` works today.

However, when `isLoading = true`, the button renders a `CircularProgressIndicator`
instead of the text label. At that point the button's accessible name becomes
empty or undefined, breaking any assertion that expects the button to be visible
by its label during a loading state.

**Expected fix:** Add a `Semantics` wrapper that preserves the label during loading:

```dart
Semantics(
  label: label,
  button: true,
  child: ElevatedButton(onPressed: effectiveOnPressed, child: child),
)
```

---

## BUG-003: Weight stepper value text has no explicit Semantics label

**Severity:** Medium — test robustness  
**File:** `lib/shared/widgets/weight_stepper.dart`

The tappable weight value text (the large number in the set row, e.g. "0") inside
`WeightStepper` is wrapped in a `GestureDetector` but has no `Semantics` label.
Playwright tests target it with `page.locator('text=0').first()`, which is fragile
because:

1. "0" can match many other text nodes on the page (reps value, set numbers, etc.)
2. If the weight is non-zero (e.g. "60"), the selector must change to `text=60`

The E2E helpers currently exploit the fact that after adding a new exercise the
first "0" is the weight cell — but this ordering assumption will break if the UI
layout changes or if any other visible "0" appears earlier in the DOM.

**Expected fix:** Wrap the value text in `Semantics` with a descriptive label:

```dart
// In WeightStepper.build(), around the GestureDetector for the value:
Semantics(
  label: 'Weight value: ${_formatWeight(widget.value)} kg. Tap to enter weight.',
  button: true,
  child: GestureDetector(
    onTap: _showNumberInput,
    child: SizedBox(width: 72, child: Text(...)),
  ),
),
```

This would allow the test to use `[aria-label^="Weight value"]` as a reliable
selector instead of the fragile `text=0`.

---

## BUG-004: Reps stepper value text has no explicit Semantics label

**Severity:** Medium — test robustness  
**File:** `lib/shared/widgets/reps_stepper.dart`

Same problem as BUG-003, but for the reps value. `RepsStepper` shows the integer
rep count as large text without a `Semantics` label.

The `setReps()` helper relies on the assumption that after setting weight, the
first remaining "0" in the DOM is the reps value. This breaks if:
- Weight was set to 0 (the helper would click weight again)
- Multiple exercise sets are visible simultaneously

**Expected fix:** Same pattern as BUG-003:

```dart
Semantics(
  label: 'Reps value: ${widget.value}. Tap to enter reps.',
  button: true,
  child: GestureDetector(
    onTap: _showNumberInput,
    child: SizedBox(width: 56, child: Text(...)),
  ),
),
```

---

## BUG-005: Active workout AppBar title text has no Semantics label for the workout name

**Severity:** Low — test coverage gap  
**File:** `lib/features/workouts/ui/active_workout_screen.dart`

The workout name displayed in the AppBar title is inside a `GestureDetector`
(for tap-to-rename) with no `Semantics` label. The E2E test for the auto-generated
workout name uses `flt-semantics[aria-label*="Workout \u2014"]` which relies on
Flutter inferring the aria-label from the `Text` widget's content.

In practice Flutter does propagate text content as the accessible name for `Text`
widgets inside `Semantics` contexts, but this is not guaranteed across Flutter
versions. If the semantics tree changes, this selector will silently stop working.

**Expected fix:** Add an explicit `Semantics` label to the title `GestureDetector`:

```dart
Semantics(
  label: '${widget.state.workout.name}. Tap to rename workout.',
  child: GestureDetector(
    onTap: () { ... },
    child: Row(...),
  ),
),
```

---

## BUG-006: Discard workout triggers via close icon, not a "Discard" label

**Severity:** Low — selector mismatch risk  
**File:** `lib/features/workouts/ui/active_workout_screen.dart`

The AppBar leading button uses `tooltip: 'Discard workout'` and an `Icons.close`
icon. The E2E tests look for `WORKOUT.discardButton` which maps to
`'text=Discard'`. This text appears in the confirmation dialog (inside
`DiscardWorkoutDialog`), not on the AppBar close button itself.

This means `page.locator(WORKOUT.discardButton)` will only match after the
discard dialog is already open — which is not how the selector is described in
the comments. The tests work today only because they click the AppBar close icon
(via `page.locator(WORKOUT.discardButton).click()` failing silently and then
falling through to a dialog check), or because the dialog text happens to be
found. This creates a confusing test flow.

**Expected fix in the app:** Add a `Semantics` label to the AppBar leading button:

```dart
Semantics(
  label: 'Discard workout',
  child: IconButton(
    onPressed: _onBackPressed,
    icon: const Icon(Icons.close),
    tooltip: 'Discard workout',
  ),
),
```

**Expected fix in tests:** Update `WORKOUT.discardButton` in `selectors.ts` to
`'[aria-label="Discard workout"]'` once the Semantics label is added.

---

## BUG-007: `FinishWorkoutDialog` uses `Text('Finish Workout')` as button label, causing selector ambiguity

**Severity:** Low — test reliability  
**File:** `lib/features/workouts/ui/widgets/finish_workout_dialog.dart`

Both the bottom-bar `FilledButton` ("Finish Workout") and the dialog confirmation
button ("Finish Workout") use the same text label. The `finishWorkout()` helper
uses `page.locator(WORKOUT.finishButton).last()` to target the dialog button
(relying on DOM order). If the bottom bar button remains in the DOM while the
dialog is open, the `.last()` heuristic could pick the wrong element.

**Expected fix:** Give the dialog action button a distinct Semantics label, such
as "Confirm finish workout", to make it unambiguously selectable:

```dart
Semantics(
  label: 'Confirm finish workout',
  child: FilledButton(
    onPressed: () { ... },
    child: const Text('Finish Workout'),
  ),
),
```

Then update `WORKOUT.finishButton` to have a separate `finishConfirmButton`
constant in `selectors.ts`.

---

## Summary table

| ID      | File                                   | Severity | Type                        |
|---------|----------------------------------------|----------|-----------------------------|
| BUG-001 | auth/ui/login_screen.dart              | Medium   | Missing Semantics liveRegion |
| BUG-002 | shared/widgets/app_button.dart         | Medium   | Missing Semantics during loading |
| BUG-003 | shared/widgets/weight_stepper.dart     | Medium   | Missing Semantics label      |
| BUG-004 | shared/widgets/reps_stepper.dart       | Medium   | Missing Semantics label      |
| BUG-005 | workouts/ui/active_workout_screen.dart | Low      | Implicit Semantics (fragile) |
| BUG-006 | workouts/ui/active_workout_screen.dart | Low      | Selector mismatch risk       |
| BUG-007 | workouts/ui/widgets/finish_workout_dialog.dart | Low | Ambiguous button label |
