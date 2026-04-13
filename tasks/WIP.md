# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## ACTIVE: E2E Test Fixes — Get CI Green + QA Improvements

**Branch:** `fix/e2e-infra-full-regression` (PR #50)
**Spec:** Plan file `functional-imagining-moler.md`

### Problem
- HOME_STATS selectors reference removed stat cards (replaced by ContextualStatCells)
- Strict mode violations: text=Routines (4 matches), text=Reset Account (2 matches), text=Add Set (2 matches)
- Finish Workout button disabled when no sets completed — tests click it without completing sets
- ~30 hard waits (waitForTimeout) causing CI timeout at 30min

### Checklist
- [ ] Update `selectors.ts` — HOME_STATS, MANAGE_DATA.resetButton, PR_DISPLAY
- [ ] Update `helpers/app.ts` — reduce hard waits in waitForAppReady + navigateToTab
- [ ] Rewrite `home-navigation.spec.ts` — 6 stat card tests
- [ ] Fix `workout-logging.spec.ts` — disabled Finish + sheet dismiss waits
- [ ] Fix `manage-data.spec.ts` — strict mode + 2s/3s hard waits
- [ ] Fix `exercise-detail-sheet.spec.ts` — sheet dismiss waits
- [ ] Fix `routine-regression.spec.ts` — reload waits
- [ ] Fix `routines.spec.ts` — strict mode (.first())
- [ ] Fix smoke specs hard waits + increase CI timeout to 45min
- [ ] Verify: full regression suite locally
- [ ] Commit, push, verify CI passes

---
