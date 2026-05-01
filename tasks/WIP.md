# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Wave 2 / Cluster 5+6 — Localization, a11y, brand polish (fix/cluster5-6-ui-polish)

Per BUGS.md Cluster 5 (Localization & accessibility) + Cluster 6 (Brand consistency). Combined into one PR because the file scope is disjoint from Cluster 2 + Cluster 7 wave-2 branches.

### Cluster 5 — Localization & a11y

- [ ] BUG-021 — `PendingSyncBadge` Semantics label hardcoded English (add `pendingSyncBadgeSemantics` ARB key with `{label}` placeholder)
- [ ] BUG-022 — `equipmentBands` not localized in pt (`"Bands"` → `"Elásticos"`)
- [ ] BUG-023 — Home status line WCAG AA contrast (alpha 0.55 → 0.75)
- [ ] BUG-024 — `ActiveTitlePill` overflow handling (ellipsis + maxWidth)
- [ ] BUG-025 — Saga intro overlay skip path (`sagaIntroSkip` ARB key + skip TextButton)

### Cluster 6 — Brand consistency

- [ ] BUG-026 — Character-sheet error icon `Icons.error_outline` → `AppIcons.hero`
- [ ] BUG-027 — Titles screen double `CircularProgressIndicator` → branded skeleton
- [ ] BUG-028 — Onboarding `ChoiceChip` → branded pill buttons
- [ ] BUG-029 — Routine list empty state branded (illustration + inline FilledButton)

### Files in scope

- `lib/l10n/app_en.arb`, `lib/l10n/app_pt.arb`
- `lib/shared/widgets/pending_sync_badge.dart`
- `lib/features/workouts/ui/widgets/home_status_line.dart`
- `lib/features/rpg/ui/widgets/active_title_pill.dart`
- `lib/features/rpg/ui/saga_intro_overlay.dart`
- `lib/features/rpg/ui/character_sheet_screen.dart`
- `lib/features/rpg/ui/titles_screen.dart`
- `lib/features/auth/ui/onboarding_screen.dart`
- `lib/features/routines/ui/routine_list_screen.dart`
- Widget tests under `test/widget/...`
- `BUGS.md` (mark BUG-021..029 RESOLVED)

### Verification

- [ ] `make ci` green (format + analyze + test + android-debug-build)
- [ ] ARB completeness test passes
- [ ] BUGS.md updated with ✅ RESOLVED tags for BUG-021..029
- [ ] Branch pushed; do NOT open PR (orchestrator opens it)

---

## Wave 2 / Cluster 2 — Unsafe casts in repository layer (`fix/cluster2-unsafe-casts`)

Per `BUGS.md` BUG-010: replace `as T` casts at four untrusted Supabase/state.extra
boundaries with typed exceptions. Prevents cryptic Dart cast errors from leaking
to users / Sentry without context. Dart-only PR — no schema or migration changes.

### Scope

- [x] Add `lib/core/data/json_helpers.dart` with `requireField<T>`, `optionalField<T>`,
      `requireInt`, `requireDouble`, `requireDateTime`, `optionalDateTime`. All
      throw `DatabaseException` (code: `json_missing_field`, `json_wrong_type`,
      `json_bad_timestamp`).
- [x] `lib/features/personal_records/data/pr_repository.dart:267` — `setRows.map<String>((r) => r['id'] as String)` → `requireField<String>(r, 'id')`.
- [x] `lib/features/rpg/data/rpg_repository.dart` — `CharacterState.fromJson` (5 casts) and `BackfillProgress.fromJson` (7 casts) routed through helpers.
- [x] `lib/features/rpg/data/titles_repository.dart` — `EarnedTitleRow.fromJson` (4 casts) + `getActiveTitleSlug` row cast routed through helpers.
- [x] `lib/core/router/app_router.dart` — `/pr-celebration` GoRoute extras now flow through new top-level `PrCelebrationArgs.fromExtra(extra)` (throws `StateError` naming the bad field) + `validatePrCelebrationExtra` redirect gate (returns false → `/home`).
- [x] `analysis_options.yaml` — enable `avoid_dynamic_calls` lint to catch future regressions at compile time.

### Tests

- [x] `test/unit/core/data/json_helpers_test.dart` — full coverage of all 6 helpers (valid, missing, null, wrong type, malformed timestamp).
- [x] `test/unit/features/personal_records/data/pr_repository_test.dart` — added BUG-010 regression test (sets row missing `id`).
- [x] `test/unit/features/rpg/data/rpg_repository_test.dart` (NEW) — `CharacterState.fromJson` + `BackfillProgress.fromJson` exception cases.
- [x] `test/unit/features/rpg/data/titles_repository_test.dart` — added `EarnedTitleRow.fromJson` group with 8 cases.
- [x] `test/unit/core/router/pr_celebration_args_test.dart` (NEW) — pins both the redirect-gate validator and the builder fallback factory.

### CI gate fixes encountered

- `avoid_dynamic_calls` flagged 19 violations in test files. Fixed `rank_curve_test.dart` properly with typed intermediate maps; suppressed in 3 integration tests with `// ignore_for_file: avoid_dynamic_calls` and rationale (RPG test fixtures form a dynamic Map cycle by design).
- Pre-existing `FakePRFilterBuilder.then<S>` in `pr_repository_test.dart` used `Future.value(onValue(data))` which calls the post-await continuation synchronously. The new BUG-010 sync throw in the body exposed this — the throw escaped past `throwsA`/`try-catch` and leaked to the zone error handler. Fixed the fake to forward through `Future<T>.value(data).then(onValue, onError: onError)` so post-await throws become proper future rejections.

### Verification

- [x] `dart format .` clean.
- [x] `dart analyze --fatal-infos` clean (`No issues found!`).
- [x] `flutter test --exclude-tags integration` — 2187/2187 pass.
- [x] `flutter build apk --debug --no-shrink` — green.

### Next steps

- [ ] Mark BUG-010 RESOLVED in `BUGS.md` with branch reference.
- [ ] Commit `fix(core): Cluster 2 — repository unsafe-cast audit (BUG-010)`.
- [ ] `git push -u origin fix/cluster2-unsafe-casts` (no PR open — orchestrator handles).

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

