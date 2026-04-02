# Step 5: Workout Logging — Design Spec

## Context

Workout logging is GymBuddy's core feature. Steps 1-4b established the foundation (project setup, DB schema, auth, exercise library). Step 5 builds the primary value loop: start a workout, add exercises, log sets with weight/reps, finish, and review history.

The feature is decomposed into four independently shippable sub-steps (5a-5d), each building on the previous, each merged to main via PR.

## Sub-step Breakdown

### 5a: Models + Migration + Repository + Hive Persistence

**Goal:** Build the data layer — everything below the UI.

**Database migration** (`supabase/migrations/00005_save_workout_rpc.sql`):
- `save_workout(p_workout jsonb, p_exercises jsonb, p_sets jsonb)` Postgres RPC
- SECURITY DEFINER, single transaction
- Validates `auth.uid()` matches workout user_id
- Inserts into workouts, workout_exercises, sets atomically
- Sets `is_active = false` and `finished_at` on the saved workout

**Freezed models** (`lib/features/workouts/models/`):
- `workout.dart` — matches `workouts` table (id, userId, name, startedAt, finishedAt, durationSeconds, isActive, notes, createdAt)
- `workout_exercise.dart` — matches `workout_exercises` table + optional `Exercise? exercise` for display (excluded from toJson)
- `exercise_set.dart` — matches `sets` table including set_type, weight as double, rpe as int?
- `set_type.dart` — enum: working, warmup, dropset, failure (follows MuscleGroup pattern with displayName + fromString)
- `weight_unit.dart` — enum: kg, lbs with defaultIncrement (2.5 / 5.0)
- `active_workout_state.dart` — nested Freezed: Workout + List<WorkoutExercise> (each with List<ExerciseSet>) + schemaVersion int. This is the Hive serialization shape.

**Repository** (`lib/features/workouts/data/workout_repository.dart`):
- Extends `BaseRepository`, uses `mapException()` wrapper
- `saveWorkout(workout, exercises, sets)` — calls `_client.rpc('save_workout')`
- `getActiveWorkout(userId)` — query where `is_active = true`
- `getWorkoutHistory(userId, {limit, offset})` — ordered by `finished_at DESC`
- `getWorkoutDetail(workoutId)` — full workout with joined exercises and sets
- `getLastWorkoutSets(exerciseIds)` — batch query with `exercise_id = ANY($ids)`
- `discardWorkout(workoutId)` — delete active workout row

**Hive persistence** (`lib/features/workouts/data/workout_local_storage.dart`):
- Uses existing `HiveService.activeWorkout` box
- `saveActiveWorkout(state)` — jsonEncode + store schemaVersion
- `loadActiveWorkout()` — returns null on: empty box, corrupt JSON, version mismatch
- `clearActiveWorkout()`, `hasActiveWorkout` getter

**Provider foundations** (`lib/features/workouts/providers/workout_providers.dart`):
- `workoutRepositoryProvider`, `workoutLocalStorageProvider`, `hasActiveWorkoutProvider`

**Test factories** — extend `test/fixtures/test_factories.dart` with set_type field on TestSetFactory, add TestActiveWorkoutStateFactory.

**Agents:** supabase-dev (migration) -> tech-lead (models, repo, Hive, providers) -> qa-engineer (tests)

---

### 5b: Active Workout Screen — Exercise Picker, Set Logging, Basic Completion

**Goal:** Build the core workout experience — start, add exercises, log sets, mark complete.

**ActiveWorkoutNotifier** (`lib/features/workouts/providers/notifiers/active_workout_notifier.dart`):
- AsyncNotifier<ActiveWorkoutState?> — the core state machine
- build(): check Hive for existing workout
- startWorkout(name): create state, insert DB row with is_active=true, save to Hive
- addExercise, removeExercise, addSet, updateSet, completeSet, deleteSet
- resumeWorkout(), discardWorkout()
- Every mutation auto-saves to Hive (fire-and-forget)

**Supporting providers:**
- `lastWorkoutProvider` — FutureProvider.family keyed by exercise IDs, batch query for previous weight/reps
- `elapsedTimerProvider` — StreamProvider emitting formatted duration every second

**Active workout screen** (`lib/features/workouts/ui/active_workout_screen.dart`):
- Full-screen route at `/workout/active` (outside shell, no bottom nav)
- AppBar: workout name, elapsed timer, back (with discard confirmation)
- ListView of exercise cards with set rows
- Empty state: "Add your first exercise" with add button
- FAB: "Add Exercise" opening picker sheet

**Widgets:**
- `set_row.dart` — set number, weight stepper, reps stepper, completion checkbox (48x48dp min)
- `exercise_picker_sheet.dart` — 70% height bottom sheet, search, recent exercises, reuses exercise repository from Step 4
- `resume_workout_dialog.dart` — shown on startup if Hive has active workout
- `discard_workout_dialog.dart` — shows duration, destructive confirm

**Shared widgets:**
- `weight_stepper.dart` — minus/value/plus with configurable increment (2.5kg/5lbs), long-press fast increment
- `reps_stepper.dart` — same pattern, integer increments

**Router changes:** Add `/workout/active` outside ShellRoute.

**Agents:** tech-lead (notifier, providers, steppers) -> flutter-dev (screens, widgets, router) -> qa-engineer (tests)

---

### 5c: Rest Timer, Reorder, Polish

**Goal:** Add the UX polish features that make workout logging feel professional.

**New packages:** `wakelock_plus: ^1.2.0`, `vibration: ^2.0.0`

**Rest timer:**
- `rest_timer_notifier.dart` — AsyncNotifier managing countdown, wakelock while active, vibration (3 short pulses) on complete
- `rest_timer_overlay.dart` — full-screen overlay with 72sp+ countdown, circular progress ring, skip button, auto-dismiss

**Set row enhancements:**
- Set type selector (working/warmup/dropset/failure) — small chip per row
- RPE input — hidden by default, tap icon to reveal 1-10 picker
- Swipe right = complete (green reveal), swipe left = delete with 5s undo snackbar
- Haptic feedback: mediumImpact on complete, lightImpact on delete

**Copy/Fill:**
- "Copy last set" button per row (copies previous set's weight/reps)
- "Fill remaining sets" long-press on "Add Set" (fills empty sets with last completed values)

**Exercise management:**
- Reorder mode: toggle via AppBar, up/down arrow buttons (56dp), NOT drag
- Swap exercise: long-press context menu, opens picker, preserves set structure

**Agents:** tech-lead (timer notifier, notifier methods) -> flutter-dev (all UI: overlay, selectors, swipe, reorder) -> ui-ux-critic (gym-floor usability review) -> qa-engineer (tests)

---

### 5d: Finish Flow, Workout History, Nav Indicator

**Goal:** Close the workout loop — save, review history, navigate back.

**Finish workout:**
- `finishWorkout({notes})` on ActiveWorkoutNotifier
- Check incomplete sets (return count for UI confirmation)
- Calculate duration, call save_workout RPC, clear Hive
- On RPC failure: keep Hive intact, queue to offline_queue box, show error with retry
- Return saved data (// TODO: PR detection Step 7 placeholder)

**Finish dialog** (`finish_workout_dialog.dart`):
- Incomplete set warning with count
- Notes text field
- "Finish Workout" / "Keep Going" buttons

**Workout history:**
- `workout_history_screen.dart` — replaces /history placeholder in shell
- List: date, name, exercise count, duration, volume
- Pull-to-refresh, pagination
- Empty state: "Start your first workout" with CTA
- `workout_detail_screen.dart` — route `/history/:workoutId`, read-only view of exercises + sets

**Models:** `workout_detail.dart` — read-only Freezed wrapper (separate from ActiveWorkoutState)

**Providers:** `workout_history_providers.dart` — AsyncNotifier with pagination, FutureProvider.family for detail

**Utility:** `lib/core/utils/workout_formatters.dart` — formatDuration, formatVolume, formatWorkoutDate

**Active workout nav indicator:**
- Modify `_ShellScaffold` in app_router.dart to become ConsumerWidget
- When active workout exists: 56dp mini-bar above bottom nav with duration + "Return to Workout"
- Tap navigates to `/workout/active`

**Router:** Add `/history/:workoutId` sub-route

**Agents:** tech-lead (model, finishWorkout, formatters, nav indicator logic) -> supabase-dev (verify history/detail queries) -> flutter-dev (finish dialog, history screens, mini-bar UI, router) -> ui-ux-critic (review) -> qa-engineer (tests)

---

## Key Architectural Decisions

1. **Single ActiveWorkoutNotifier** holds full nested state. For 5-8 exercises with 4 sets each, Freezed copyWith rebuild cost is negligible.

2. **Hive serialization** via `jsonEncode(state.toJson())` — no custom Hive adapters. Schema version int for migration safety. Corrupt/mismatched data returns null, never throws.

3. **Atomic save via Postgres RPC** — workout + exercises + sets in one transaction. No partial data on network failure.

4. **Exercise picker scoped providers** — picker uses separate filter state from the exercise list screen to avoid interference.

5. **Rest timer is global** to the workout (not per-exercise), survives exercise navigation, implemented as overlay (not a route).

6. **Offline failure path** — on RPC failure, queue to offline_queue Hive box. Sync worker is out of scope for Step 5 (just queue it).

## Verification

After each sub-step:
1. `make ci` passes (format + analyze + gen + test)
2. All new tests pass
3. Manual smoke test on Android emulator where applicable (5b+)

End-to-end validation after 5d:
- Start workout -> add exercises -> log sets -> finish -> verify in history
- Resume after app restart (Hive recovery)
- Discard workout confirmation
- Rest timer with vibration
- History list and detail screens populated
