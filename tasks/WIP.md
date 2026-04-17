# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 14b: Offline Workout Capture + Queue

**Branch:** `feature/14b-offline-workout-queue`
**Source:** PLAN.md Phase 14b + PO/UX feedback

### Data Layer

- [x] **PendingAction sealed class** — Freezed discriminated union supporting 3 action types:
  - `saveWorkout`: full RPC payload (workout, exercises, sets)
  - `upsertRecords`: list of PersonalRecord
  - `markRoutineComplete`: planId, routineId, workoutId
  - Common metadata: `queuedAt`, `retryCount`, `lastError`
- [x] **OfflineQueueService** — reads/writes `PendingAction` items to `offline_queue` Hive box
  - `enqueue(PendingAction)`, `dequeue(String id)`, `getAll()`, `updateAction(PendingAction)`
  - `pendingCount` getter for badge reactivity
- [x] **PendingSyncNotifier** — Riverpod `Notifier<int>` wrapping OfflineQueueService
  - `enqueue()`, `retryItem()`, `getAll()` with automatic state updates
  - `retryItem` executes action via repo, dequeues on success, increments retryCount on failure
- [x] **`getFinishedWorkoutCount` cached counter** — read from `user_prefs`, increment locally on offline finish

### Notifier Changes

- [x] **Update `ActiveWorkoutNotifier.finishWorkout()`** — handle offline for downstream calls:
  - `saveWorkout` try/catch: on failure, enqueue as `PendingAction.saveWorkout`, increment cached count
  - PR detection: read `existingRecords` from `pr_cache` (14a), read `totalFinishedWorkouts` from cached counter
  - `upsertRecords`: try network, on failure enqueue as `PendingAction.upsertRecords`
  - `markRoutineComplete`: try network, on failure enqueue as `PendingAction.markRoutineComplete`
- [x] **Finish-screen offline copy** — when offline, show SnackBar "Workout saved. Will sync when back online." with tertiary color

### Presentation Layer

- [x] **Pending sync badge** — slim full-width tappable row below `HomeStatusLine`:
  - `colorScheme.tertiary` background (alpha: 0.12), `cloud_upload_outlined` icon
  - Text: "1 workout pending sync" / "2 workouts pending sync" (show count)
  - Static (no animation), only rendered when queue non-empty
  - Tap opens modal bottom sheet
- [x] **Pending sync bottom sheet** — modal bottom sheet with drag-to-dismiss:
  - Each queued item: type icon, description, timestamp, "Retry" FilledButton.tonal
  - 48dp minimum row height
  - Manual retry executes single item, removes on success, shows error on failure

### Tests (TDD -- written alongside implementation)

- [x] Unit: PendingAction serialization roundtrip (all 3 types) — 4 tests
- [x] Unit: OfflineQueueService enqueue/dequeue/getAll/updateAction — 8 tests
- [x] Unit: finishedWorkoutCount cached increment — 4 tests
- [x] Widget: Pending sync badge renders with correct count — 3 tests
- [x] Widget: Pending sync badge hidden when queue empty — 1 test
- [x] Widget: Bottom sheet opens on tap — 1 test
- [x] Fix: 20 existing home screen tests updated with pendingSyncProvider override

### Verification

- [x] `dart format .` — 0 changed
- [x] `dart analyze --fatal-infos` — No issues found
- [x] `flutter test` — 1256 tests pass, 0 fail
- [ ] `make ci` full pipeline (format + analyze + test + android build)
- [ ] Acceptance criteria from PLAN.md checked against diff
