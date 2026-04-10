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
- [x] Docker + local Supabase healthy (all core containers up)
- [x] qa-engineer Round 2: live E2E account deletion spec written + passing; volume unit kg↔lbs flip exercised via Playwright MCP
- [x] Backend verification: user row gone (Admin API), cascade worked (0 workouts), re-login rejected
- [x] Smoke suite regression check: 59 passed, 0 new failures

Extra fixes (Round 2 caught):
- [x] **#5 MORE placeholder text** — Round 1 QA only flagged privacy_policy.md section 1; Round 2 found 5 more instances: privacy_policy section 11, terms_of_service sections 11+12, docs/index.md, docs/privacy_policy.md section 11, docs/terms_of_service.md sections 11+12. Also `[JURISDICTION]` in both ToS files. Fixed inline by orchestrator — email parentheticals removed, `[JURISDICTION]` → "the Federative Republic of Brazil" with venue in Comarca de Santos, State of São Paulo (operator's actual location), with CDC consumer-domicile carve-out.
- [x] Post-fix `make ci` re-run: still 912 tests passing

Ship:
- [ ] Commit + push + open PR
- [ ] reviewer pass
- [ ] squash merge
- [ ] update PLAN.md (mark Phase 13a Sprint A fully shipped incl. follow-ups)
