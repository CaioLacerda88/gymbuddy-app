# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Step 12.3c — Standalone Routine → Plan Prompt

**Status:** In progress — tech-lead implementing
**Branch:** `feature/step12.3c-plan-prompt`
**Source:** PLAN.md Step 12.3c

### Checklist

- [x] Create branch `feature/step12.3c-plan-prompt`
- [x] **Plan-match check**: `_shouldShowPlanPrompt()` in active workout screen checks routineId, plan existence, not-in-plan
- [x] **Add-to-plan method**: `addRoutineToPlan(String routineId)` added to `WeeklyPlanNotifier`
- [x] **Post-workout prompt widget**: `showAddToPlanPrompt()` bottom sheet — "X isn't in your plan yet. Add it?" with Add + Skip
- [x] **Integrate into finish flow** in `active_workout_screen.dart:_onFinish()`:
  - Captures `routineId` and `routineName` before `finishWorkout()`
  - If PRs: passes prompt data to PR celebration screen, shown on Continue tap
  - If no PRs: shows prompt directly before navigating home
- [x] **Widget tests**: 7 tests covering prompt widget and PR celebration integration
- [x] `dart format .` — clean
- [x] `dart analyze --fatal-infos` — no issues
- [x] `flutter test` — all 878 pass
