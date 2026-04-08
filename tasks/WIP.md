# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Step 12: Weekly Training Plan + Bug Fixes — `feature/step12-weekly-training-plan`

**Branch:** `feature/step12-weekly-training-plan` (pushed, PR #32 open)
**Ref:** PLAN.md Step 12, BUGS.md
**Migration:** Applied to hosted Supabase (`dgcueqvqfyuedclkxixz.supabase.co`)
**Tests:** 787 passing (723 original + 64 new)
**E2E:** 60 total (36 existing + 24 new smoke tests)
**Commits:** 19 on branch

### Done
- [x] Step 12 core: models, repo, providers, widgets, screens, migration (11 new files)
- [x] Step 12 wiring: profile model/repo/providers, onboarding, profile screen, home screen, router, workout notifier
- [x] BUG-1 (P0): context.push for stat card navigation
- [x] BUG-4 (P0): null weight guard + PR display as `100 kg × 5` (reps field added to PersonalRecord)
- [x] BUG-2 (P1): copy weight and reps when adding sets
- [x] BUG-3 (P2): hide/rename Fill button
- [x] Review critical fixes: routineId matching, atomic markRoutineComplete, auto-populate wiring, Dismissible key, RLS WITH CHECK, plan screen init
- [x] Week review stats computed from completed workouts
- [x] Auto-fill button on plan management screen
- [x] 64 widget/unit tests
- [x] Reviewer audit complete (5 critical + 9 warnings addressed)
- [x] QA regression audit complete (5 new bugs + E2E gap analysis)
- [x] BUG-R1 (P1): Auto-populate strips completed routines for new week
- [x] BUG-R2 (P1): Auto-populate moved out of build() via Future.microtask
- [x] BUG-R3 (P2): Week review uses dynamic weight unit from profile
- [x] BUG-R4 (P2): Records screen no longer highlights Home tab
- [x] BUG-R5 (P2): Undo-remove clamps index and renumbers order
- [x] 6 E2E smoke tests (24 new tests): weekly-plan, onboarding, routine-management, pr-display, weekly-plan-review, profile-weekly-goal

### Ready to ship
- [ ] Push to remote, update PR #32
- [ ] Final review pass (optional)
- [ ] Merge PR #32

### Blockers
- `.env` currently points at prod Supabase (not committed)
