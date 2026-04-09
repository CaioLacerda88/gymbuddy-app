# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Next Up: Step 12.3a — P0 Bug Fixes

**Status:** Planning complete, ready to implement.
**Source:** PLAN.md Step 12.3a

### Context

- Steps 12.2a (#36), 12.2b (#37), 12.2c (#38) all merged to main
- Manual QA on device found 6 issues → analyzed by PO, UX, QA agents
- Step 12.3 written in PLAN.md with 3 sub-steps (a/b/c)
- Migration 00012 (personal_records.reps) applied to prod
- 852 tests passing on main

### 12.3a: Two P0 Bugs

**Bug 1: Back nav closes app on active workout**
- Root cause: `PopScope` on `_ActiveWorkoutBody` child, not top-level `ActiveWorkoutScreen`. Loading state has no PopScope. Also `context.go()` clears nav stack.
- Fix: Move PopScope to wrap entire `ActiveWorkoutScreen.build()`. Audit go vs push for workout route.
- Files: `active_workout_screen.dart`, `app_router.dart`

**Bug 2: Home screen elements disappear on nav return**
- Root cause: `.when(loading: SizedBox.shrink())` in `week_bucket_section.dart:32`. Provider reload blanks THIS WEEK section. Also `valueOrNull` returns null during loading in `home_screen.dart`.
- Fix: Show stale data during reload instead of SizedBox.shrink(). Guard `hasActivePlan` derivation.
- Files: `week_bucket_section.dart`, `home_screen.dart`

### Checklist

- [x] Create branch `feature/step12.3a-p0-bug-fixes`
- [x] Bug 1: Move PopScope to `ActiveWorkoutScreen.build()` top level (loading + active states)
- [x] Bug 1: Extract `_showDiscardDialog` to top-level ConsumerWidget for PopScope callback
- [x] Bug 1: Remove PopScope from `_ActiveWorkoutBody.build()` (keep `_onBackPressed` for AppBar close button)
- [x] Bug 1: Change `context.go('/workout/active')` to `context.push(...)` in `home_screen.dart` (lines 124, 140)
- [x] Bug 1: Change `context.go('/workout/active')` to `context.push(...)` in `_ActiveWorkoutBanner` (`app_router.dart`)
- [x] Bug 2: Replace `.when()` in `week_bucket_section.dart` with stale-data-during-reload pattern
- [x] Bug 2: Fix `hasActivePlan` derivation in `home_screen.dart` to use `hasValue`/`value`
- [x] Widget test: PopScope wraps loading state
- [x] Widget test: PopScope wraps active workout state
- [x] Widget test: Back press shows discard dialog
- [x] Widget test: WeekBucketSection retains content during provider reload
- [x] Widget test: WeekBucketSection hides on initial load (no cached data)
- [x] Widget test: HomeScreen routines list stays hidden during plan reload
- [x] `dart format .` -- clean
- [x] `dart analyze --fatal-infos` -- no issues
- [x] `flutter test` -- 858/858 pass (6 new tests)
- [ ] CI check
- [ ] Reviewer + UX review
- [ ] QA gate
- [ ] PR + merge
