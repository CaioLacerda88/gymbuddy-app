# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

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

---

## Cluster 1 leftovers — BUG-003/005/006/007/008/009 (BUGS.md, 2026-04-30)

**Branch:** `fix/cluster1-leftovers`
**Source:** BUGS.md Cluster 1 remaining entries after PR #124

PR #124 shipped the P0 data-loss subset (BUG-001/002/004/042) and introduced the
`dependsOn: List<String>` mechanism on `PendingAction`, the `SyncErrorMapper`
classifier, and `ExerciseSet.toRpcJson()`. This branch reuses those primitives
to clear out the remainder.

### Code changes

- [x] **BUG-003** [P0] — `PendingCreateExercise` queue variant
- [x] **BUG-005** [P1] — Sync drain provider invalidation
- [x] **BUG-006** [P1] — PR cache key unification
- [x] **BUG-007** [P1] — `OfflineQueueService` rethrow + Sentry capture
- [x] **BUG-008** [P1] — Sync sheet retry CTA classification
- [x] **BUG-009** [P1] — PR-detection Sentry capture

### Tests

- [x] `sync_service_test.dart` extended (BUG-003/005/006)
- [x] `offline_queue_service_test.dart` extended (BUG-007)
- [x] `pending_sync_sheet_test.dart` new (BUG-008)
- [x] `active_workout_notifier_test.dart` extended (BUG-009)

### Files

**Modified:**
- `lib/core/offline/pending_action.dart` (+ regen)
- `lib/core/offline/sync_service.dart`
- `lib/core/offline/sync_error_mapper.dart`
- `lib/core/offline/offline_queue_service.dart`
- `lib/core/offline/pending_sync_provider.dart`
- `lib/features/exercises/data/exercise_repository.dart`
- `lib/features/exercises/providers/exercise_providers.dart`
- `lib/features/exercises/ui/create_exercise_screen.dart`
- `lib/features/workouts/providers/notifiers/active_workout_notifier.dart`
- `lib/shared/widgets/pending_sync_sheet.dart`
- `lib/l10n/app_pt.arb`
- `lib/l10n/app_en.arb`
- `BUGS.md` (mark resolved)

**Tests:**
- `test/unit/core/offline/sync_service_test.dart` (extend)
- `test/unit/core/offline/offline_queue_service_test.dart` (extend)
- `test/widget/shared/widgets/pending_sync_sheet_test.dart` (new)
- `test/unit/features/workouts/providers/active_workout_notifier_test.dart` (extend)

### Done

- [x] All checklist items above checked
- [x] `make ci` green (format + analyze + 2155 tests + android-debug-build)
- [x] BUGS.md updated to mark BUG-003/005/006/007/008/009 RESOLVED
- [x] Cluster 1 header reflects "fully resolved"
- [ ] qa-engineer gate
- [ ] PR opened
- [ ] reviewer pass
- [ ] merged

