# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 17.0d — Arcane Ascent Polish Sprint (IN PROGRESS 2026-04-24)

**Branch:** `fix/phase17-0d-ui-polish`
**Source:** ui-ux-critic audit findings + user QA pass on 17.0c build (2026-04-24)

Bundled P0+P1 fix pass to close residual non-Arcane surfaces before starting 17a. Zero navigation flow change → visual-only per CLAUDE.md E2E rules (selector impact assessment, skip full suite run).

### Fixes

**P0 — ship-blockers**

- [ ] **Weekly bucket color fix** — `lib/features/weekly_plan/ui/widgets/routine_chip.dart:45,73`. Introduce two constants: `_nextColor = AppColors.primaryViolet` (solid CTA fill for up-next chip), `_doneAccent = AppColors.success` (tint + border + checkmark for done chip only). `_buildNext` uses `_nextColor`; `_buildDone` uses `_doneAccent`. Update enum docstring at line 9. Keep sequence-badge `abyss@0.26` overlay + `abyss` text on the violet fill (contrast verified).

- [ ] **PR celebration gold flash** — `lib/features/personal_records/ui/pr_celebration_screen.dart:230`. Replace `theme.colorScheme.primary` with `RewardAccent.color`. Remove the `TODO(phase17a)` comment at line 222 since this closes it. The `check_reward_accent.sh` lint allows `RewardAccent.color` static reads.

- [ ] **Custom muscle + equipment SVG icon set** — replaces 14 raw Material icons.
  - Create `lib/core/theme/app_muscle_icons.dart` — class `AppMuscleIcons` with 7 static SVG constants following `AppIcons` conventions (48×48 viewBox, `currentColor`, stroke-2.4, monoline). Shape specs below.
  - Create `lib/core/theme/app_equipment_icons.dart` — class `AppEquipmentIcons` with 6 new SVG constants (barbell reuses `AppIcons.lift`).
  - Refactor `lib/features/exercises/models/exercise.dart`: replace `MuscleGroup.icon` (IconData) and `EquipmentType.icon` (IconData) with `String get svgIcon` returning the new constants.
  - Update 4 call sites — replace `Icon(group.icon, size: X)` with `AppIcons.render(group.svgIcon, size: X, color: ...)`:
    - `lib/features/exercises/ui/exercise_list_screen.dart` (`_MuscleGroupButton` + `_InfoChip`)
    - `lib/features/exercises/ui/exercise_detail_screen.dart` (`_DetailChip`)
    - `lib/features/workouts/ui/active_workout_screen.dart` (`_SheetChip`)
    - `lib/features/workouts/ui/widgets/exercise_picker_sheet.dart` (if icon rendered)
  - Register both new files in any widget index if such exists.

- [ ] **Login + onboarding hero = brand sigil** — matches launcher icon from PR #106.
  - `lib/features/auth/ui/login_screen.dart:180-184` — replace `Icon(Icons.fitness_center, size: 48, color: primary)` with `Image.asset('assets/app_icon/arcane_sigil_foreground.png', width: 96, height: 96)` (bump the visual size since it's a colored composite rather than a tintable glyph). Keep the `const SizedBox(height: 16)` below.
  - `lib/features/auth/ui/onboarding_screen.dart:196-200` — replace `Icon(Icons.fitness_center, size: 80, color: primary)` with same asset at `width: 128, height: 128`.
  - Verify asset is already declared in `pubspec.yaml` under `assets:` (PR #106 would have added it).

**P1 — polish**

- [ ] **Workout detail PR trophy** — `lib/features/workouts/ui/workout_detail_screen.dart:317`. Replace `Icon(Icons.emoji_events, size: 18)` inside `RewardAccent` with `AppIcons.render(AppIcons.levelUp, size: 18)`. Color inherits from `IconTheme` via the `RewardAccent` wrapper — no explicit color arg.
- [ ] **Empty states** — replace `Icons.fitness_center` at 64dp with `AppIcons.lift`:
  - `lib/features/exercises/ui/exercise_list_screen.dart:510-514` (also swap `Icons.search_off_rounded` → `AppIcons.search` for the filtered-empty state)
  - `lib/features/workouts/ui/active_workout_screen.dart:634-637`
- [ ] **Active-logger AppBar icons** — `lib/features/workouts/ui/active_workout_screen.dart`:
  - Line 389 `Icons.close` → `AppIcons.render(AppIcons.close, size: 24)`
  - Line 432 `Icons.edit` (14dp) → `AppIcons.render(AppIcons.edit, size: 14)`
- [ ] **Week-review "NEW WEEK" link color** — `lib/features/weekly_plan/ui/widgets/week_review_section.dart` — change the `newWeekLink` text color from `_primaryGreen` / `AppColors.success` to `AppColors.hotViolet` (navigation CTA, not completion signal). Keep "WEEK COMPLETE" header green.
- [ ] **Router offline placeholder** — `lib/core/router/app_router.dart:383` `Icons.fitness_center` → `AppIcons.lift`.
- [ ] **PR type icons** (lower-priority duplicated code path) — `lib/features/exercises/ui/exercise_detail_screen.dart:401-403` + `lib/features/workouts/ui/active_workout_screen.dart:1361-1363`: map `RecordType.maxWeight` to `AppIcons.lift`. Leave `maxReps` (`Icons.repeat`) and `maxVolume` (`Icons.bar_chart`) as Material — no AppIcons equivalent yet; flag in a `TODO` for a future icon-set pass.

### Muscle icon shape specs (per ui-ux-critic)

All 48×48 viewBox, stroke `currentColor`, stroke-width 2.4 monoline unless noted.

- **chest** — pectoral arch: two mirrored convex curves meeting at sternum centerline; left arc rises center-bottom→shoulder→clavicle notch, right mirrors. No arm, no head. Parentheses-meeting-at-top silhouette.
- **back** — trapezius V: wide inverted trapezoid. Diagonals from shoulder points (x:8,y:10 / x:40,y:10) converge to waist (x:24,y:36). Horizontal shoulder-bar. Short vertical from shoulder-bar center to cervical notch (x:24,y:6).
- **legs** — quad sweep: two teardrop columns (x:14→22 / x:26→34, y:10→38), slightly angled outward at base. No knee, no foot.
- **shoulders** — deltoid arc: arc from x:8,y:24 over top (x:24,y:8) to x:40,y:24; short descending lines from each endpoint to y:34 anchor.
- **arms** — biceps curl (user callout): shoulder circle at (x:12,y:10) r:4; upper arm line (x:16,y:10)→(x:20,y:28); forearm angled up-right (x:20,y:28)→(x:32,y:18). No bone outline. Riff off `AppIcons.hero` arm geometry minus humerus internal line.
- **core** — ab grid 2×3: horizontals at y:16/24/32, vertical from y:10→38, bounded x:16→32. Inner grid stroke 2.0 (lighter than frame).
- **cardio** — ECG trace: flat from x:4,y:24, narrow spike (x:16,24 → x:20,10 → x:24,36 → x:28,18 → x:32,24), flat to x:44,y:24.

### Equipment icon shape specs

- **barbell** — reuse `AppIcons.lift`. No new constant.
- **dumbbell** — side view: horizontal shaft (x:10,24 → x:38,24); ONE plate each side (left: rect x:6,y:18 w:6 h:12; right: rect x:36,y:18 w:6 h:12). One plate distinguishes from `AppIcons.lift` (which has two asymmetric plates).
- **cable** — pulley circle top-right (cx:36,cy:10,r:5); diagonal cable (x:31,13 → x:12,38); handle-grip rect at bottom-left (x:8,y:36 w:8 h:5 rx:2).
- **machine** — weight stack: 4 thin rects at x:18 (w:12 h:5) at y:10/18/26/34; vertical guide rails at x:16 and x:32 (y:8→40); pin circle (cx:24,cy:22,r:2 filled).
- **bodyweight** — stick figure in "ready" stance (not yoga): head circle (cx:24,cy:9,r:5); torso (x:24,14→24,28); legs (28→16,40 / 28→32,40); arms at 45° (x:24,20→14,14 / 24,20→34,14).
- **bands** — resistance band loop: flat ellipse (cx:24,cy:24,rx:18,ry:10) with two horizontal crease lines inside at y:20 and y:28 (clipped to ellipse).
- **kettlebell** — semicircle handle at top (arc cx:24,cy:12 from x:16,18 over to x:32,18) connecting to rounded trapezoid body (x:16,18 → x:14,34 curved to x:34,34 → x:32,18). Wider at bottom.

### Tests

- [ ] **Widget test per new icon**: `test/widget/core/theme/app_muscle_icons_test.dart` + `app_equipment_icons_test.dart` — render each glyph at 24/48/64 dp with explicit color and with IconTheme fallback. Smoke-check viewBox presence + `currentColor` substring in the raw SVG string.
- [ ] **Widget test routine_chip states**: `test/widget/features/weekly_plan/widgets/routine_chip_test.dart` (update existing if present) — assert `next` renders `primaryViolet` material fill, `done` renders `success` tint + border, `remaining` renders `surface2`. Include contrast-tag (semantic label) if the existing test pattern has one.
- [ ] **Widget test login + onboarding hero**: assert `Image.asset` with path `assets/app_icon/arcane_sigil_foreground.png` at the expected size.
- [ ] **Widget test PR celebration flash**: assert the flash container uses `RewardAccent.color` (`AppColors.heroGold`), not `theme.colorScheme.primary`.
- [ ] **Update stale tests**: any test asserting `Icons.fitness_center` on login/onboarding/empty states or `Icons.emoji_events` on workout detail trophy must swap to the new widgets. Any test asserting `MuscleGroup.icon == IconData` must migrate to `svgIcon` string.

### E2E impact

Visual-only migration per CLAUDE.md rules — no navigation flow change, no route restructuring, no provider/repository logic touched. Selector impact assessment only. `helpers/selectors.ts` should need no changes (role=name strings unchanged; icons are not accessible-named). Skip full suite run; confirm smoke tag (`--grep @smoke`) still passes locally after the build.

### Files — create

- `lib/core/theme/app_muscle_icons.dart`
- `lib/core/theme/app_equipment_icons.dart`
- `test/widget/core/theme/app_muscle_icons_test.dart`
- `test/widget/core/theme/app_equipment_icons_test.dart`

### Files — modify

- `lib/features/weekly_plan/ui/widgets/routine_chip.dart`
- `lib/features/weekly_plan/ui/widgets/week_review_section.dart`
- `lib/features/personal_records/ui/pr_celebration_screen.dart`
- `lib/features/exercises/models/exercise.dart` (enum icon getters)
- `lib/features/exercises/ui/exercise_list_screen.dart`
- `lib/features/exercises/ui/exercise_detail_screen.dart`
- `lib/features/workouts/ui/active_workout_screen.dart`
- `lib/features/workouts/ui/workout_detail_screen.dart`
- `lib/features/workouts/ui/widgets/exercise_picker_sheet.dart` (if icon rendered)
- `lib/features/auth/ui/login_screen.dart`
- `lib/features/auth/ui/onboarding_screen.dart`
- `lib/core/router/app_router.dart` (offline placeholder icon)
- Any existing tests touching replaced icons

### Acceptance

- Home screen: up-next bucket chip is solid violet, not green. Done bucket chip is green-tinted outline-checkmark. No green CTA anywhere.
- PR celebration screen: flash fires gold (`#FFB800`), not violet, on every PR-triggering workout save.
- Exercise list muscle-group tiles render Arcane monoline SVG glyphs (no Material icons visible).
- Login + onboarding show the brand sigil (matches the phone launcher icon), no dumbbell.
- Workout detail row trophies render `AppIcons.levelUp` star in gold via `RewardAccent`.
- `make ci` green locally. E2E smoke (`--grep @smoke`) green.
- `scripts/check_reward_accent.sh` still clean (no new `heroGold` leaks outside `RewardAccent.color` static read at PR flash).

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
