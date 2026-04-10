# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 13a Sprint A — QA Follow-ups

**Branch:** `feature/phase13a-sprintA-qa-followups`
**Reference:** QA pass 2026-04-10 found no bugs but 4 small polish items + 1 coverage gap.

Fixes (tech-lead):
- [x] **#1 Placeholder email** — `assets/legal/privacy_policy.md:9` + `docs/privacy_policy.md:14` currently read `support@gymbuddy.app (placeholder — final contact email to be confirmed before public release)`. Replace with clean fictional address (drop the placeholder parenthetical).
- [x] **#2 PWA theme_color** — `web/manifest.json` `theme_color` + `background_color` are Flutter default `#0175C2`. Change to `#00E676` (primary) + `#0F0F1A` (background) per AppTheme.
- [x] **#3 DELETE gate partial-string tests** — `test/widget/features/profile/ui/manage_data_screen_test.dart` covers 'DELETE'/empty but not 'DELET'/'DELETED'. Add one test each.
- [x] **#4 Volume-unit widget tests** — No widget tests assert `profileProvider.weightUnit` flips the suffix in home_screen (`Week's volume` card) or workout_detail_screen (per-set rows + total). Add both.

Verification:
- [x] `make ci` green (format + gen + analyze 0 issues + 912 tests passed)
- [ ] Start Docker Desktop → `npx supabase start` → verify healthy
- [ ] qa-engineer Round 2: live E2E account deletion against local Supabase + live volume-unit kg↔lbs flip
- [ ] All merged Sprint A items green before PR

Ship:
- [ ] Open PR, reviewer pass, squash merge, update PLAN.md (mark Phase 13a Sprint A fully shipped incl. follow-ups)
