# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## QA Audit Bug Fixes — `fix/qa-audit-cleanup`

**Source:** PLAN.md QA Status (audit 2026-04-07)
**Branch:** `fix/qa-audit-cleanup`
**Status:** All 13 bugs fixed by tech-lead. QA engineer running tests (background agent).

### Tech-lead work (DONE)

All 13 bugs fixed. 698 tests pass. Files changed:
- `lib/core/theme/radii.dart` — NEW (border radius constants kRadiusSm/Md/Lg/Xl)
- `lib/shared/widgets/section_header.dart` — NEW (extracted from home_screen + routine_list)
- `lib/features/auth/ui/login_screen.dart` — NEW-006 (SnackBar 8s), PO-004 (clear password on toggle)
- `lib/features/auth/ui/onboarding_screen.dart` — PO-007 (back button page 2)
- `lib/features/exercises/ui/exercise_list_screen.dart` — PO-016 (RefreshIndicator)
- `lib/features/personal_records/ui/pr_list_screen.dart` — PO-031 (tappable PR cards → exercise detail)
- `lib/features/profile/ui/profile_screen.dart` — PO-039 (edit name dialog)
- `lib/features/routines/ui/routine_list_screen.dart` — UX-D05 (use shared SectionHeader, removed old _SectionHeader)
- `lib/features/workouts/ui/home_screen.dart` — PO-008 (fixed stat card height), NEW-007 (return after discard), UX-D05
- `lib/features/workouts/ui/workout_history_screen.dart` — PO-028 (loading indicator)
- `lib/features/workouts/providers/workout_history_providers.dart` — PO-028 (exposed isLoadingMore)
- `lib/shared/widgets/weight_stepper.dart` — UX-V02 (26sp)
- `lib/shared/widgets/reps_stepper.dart` — UX-V02 (18sp)
- 2 test files updated for isLoadingMore mock

### QA engineer work (DONE)

Widget tests written and passing (25 new tests, 723 total):
- [x] **PO-004** — `login_screen_test.dart`: 2 tests — toggle to signup/login clears password field
- [x] **PO-007** — `onboarding_screen_test.dart`: 3 tests — back button present, returns to page 1, can navigate forward again
- [x] **NEW-007** — `home_screen_discard_test.dart` (new file): 6 tests — dialog actions, non-dismissible, result enum integrity
- [x] **PO-016** — `exercise_list_screen_test.dart`: 1 test — RefreshIndicator present in exercise list
- [x] **PO-028** — `workout_history_screen_test.dart` (new file): 7 tests — empty state, cards, loading indicator states, RefreshIndicator
- [x] **PO-031** — `pr_list_screen_test.dart`: 2 tests — InkWell present on single and multiple PR cards
- [x] **PO-039** — `profile_screen_test.dart`: 4 tests — edit icon present, dialog opens, pre-populated name, cancel safe

E2E selector impact analysis — no breakage:
- [x] `SectionHeader` extraction — text unchanged, no e2e impact
- [x] `RefreshIndicator` on exercise list — selectors target exercise cards/FAB, not the list container
- [x] Profile edit name dialog — no e2e test taps the display name
- [x] History loading indicator — no e2e test targets CircularProgressIndicator
- [x] Onboarding back button — no e2e onboarding spec exists

Verification:
- [x] `dart format .` — 7 files reformatted
- [x] `dart analyze --fatal-infos` — no issues
- [x] `flutter test` — 723 tests pass (up from 698)

### Remaining after QA completes

- [ ] Update PLAN.md QA Status — mark all 13 bugs as resolved
- [ ] Commit all changes
- [ ] Push and create PR
- [ ] Squash merge to main
- [ ] Remove this section from WIP.md

### Also done this session (non-code)

- Updated PLAN.md QA Status with audit results (20 fixed, 13 remaining → now all fixed)
- Added WIP tracking protocol to CLAUDE.md
- Added Context Hygiene guideline to CLAUDE.md
- Created `tasks/WIP.md` tracking file
- Fixed statusline config (`~/.claude/statusline.sh`) — correct field names, head -1 for dedup
- Saved feedback memories: WIP tracking, context hygiene
