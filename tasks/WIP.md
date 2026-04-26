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
- [ ] Integration: `rpg_record_set_xp_test.dart` (PG/Dart parity, concurrent INSERT race) — defer to qa-engineer
- [ ] Integration: `rpg_backfill_test.dart` (1500-set fixture user vs Python sim reference) — defer to qa-engineer
- [ ] Integration: `rpg_backfill_resume_test.dart` (kill mid-run + restart) — defer to qa-engineer
- [ ] Migration dry-run on hosted DB snapshot — apply post-merge per CLAUDE.md step 10

### Verification gate (before PR)
- [x] `dart analyze --fatal-infos` clean
- [x] `dart format` clean
- [x] `flutter test` — 1885 tests passing
- [ ] `make ci` green (format + analyze + test + android-debug-build) — orchestrator runs before PR
- [ ] Performance benchmark: 100-set workout `save_workout` p95 ≤ 50ms — qa-engineer captures
- [ ] No selectors broken (no UI surface change in 18a) — qa-engineer audits

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
