# Plan: Exercise Detail Link + Home Stat Cards

## Context

Two UX improvements informed by PO and UI/UX review:
1. The 40x40 exercise thumbnail in the active workout screen wastes space and serves no purpose mid-workout. Users need a way to check exercise details (form, PRs) without one today.
2. History and PRs are only reachable via "View All" links buried in the home screen scroll. New users with no data see no navigation path at all (sections collapse via `SizedBox.shrink()`).

---

## Change 1: Exercise Detail Bottom Sheet in Active Workout

**Remove** the 40x40 `ExerciseImage` thumbnail from exercise cards. **Add** a tappable exercise name with small info icon that opens exercise detail as a full-screen bottom sheet (modal). Workout state is never at risk.

### Exercise card header — before vs after

```
BEFORE:  [40x40 img] [Exercise Name (long-press=swap)] [swap] [delete]
AFTER:   [Exercise Name ⓘ (tap=detail, long-press=swap)] [swap] [delete]
```

### Files to modify

1. **`lib/features/workouts/ui/active_workout_screen.dart`** (`_ExerciseCard` class, ~line 521)
   - Remove the `ExerciseImage` widget and its conditional rendering
   - Add `onTap` to the exercise name `GestureDetector` → calls `_showExerciseDetail()`
   - Add 14dp `Icons.info_outline` icon after the name text, `onSurface` at 35% opacity, with 6dp gap
   - Ensure the entire name+icon row is wrapped in an `InkWell` with min 48dp height
   - Keep existing `onLongPress` for swap

2. **`lib/features/workouts/ui/active_workout_screen.dart`** (new method `_showExerciseDetail`)
   - `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)` 
   - Content: reuse `ExerciseDetailScreen` content or build a lightweight version showing:
     - Exercise name, muscle group chip, equipment chip
     - Start/end images (existing `ExerciseImage` widget)
     - PR section (reuse existing PR display from exercise detail)
   - Close button in AppBar or drag-to-dismiss

3. **`lib/features/exercises/ui/exercise_detail_screen.dart`** (optional)
   - Consider extracting the body content into a reusable `ExerciseDetailContent` widget that both the full screen and the bottom sheet can use
   - If too coupled to `Scaffold`, build a simpler bottom sheet body directly

### Design specs
- Exercise name: `titleMedium` (16sp w600), `onSurface` — unchanged
- Info icon: `Icons.info_outline`, 14dp, `onSurface.withValues(alpha: 0.35)`
- Gap between name and icon: 6dp `SizedBox`
- InkWell splash: `BorderRadius.circular(8)`
- Bottom sheet: `DraggableScrollableSheet` with `initialChildSize: 0.85`, rounded top corners 16dp

### Do NOT
- Navigate via `context.go('/exercises/$id')` — destroys active workout screen
- Underline the exercise name — web convention, reads as noise on dark UI
- Make name text green — reserved for completion states
- Add a separate "View Details" button — wastes vertical space

---

## Change 2: Stat Cards on Home Screen

**Add** two tappable stat cards below the header showing live counts. Tap navigates to full page. Keep existing "View All" links in sections.

### Home screen layout — after

```
GymBuddy
Mon, Apr 6

┌───────────────┐ ┌──────────────┐
│  14           │ │  3           │
│  Workouts     │ │  Records     │
└───────────────┘ └──────────────┘

MY ROUTINES
...
RECENT                    View All
...
RECENT RECORDS            View All
...
```

### Files to modify

1. **`lib/features/workouts/ui/home_screen.dart`**
   - Add `_StatCardsRow` widget after the date subtitle, before MY ROUTINES section
   - Two `Expanded` cards in a `Row` with 8dp gap
   - Left card: workout count → navigates to `/home/history`
   - Right card: PR count → navigates to `/records`
   - Watch `workoutCountProvider` and `prCountProvider` (already created in the reviewer fixes)

2. **`lib/features/workouts/ui/home_screen.dart`** (new widget `_StatCard`)
   - Reusable stat card: takes `count`, `label`, `onTap`
   - Card height: 72dp
   - Number: `headlineMedium` (24sp w700), `colorScheme.primary` (#00E676)
   - Label: `bodySmall` (12sp), `onSurface.withValues(alpha: 0.55)`
   - Background: `cardTheme.color` (#232340), `borderRadius: 12`
   - Padding: `EdgeInsets.symmetric(horizontal: 16, vertical: 12)`
   - InkWell with `borderRadius: 12` for tap feedback
   - Loading state: show `--` for count while providers load
   - Semantics: `"14 Workouts, tap to view history"`

### Layout spacing
- 16dp above stat row (after date)
- 20dp below stat row (before MY ROUTINES header)
- 8dp gap between the two cards

### Do NOT
- Use icons inside the stat cards — the number IS the content
- Use a horizontal scrollable chip row — hidden content is a discoverability trap
- Remove "View All" links from sections — they serve a different context (in-section discovery)
- Use green for the card background — green is for numbers only

---

## Change 3: Manage Data (Centralized in Profile)

**Add** a "Manage Data" sub-screen accessible from the Profile screen. Two options with escalating confirmation severity. Replaces the idea of scattered trash icons on individual screens.

### Profile screen addition

```
  ─────────────────────────────────
  DATA MANAGEMENT

  ┌─────────────────────────────────┐
  │  Manage Data                 ›  │   ← standard row, chevron
  └─────────────────────────────────┘

  ┌─────────────────────────────────┐
  │  Log Out                        │
  └─────────────────────────────────┘
```

### Manage Data sub-screen

```
  ← Manage Data
  ─────────────────────────────────

  WORKOUT HISTORY
  ┌─────────────────────────────────┐
  │  Delete Workout History         │
  │  14 workouts will be removed    │   ← live count, secondary text
  └─────────────────────────────────┘

  ─────────────────────────────────
  DANGER
  ┌─────────────────────────────────┐   ← #FF5252 at 12% bg tint
  │  Reset All Account Data         │   ← bold weight
  │  Removes everything. Permanent. │
  └─────────────────────────────────┘
```

### Two options, two confirmation tiers

**Option 1: "Delete Workout History"** — two-step dialog
- Deletes all finished workouts (`finished_at IS NOT NULL AND is_active = false`)
- PRs, custom exercises, and routines are preserved
- First dialog: "Delete all workout history? This will permanently delete all X workouts and cannot be undone." [Cancel] [Delete History] (red)
- Second dialog: "Are you sure? Your personal records and routines will be kept." [Cancel] [Yes, Delete] (red)
- SnackBar: "Workout history cleared"

**Option 2: "Reset All Account Data"** — type-to-confirm full-screen modal
- Deletes workouts + PRs
- Routines and custom exercises survive (they're definitions/templates, not records — and routines reference custom exercises)
- Full-screen modal (not a bottom sheet — signals nuclear severity):
  ```
  ╔═════════════════════════════════╗
  ║   Reset Account Data            ║
  ║                                 ║
  ║   This will permanently delete  ║
  ║   all workouts and personal      ║
  ║   records. Your routines and    ║
  ║   custom exercises will be      ║
  ║   kept. There is no undo.       ║
  ║                                 ║
  ║   Type RESET to confirm         ║
  ║   ┌─────────────────────────┐   ║
  ║   │  _                      │   ║
  ║   └─────────────────────────┘   ║
  ║                                 ║
  ║   [Cancel]   [Reset Account]    ║
  ╚═════════════════════════════════╝
  ```
- "Reset Account" button disabled until user types "RESET" (case-insensitive)
- Button uses destructive gradient (#FF5252 → #D32F2F) when enabled
- Heavy haptic feedback on confirm

### Files to modify

1. **`lib/features/workouts/data/workout_repository.dart`**
   - Add `clearHistory(String userId)` method
   - SQL: `DELETE FROM workouts WHERE user_id = $1 AND finished_at IS NOT NULL AND is_active = false`
   - Only deletes finished, non-active workouts (never touch an in-progress workout)
   - Cascade: `workout_exercises` and `sets` delete via FK cascade (verify schema has `ON DELETE CASCADE`)

2. **`lib/features/personal_records/data/pr_repository.dart`**
   - Add `clearAllRecords(String userId)` method

3. **`lib/features/profile/providers/`** (new or extend existing)
   - Add `clearHistoryProvider` — calls workout repo, invalidates history + count providers
   - Add `resetAllDataProvider` — calls workout + PR repos, invalidates all relevant providers

5. **`lib/features/profile/ui/profile_screen.dart`**
   - Add "DATA MANAGEMENT" section with "Manage Data" row above logout
   - Navigates to new route `/profile/manage-data`

6. **`lib/features/profile/ui/manage_data_screen.dart`** (new)
   - Two sections: "Workout History" and "Danger"
   - Workout count from `workoutCountProvider`, PR count from `prCountProvider`
   - Danger row: `#FF5252` at 12% opacity background tint

7. **`lib/core/router/app_router.dart`**
   - Add route `/profile/manage-data` → `ManageDataScreen`

### Design specs
- Section headers: `bodySmall`, `onSurface.withValues(alpha: 0.55)`, uppercase
- Row tiles: standard `ListTile` height, secondary text for counts
- Danger tile background: `colorScheme.error.withValues(alpha: 0.12)`
- Dialog/modal buttons: Cancel = `TextButton`, Delete = `TextButton` with `colorScheme.error`
- Type-to-confirm field: standard `TextField` with `colorScheme.error` focus border
- "Reset Account" button: disabled `GradientButton` → destructive gradient when "RESET" typed
- Heavy haptic on both final confirmations

### Do NOT
- Put trash icons on the history screen or PR list screen — all destructive actions live here
- Delete routines or custom exercises — they're definitions/templates, not records; routines reference exercises
- Offer standalone "Clear PRs" — PRs are derived from history, no credible solo use case
- Use "Danger Zone" label — consumer app, not dev tools; use "Data Management"
- Offer undo/soft-delete — permanent actions should feel permanent

---

## Testing

### Widget tests to write
- `_StatCardsRow`: renders counts, shows `--` on loading, taps navigate to correct routes
- Exercise card header: info icon present, tap opens bottom sheet, long-press still triggers swap
- Bottom sheet: renders exercise name/muscle/equipment/images/PRs, dismissible
- Manage Data screen: renders both options with live counts
- Delete History dialog: two-step confirmation, cancel at each step aborts, final confirm triggers delete
- Reset All modal: type-to-confirm field, button disabled until "RESET" typed, executes reset
- Profile screen: "Manage Data" row navigates to sub-screen

### Unit tests to write
- `clearHistory` repository method: deletes finished workouts, does NOT delete active workouts
- `clearAllRecords` repository method: deletes all PRs for user
- `resetAllDataProvider`: calls workout + PR repos, invalidates all providers
- Provider invalidation: `workoutCountProvider` and `prCountProvider` refresh after clear

### Existing tests to update
- Active workout screen tests that assert on the exercise image widget — remove those assertions
- Home screen tests — add stat cards expectations

### Verification
```bash
export PATH="/c/flutter/bin:$PATH"
dart format .
dart analyze --fatal-infos
flutter test
flutter run -d RXCY500Z22M --release  # visual verification on phone
```

Manual checks:
- Tap exercise name mid-workout → bottom sheet opens, workout timer keeps running
- Dismiss bottom sheet → return to exact scroll position in workout
- Home screen stat cards show correct counts
- Tap Workouts card → history screen, tap Records card → PR list
- New user (0 workouts, 0 PRs) → cards show "0", still tappable
- Profile → Manage Data → Delete History: two-step confirm, history cleared, stat card shows "0", PRs intact
- Profile → Manage Data → Reset All: type "RESET", everything cleared, routines survive
- After reset: home stat cards show "0", history empty, PR list empty, routines + custom exercises still present
