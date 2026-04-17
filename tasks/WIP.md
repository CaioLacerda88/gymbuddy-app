# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## QA Monkey Testing + Filter Bug Investigation (2026-04-16)

Findings from code-level analysis. Reproduction steps documented for post-fix verification.

### CRASH — Must Fix

- [ ] **C1: Double-tap "Finish Workout" → concurrent state writes**
  - File: `active_workout_screen.dart:199-271`
  - Root cause: `_onFinish` is async with no in-flight guard. Two rapid taps open two `FinishWorkoutDialog`s; both resolve → `notifier.finishWorkout()` called twice → Supabase duplicate ID or silent data corruption.
  - Repro:
    1. Start a workout, add an exercise, complete at least one set
    2. Two-finger tap (or rapid double-tap within 200ms) on "Finish Workout" button
    3. Expected: one dialog appears, button is disabled during async operation
    4. Actual: two dialogs stack; both can resolve → double save attempt

- [ ] **C2: Stacked Discard dialogs from back-button spam**
  - Files: `active_workout_screen.dart:68-115` (PopScope) + `:174-197` (_onBackPressed)
  - Root cause: Two independent paths show `DiscardWorkoutDialog`. Simultaneous triggers → two dialogs stack → double `discardWorkout()` → `context.go('/home')` fires on disposed context.
  - Repro:
    1. Start a workout with at least one exercise added
    2. Simultaneously: tap AppBar close (X) icon AND press hardware back button
    3. Expected: one discard confirmation dialog
    4. Actual: two dialogs can appear stacked; dismissing both causes double navigation

- [ ] **C3: PRCelebrationScreen `ref.read()` after disposal**
  - File: `pr_celebration_screen.dart:67-77`
  - Root cause: `_logCelebrationSeen()` called outside `mounted` check in `addPostFrameCallback`. Navigating away within first frame → `ref.read()` on disposed element → `StateError`.
  - Repro:
    1. Trigger a PR celebration (log a workout that beats a previous PR)
    2. Instantly tap back/navigate away before the celebration animation starts (~first frame)
    3. Expected: clean navigation, analytics logged or skipped gracefully
    4. Actual: `StateError` in debug mode ("Tried to use ref after element disposed")

### FREEZE — High Priority

- [ ] **F1: `exerciseListProvider` unbounded cache (ROOT CAUSE of user-reported filter freeze)**
  - File: `exercise_providers.dart:49-63`
  - Root cause: `FutureProvider.family` without `autoDispose`. Every distinct `ExerciseFilter` (muscleGroup × equipmentType × searchQuery) creates a permanent cache entry. Never GC'd.
  - Repro:
    1. Go to Exercises tab
    2. Tap through 3-4 different muscle group filters
    3. Type a search query, clear it, type another
    4. Switch equipment type filter back and forth
    5. Expected: smooth filtering, old results released
    6. Actual: 10-20+ provider instances accumulate in memory, each holding full exercise list + Supabase future. UI becomes progressively sluggish.
  - Fix: `FutureProvider.autoDispose.family` (matches existing `exerciseByIdProvider` and `exerciseProgressProvider` patterns).

- [ ] **F2: `filteredExerciseListProvider` invalidation doesn't clear family cache**
  - File: `exercise_list_screen.dart:98`
  - Root cause: `onRefresh` calls `ref.invalidate(filteredExerciseListProvider)` — only invalidates the thin wrapper, not underlying `exerciseListProvider(filter)` entries.
  - Repro:
    1. Filter exercises by muscle group
    2. Pull-to-refresh
    3. Expected: fresh data from Supabase, old cache cleared
    4. Actual: old cached entries persist; refresh appears instant but uses stale data
  - Fix: `ref.invalidate(exerciseListProvider)` (matches `deleteExercise()` and `create_exercise_screen.dart` pattern).

- [ ] **F3: Double rebuild per filter change — redundant `ref.watch()`**
  - File: `exercise_list_screen.dart:44-111`
  - Root cause: `build()` watches filter state providers AND `filteredExerciseListProvider`. Each filter tap → two rebuilds.
  - Repro:
    1. Open Exercises tab
    2. Tap a muscle group filter chip
    3. Expected: one rebuild cycle
    4. Actual: entire widget tree rebuilds twice per filter change (observable via Flutter DevTools widget rebuild counter)
  - Fix: filter selectors should be self-contained `ConsumerWidget`s, not passed-through values.

- [ ] **F4: No debounce on filter chip taps — immediate Supabase round-trip**
  - Files: `exercise_providers.dart:49-63`, `exercise_repository.dart:15-61`
  - Root cause: 300ms debounce exists only for search text. Muscle group / equipment type changes fire immediately.
  - Repro:
    1. Rapidly tap through muscle group chips: Chest → Back → Legs → Shoulders → Arms (within 2 seconds)
    2. Expected: only final filter fires a network request
    3. Actual: 5 concurrent Supabase requests in flight simultaneously

- [ ] **F5: Stepper long-press timer leak on gesture tracking loss**
  - Files: `weight_stepper.dart:43-50`, `reps_stepper.dart:38-50`
  - Root cause: `Timer.periodic(150ms)` relies on `onLongPressEnd` which may not fire if finger breaks gesture tracking. Timer keeps firing → dozens of Hive writes/sec.
  - Repro:
    1. During active workout, long-press a weight stepper +/- button
    2. While pressing, slide finger to scroll the exercise list (breaking gesture tracking)
    3. Expected: timer stops when finger leaves button area
    4. Actual: timer may continue firing indefinitely until widget disposed (navigate away)

- [ ] **F6: `elapsedTimerProvider` + `RestTimerNotifier` tick in background**
  - Files: `workout_providers.dart:42-49`, `rest_timer_notifier.dart:78`
  - Root cause: No `WidgetsBindingObserver` anywhere in codebase. `Stream.periodic` and `Timer.periodic` run continuously regardless of app lifecycle.
  - Repro:
    1. Start a workout (elapsed timer visible)
    2. Start a rest timer
    3. Switch to another app for 30+ seconds
    4. Return to GymBuddy
    5. Expected: timers resume smoothly from correct elapsed time
    6. Actual: possible burst of accumulated ticks on return → rapid setState calls → UI jump

- [ ] **F7: ModalBarrier freeze on network failure during finish/discard**
  - File: `active_workout_screen.dart:46-84`
  - Root cause: `ModalBarrier(dismissible: false)` shown during `AsyncLoading`. If operation stalls, screen is trapped: barrier blocks taps, `PopScope(canPop: false)` blocks back.
  - Repro:
    1. Start a workout, complete sets
    2. Enable airplane mode
    3. Tap "Finish Workout" → confirm dialog
    4. Expected: timeout or error state with recovery option
    5. Actual: semi-opaque black overlay with spinner. No way to dismiss. Must kill app.

- [ ] **F8: `PlanManagementScreen` fires upsert per reorder step**
  - File: `plan_management_screen.dart:198-213, 221-251, 402`
  - Root cause: `_savePlan()` called on every drag step with no debounce. Rapid reorder → 10-20+ concurrent Supabase writes.
  - Repro:
    1. Add 4-5 routines to weekly plan
    2. Rapidly drag rows up and down for several seconds
    3. Expected: save fires once after reorder settles
    4. Actual: one Supabase upsert per drag position change. Final DB state may not match UI.

### VISUAL GLITCH — Normal Priority

- [ ] **G1: ExercisePickerSheet pushes over modal bottom sheet**
  - File: `exercise_picker_sheet.dart:174, 204`
  - Root cause: Pushes full-page `CreateExerciseScreen` over live bottom sheet. Back button reveals stale sheet.
  - Repro:
    1. In active workout, tap "Add Exercise"
    2. Search for non-existent exercise name
    3. Tap "Create [exercise name]" button
    4. Press device back button (don't submit the create form)
    5. Expected: clean return to exercise picker
    6. Actual: picker sheet reappears in loading/empty state

- [ ] **G2: Rapid tab switching → provider churn**
  - File: `app_router.dart:263-265`
  - Root cause: `context.go()` on every tab tap. Rapid switching → multiple provider subscribe/unsubscribe cycles → concurrent Supabase queries.
  - Repro:
    1. Rapidly alternate between Exercises and Routines tabs (5-6 taps/second)
    2. Expected: last tab wins cleanly
    3. Actual: exercise list flashes between loading spinner and data

- [ ] **G3: SetRow Dismissible race on rapid double-swipe**
  - File: `set_row.dart:137-161`
  - Root cause: Swiping two sets within ~100ms. List re-renders mid-gesture. Dismissible key changes after renumbering.
  - Repro:
    1. In active workout, add exercise with 3+ sets
    2. Swipe-to-delete two sets in rapid succession (within ~100ms)
    3. Expected: both sets deleted cleanly
    4. Actual: set may visually disappear but persist in state, or vice versa

- [ ] **G4: Exercise list full card rebuilds on filter change**
  - File: `exercise_list_screen.dart:294-311`
  - Root cause: `_ExerciseCard` non-const constructor. `ListView.builder` rebuilds all visible cards during `AsyncValue` loading → data transition.
  - Repro:
    1. Observe with Flutter DevTools widget rebuild counter enabled
    2. Tap a filter chip
    3. Expected: only changed cards rebuild
    4. Actual: all visible cards rebuild twice (loading flash + data)

### MINOR — Low Priority

- [ ] **M1: `CreateRoutineScreen._save()` ~16ms double-tap window**
  - File: `create_routine_screen.dart:57-99`
  - Repro: Automated 120Hz rapid-tap on Save button. Human can't trigger. Low risk.

- [ ] **M2: `WorkoutHistoryScreen._onScroll` calls `loadMore()` past end**
  - File: `workout_history_screen.dart:35-43`
  - Repro: Scroll to bottom of complete workout history. One extra async call wasted. No user impact.

- [ ] **M3: `RoutineListScreen` no virtualization**
  - File: `routine_list_screen.dart:52-110`
  - Repro: Create 30+ routines, observe scroll jank. Fine at current scale.

### Architecture Observations (inform fixes, not standalone items)

- No `WidgetsBindingObserver` anywhere in the codebase — all timers/streams lack lifecycle awareness
- `autoDispose` missing on family providers is systemic: also `workoutSetsProvider` (`workout_providers.dart:32`), `workoutDetailProvider` (`workout_history_providers.dart:99`)
- No optimistic rollback in `ActiveWorkoutNotifier` — Hive write failure desyncs in-memory vs persisted state silently

---

---

## PR 1: fix/exercise-filter-performance (in progress)

Branch: `fix/exercise-filter-performance`
Per approved plan: `C:\Users\caiol\.claude\plans\dazzling-chasing-dream.md`

- [x] F1: `exerciseListProvider` → `autoDispose.family` (`exercise_providers.dart:49`)
- [x] F2: Fix `ref.invalidate` target (`exercise_list_screen.dart:98`) — now invalidates `exerciseListProvider`
- [x] F3: Extract filter selectors into self-contained `ConsumerWidget`s — `_MuscleGroupSelector` and `_EquipmentFilter` now watch their own state
- [x] F4: Debounce not needed — autoDispose (F1) handles memory; chip taps should be instant for responsiveness
- [x] Systemic: `lastWorkoutSetsProvider` → `autoDispose.family` (`workout_providers.dart:31`)
- [x] Systemic: `workoutDetailProvider` → `autoDispose.family` (`workout_history_providers.dart:99`)
- [x] Tests: 10 new unit tests (exercise_list_provider_test.dart + autodispose_family_test.dart)
- [ ] `make ci` passes (pending orchestrator verification)

**Local repo state:** `main` at `17da20e`.
