# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Step 12.2a: Bug Fixes
**Branch:** `feature/step12.2a-bug-fixes`
**Source:** Per PLAN.md Step 12.2a

### Checklist
- [x] Bug #1: `fillRemainingSets()` — add `isCompleted: true` to copied sets
- [x] Bug #2: Invalidate `workoutCountProvider`, `prCountProvider`, `recentPRsProvider` after workout save
- [x] Bug #3: Profile stat cards — wrap Workouts → `/home/history`, PRs → `/records`
- [x] Bug #4: All uncompleted weekly plan chips tappable (not just "next")
- [x] Bug #5: Visible "Edit" icon in THIS WEEK section header
- [x] Bug #6: Investigated — case (b): label ambiguity, not cache bug. Relabeled "Last:" → "Previous:"
- [x] Bug #7: Replace invisible `Tooltip` with inline "goal reached" text
- [x] Unit/widget tests for each fix (3 test files updated)
- [x] `make ci` passes (787/787 tests, 0 format/analyze issues)
- [x] Code review
- [x] QA gate (795/795 tests, 0 failures; 1 test assertion strengthened in set_row_test.dart)
- [ ] PR opened
