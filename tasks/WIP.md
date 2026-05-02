# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Wave 3 / Cluster 4 — Tap-target & sweat-proof UX (`fix/cluster4-tap-targets`)

**Per BUGS.md Cluster 4 (BUG-018..020).** Three small UX fixes on the primary
logging flow. File scope: `lib/features/workouts/ui/widgets/set_row.dart` +
`lib/features/workouts/ui/active_workout_screen.dart`. Strictly UI work — no
ARB, migration, repository, or data-layer changes.

### Source files

- [x] BUG-018 — `lib/features/workouts/ui/widgets/set_row.dart:236-241` — set-row number cell bumped to `minWidth: 48, minHeight: 48` (was 40dp)
- [x] BUG-019 — `lib/shared/widgets/weight_stepper.dart:141,186` AND `lib/shared/widgets/reps_stepper.dart:117,153` — both stepper button constraints bumped to `minWidth: 40, minHeight: 48` (was 32x44). Reps stepper extended for sibling-consistency on the same logging row.
- [x] BUG-020 — `lib/features/workouts/ui/active_workout_screen.dart` — Finish button moved from AppBar trailing to a new persistent `_FinishBottomBar` (`Scaffold.bottomNavigationBar`). Same `Semantics(identifier: 'workout-finish-btn')` so E2E selectors are preserved. Hidden on the empty body. Phase 18c §13 docblock replaced with BUG-020 reach + discoverability rationale.

### Widget tests

- [x] `test/widget/features/workouts/ui/widgets/set_row_test.dart` — number-cell BoxConstraints pin (BUG-018)
- [x] `test/widget/shared/widgets/weight_stepper_test.dart` — stepper BoxConstraints pin at 360dp (BUG-019)
- [x] `test/widget/shared/widgets/reps_stepper_test.dart` — sibling stepper BoxConstraints pin at 360dp (BUG-019)
- [x] `test/widget/features/workouts/ui/active_workout_finish_button_test.dart` — bottom-bar slot, semantics-identifier survival, AppBar.actions clear, empty-state hidden, tap fires AlertDialog (BUG-020)

### E2E impact

BUG-020 changes the **finish-workout** user flow (bottom bar instead of AppBar).
Per CLAUDE.md QA gate: navigation/flow change → run full E2E suite locally + update
any selectors targeting the AppBar finish action.

- [x] qa-engineer: scan all spec files for AppBar-finish selectors; updated `helpers/selectors.ts` comment, fixed `startEmptyWorkout` sentinel in `workout.ts`, patched all pre-exercise `finishButton.toBeVisible` assertions in `workouts.spec.ts`, `rank-up-celebration.spec.ts`, `home.spec.ts`, `workouts-localization.spec.ts`, `offline-sync.spec.ts`
- [x] Full E2E suite: **211/212 passed** (1 pre-existing failure: `manage-data.spec.ts` account-deletion redirect timeout, unchanged from main, outside Cluster 4 scope)

### Cleanup

- [ ] Mark BUG-018..020 RESOLVED in `BUGS.md` with strikethrough heads + `RESOLVED in PR #NN`
- [ ] `make ci` green (format + gen + analyze + test + android-debug-build)
- [ ] `git push -u origin fix/cluster4-tap-targets`

### Out of scope

- Cluster 3 (RPG progression UX) — needs product-owner + ui-ux-critic spec calls first (BUG-011 ClassChangeEvent, BUG-015 predicate rebalance)
- Cluster 8 (architecture refactors) — separate sweep PRs

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

