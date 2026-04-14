# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## P9 — Exercise description + form_tips standard + library expansion

**Branch:** `feature/p9-exercise-content-standard`
**Source:** Per PLAN.md Phase 13 Sprint B Slot 1 (P9), lines 577-620.
**Goal:** Backfill 31 content-less exercises from migration 00014, ship 58 new exercises, land detail-sheet hierarchy fix + browse polish + CI pairing guard. After this PR, `SELECT COUNT(*) FROM exercises WHERE is_default = true AND (description IS NULL OR form_tips IS NULL)` returns 0 and the library is 150 default exercises.

### Track A — Migrations (content)

- [ ] Create `supabase/migrations/00019_expand_exercise_library.sql` inserting 58 new default exercises (idempotent, follows 00014 pattern)
  - [ ] 6 chest, 9 back, 14 legs, 7 shoulders, 10 arms, 12 core = 58
  - [ ] No cardio, no "Cable Fly", no "Pistol Squat", no Olympic lifts
- [ ] Create `supabase/migrations/00020_seed_exercise_content_p9.sql` with 89 `UPDATE` statements
  - [ ] 31 backfills for 00014 exercises (including 5 cardio)
  - [ ] 58 updates for the new exercises from 00019
  - [ ] Voice matches 00010 exactly; 15-25 word descriptions; 4 bullets form_tips; no medical vocabulary
  - [ ] Upright Row special-case tip: shoulder-impingement warning
  - [ ] Idempotent UPDATEs, single-quote escaping
- [ ] Apply migrations to local Supabase (`npx supabase db reset`) and verify:
  - [ ] `SELECT COUNT(*) FROM exercises WHERE is_default = true` == 150
  - [ ] `WHERE is_default = true AND description IS NULL` == 0
  - [ ] `WHERE is_default = true AND form_tips IS NULL` == 0
- [ ] Commit: `feat(exercises): expand library to 150 and seed all descriptions/form_tips (P9 Track A)`

### Track B — Governance (CI guard + CLAUDE.md rule)

- [ ] Create `scripts/check_exercise_content_pairing.sh` (POSIX-compatible, ~20-30 lines)
- [ ] Wire into `.github/workflows/ci.yml` as fast-failing step `exercise-content-pairing-check`
- [ ] Add pairing-rule subsection to `CLAUDE.md`
- [ ] Self-test: runs clean on P9 migrations; exits 1 on synthetic unpaired case
- [ ] Commit: `ci(exercises): enforce description+form_tips pairing for default-exercise migrations (P9 Track B)`

### Track C — Detail-sheet hierarchy fix

- [ ] `lib/features/exercises/ui/exercise_detail_screen.dart`:
  - [ ] Reorder: name -> custom-exercise label -> description -> chips -> images -> form tips -> PRs -> delete
  - [ ] Drop "Created <date>" from main flow
- [ ] `lib/shared/widgets/exercise_info_sections.dart`:
  - [ ] Description body text at full opacity
  - [ ] Form tips: replace `check_circle_outline` with 6x6 circular Container (primary), full opacity on bullet and tip
  - [ ] Keep FORM TIPS / ABOUT labels at 55% opacity
- [ ] Update widget tests in `test/widget/shared/widgets/exercise_info_sections_test.dart` (replace check-circle assertions)
- [ ] Update widget tests in `test/widget/features/exercises/ui/exercise_detail_screen_test.dart` (hierarchy + no Created date)
- [ ] Run `make format` + `make analyze` + `make test`
- [ ] Commit: `refactor(exercises): tighten detail-sheet hierarchy and form-tip visuals (P9 Track C)`

### Track D — Browse polish

- [ ] `lib/features/exercises/ui/exercise_list_screen.dart`: add 3dp primary left-border to non-default exercise cards
- [ ] `lib/shared/widgets/exercise_image.dart`: ensure `memCacheHeight` is also set (review constraints for list-card decode safety)
- [ ] Widget test: custom-exercise card has visible left accent; default does not
- [ ] Run `make format` + `make analyze` + `make test`
- [ ] Commit: `feat(exercises): custom-exercise left-accent and image-cache tightening (P9 Track D)`

### Final verification

- [ ] `make ci` — full pipeline green
- [ ] Three SQL checks re-run against local Supabase, output pasted into PR body by orchestrator
- [ ] Summary to orchestrator with commits / counts / files changed
