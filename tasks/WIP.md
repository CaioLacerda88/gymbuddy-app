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

## Cluster 8 PR B — `active_workout_screen.dart` decomposition (BUG-036, BUG-041)

**Branch:** `fix/cluster8-active-workout-extraction`
**Source:** BUGS.md BUG-036 (1706-line monolith, `_onFinish` 266 lines) + BUG-041 (file-level mutable globals).
**Risk:** HIGH — primary user surface. Full local E2E run mandatory (CLAUDE.md QA gate). Pure refactor: zero behavior change.

### Goals

1. Drop `active_workout_screen.dart` to under ~300 lines (orchestration shell only).
2. `_ActiveWorkoutBody.build` < 50 lines (currently 102) — extract title editor.
3. Extract three coordinator classes per BUGS.md BUG-036:
   - `_FinishWorkoutCoordinator` — owns `_onFinish` orchestration + `_isFinishHandled` instance field
   - `_CelebrationOrchestrator` — saga-intro wait + `CelebrationPlayer.play` invocation
   - `_PostWorkoutNavigator` — `_shouldShowPlanPrompt`, `_showPlanPromptAndGoHome`, post-finish nav switch
4. Resolve BUG-041: hoist `_isShowingDiscardDialog` + `_isFinishHandled` from file-level globals to instance fields. Cleanest path: convert `ActiveWorkoutScreen` → `ConsumerStatefulWidget`, owns coordinator instances.
5. Extract bloated inline widgets: `_ExerciseCard` (292-line build) → own file; supporting `_ExerciseDetailSheet`, `_SheetChip`, `_SheetPRSection`, `_SetColumnHeaders` move with it. Other inlined widgets (`_LoadingOverlay`, `_EmptyWorkoutBody`, `_FinishBottomBar`, `_AddExerciseFab`, `_ElapsedTimer`, `_ExerciseList`) move to dedicated files under `widgets/`.

### Files to create

- `lib/features/workouts/ui/coordinators/finish_workout_coordinator.dart`
- `lib/features/workouts/ui/coordinators/celebration_orchestrator.dart`
- `lib/features/workouts/ui/coordinators/post_workout_navigator.dart`
- `lib/features/workouts/ui/coordinators/discard_workout_coordinator.dart` (owns `_isShowingDialog` instance field, used by both PopScope handler and AppBar close)
- `lib/features/workouts/ui/widgets/exercise_card.dart` (+ `_ExerciseDetailSheet`, `_SheetChip`, `_SheetPRSection`, `_SetColumnHeaders` co-located)
- `lib/features/workouts/ui/widgets/active_workout_loading_overlay.dart`
- `lib/features/workouts/ui/widgets/empty_workout_body.dart`
- `lib/features/workouts/ui/widgets/finish_bottom_bar.dart`
- `lib/features/workouts/ui/widgets/add_exercise_fab.dart`
- `lib/features/workouts/ui/widgets/elapsed_timer.dart`
- `lib/features/workouts/ui/widgets/active_workout_app_bar_title.dart` (extracted name editor + timer)

### Hard constraints (DO NOT VIOLATE)

- **Every `Semantics(identifier: ...)` value preserved verbatim.** E2E selectors depend on these — `workout-discard-btn`, `workout-finish-btn`, `workout-add-exercise`, `workout-add-set`. Grep test before opening PR: `grep -rn "workout-finish-btn\|workout-discard-btn\|workout-add-exercise\|workout-add-set" lib/` returns same identifier strings.
- **`ValueKey('finish-bottom-bar')` preserved verbatim.**
- **Public class `ActiveWorkoutScreen`** keeps the same import path (`lib/features/workouts/ui/active_workout_screen.dart`) and constructor signature `const ActiveWorkoutScreen({super.key})`. Routing wiring untouched.
- **`_onFinish` behavior preserved exactly.** All `_isFinishHandled` lifecycle, all `mounted`/`rootContext.mounted` guards, all provider invalidations, all postFrameCallback ordering.
- **Saga-intro `5 s timeout` on `SagaIntroSequencer.waitForIntroDismissed` preserved.** This was the BUG-039 defensive fix from PR #136 — do not regress it.
- **All comments explaining WHY (lifecycle, dispose race, root-navigator capture) carry over** with the extracted code. Don't strip these — they document load-bearing invariants.
- **No new `dynamic` casts**, no swallowed errors, no behavior simplification. Pure structural refactor.
- **No public API changes** to `activeWorkoutProvider`, `restTimerProvider`, `FinishWorkoutResult`, etc.

### Build steps (tech-lead)

- [x] Read full `lib/features/workouts/ui/active_workout_screen.dart` (1706 lines)
- [x] Read `lib/features/workouts/providers/notifiers/active_workout_notifier.dart` for `FinishWorkoutResult` shape and `consumeLastCelebration` signature
- [x] Read `lib/features/rpg/ui/celebration_player.dart` for `CelebrationPlayer.play` signature + return shape
- [x] Read `lib/features/rpg/ui/saga_intro_gate.dart` for `SagaIntroSequencer.waitForIntroDismissed` contract
- [x] Identify all selector / ValueKey strings to preserve — grep before/after
- [x] Create `widgets/` extractions first (low-risk leaf widgets) → run `make analyze` after each
- [x] Extract `_ExerciseCard` (largest leaf) → run analyze
- [x] Convert `ActiveWorkoutScreen` to `ConsumerStatefulWidget`, hoist coordinator instances into `_ActiveWorkoutScreenState`
- [x] Create `DiscardWorkoutCoordinator` (instance field `_isShowingDialog`), wire into PopScope + body's back button
- [x] Create `FinishWorkoutCoordinator` (instance fields `_isFinishHandled`, `_isFinishing`), wire into Finish bottom bar
- [x] Create `CelebrationOrchestrator` (stateless helper class) used by FinishWorkoutCoordinator
- [x] Create `PostWorkoutNavigator` (stateless helper class) used by FinishWorkoutCoordinator
- [x] Delete file-level `_isShowingDiscardDialog` and `_isFinishHandled` globals
- [x] Verify `_ActiveWorkoutBody.build` is < 50 lines (now 35) and `ExerciseCard.build` is < 50 lines (now 53; was 292) — title editor extracted to `ActiveWorkoutAppBarTitle`, header extracted to `_ExerciseCardHeader`
- [x] Run `dart format .` and `dart analyze` — clean (0 issues)
- [x] Run `flutter test` — workout widget suite (183) green; only failures are 9 pre-existing network-dependent integration tests in `rpg_vitality_nightly_test.dart` (Supabase Edge Function 503 / DNS), unrelated to this refactor
- [x] Update WIP checklist (this file) as you go

### QA gate (qa-engineer, after tech-lead handoff)

- [ ] Selector audit: `grep -rn "Semantics(identifier" lib/features/workouts/ui/` — every previous identifier still present
- [ ] Selector impact assessment: read `test/e2e/helpers/selectors.ts` workout selectors, confirm none broke
- [ ] **Full local E2E suite run mandatory** — primary user surface, navigation/flow code touched
- [ ] Add widget-level pin if reasonable: `_FinishWorkoutCoordinator` lifecycle (start/finish, double-tap guard, error path)

### Acceptance

- All `make ci` green (format, analyze, test, android-debug-build)
- Full local E2E suite green (145 tests)
- `wc -l lib/features/workouts/ui/active_workout_screen.dart` returns < 350
- No file-level mutable variables remain in `active_workout_screen.dart`
- All Semantics identifiers + ValueKey('finish-bottom-bar') preserved verbatim
- `_onFinish` behavior bit-for-bit equivalent (manual trace through coordinator)

