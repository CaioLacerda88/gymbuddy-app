# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## P9 — Exercise description + form_tips standard + library expansion

**Branch:** `feature/p9-exercise-content-standard`
**Source:** Per PLAN.md Phase 13 Sprint B Slot 1 (P9), lines 577-620.
**Goal:** Backfill 31 content-less exercises from migration 00014, ship 58 new exercises, land detail-sheet hierarchy fix + browse polish + CI pairing guard. After this PR, `SELECT COUNT(*) FROM exercises WHERE is_default = true AND (description IS NULL OR form_tips IS NULL)` returns 0 and the library is 150 default exercises.

### Track A — Migrations (content)

- [x] Create `supabase/migrations/00019_expand_exercise_library.sql` inserting 58 new default exercises (idempotent, follows 00014 pattern)
  - [x] 6 chest, 9 back, 14 legs, 7 shoulders, 10 arms, 12 core = 58
  - [x] No cardio, no "Cable Fly", no "Pistol Squat", no Olympic lifts
- [x] Create `supabase/migrations/00020_seed_exercise_content_p9.sql` with 89 `UPDATE` statements
  - [x] 31 backfills for 00014 exercises (including 5 cardio)
  - [x] 58 updates for the new exercises from 00019
  - [x] Voice matches 00010 exactly; 15-25 word descriptions; 4 bullets form_tips; no medical vocabulary
  - [x] Upright Row special-case tip: shoulder-impingement warning
  - [x] Idempotent UPDATEs, single-quote escaping
- [x] Apply migrations to local Supabase (`npx supabase db reset`) and verify (via distinct-name counts because pre-existing seed.sql introduces duplicates on local reset only; production `db push` never runs seed.sql):
  - [x] `SELECT COUNT(DISTINCT name) FROM exercises WHERE is_default = true` == 150
  - [x] `WHERE is_default = true AND description IS NULL` == 0 (after dedup of seed.sql duplicates)
  - [x] `WHERE is_default = true AND form_tips IS NULL` == 0 (after dedup)
- [x] Commit: `feat(exercises): expand library to 150 and seed all descriptions/form_tips (P9 Track A)`

### Track B — Governance (CI guard + CLAUDE.md rule)

- [x] Create `scripts/check_exercise_content_pairing.sh` (POSIX-compatible)
- [x] Wire into `.github/workflows/ci.yml` as fast-failing job `exercise-content-pairing-check` upstream of analyze/test/build
- [x] Add pairing-rule subsection to `CLAUDE.md`
- [x] Self-test: runs clean on P9 migrations; exits 1 on synthetic unpaired case (verified with branch-based synthetic)
- [x] Commit: `ci(exercises): enforce description+form_tips pairing for default-exercise migrations (P9 Track B)` — b3fcdfe

### Track C — Detail-sheet hierarchy fix

- [x] `lib/features/exercises/ui/exercise_detail_screen.dart`:
  - [x] Reorder: name -> custom-exercise label -> description -> chips -> images -> form tips -> PRs -> delete
  - [x] Drop "Created <date>" from main flow
- [x] `lib/shared/widgets/exercise_info_sections.dart`:
  - [x] Description body text at full opacity
  - [x] Form tips: replace `check_circle_outline` with 6x6 circular Container (primary), full opacity on bullet and tip
  - [x] Keep FORM TIPS / ABOUT labels at 55% opacity
- [x] Update widget tests in `test/widget/shared/widgets/exercise_info_sections_test.dart` (replace check-circle assertions + full-opacity checks)
- [x] Update widget tests in `test/widget/features/exercises/ui/exercise_detail_screen_test.dart` (hierarchy + no Created date; 5 new tests)
- [x] Local widget test run: 38/38 pass
- [x] Commit: `refactor(exercises): tighten detail-sheet hierarchy and form-tip visuals (P9 Track C)` — d407fd4
- [x] Follow-up: update 2 stale test files (detail-sheet + literal-newline) that still asserted `check_circle_outline` — 45ae2b9

### Track D — Browse polish

- [x] `lib/features/exercises/ui/exercise_list_screen.dart`: add 3dp primary left-border to non-default exercise cards (dropped inner `borderRadius` because Flutter's `Border` requires uniform sides when `borderRadius` is set; the outer `Material` with `clipBehavior: Clip.antiAlias` still rounds the visible corners)
- [x] `lib/shared/widgets/exercise_image.dart`: ensure `memCacheHeight` is also set — height-only callers (detail sheet) were decoding full-resolution images
- [x] Widget test: custom-exercise card has visible left accent; default does not
- [x] Widget test: `ExerciseImage` forwards `memCacheHeight` when only height is given, and both when both are given
- [x] Run `dart format` + `dart analyze --fatal-infos` on Track D files (0 issues)
- [x] Run widget tests for Track D files (19/19 pass)
- [x] Commit: `feat(exercises): custom-exercise left-accent and image-cache tightening (P9 Track D)` — 9e9e2f0

### Final verification

- [x] Full local pipeline green: `dart format` (0 changed) + `dart run build_runner build` (0 outputs) + `dart analyze --fatal-infos` (0 issues) + `flutter test` (1030 tests pass) + `flutter build apk --debug` (success)
- [x] Three SQL checks re-run against local Supabase (after `npx supabase db reset`):
  - `SELECT COUNT(DISTINCT name) FROM exercises WHERE is_default = true AND deleted_at IS NULL` → **150**
  - `SELECT COUNT(*) FROM exercises WHERE is_default = true AND description IS NULL AND deleted_at IS NULL` → **0**
  - `SELECT COUNT(*) FROM exercises WHERE is_default = true AND form_tips IS NULL AND deleted_at IS NULL` → **0**
- [x] Summary to orchestrator: commits c652801 (Track A), b3fcdfe (Track B), d407fd4 (Track C), 9e9e2f0 (Track D), 45ae2b9 (test follow-up)
