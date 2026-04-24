# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 17.0a — Pixel-Chrome Cleanup (2026-04-23)

**Branch:** `feature/phase17.0a-pixel-chrome-cleanup`
**Source:** ui-ux-critic SHIP verdict on PR #101 flagged three items as out-of-scope for 17.0 but required before 17a.
**Dependency:** §17.0 (DONE, PR #101) — palette + `PixelImage` ready to consume.
**Unblocks:** §17a (Celebration Overlay) and §17b visual polish; shipping as its own small PR keeps 17a's scope pure to celebration UX.

### Pre-implementation review (2026-04-23)

- **product-owner verdict:** Full radii=0 sweep. No chamfer compromise on cards/buttons/inputs/FABs. The retention risk is half-measures ("looks like a theme job that wasn't finished"), not commitment. Apply without apology.
- **ui-ux-critic verdict:**
  - Banner: use `assets/pixel/equipment/dumbbell.png`, NOT `exercises_active.png` — latter collides with nav state (same asset rendered twice when user is on Exercises tab).
  - Chevron: Text '›' styled with `pixelLabel` wins over CustomPainter at small sizes (painter anti-aliases into mud without integer-scale pipeline).
  - Empty state split: `empty_tavern.png` for pristine "no exercises yet"; `quest_marker.png` for filtered "no search matches" (locked.png would imply gated content — wrong semantic).
  - Add `BottomSheetThemeData` + `SnackBarThemeData` to the sweep — Material defaults (4px SnackBar, floating-pill sheet) would leak through otherwise. 2px chamfer for these two ONLY; rest is 0.

### Acceptance checklist

- [ ] **`_ActiveWorkoutBanner`** (`lib/core/router/app_router.dart:386,411`):
  - Replace `Icon(Icons.fitness_center, size: 20)` with `PixelImage('assets/pixel/equipment/dumbbell.png', size: 20)` (nearest-neighbor; no nav collision)
  - Replace `Icon(Icons.chevron_right, ...)` with `Text('›', style: AppTextStyles.pixelLabel.copyWith(color: theme.colorScheme.onPrimary, fontSize: 16))` — adjust fontSize to match 24px chevron visual weight
- [ ] **`_EmptyState`** (`lib/features/exercises/ui/exercise_list_screen.dart:513`):
  - Replace the 48dp Material icon branching with split pixel assets:
    - `hasFilters == true` → `PixelImage('assets/pixel/micro/quest_marker.png', size: 64)`
    - `hasFilters == false` → `PixelImage('assets/pixel/micro/empty_tavern.png', size: 64)`
  - Keep semantic identifiers (`exercise-list-empty-filtered` / `exercise-list-empty-no-filter`) — E2E depends on them
- [ ] **Theme borderRadius → pixel-sharp** (`lib/core/theme/app_theme.dart` + `lib/core/theme/radii.dart`):
  - `kRadiusSm/Md/Lg/Xl` in `radii.dart` → all `0.0` (auto-propagates to ~40 call sites across profile, weekly_plan, home, personal_records, shared/widgets)
  - Inline `BorderRadius.circular(16)` in `_cardTheme` → `BorderRadius.zero`
  - Inline `BorderRadius.circular(12)` in `_elevatedButtonTheme` → `BorderRadius.zero`
  - 4× inline `BorderRadius.circular(12)` in `_inputDecorationTheme` → `BorderRadius.zero`
  - Add `floatingActionButtonTheme: const FloatingActionButtonThemeData(shape: RoundedRectangleBorder())` to force square FABs
  - **NEW per UI/UX review:** Add `bottomSheetTheme: BottomSheetThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(2))))` — 2px chamfer on top corners only
  - **NEW per UI/UX review:** Add `snackBarTheme: SnackBarThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)))` — 2px chamfer so SnackBar reads as floating element, not status-bar overlay
- [ ] Widget/unit tests green — any golden tests that asserted rounded radii need re-baselining
- [ ] E2E unaffected — no selector/text changes, visual-only change per CLAUDE.md convention
- [ ] Manual smoke in Chrome: scan Home/Exercises/Routines/Profile — all cards/buttons/inputs pixel-sharp; SnackBar + modal sheet have 2px chamfer; no stray roundness elsewhere

### Out of scope (tracked, not in this PR)

- [ ] **Asset regen** — `exercises_inactive.png` white halo, `cardio` muscle icon (full-gold outlier), `rank_up` crown collision, streak_7/first_pr sparkles. These are PNG-retouch/regen tasks for the asset pipeline and need a designer or asset-regen prompt — NOT code. File separate tracking note after this PR lands.

### Verification gate (before PR)

- `make ci` → format + gen + analyze + test + android-debug-build (all pass)
- Manual: `flutter run -d chrome` → visit every tab, confirm no rounded corners, confirm banner + empty state render correctly

### Pipeline

1. product-owner — check that pixel-sharp across the entire app doesn't hurt readability/trust for non-pixel-curious users; 1-paragraph verdict (read-only, parallel)
2. ui-ux-critic — verify the chosen replacements hit the pixel aesthetic; flag anything else they want bundled into this sweep (read-only, parallel)
3. tech-lead — implement the 3 items + radii audit; re-run `make ci`; open PR (foreground, Opus)
4. Verification gate + manual smoke
5. Open PR → reviewer → ship

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
