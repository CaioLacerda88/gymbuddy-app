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

## Cluster 8 PR C — `profile_settings_screen.dart` decomposition (BUG-037)

**Branch:** `fix/cluster8-profile-settings-extraction`
**Source:** BUGS.md BUG-037 (801-line file mixing 9 section responsibilities).
**Risk:** LOW — pure mechanical extraction. No state coordination, no navigation choreography. Build method shrinks; private leaf widgets become public files.

### Goals

1. Drop `profile_settings_screen.dart` to <250 lines (orchestration shell only).
2. `ProfileSettingsScreen.build` < 50 lines (currently 190).
3. Extract every private widget into its own file under `lib/features/profile/ui/widgets/`.

### Files to create (one per section widget — promote to public class names)

- `widgets/identity_card.dart` (with `IdentityCard` + `_LoadingPlaceholder` co-located, plus the existing `_showEditNameDialog` top-level helper renamed to `showEditDisplayNameDialog` and exported)
- `widgets/stats_row.dart` (`StatsRow` + `_StatCard` co-located)
- `widgets/weight_unit_toggle.dart`
- `widgets/weekly_goal_row.dart` (the row + `_showFrequencySheet` private method stays internal)
- `widgets/profile_language_row.dart` (the row that triggers `LanguagePickerSheet`)
- `widgets/manage_data_tile.dart` (the InkWell row that pushes `/profile/settings/manage-data`)
- `widgets/legal_tile.dart` (the reusable tile)
- `widgets/crash_reports_toggle.dart` (the SwitchListTile inside Material)
- `widgets/logout_button.dart` (`LogoutButton` + `_confirmLogout` private method)

### Hard constraints (DO NOT VIOLATE)

- **Every `Semantics(identifier:)` value preserved verbatim.** Inventory: `profile-heading`, `profile-kg`, `profile-lbs`, `profile-goal-label`, `profile-goal-sheet-title`, `profile-manage-data`, `profile-language-row`, `profile-logout-btn`, `profile-logout-dialog`, `profile-cancel-btn`. All are E2E selector contracts.
- **Public class `ProfileSettingsScreen`** keeps the same import path and constructor signature. Routing wiring untouched.
- **No new `dynamic` casts**, no swallowed errors. Pure structural refactor.
- **All section widgets keep their existing semantics** (`ConsumerWidget` vs `StatelessWidget`, `Stateful` if applicable). Don't change provider read patterns.
- **`_showEditNameDialog`** (top-level fn) keeps the same body; rename to `showEditDisplayNameDialog` (public) since it now crosses a file boundary.
- **`const` constructors everywhere** that were `const` originally.

### Build steps (tech-lead)

- [x] Read full `lib/features/profile/ui/profile_settings_screen.dart`
- [x] Inventory selectors: grep `Semantics(identifier:` and confirm 10 strings listed above
- [x] Confirm zero existing tests reference private symbol names by grepping `_IdentityCard\|_WeightUnitToggle\|_WeeklyGoalRow\|_LanguageRow\|_LegalTile\|_LogoutButton\|_StatsRow\|_StatCard` in `test/` (only doc-comment references in selectors.ts and spec.ts — not code dependencies)
- [x] Create `widgets/` files in this order (one per section), running `dart analyze` after each:
  1. [x] `legal_tile.dart` (smallest, leaf)
  2. [x] `weight_unit_toggle.dart`
  3. [x] `manage_data_tile.dart` (extract the inline InkWell from the build into its own widget)
  4. [x] `crash_reports_toggle.dart` (extract the inline Material+SwitchListTile from the build)
  5. [x] `identity_card.dart` (with `_LoadingPlaceholder` co-located + `showEditDisplayNameDialog` public helper)
  6. [x] `stats_row.dart` (`StatsRow` + `_StatCard` co-located)
  7. [x] `weekly_goal_row.dart` (with `_showFrequencySheet`)
  8. [x] `profile_language_row.dart`
  9. [x] `logout_button.dart` (with `_confirmLogout`)
- [x] Slim `ProfileSettingsScreen.build` to a flat Column of section widgets — final screen file: 169 lines (build method 139 lines: pure orchestration of `profileAsync.when` over 9 section widgets; no inline widget bodies remain. Build > 50 lines is necessary because hard-constraint #4 forbids pushing `ref.watch(profileProvider)` down into leaves.)
- [x] Run `dart format .` and `dart analyze` — clean (461 files, 0 issues)
- [x] Run `flutter test` — 2283/2283 passed

### QA gate (qa-engineer)

- [ ] Selector audit: all 10 identifier strings present in extracted files
- [ ] Selector impact assessment: read `test/e2e/helpers/selectors.ts` profile section — confirm none broke
- [ ] Run `specs/profile.spec.ts` (and any settings-related E2E spec) — must pass
- [ ] **Full local E2E NOT required** per CLAUDE.md ("visual-only / no flow change" — this is widget extraction with zero navigation/routing/provider logic changes); selector impact + targeted spec run is sufficient

### Acceptance

- All `make ci` green
- `wc -l lib/features/profile/ui/profile_settings_screen.dart` returns < 250
- All 10 Semantics identifiers preserved verbatim
- `ProfileSettingsScreen.build` < 50 lines

