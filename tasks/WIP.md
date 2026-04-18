# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 14d — Local PR Detection + Reconciliation
**Branch:** `feature/phase14d-local-pr-detection`
**Per:** PLAN.md Phase 14d

### Implementation
- [x] Rewrite `finishWorkout()` PR block to read `existingRecords` from `pr_cache` directly (not network-first)
- [x] Use `getCachedWorkoutCount()` unconditionally for `totalFinishedWorkouts` (fallback to 1)
- [x] Always enqueue `upsertRecords` via offline queue (no try-network-first)
- [x] Optimistically update `pr_cache` with detected new records after detection
- [x] Add SyncService post-drain hook: refresh `pr_cache` from server after `upsertRecords` drain success
- [x] Log cache divergence as Sentry breadcrumb (not error)
- [x] Do NOT re-celebrate server-only PRs
- [x] Add `userId` field to `PendingAction.upsertRecords` + update all callers

### Tests
- [x] Unit: finishWorkout reads from cache, detects PRs, queues upsert, updates cache optimistically (5 tests)
- [x] Unit: SyncService post-drain refreshes pr_cache (3 tests)
- [x] Unit: Divergence logging on reconciliation (covered by reconciliation tests)

### Verification
- [x] `dart format .` — 0 changes needed
- [x] `dart analyze --fatal-infos` — 0 issues
- [x] `flutter test` — all 1323 tests pass (was 1315 before, +8 new tests)
- [ ] Acceptance criteria from PLAN.md 14d checked against diff
