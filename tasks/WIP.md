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

## Cluster 8 PR D — `plan_management_screen.dart` decomposition (BUG-038)

**Branch:** `fix/cluster8-plan-management-extraction`
**Source:** BUGS.md BUG-038 (752-line file with 3 leaf widgets and a complex Stateful screen).
**Risk:** LOW — pure mechanical leaf extraction. The Stateful screen has critical analytics + save debounce lifecycle that must NOT be touched; extractions are limited to the three private widgets at the bottom of the file.

### Goals

1. Drop `plan_management_screen.dart` from 752 lines to under ~520 lines (orchestration + state lifecycle remains).
2. Extract the three leaf widgets to `widgets/`.
3. **DO NOT modify `_PlanManagementScreenState`'s lifecycle logic** — analytics debounce, save debounce, `_dirty`/`_seeded` gates, dispose flush, `ref.listenManual` are all load-bearing and stay verbatim.

### Files to create

- `widgets/plan_routine_row.dart` — `PlanRoutineRow` (currently `_RoutineRow`, 113 lines). Self-contained: name + sequence/check + drag handle + Dismissible.
- `widgets/plan_add_routine_row.dart` — `PlanAddRoutineRow` (currently `_AddRoutineRow`, 85 lines). The bottom add-routine bordered tap target.
- `widgets/plan_empty_state.dart` — `PlanEmptyState` (currently `_EmptyState`, 47 lines). The icon + label + add/auto-fill CTAs shown when bucket is empty.

### Hard constraints (DO NOT VIOLATE)

- **Selectors preserved verbatim:** `weekly-plan-title`, `weekly-plan-overflow`, `weekly-plan-clear-week`, `weekly-plan-clear-confirm`, `weekly-plan-add-routine-row`, `weekly-plan-add-routines`. The first four stay in the screen file (they wrap AppBar + dialog elements, not extracted widgets); the last two move with their widgets.
- **ValueKeys preserved verbatim:** `ValueKey('add-routine')` (on `PlanAddRoutineRow`), `ValueKey(bucket.routineId)` (on `PlanRoutineRow`), `ValueKey('dismiss-$routineId')` (on the inner `Dismissible`). These gate Flutter's reorder + dismissible identity.
- **Public class `PlanManagementScreen`** keeps the same import path and constructor. Routing wiring untouched.
- **`_PlanManagementScreenState`'s lifecycle is OFF LIMITS** — analytics debounce fields, save debounce, `dispose()` flush sequence (cancel timer → flush save → flush analytics → super.dispose), `ref.listenManual(weeklyPlanProvider)` in postFrameCallback, `_savePlan` capture pattern (notifier + repo + userId + frequency), `_dirty` / `_seeded` gates — all stay verbatim. The whole point is that this State is correct and the only thing wrong is the leaf-widget bloat. Only `build`'s widget composition changes.
- **All `const` constructors** that existed before are preserved on the promoted public classes.
- **No new `dynamic` casts**, no swallowed errors, no new `// ignore:` directives.

### Build steps (tech-lead)

- [x] Read full `lib/features/weekly_plan/ui/plan_management_screen.dart` (752 lines)
- [x] Inventory selectors + ValueKeys; confirm zero tests reference private widget names by grepping `_RoutineRow\|_AddRoutineRow\|_EmptyState` in `test/` (only one stale comment in `plan_management_screen_test.dart` line 455 — updated to `PlanAddRoutineRow`)
- [x] Create `widgets/plan_empty_state.dart` (62 lines, smallest leaf) → analyze + test clean
- [x] Create `widgets/plan_add_routine_row.dart` (99 lines) → analyze + test clean
- [x] Create `widgets/plan_routine_row.dart` (129 lines) → analyze + test clean
- [x] Update screen file imports + replace inline class refs with imported public names. Build method's `ReorderableListView` now references the three new public widgets verbatim; `_PlanManagementScreenState` lifecycle methods are byte-identical to main.
- [x] Run `dart format . && dart analyze --fatal-infos` → 0 issues (464 files)
- [x] Run `flutter test` → 2283/2283 passed
- [x] Selector grep + ValueKey grep: confirm all 6 selectors + 3 ValueKey strings still present in `lib/features/weekly_plan/ui/`
- [x] `wc -l lib/features/weekly_plan/ui/plan_management_screen.dart` → 503 lines (target <520)
- [x] Update `tasks/WIP.md` checklist

### QA gate (qa-engineer)

- [ ] Selector audit: all 6 identifier strings present
- [ ] Selector impact assessment: read `test/e2e/helpers/selectors.ts` weekly-plan section
- [ ] Run `specs/weekly-plan.spec.ts` (or whatever spec covers this screen) — must pass
- [ ] **Full local E2E NOT required** per CLAUDE.md ("visual-only / no flow change" — leaf widget extraction with zero state-logic / navigation / provider changes)

### Acceptance

- All `make ci` green
- `wc -l lib/features/weekly_plan/ui/plan_management_screen.dart` returns < 520
- All 6 Semantics identifiers + 3 ValueKey strings preserved verbatim
- `_PlanManagementScreenState`'s lifecycle code (analytics debounce, save debounce, dispose, listenManual) is bit-for-bit identical to current main

