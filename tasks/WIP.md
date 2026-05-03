# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Wave 5 / Cluster 8 PR A — small architecture refactors (`fix/cluster8-small-refactors`)

**Per BUGS.md Cluster 8 (BUG-035, 039, 040).** Three independent mechanical fixes
bundled because each is small and they touch disjoint files. Pure refactor — no
behavior change. The three larger extractions (BUG-036/037/038) ship as separate PRs.

### Source files

- [x] **BUG-035** — `lib/features/rpg/domain/vitality_state_mapper.dart` — stripped `package:flutter/painting.dart` + `AppLocalizations`. Color resolution + l10n copy moved to new `lib/features/rpg/ui/utils/vitality_state_styles.dart` (with the `VitalityStateColor` extension carrying the legacy `state.borderColor` shape). The `borderColor` extension also migrated out of `lib/features/rpg/models/vitality_state.dart` so the model file is Flutter-agnostic. Eight UI callsites updated to import the new utils file.
- [x] **BUG-039** — `lib/features/workouts/providers/notifiers/active_workout_notifier.dart` — added `savedOffline` field to `ActiveWorkoutState` (Freezed, `@Default(false)`) AND changed `finishWorkout` return type to `FinishWorkoutResult` record (`prResult`, `savedOffline`). Public notifier field deleted. Screen reads via the explicit return record (the spec listed both options; the return-record path solves the "state is null after finish" gap that the state-only approach hits).
- [x] **BUG-040** — `lib/features/workouts/providers/workout_history_providers.dart` — added `_invalidateOnUserIdChange(Ref)` helper that listens to `authStateProvider` and invalidates the calling provider when the user-id slice transitions. Wired into `workoutHistoryProvider.build()` and `workoutCountProvider`. Token-refresh emissions short-circuit (same user-id → no re-fetch).

### Tests

- [x] **BUG-035** — split into two files: `test/unit/features/rpg/domain/vitality_state_mapper_test.dart` (pure-domain boundary tests, ZERO Flutter imports — structural canary) + new `test/unit/features/rpg/ui/utils/vitality_state_styles_test.dart` (Color + l10n + `VitalityStateColor.borderColor` extension).
- [x] **BUG-039** — added `BUG-039: savedOffline lives on FinishWorkoutResult, not the notifier` test in `active_workout_notifier_test.dart`. Pins both the result-record contract AND that `(notifier as dynamic).savedOffline` throws `NoSuchMethodError`.
- [x] **BUG-040** — new `workout_history_providers_test.dart` with two tests: invalidates on user-id change (drives synthetic `authStateProvider` stream), and does NOT re-fetch on token-refresh emissions (same user-id short-circuit).

### E2E

No user-facing flow change — pure internal refactor. Selector impact assessment
sufficient (qa-engineer scans for any tests that depend on the public `notifier.savedOffline`
API surface and updates if needed). No new E2E specs.

### Cleanup

- [x] Mark BUG-035, 039, 040 RESOLVED in `BUGS.md` with strikethrough heads + `RESOLVED in PR #NN`
- [x] `make ci` green (full test suite 2257 passed; analyze clean; android-debug build clean)
- [x] Commit `refactor(arch): Cluster 8 PR A — small architecture leaks (BUG-035, 039, 040)`
- [x] `git push -u origin fix/cluster8-small-refactors`

### Out of scope (separate PRs to follow)

- BUG-036 + BUG-041 → PR B (`active_workout_screen.dart` decomposition, bundled to avoid file-level merge conflicts)
- BUG-037 → PR C (`profile_settings_screen.dart` decomposition)
- BUG-038 → PR D (`plan_management_screen.dart` decomposition)

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

