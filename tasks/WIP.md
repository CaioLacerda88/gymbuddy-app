# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 18a — RPG v1 Foundation (schema + XP engine + backfill)

**Branch:** `feature/phase18-rpg-system-v1`
**Source:** PLAN.md Phase 18a + design spec `docs/superpowers/specs/2026-04-25-rpg-system-v1-design.md`
**Decisions locked:** RPC inside `save_workout` (not trigger), 500-set chunked backfill with advisory lock, `session_id` added to `xp_events`, `/saga` as new top-level route.

**Architecture deviation (locally validated):** spec called for `backfill_rpg_v1` to be a PROCEDURE with internal `COMMIT` between chunks. Postgres forbids `COMMIT` inside `SECURITY DEFINER` procedures, AND PostgREST always wraps RPCs in a transaction — both fail with "invalid transaction termination". Refactored to FUNCTION returning `(out_processed, out_total_processed, out_is_complete)`; the Dart driver loops until `out_is_complete=true`. Each invocation is its own txn. All chunking + advisory-lock + checkpoint + resume-after-kill semantics preserved. Documented inline in `00040_rpg_system_v1.sql` and `RpgRepository.runBackfill`.

### Schema + migration
- [x] `supabase/migrations/00040_rpg_system_v1.sql` — create `xp_events`, `body_part_progress`, `exercise_peak_loads`, `earned_titles`, `backfill_progress`
- [x] Add `secondary_muscle_groups` + `xp_attribution` columns to `exercises`
- [x] Create IMMUTABLE helper fn `xp_attribution_sum(jsonb)` + CHECK `xp_attribution_sums_to_one`
- [x] Create derived view `character_state`
- [x] INSERT `xp_attribution` JSON onto every `is_default = true` exercise per spec §5.2 mappings
- [x] Cleanup of 17b placeholder rows (drop user_xp + xp_events tables; backfill driver re-creates)
- [x] RLS policies (owner-read, owner-write) on all new tables
- [x] `scripts/emergency_rollback_phase18.sql` rollback script
- [x] Migration applies cleanly via `supabase db reset --local`
- [x] End-to-end smoke test: `record_set_xp` distributes XP per attribution map (60kg×8 bench → 38.72 chest, 11.06 shoulders, 5.53 arms)
- [x] `save_workout` → `record_set_xp` integration verified end-to-end
- [x] `backfill_rpg_v1` chunked function: cursor advances correctly, idempotent re-run is no-op, multi-chunk loop terminates correctly

### XP engine — Dart pure functions
- [x] `lib/features/rpg/domain/xp_calculator.dart` — `set_xp = volume_load^0.65 × intensity_mult × strength_mult × novelty_mult × cap_mult`
- [x] `lib/features/rpg/domain/rank_curve.dart` — `xp_for_rank(n)` cumulative table + `rank_for_xp(total)`
- [x] `lib/features/rpg/domain/vitality_calculator.dart` — asymmetric EWMA (formulas only; driver in 18d)
- [x] `lib/features/rpg/domain/xp_distribution.dart` — attribution map application
- [x] Models: `body_part.dart`, `body_part_progress.dart`, `xp_event.dart`, `peak_load.dart`, `attribution.dart`

### XP engine — Postgres RPC
- [x] `record_set_xp(set_id uuid)` PL/pgSQL RPC inside same migration (RETURNS TABLE with `out_` prefixed columns to avoid ON CONFLICT ambiguity)
- [x] Wire `record_set_xp` call into existing `save_workout` RPC (per inserted set, same transaction)
- [x] `INSERT ... ON CONFLICT DO UPDATE` for body_part_progress (idempotent under concurrent writes)

### Backfill
- [x] `backfill_rpg_v1(user_id, chunk_size)` chunked FUNCTION (refactored from PROCEDURE — see deviation note above)
- [x] `pg_advisory_xact_lock` for per-user serialization (per-chunk, since each call is its own txn)
- [x] `backfill_progress` checkpoint table for resume-after-kill
- [x] Dart `RpgRepository.runBackfill()` loops the function until `out_is_complete=true`
- [x] `XpRepository.runRetroBackfill` (gamification shim) updated to use the same loop pattern

### Repositories + providers
- [x] `lib/features/rpg/data/rpg_repository.dart`
- [x] `lib/features/rpg/data/peak_loads_repository.dart`
- [x] `lib/features/rpg/providers/rpg_progress_provider.dart`

### Tests (per PLAN.md test plan)
- [x] Unit: `xp_calculator_test.dart` (40+ cases — every formula component + boundary)
- [x] Unit: `attribution_test.dart` (sum-to-one, NULL fallback)
- [x] Unit: `rank_curve_test.dart` (parity vs spec §6 milestones)
- [x] Unit: `vitality_calculator_test.dart` (asymmetric α, peak monotonicity)
- [x] Unit: `gamification/xp_repository_test.dart` updated for 18a shim contract (character_state read, awardXp no-op, backfill loop assertion)
- [x] Integration: `rpg_record_set_xp_test.dart` (10 tests — PG/Dart parity, BUG-RPG-001 idempotent re-save, concurrent guard, peak advancement)
- [x] Integration: `rpg_backfill_test.dart` (3 tests — 60-set fixture parity, idempotent re-run, wipe-on-first-chunk)
- [x] Integration: `rpg_backfill_resume_test.dart` (3 tests — partial chunk + resume, cursor skip, advisory-lock serialization)
- [ ] Migration dry-run on hosted DB snapshot — apply post-merge per CLAUDE.md step 10

### QA round 1 fixes (BUG-RPG-001/002/003 — this cycle)
- [x] BUG-RPG-002: backfill chunk counter no longer inflated by idempotent skips. Cursor advance + chunk fetch use the SAME total ordering tuple `(w.started_at ASC, s.id ASC)`. `_rpg_backfill_chunk` now returns `(processed, visited, last_set_id, last_set_ts)`; `processed` is incremented only on real INSERT, `visited` drives end-of-input detection. Defense-in-depth: idempotent-skip branch advances cursor but does NOT increment processed. Verified: `out_total_processed == set_count` on 60-set fixture.
- [x] BUG-RPG-003: `numeric(_,2) → numeric(_,4)` widening on `xp_events.total_xp`, `body_part_progress.{total_xp,vitality_ewma,vitality_peak}`, `exercise_peak_loads.peak_weight`. Per-row rounding error <0.0001; cumulative drift after 25+ sets stays well under the 0.01 spec tolerance.
- [x] BUG-RPG-001: `save_workout` now applies REVERSAL PATTERN before cascade-deleting prior sets — sums per-(user, body_part) contributions from `xp_events` tied to this `session_id` and decrements `body_part_progress.total_xp` (clamped at 0) + recomputes `rank` via `rpg_rank_for_xp`. Cascade then wipes `xp_events`; subsequent `record_set_xp` loop rebuilds from a clean per-session baseline. Test inverted: re-save delta ≤ 0.01.

### Verification gate (before PR)
- [x] `dart analyze --fatal-infos` clean
- [x] `dart format` clean
- [x] `flutter test` — 1902 tests passing (1885 unit/widget + 17 integration including perf bench)
- [x] `make ci` components green: format clean, analyze clean, 1902 tests passing, android-debug APK built
- [x] Performance benchmark: BUG-RPG-004 fixed — `record_session_xp_batch` replaces per-set FOR loop; p95 = 11ms for 100-set payload (gate ≤50ms passes). HTTP wall-clock p95 well within 2000ms sanity gate.
- [x] No selectors broken — GAMIFICATION.lvlBadge at line 664 is the only RPG selector used in 18a; shim returns correct shape; no regression expected
- [x] **E2E gate (2026-04-26):** All 6 `specs/rpg-foundation.spec.ts` tests pass (18a-E1..E6). `specs/gamification-intro.spec.ts` regression-clean (3/3). Root cause found and fixed: `character_state` view missing `WITH (security_invoker = true)` caused all authenticated users to see other users' body_part_progress rows instead of their own — fixed in migration `00040_rpg_system_v1.sql` and applied to local Supabase. E6 attribution ratio test corrected to use 1 set (novelty=1.0 baseline) to avoid per-body-part novelty decay divergence. E3/E6 `save_workout` auth fixed via `makeUserClient()`. All `toBeLessThanOrEqualTo` → `toBeLessThanOrEqual` matcher names corrected.

### Reviewer-fix cycle (2026-04-26 — REQUEST_CHANGES → fixed in same cycle)

| Severity   | Finding                                                                                       | Fix                                                                                                                                                                                                                                                                                                                                                            | Files                                                                                                                                                                                                                                          |
| ---------- | --------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| IMPORTANT  | §15 deploy comment used `CALL` (procedure syntax) for what is now a FUNCTION                  | Rewrote the post-migration handoff snippet to drive the chunked function via `WHILE NOT v_done LOOP SELECT out_is_complete INTO v_done FROM public.backfill_rpg_v1(r.user_id); END LOOP`. Updated prose: "procedure with internal COMMITs" → "chunked function: each invocation processes one chunk and returns progress, the CLIENT loops until completion". | `supabase/migrations/00040_rpg_system_v1.sql` §15                                                                                                                                                                                              |
| IMPORTANT  | `record_set_xp` claimed stale-peak risk for multi-set same-session calls                      | Verified the claim is **false in practice** — within a single transaction PG `ON CONFLICT DO UPDATE` writes are visible to subsequent SELECTs, so peak self-corrects. Documented intended use as ONE-SET-PER-CALL diagnostic and noted production hot path is `record_session_xp_batch`. Added comments above function header and beside GRANT line. No grant revoked (concurrent-guard regression test exercises this entry point).                                                                                                                                                                                | `supabase/migrations/00040_rpg_system_v1.sql` (record_set_xp header + GRANT)                                                                                                                                                                   |
| IMPORTANT  | Stale comment in `xp_provider.dart` referenced dropped `retro_backfill_xp` function            | Updated comment to describe `backfill_rpg_v1` chunked-function loop driven from `XpRepository.runRetroBackfill`; clarified `backfill_progress.completed_at` is the source of truth and the local flag exists only to avoid the cold-start round-trip.                                                                                                          | `lib/features/gamification/providers/xp_provider.dart`                                                                                                                                                                                         |
| IMPORTANT  | Integration tests would fail in remote CI (no live Supabase), real merge blocker on `ci.yml`  | Added `@Tags(['integration'])` above `library;` directive in all 4 integration test files. Created `dart_test.yaml` declaring the `integration` tag. Updated `.github/workflows/ci.yml` to `flutter test --coverage --exclude-tags integration`. Updated `Makefile`: `test:` now `flutter test --exclude-tags integration`; added `test-integration:` target. | `test/integration/{rpg_backfill_test,rpg_record_set_xp_test,rpg_save_workout_perf_test,rpg_backfill_resume_test}.dart`, `dart_test.yaml`, `.github/workflows/ci.yml`, `Makefile`                                                                |
| NIT        | `readLvlFromBadge` 15-attempt × 500 ms inner timeout was 7.5 s blackout                      | Reduced inner loop to 5 × 200 ms = 1 s max per outer poll. Outer poll loop iterates more frequently — closer to UX of "fast feedback when badge text appears". Both fallback strategies (textContent + accessibility snapshot) preserved.                                                                                                                      | `test/e2e/specs/rpg-foundation.spec.ts`                                                                                                                                                                                                       |
| NIT        | `exercise_peak_loads.updated_at` advanced even when `peak_weight` unchanged                   | Added `WHERE EXCLUDED.peak_weight > public.exercise_peak_loads.peak_weight` to the ON CONFLICT DO UPDATE in **both** `record_set_xp` §9 and `record_session_xp_batch` §7. Skips the row update entirely when peak didn't advance — `updated_at` is now an honest "peak last advanced" timestamp. Monotone non-decreasing invariant preserved by the guard.    | `supabase/migrations/00040_rpg_system_v1.sql` (record_set_xp §9, record_session_xp_batch §7)                                                                                                                                                  |

**Verification:**

- `dart format .` — no changes needed (354 files, 0 changed)
- `dart analyze --fatal-infos` — clean (0 issues)
- `npx supabase db reset --local` — migration applied cleanly
- `flutter test --exclude-tags integration` — 1885 tests passing, integration files NOT picked up (verified)
- `flutter test --tags integration` — 17 integration tests passing (16 functional + 1 perf bench; perf p95 = 97 ms HTTP wall-clock, well within 2000 ms relaxed gate)
- `flutter build web` — built clean
- `cd test/e2e && FLUTTER_APP_URL= npx playwright test specs/rpg-foundation.spec.ts specs/gamification-intro.spec.ts` — 9/9 passing

**Skipped findings (per orchestrator brief):**

- NIT #1 (`_rpg_backfill_chunk` OUT param style) — pure cosmetic, no functional impact, leave as-is
- NIT #3 (`xp_calculator.dart` 17b dead code) — explicitly tracked for 18e cleanup per PLAN.md, not a runtime-decided deferral

**Concerns to escalate:** Reviewer's stale-peak claim on `record_set_xp` is **false in practice** within a single transaction (PG ON CONFLICT DO UPDATE writes are visible to subsequent SELECTs in the same backend connection). Documented this in the function header so future readers don't re-litigate the question. Production hot path is `record_session_xp_batch` regardless — the strength-mult correctness invariant is preserved end-to-end.

### E2E coverage — bulletproof RPG (lock in 18a, deliver per-phase as UI lands)

**Standing rule:** RPG cannot ship without comprehensive e2e. This matrix is the
contract — every row gets a passing test before its phase merges. 18a delivers
the rows observable through the 17b shim (LVL line). 18b/18c rows are gated to
those phases when the character sheet UI / saga overlay v2 land.

**Selectors to add** (extend `test/e2e/helpers/selectors.ts` `GAMIFICATION` block):
- `lvlBadge` (already exists) — used for through-shim XP assertions in 18a
- `sagaTab` — bottom-nav `nav-saga` (18b)
- `bodyPartTile(name)` — `body-part-{slug}` per body part (18b)
- `bodyPartRune(name)` — `body-part-rune-{slug}` Dormant/Fading/Active/Radiant variants (18b)
- `bodyPartRank(name)` — `body-part-rank-{slug}` numeric label (18b)
- `bodyPartVitalityPct(name)` — `body-part-vitality-{slug}` (18b)
- `classCard` — `class-card` showing derived class label (18b)
- `statsDeepDive(name)` — `stats-deep-dive-{slug}` panel route (18b)
- `peakBadge(name)` — `peak-badge-{slug}` "NEW PEAK" pill (18b)
- `rankUpToast` — `rank-up-toast` non-blocking inline animation (18b)
- `titlePill(slug)` — `title-{slug}` mid-workout title award (18c)
- `earnedTitlesCarousel` — `earned-titles` (18c)
- `sagaIntroV2Step{n}` — new copy keyed under same overlay (18c)

**New test users** (add to `test/e2e/fixtures/test-users.ts` + `global-setup.ts`):
- `rpgFoundationUser` — profile seeded, ~12 prior workouts spanning 6 weeks across multiple body parts (used by 18a backfill + accumulation tests)
- `rpgFreshUser` — profile seeded, zero history (used by 18a first-workout-XP test + 18b dormant-runes test)
- `rpgArmsDominantUser` — profile seeded, 20+ arm-only sessions (used by 18b class derivation = Berserker test)
- `rpgLayoffUser` — profile seeded, history with a 6-week gap (used by 18a/b vitality decay + recovery tests)
- `rpgPeakUser` — profile seeded, history that establishes a clear peak_load (used by 18b PR-reattainment + cap-mult tests)

#### 18a-deliverable e2e (foundation; observable via 17b shim — `specs/rpg-foundation.spec.ts`)

- [x] **18a-E1 — Backfill on first login (`rpgFoundationUser`)** — login → LVL badge reflects character_state.lifetime_xp from backfilled history (LVL > 1). @smoke
- [x] **18a-E2 — First-workout XP applied (`rpgFreshUser`)** — fresh login, LVL = 1 → save 5-set bench workout → LVL badge updates (LVL > before). @smoke
- [x] **18a-E3 — Re-save doesn't double XP (BUG-RPG-001 regression, `rpgFreshUser`)** — save_workout RPC called twice with same IDs → total_xp within 1% of first-save value. @smoke
- [x] **18a-E4 — XP accumulates across workouts (`rpgFoundationUser`)** — record LVL → save additional workout → LVL >= before.
- [x] **18a-E5 — Saga intro gate regression** — sentinel test re-uses sagaIntroUser from gamification-intro.spec.ts; LVL badge visible and >= 1 after saga intro dismissal.
- [x] **18a-E6 — Concurrent body-part attribution (`rpgFreshUser`)** — save barbell_squat workout (legs 0.80/core 0.10/back 0.10) → body_part_progress rows reflect ±5% of expected ratio (asserted via Supabase admin read).

#### 18b-deliverable e2e (character sheet UI — `specs/rpg-character-sheet.spec.ts`)

- [ ] **18b-E1 — `/saga` route accessible** — Saga tab visible in bottom nav, tap routes to character sheet. @smoke
- [ ] **18b-E2 — Untrained body parts show dormant runes (`rpgFreshUser`)** — character sheet → all 6 body parts (Chest/Back/Legs/Shoulders/Arms/Core) render dormant variant, rank 0, vitality 0%.
- [ ] **18b-E3 — Trained body part shows active rune (`rpgFoundationUser`)** — at least one body part renders Active or Radiant rune, rank ≥ 1, vitality > 0%. @smoke
- [ ] **18b-E4 — Stats deep-dive opens (`rpgFoundationUser`)** — tap body part tile → deep-dive panel shows total volume, peak load, set count, vitality trajectory chart. @smoke
- [ ] **18b-E5 — Class card derivation (`rpgArmsDominantUser`)** — class label = "Berserker" (arms-dominant rule per spec §9). Fresh user → "Initiate" floor.
- [ ] **18b-E6 — Rank-up animation fires inline mid-workout** — complete enough volume to cross rank threshold mid-session → `rank-up-toast` renders without blocking the workout flow (assert toast present + workout still navigable).
- [ ] **18b-E7 — Peak badge on PR (`rpgPeakUser`)** — log a working set above prior peak_load → "NEW PEAK" pill renders on body part tile + peak_load updates in deep-dive. @smoke
- [ ] **18b-E8 — Vitality decay observable (`rpgLayoffUser`)** — login → vitality < 100% on body parts the user hasn't trained recently (validates asymmetric EWMA τ_down = 42d).
- [ ] **18b-E9 — Vitality recovery faster than decay (`rpgLayoffUser`)** — save 3 sessions on a faded body part → vitality climbs measurably (validates τ_up = 14d).
- [ ] **18b-E10 — Strength-mult floor (`rpgPeakUser`)** — log multiple sessions at 50% of peak_load → XP awarded > 0 (strength_mult floors at 0.4, not zero); per-set XP delta consistent with calculator.
- [ ] **18b-E11 — Weekly cap-mult kicks in** — log 25 sets on one body part in a single week → set #21+ awards diminished XP per spec §4 cap rule.
- [ ] **18b-E12 — Bodyweight (zero load) handled** — log a set with weight = 0 + reps > 0 → no NaN/error, XP awarded per the bodyweight branch of the calculator.

#### 18c-deliverable e2e (overlay rewire + titles + class system — `specs/rpg-overlay.spec.ts`)

- [ ] **18c-E1 — Title earned mid-workout** — cross a title threshold → `title-{slug}` pill animates in inline (not a blocking modal). @smoke
- [ ] **18c-E2 — Earned titles carousel** — character sheet renders `earned-titles` with all earned titles for the user.
- [ ] **18c-E3 — Saga intro overlay v2 copy** — fresh user sees new dual-track Rank+Vitality copy on first launch (steps 0/1/2 still 3-step structure, content updated per spec §13).
- [ ] **18c-E4 — Class transition** — user trains a new body part to dominance → class card label transitions (e.g. Berserker → Sentinel) on character sheet.

#### Cross-platform parity (one-time, end of 18b)

- [ ] **18b-E13 — Web/Android XP parity** — same user on both platforms (run e2e on Chrome + smoke check on Android emulator) → identical LVL + per-body-part XP. (Manual or scripted; not blocking 18b PR if Android emulator setup is non-trivial — gate with explicit decision.)

#### Coverage acceptance

- **Phase 18a PR:** rows 18a-E1..E6 must be green in `specs/rpg-foundation.spec.ts`, all tagged appropriately, and `gamification-intro.spec.ts` regression-clean.
- **Phase 18b PR:** all 18b-E1..E12 green. 18b-E13 captured in PR description (parity numbers) but not gating.
- **Phase 18c PR:** all 18c-E1..E4 green.

#### Bug-found protocol during e2e authoring

If any e2e reveals an unexpected backend or calculator behavior, STOP — do not patch the test to match the bug. Surface to tech-lead via the orchestrator pipeline. Same standing rule as integration: no deferring review findings.

---

## Phase 16 — Subscription Monetization — PARKED (2026-04-22)

**Why parked:** Phase 16 keeps hitting external blockers (Brazilian merchant account, Play Console → upload signed AAB required before subscription product can be created, license-tester account setup). Phase 17 gamification is fully internal code work with no external gates and produces the retention moat that makes Phase 16's paywall pitch compelling. Decision: ship Phase 17 (Gamification) before resuming 16b/c/d.

### What's complete in Phase 16

- **16a** (backend): migrations + Edge Functions shipped in PR #93. Vault secrets set. Confirmed working end-to-end after GCP migration (PR #99): Play test notification → Pub/Sub → `rtdn-webhook` returns 200 with new `repsaga-prod` credentials.
- External infrastructure fully rebuilt in `repsaga-prod`: SA, Pub/Sub topic/push-sub, Supabase secrets rotated, Edge Functions redeployed. Old `gymbuddy-app-proj` shut down.

### What's blocked (resume on Phase 17 complete)

- **16b** (client + paywall UI + onboarding rewire): needs `in_app_purchase` package added, models, repo, notifier, `PaywallScreen`, l10n. No external dep; could technically ship without real purchases. **Deferred by choice, not blocker.**
- **Play Console subscription product `repsaga_premium`**: blocked on uploading a signed AAB to Internal Testing. Blocked on generating the upload keystore (`android/keystore/repsaga-release.jks` + `android/key.properties`). Keystore generation is a 10-min chore; the app bundle upload + Play App Signing enrollment is another ~15 min. **Not doing now — pivot to Phase 17.**
- **16c** (hard gate + E2E): depends on 16b.
- **16d** (analytics + merchant-account launch gate): depends on Brazilian merchant account, blocked on 16b/c.

### Resume checklist (when we come back to Phase 16)

- [ ] Generate upload keystore: `keytool -genkey -keystore android/keystore/repsaga-release.jks -alias repsaga-release -keyalg RSA -keysize 2048 -validity 10000`
- [ ] Create `android/key.properties` (not committed) from `android/key.properties.example`
- [ ] Back up keystore + key.properties (1Password attachment, encrypted secondary)
- [ ] `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`
- [ ] Upload AAB to Play Console → RepSaga → Testing → Internal testing → Create release (save as draft, no rollout needed). Enroll in Play App Signing (Google-managed).
- [ ] Create subscription product `repsaga_premium` with 2 base plans (monthly + annual), trial-14d offer, BRL/USD/EUR prices + PPP auto-convert (full spec in PLAN.md Phase 16 → Business Model)
- [ ] Proceed with Phase 16b dev (tech-lead pipeline per CLAUDE.md)

---

## post-rebrand: external service rename cascade (tracking only)

**Why:** PR #98 merged the GymBuddy → RepSaga code rename. Codebase is 100% clean
(zero `gymbuddy`/`GymBuddy` refs post-merge). This section tracks external
services and manual actions that still need renaming outside the repo. Not a
branch — purely a coordination checklist.

### GitHub

- [x] **Rename repo** `gymbuddy-app` → `repsaga` (done; local `origin` updated; old URL auto-redirects)
- [x] **Rename local folder** — Claude Code session now runs in `C:\Users\caiol\Projects\repsaga` (folder + memory dir already migrated)

### Google Cloud Platform

- [x] **Fresh GCP project** `repsaga-prod` created; old `gymbuddy-app-proj` shut down (2026-04-22, see `docs/gcp-project-recreation.md`)
- [x] **Pub/Sub topic** `repsaga-rtdn` created in `repsaga-prod`; Play granted publisher; Play Console RTDN pointed at `projects/repsaga-prod/topics/repsaga-rtdn`
- [x] **Pub/Sub push subscription** `repsaga-rtdn-push` → `rtdn-webhook` Edge Function (OIDC-authed, test notification returns 200)

### Supabase

- [ ] **Project display name** — Dashboard → Project Settings → General → rename to "RepSaga"
- [ ] **Auth redirect URLs allowlist** — Dashboard → Authentication → URL Configuration → add `io.supabase.repsaga://login-callback/` **when Google Sign-In is enabled** (Phase 16b+). Not blocking today since only email/password auth is wired.
- [x] **Edge Function secrets** — `GOOGLE_PLAY_PACKAGE_NAME=com.repsaga.app`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` (new `repsaga-prod` SA), `RTDN_PUBSUB_AUDIENCE` all set; Edge Functions redeployed (2026-04-22)

### Google Play Console (blocked → now unblocked)

- [x] **Create app** with package `com.repsaga.app` — unblocks Phase 16a Stages 1.3, 3.4, 4, 5.3
- [ ] **Create subscription product** `repsaga_premium` (code + test fixtures already expect this ID)
- [x] **Link service account** — `repsaga-play-api@repsaga-prod.iam.gserviceaccount.com` invited via Users and permissions (new flow; old API-access page deprecated by Google ~2024)
- [x] **Point Play at Pub/Sub topic** — `projects/repsaga-prod/topics/repsaga-rtdn`; test notification verified end-to-end (Play → Pub/Sub → `rtdn-webhook` 200)

### Brand assets

- [ ] **Domains** — register `repsaga.com`, `repsaga.app`, `repsaga.com.br`
- [ ] **Social handles** — lock `@repsaga` on Instagram, X/Twitter, TikTok

### Local development environment

- [x] **IntelliJ/Android Studio** — stale `.iml` files + `.idea/modules.xml` deleted; IDE will regenerate with `repsaga` names on next open
- [x] **Claude Code memory dir** — migrated to `C--Users-caiol-Projects-repsaga\memory\`; MEMORY.md index loads correctly this session

### Not renameable (stuck forever — fine)

- Supabase project ref `dgcueqvqfyuedclkxixz` — internal ID, appears in `.env` as part of the Supabase URL
- Android keystore signing certificate (cryptographic; key alias is internal-only)
- Git commit history (correct historical record)

### Acceptance

All checklist items above completed. Phase 16a external setup can proceed with `com.repsaga.app` everywhere.
