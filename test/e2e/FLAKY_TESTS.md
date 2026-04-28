# Flaky & Failing E2E Tests

This is a **debt register**, not a permanent home. The goal is to converge to zero entries here. Every test listed below is a latent bug — either a real production race, a missing wait, a timing assumption, or a seed-isolation gap — and we treat it as such.

## How this doc is used

- `qa-engineer` excludes anything tagged `@flaky` from Stage 2 of the staged-run strategy and routes it through Stage 3 with `--retries=2` instead.
- When a new flake appears, add a row here, tag the test `@flaky`, and open or update an investigation entry.
- When a test passes 5 consecutive runs (cross-PR, cross-platform), remove the `@flaky` tag AND delete its entry here.
- A flaky test that fails 3× in a row in Stage 3 has drifted toward "broken." Promote to a real bug report against `lib/**` (tech-lead) or `test/e2e/**` (qa-engineer self).

## Hard failures (must fix before next phase milestone)

These tests do not recover on retry. Each one is either a real prod regression we are shipping with, or a test infrastructure problem we have not finished diagnosing.

| # | Spec | Test | First seen | Suspected lane | Suspected cause | Status |
|---|------|------|------------|----------------|-----------------|--------|
| 1 | `specs/offline-sync.spec.ts` | OFFLINE-001 | pre-Phase-18c | TBD | Service worker / IndexedDB lifecycle on Flutter web | Open — unowned |
| 2 | `specs/offline-sync.spec.ts` | OFFLINE-002 | pre-Phase-18c | TBD | Same family as OFFLINE-001 | Open — unowned |
| 3 | `specs/offline-sync.spec.ts` | OFFLINE-005 | pre-Phase-18c | TBD | Same family | Open — unowned |
| 4 | `specs/offline-sync.spec.ts` | OFFLINE-007 | pre-Phase-18c | TBD | Same family | Open — unowned |
| 5 | `specs/manage-data.spec.ts` | account-deletion smoke | pre-Phase-18c | TBD | Likely RLS/cascade timing or auth-state flush after deletion | Open — unowned |
| 6 | `specs/manage-data.spec.ts` | MD-010 Reset All | pre-Phase-18c | TBD | Same family as account-deletion | Open — unowned |
| 7 | `specs/personal-records.spec.ts` | first-workout celebration | pre-Phase-18c | TBD | PR detection + post-workout celebration timing race | Open — unowned |
| 8 | `specs/rpg-foundation.spec.ts` | 18a-E2 first-workout XP | pre-Phase-18c | TBD | Server-side XP record race vs client-side polling | Open — unowned |

## Flaky (recovers on retry, but unstable)

These tests pass on retry #1 with current waits but fail intermittently on first attempt. Each is a candidate for a deterministic-wait refactor (`waitForSelector`, `waitForURL`, `waitForResponse`) instead of `waitForTimeout`-based polling.

| # | Spec | Test | Observed mode | Suspected cause | Status |
|---|------|------|---------------|-----------------|--------|
| 9 | `specs/manage-data.spec.ts` | MD-005 | Selector race after data reset | Missing wait on post-reset reload | Open — unowned |
| 10 | `specs/manage-data.spec.ts` | MD-006 | Same family as MD-005 | Same | Open — unowned |
| 11 | `specs/manage-data.spec.ts` | MD-007 | Same family as MD-005 | Same | Open — unowned |
| 12 | `specs/personal-records.spec.ts` | new-PR celebration | PR celebration overlay timing | Same family as #7 | Open — unowned |
| 13 | `specs/workouts.spec.ts` | full-journey smoke | Multi-step navigation race | Multiple `waitForTimeout` polls in helper chain | Open — unowned |
| 14 | `specs/workouts.spec.ts` | navigate-after-finish | Post-finish nav race | Likely related to the celebration → navigation handshake (Phase 18c hardened the canonical path; this test may need re-verification) | Open — verify Phase 18c didn't fix it |
| 15 | `specs/workouts.spec.ts` | decimal-weight round-trip (WK-023) | Locale-dependent decimal parsing flake | en/pt locale switching mid-test | Open — unowned |
| 16 | `specs/crash-recovery.spec.ts` | HOME-004 | Post-finish nav timing | Same family as #14 | Open — verify Phase 18c didn't fix it |
| 17 | `specs/home.spec.ts` | last-session-line | Home dashboard rebuild after workout finish | Riverpod refresh ordering on /home | Open — unowned |
| 18 | `specs/home.spec.ts` | history-nav | Same family as #17 | Same | Open — unowned |
| 19 | `specs/home.spec.ts` | quick-workout | Same family as #17 | Same | Open — unowned |
| 20 | `specs/exercises-localization.spec.ts` | A1 / A2 / B1 (3 tests) | Locale switch flush timing | Translation cache vs localized name fetch race | Open — unowned |
| 21 | `specs/exercises.spec.ts` | clear-search | Search-input clear race | Flutter web hidden input proxy event ordering | Open — unowned |

## Investigation playbook

For any flake or hard failure, the systematic approach:

1. **Reproduce.** `--repeat-each=5 --retries=0 --grep "<test name>"`. Confirm consistent vs intermittent.
2. **Capture.** stderr (`2>&1`), screenshot, page console logs (`page.on('console')`). Pin down exact failure point.
3. **Categorize.**
   - **Test-infra:** missing `waitFor*`, racy fixture setup, helper chain assumes ordering — fix in test/e2e/.
   - **Prod-code:** real lazy-init bug, race in Riverpod refresh, swallowed exception, navigation racing dialog — bug report → tech-lead.
4. **Fix.** Deterministic wait > timeout-based polling. If you can replace `waitForTimeout(N)` with `waitForResponse(...)` or `waitForSelector(...)`, do it.
5. **Verify.** `--repeat-each=20 --retries=0` against the fix. 20/20 stable before claiming "fixed."
6. **Discharge.** Remove `@flaky` tag, delete entry from this doc, commit with rationale.

## Backlog priorities

Suggested order based on user-impact-during-flake and ease-of-investigation:

1. **personal-records + rpg-foundation** (#7, #8, #12) — same family. Fixing them likely unblocks several Phase 18c-adjacent tests and validates the celebration→DB write path.
2. **post-finish nav family** (#14, #16, #17, #18, #19) — Phase 18c hardened the canonical celebration→nav handshake. These may already be fixed; needs verification.
3. **manage-data** (#5, #6, #9, #10, #11) — same family. Reset-all + account-deletion likely share an auth/storage flush race.
4. **offline-sync** (#1–#4) — service worker / IndexedDB area, deepest investigation, unique skill set.
5. **workouts decimal + exercises localization** (#15, #20, #21) — locale/i18n family.

When a phase touches code in any of these areas, the agent driving that phase is responsible for verifying its tests against this register and either fixing the relevant entries or confirming "no longer reproduces, removed from doc."
