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

- [ ] `rm -rf assets/pixel/` (63 PNGs, 11 folders)
- [ ] `rm -rf assets/fonts/press_start_2p/`
- [ ] Delete `lib/shared/widgets/pixel_image.dart`, `pixel_panel.dart` + their tests under `test/widget/shared/`
- [ ] Remove pubspec.yaml pixel asset directives (`assets/pixel/**`) and PressStart2P font block
- [ ] Strip `AppTextStyles.pixelHero`, `pixelLabel`, `pixelNumeric` from `lib/core/theme/app_theme.dart`
- [ ] Strip pixel-specific `AppColors` tokens (deepVoid, arcanePurple, hotGold, parchmentCream, ironGrey, leafGreen, hazardRed, etc.). Rename `hotGold` → `heroGold` if retained; otherwise delete.
- [ ] Revert `MuscleGroup.iconPath` / `EquipmentType.iconPath` → `IconData` (Material icons) in `lib/features/exercises/models/exercise.dart`
- [ ] Update `scripts/check_hardcoded_colors.sh` allowlist to Arcane palette tokens
- [ ] Delete obsolete mockup artifacts: `tasks/mockups/chatgpt-pixel-art-prompt.md`, `audit_assets.py`, `crop_to_main_blob.py`, `asset_audit_report.json`

**Stage 2 — Arcane theme foundation**

- [ ] Add `google_fonts: ^6.2.0` to `pubspec.yaml`
- [ ] Rewrite `AppColors` with Arcane palette — each token has dartdoc; `heroGold` explicitly marked "use only via RewardAccent"
- [ ] Rewrite `AppTextStyles`: `display`, `headline`, `title`, `body`, `bodySmall`, `label`, `numeric` via `GoogleFonts.rajdhani(...)` / `GoogleFonts.inter(...)`
- [ ] Rewrite `AppTheme.dark()`:
  - `ColorScheme.fromSeed(seedColor: primaryViolet, brightness: dark, primary: primaryViolet, secondary: hotViolet, surface: surface, onSurface: textCream)`
  - Restore sensible radii (cards 12, buttons 10, inputs 10). Undo pixel-sharp 0.
  - Restore bottomSheetTheme / snackBarTheme / floatingActionButtonTheme to Material-normal
  - `appBarTheme`, `cardTheme`, `elevatedButtonTheme`, `outlinedButtonTheme`, `inputDecorationTheme` pick up new palette + typography
- [ ] `lib/core/theme/radii.dart` → restore meaningful values (sm 4, md 8, lg 12, xl 16)
- [ ] Update/create `lib/core/theme/README.md` documenting reward-scarcity rule

**Stage 3 — Icon system**

- [ ] Create `lib/core/theme/app_icons.dart` — static class with SVG-string constants
- [ ] Icons: `home, lift, plan, stats, hero, xp, levelUp, streak, check, add, edit, delete, filter, search, settings, play, pause, resume, finish, close`
- [ ] **Lift icon:** side-view barbell — 2px horizontal bar, asymmetric rectangle plates (taller-inner, shorter-outer). Monoline stroke default; filled variant for active nav.
- [ ] Each accessor returns `SvgPicture.string` with `color` + `size` params (uses existing `flutter_svg` dep)
- [ ] Test: `test/unit/core/theme/app_icons_test.dart` — each icon renders at 24/40/64

**Stage 4 — Reward scarcity enforcement**

- [ ] Create `lib/shared/widgets/reward_accent.dart` — `RewardAccent({required Widget child})`; only widget referencing `AppColors.heroGold`
- [ ] Create `scripts/check_reward_accent.sh` — greps `heroGold|0xFFFFB800|0xFFFFC107|0xFFFFD54F` outside `reward_accent.dart` + theme token file. Exits 1 on violation.
- [ ] Wire into `Makefile` `analyze` target
- [ ] Test: `test/widget/shared/reward_accent_test.dart`

**Stage 5 — Migration (every pixel-bound surface)**

- [ ] `_ActiveWorkoutBanner` (`lib/core/router/app_router.dart`) → Material `Icon(Icons.fitness_center_rounded)` + `Icon(Icons.chevron_right)` with Arcane theme
- [ ] `lib/features/auth/ui/splash_screen.dart` → Rajdhani "REPSAGA" wordmark + new app icon (placeholder `AppIcons.hero` at 96px until icon lands)
- [ ] `_EmptyState` in `exercise_list_screen.dart` → `Icons.search_off_rounded` (filtered) / `Icons.fitness_center_rounded` (pristine) at 64dp `textDim`
- [ ] `_LvlBadge` in `home_screen.dart` → `AppTextStyles.label.copyWith(color: AppColors.hotViolet)`. No RewardAccent wrapping yet (17e adds the gain animation)
- [ ] `lib/features/gamification/ui/saga_intro_overlay.dart` (3 screens) → reskin: Material surfaces, `AppTextStyles.headline`, `AppIcons.hero/lift/xp` @ 80px. Keep 3-screen flow + dismiss button + Hive gate logic untouched.
- [ ] Nav tabs in `app_router.dart` → `AppIcons.home/lift/plan/stats/hero` (monoline idle / filled active)
- [ ] Every `Image.asset('assets/pixel/...')` and `PixelImage(...)` call site swept

**Stage 6 — App icon (orchestrator parallel; user pick)**

- [ ] Write `tasks/mockups/app-icon-prompt-arcane.md` — single ChatGPT prompt. Includes: 1024² target, abyss `#0D0319` flat background plate, violet→gold sigil motif (hooded silhouette or ascending arcane sigil), safe-zone 68%, 3-variant request, explicit anti-pixel-art language, Material-compatible
- [ ] User runs prompt, picks winner, drops PNG to `assets/app_icon/arcane_sigil_1024.png` + `arcane_sigil_foreground.png` (transparent fg)
- [ ] Update `flutter_launcher_icons` config in pubspec.yaml to new paths
- [ ] `dart run flutter_launcher_icons` → regen launcher icons
- [ ] Commit generated launcher icons

**Stage 7 — Tests**

- [ ] Delete: `palette_tokens_test.dart`, `pixel_image_test.dart`, `pixel_panel_test.dart`, `exercise_list_pixel_icon_test.dart`
- [ ] Add: `arcane_theme_test.dart`, `app_icons_test.dart`, `reward_accent_test.dart`
- [ ] Update: `saga_intro_overlay_test.dart` for Material widgets
- [ ] Update: any widget test asserting old pixel asset paths or pixel text styles
- [ ] E2E: full suite regression. Nav icon swap + visual-only; selectors unchanged. Update asset-path selectors if any lingered.

### Verification gate (before PR)

- `make ci` green
- `grep -r "assets/pixel" lib/ test/` → zero
- `grep -r "PressStart2P" lib/ test/` → zero
- `grep -rE "heroGold|0xFFFFB800" lib/ --include='*.dart' | grep -v "reward_accent.dart|app_colors.dart|app_theme.dart"` → zero
- `flutter run -d chrome` manual pass: every tab/modal/CTA; zero asset-not-found; heroGold appears only via `RewardAccent`
- E2E full suite green

### Pipeline

1. [x] Close PR #104 (2026-04-23)
2. [x] Create branch + write PLAN.md §17.0c + WIP.md (this commit)
3. `tech-lead` — stages 1→5 in order (foreground, Opus). `make ci` after each stage. Report at stage boundaries.
4. Orchestrator parallel: write `app-icon-prompt-arcane.md`; user gens + picks + drops
5. Orchestrator integrates app icon (stage 6) once user delivers
6. `qa-engineer` — coverage gate + full E2E regression (flow-change territory: nav icons change)
7. `reviewer` — quality pass
8. Verification gate → PR → merge
9. Close WIP section, condense §17.0c in PLAN.md

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
