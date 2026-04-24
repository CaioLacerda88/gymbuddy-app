# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 17.0c — Arcane Ascent Material Migration (2026-04-23)

**Branch:** `feature/phase17.0c-material-migration`
**Source:** PLAN.md §17.0c. Direction B of `tasks/mockups/material-saga-comparison-v2.html` — Arcane Ascent.
**Supersedes:** PR #104 (closed 2026-04-23) + pixel-art visual layer from PR #101.
**Retains:** Phase 17b XP data layer (PR #103) — only `SagaIntroOverlay` reskins.

### Visual direction (locked)

- **Palette:** `abyss #0D0319` → `surface #1A0F2E` → `surface2 #241640` → `primaryViolet #6A2FA8` → `hotViolet #B36DFF` daily → `heroGold #FFB800` **reward-only** → `textCream #EEE7FA`
- **Typography:** Rajdhani 700 display / Inter 400-600 body, via `google_fonts` package. PressStart2P retired. Cinzel/Cormorant rejected.
- **Icons:** inline-SVG `AppIcons` class, ~20 icons. Lift icon = side-view barbell with asymmetric plates (no circles, no dumbbell).
- **Reward scarcity:** `RewardAccent` widget is the ONLY place allowed to emit heroGold. Enforced by `scripts/check_reward_accent.sh` in `make analyze`.

### Acceptance checklist

**Stage 1 — Pixel teardown**

- [x] `rm -rf assets/pixel/` (63 PNGs, 11 folders)
- [x] `rm -rf assets/fonts/press_start_2p/`
- [x] Delete `lib/shared/widgets/pixel_image.dart`, `pixel_panel.dart` + their tests under `test/widget/shared/`
- [x] Remove pubspec.yaml pixel asset directives (`assets/pixel/**`) and PressStart2P font block
- [x] Strip `AppTextStyles.pixelHero`, `pixelLabel`, `pixelNumeric` from `lib/core/theme/app_theme.dart`
- [x] Strip pixel-specific `AppColors` tokens (deepVoid, arcanePurple, hotGold, parchmentCream, ironGrey, leafGreen, hazardRed, etc.). Rename `hotGold` → `heroGold` if retained; otherwise delete.
- [x] Revert `MuscleGroup.iconPath` / `EquipmentType.iconPath` → `IconData` (Material icons) in `lib/features/exercises/models/exercise.dart`
- [x] Update `scripts/check_hardcoded_colors.sh` allowlist to Arcane palette tokens
- [x] Delete obsolete mockup artifacts: `tasks/mockups/chatgpt-pixel-art-prompt.md`, `audit_assets.py`, `crop_to_main_blob.py`, `asset_audit_report.json`

**Stage 2 — Arcane theme foundation**

- [x] Add `google_fonts: ^6.2.0` to `pubspec.yaml`
- [x] Rewrite `AppColors` with Arcane palette — each token has dartdoc; `heroGold` explicitly marked "use only via RewardAccent"
- [x] Rewrite `AppTextStyles`: `display`, `headline`, `title`, `body`, `bodySmall`, `label`, `numeric` via `GoogleFonts.rajdhani(...)` / `GoogleFonts.inter(...)`
- [x] Rewrite `AppTheme.dark()`:
  - `ColorScheme.fromSeed(seedColor: primaryViolet, brightness: dark, primary: primaryViolet, secondary: hotViolet, surface: surface, onSurface: textCream)`
  - Restore sensible radii (cards 12, buttons 10, inputs 10). Undo pixel-sharp 0.
  - Restore bottomSheetTheme / snackBarTheme / floatingActionButtonTheme to Material-normal
  - `appBarTheme`, `cardTheme`, `elevatedButtonTheme`, `outlinedButtonTheme`, `inputDecorationTheme` pick up new palette + typography
- [x] `lib/core/theme/radii.dart` → restore meaningful values (sm 4, md 8, lg 12, xl 16)
- [x] Update/create `lib/core/theme/README.md` documenting reward-scarcity rule

**Stage 3 — Icon system**

- [x] Create `lib/core/theme/app_icons.dart` — static class with SVG-string constants
- [x] Icons: `home, lift, plan, stats, hero, xp, levelUp, streak, check, add, edit, delete, filter, search, settings, play, pause, resume, finish, close`
- [x] **Lift icon:** side-view barbell — 2px horizontal bar, asymmetric rectangle plates (taller-inner, shorter-outer). Monoline stroke default; filled variant for active nav.
- [x] Each accessor returns `SvgPicture.string` with `color` + `size` params (uses existing `flutter_svg` dep)
- [x] Test: `test/unit/core/theme/app_icons_test.dart` — each icon renders at 24/40/64

**Stage 4 — Reward scarcity enforcement**

- [x] Create `lib/shared/widgets/reward_accent.dart` — `RewardAccent({required Widget child})`; only widget referencing `AppColors.heroGold`
- [x] Create `scripts/check_reward_accent.sh` — greps `heroGold|0xFFFFB800|0xFFFFC107|0xFFFFD54F` outside `reward_accent.dart` + theme token file. Exits 1 on violation.
- [x] Wire into `Makefile` `analyze` target
- [x] Test: `test/widget/shared/reward_accent_test.dart`

**Stage 5 — Migration (every pixel-bound surface)**

- [x] `_ActiveWorkoutBanner` (`lib/core/router/app_router.dart`) → Material `Icon(Icons.fitness_center_rounded)` + `Icon(Icons.chevron_right)` with Arcane theme
- [x] `lib/features/auth/ui/splash_screen.dart` → Rajdhani "REPSAGA" wordmark + new app icon (placeholder `AppIcons.hero` at 96px until icon lands)
- [x] `_EmptyState` in `exercise_list_screen.dart` → `Icons.search_off_rounded` (filtered) / `Icons.fitness_center_rounded` (pristine) at 64dp `textDim`
- [x] `_LvlBadge` in `home_screen.dart` → `AppTextStyles.label.copyWith(color: AppColors.hotViolet)`. No RewardAccent wrapping yet (17e adds the gain animation)
- [x] `lib/features/gamification/ui/saga_intro_overlay.dart` (3 screens) → reskin: Material surfaces, `AppTextStyles.headline`, `AppIcons.hero/lift/xp` @ 80px. Keep 3-screen flow + dismiss button + Hive gate logic untouched.
- [x] Nav tabs in `app_router.dart` → `AppIcons.home/lift/plan/stats/hero` (monoline idle / filled active)
- [x] Every `Image.asset('assets/pixel/...')` and `PixelImage(...)` call site swept
- [x] Migrate pre-existing PR reward call-sites (workout_detail trophy, progress chart PR ring) to consume `RewardAccent`/`RewardAccent.color`; remove the `AppTheme.prBadgeColor` transitional alias

**Stage 6 — App icon (user-handled, out of this WIP)**

Deferred to the user per orchestration directive. The text "BEGIN" CTA + splash wordmark already reads as Arcane without a new launcher icon. Flutter_launcher_icons will be re-run when the user drops the PNGs in.

**Stage 7 — Tests**

- [x] Delete: `palette_tokens_test.dart`, `pixel_image_test.dart`, `pixel_panel_test.dart`, `exercise_list_pixel_icon_test.dart` (deleted alongside the pixel widgets in Stage 1)
- [x] Add: `test/unit/core/theme/arcane_theme_test.dart` — 12-token palette lock + Rajdhani/Inter family asserts + M3 scheme checks
- [x] Add: `test/unit/core/theme/app_icons_test.dart` — every icon renders at 24/40/64 dp; srcIn color-filter contract; semanticsLabel forwarding
- [x] Add: `test/widget/shared/reward_accent_test.dart` — IconTheme + DefaultTextStyle inheritance, `RewardAccent.of` + null-parent case, explicit-style override respected
- [x] Update: `saga_intro_overlay_test.dart` — already asserts Material text (NEXT/BEGIN/"LVL N — RANK"), nothing to rewrite
- [x] Update: `lvl_badge_test.dart` header comment — `pixelLabel / hotGold` refs replaced with Arcane rationale
- [x] Bundle Rajdhani + Inter TTFs as assets (`assets/fonts/`) so `google_fonts` finds them in the asset manifest and widget tests don't fire unhandled-future errors from CDN fetch attempts inside `tester.runAsync`
- [x] `flutter test`: 1,656 tests green
- [ ] E2E: full suite regression (orchestrator to run per CLAUDE.md — navigation icon swap is visual-only, selectors unchanged; blocked on Docker/Supabase local being up)

### Verification gate (before PR)

- [x] `dart format .` clean
- [x] `bash scripts/check_reward_accent.sh` — 0 unauthorized references under `lib/`
- [x] `bash scripts/check_hardcoded_colors.sh` — 0 hits under `lib/features/`
- [x] `dart analyze --fatal-infos` — "No issues found!"
- [x] `flutter test` — 1,656 tests green (includes the new arcane_theme/app_icons/reward_accent suites)
- [x] `flutter build apk --debug` — Gradle compile green
- [x] `grep -r "assets/pixel" lib/` → zero (documentation-only refs retained in README / phase-history comments)
- [x] `grep -r "PressStart2P" lib/` → zero
- [x] `grep -rE "heroGold|0xFFFFB800" lib/` outside `app_theme.dart` + `reward_accent.dart` → zero (enforced by `check_reward_accent.sh`)
- [ ] `flutter run -d chrome` manual pass (orchestrator) — every tab/modal/CTA; zero asset-not-found; heroGold appears only via `RewardAccent`
- [ ] E2E full suite (orchestrator; needs local Supabase)

### Pipeline

1. [x] Close PR #104 (2026-04-23)
2. [x] Create branch + write PLAN.md §17.0c + WIP.md (this commit)
3. [x] `tech-lead` — stages 1→5 + stage 7 in order. `dart analyze` / `flutter test` green after each stage.
4. [ ] User generates app icon (stage 6) — out of this WIP
5. [ ] `qa-engineer` — coverage gate + full E2E regression (flow-change territory: nav icons change)
6. [ ] `reviewer` — quality pass
7. [ ] Verification gate → PR → merge
8. [ ] Close WIP section, condense §17.0c in PLAN.md

### Out of scope (explicit)

- Phase 17a celebration overlay — still TODO; its asset refs re-spec at sub-phase start
- Phase 17c/d/e — asset refs re-spec at sub-phase start
- Marketing / store screenshots — separate follow-up
- LVL badge gain animation — lives in 17e

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
