# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 17.0 — Visual Language Foundation (2026-04-22)

**Branch:** `feature/step17.0-visual-language-foundation`
**Source spec:** PLAN.md → Phase 17 → 17.0 Visual Language Foundation.
**Why now:** Every later sub-phase (celebration overlay, character sheet, recap card) paints on this surface. Must land before any game logic.

### Current state (2026-04-23, paused mid-asset-generation)

**Direction:** Approach A — full pixel-art visual system (not the radial-gradient + Roboto plan described below). Detailed brief with §0 Decision Log + §1–§7 per-asset prompts lives at `tasks/mockups/chatgpt-pixel-art-prompt.md` — **that doc is the source of truth** for everything asset-related. Resume here by re-opening it.

**Asset progress: 63 / 71 PNGs saved** into `assets/pixel/`.
(Total raised from 57 → 71 on 2026-04-23 after adding §4.12 Exercise category icons — 14 new sprites across 2 sheets. Both sheets landed 2026-04-23 — muscle (4×2) + equipment (4×2).)

- **Branding (2/2):** app icon + wordmark — done.
- **Navigation (10/10):** all 5 active + 5 inactive with aura-family lock — done.
- **Ranks (7/7):** v2 sheet, family-locked silhouette — done.
- **Milestones (6/6):** first_workout v3, streak_7, first_pr, rank_up v1, 100_workouts, quest_streak — all done.
  - **rank_up flagged for regen** — crown collides with Gold rank glyph + 12 purple diamond sparkles violate milestone convention. §4.5.4 prompt rewritten around gold upward chevron rising from chest.
  - streak_7 + first_pr missing 2–3 gold corner sparkles; low-priority regen.
  - 100_workouts + quest_streak landed with 4 sparkles each (vs tightened 3-rule); matched pair, low-priority regen.
- **Stats (6/6):** strength, endurance, power, consistency, volume, mobility — all split from a 3×2 black-bg sheet via connected-component despeckle (BFS flood-fill). Volume flagged for possible regen (weak plate glyph).
- **Quests (3/3):** consistency, improvement, exploration — split from 1×3 white-bg sheet, 1-px purple sub-outline family-locked.
- **Celebration (4/4):** level_up (iron knight + sword + purple lightning), pr (open gold chest + rays + coins), comeback (gold heater shield + "2×" + purple mist), milestone (gold crown on purple pillow + sunburst rays) — all done.
- **Micro (8/8):** hp_heart, xp_crystal, streak_glyph, locked, check, quest_marker, coin (with "R" brand mark), empty_tavern — all split from a 2×4 white-bg sheet. streak_glyph and quest_marker intentionally echo celebration/comeback and milestones/quest_streak at smaller scale (cross-scale vocabulary, not drift).
- **Story (3/3):** empty_gym (training hall) + your_saga_begins (hooded adventurer + gold title) + first_workout (spotlit dumbbell on stone pedestal). Family lock holds.
- **Muscle (7/7):** chest, back, legs, shoulders, arms, core, cardio — split from a 4×2 white-bg sheet. Family-lock holds (iron-grey body + gold target glow + purple sub-outline). "back" flagged as low-priority regen (front-view silhouette with gold V-diamond — defensible via lat-taper metaphor but ambiguous).
- **Equipment (7/7):** barbell, dumbbell, cable, machine, bodyweight, bands, kettlebell — split from a 4×2 white-bg sheet via per-row column detection (barbell's long bar confused whole-sheet gap detection; per-row scan with min_gap=25 worked). Family-lock holds (iron-grey base + gold accents + purple sub-outline, bodyweight is the only all-gold sprite).
- **Not started:** §4.11 panel frame (1 optional — can skip if Flutter Container decoration covers it).

**§4.12 family-lock (new, locked 2026-04-23):**
1. 1-px `#8A3DC1` purple sub-outline + 1-px black outer outline (quest filterable convention).
2. Muscle sprites = iron-grey body silhouette with gold+hot-core highlight on targeted region.
3. Equipment sprites = iron-grey base + gold accents (loads/handles/pins).
4. Bodyweight is the only all-gold sprite in the equipment sheet (hero silhouette).
5. 32×32 native, 256×256 output, bodyweight-target icons readable at list-row scale.

**Decisions locked in §0 of the brief** (every per-asset prompt already reflects these — safe to regen any asset in isolation):

1. Nav-active aura family: 2-px `#B36DFF` aura + 1-px `#6A2FA8` halo + 4 corner sparkles + 1 interior gold highlight.
2. Ranks share one silhouette; only fill/glyph/banner differ. Rookie=pictorial practice sword; Iron=iron-dumbbell (not pickaxe); Iron fill=`#4A4560` true iron grey.
3. Milestones backdrop-free (no cones, no washes).
4. Milestone sparkles: exactly 3 gold 4-pointed, ≤6 px, outer corners only. No purple, no diamond-shaped.
5. No cross-grid glyph collisions between milestones and rank badges (crown/sword/hammer/gem/star all reserved).
6. Celebration family lock (§4.8 intro): hero sprite 2/3 vertical, radiating motif (rays/bolts/mist/sparkles), per-moment hero color (not always purple — gold for PR, iron+purple for level-up, purple for comeback), `#FFF1B8` peak sparkle, full black outline.

**Pipeline scripts (Python + Pillow, already used):** corner-sampling bg detection → bbox or gap-based column split → `is_light_neutral()` transparency strip (preserves saturated cream/gold at any brightness) → nearest-neighbor `fit_square()`. Connected-component BFS flood-fill for despeckle when source has scan-line noise. Prepend `PYTHONIOENCODING=utf-8` on Windows to avoid cp1252 errors with arrow chars.

**Next actions when resuming:**

1. Work through §4.9 micro (8), §4.10 story (3), §4.11 panel frame (1 optional).
2. After all PNGs land, rewrite PLAN.md 17.0 to pixel-art direction (replace §4 spec below): `pixel_theme.dart` with palette tokens + Press-Start-2P loader, `PixelImage` widget (FilterQuality.none baked in), `pixel_panel.dart` bordered container, nav migration, splash wordmark swap.
3. Dispatch tech-lead for the Flutter implementation.

**Status: READY TO OPEN PR** (2026-04-23). All Sections A–E done, all tests pass, `make ci` green.

### A. Design tokens (`lib/core/theme/app_theme.dart`) — done

- [x] `AppColors` with 20 locked palette tokens (deepVoid, duskPurple, stoneViolet, arcaneIndigo, arcanePurple, glowLavender, ironGrey, stoneGrey, emberShadow, bronzeShadow, oldGold, questGold, hotGold, creamLight, parchment, emeraldGreen, skyBlue, iceBlue, hazardRed, pureWhite)
- [x] Theme roles remapped (primary→arcanePurple, surface→duskPurple, background→deepVoid, card→stoneViolet, error→hazardRed, prBadge→hotGold). `AppTheme.primaryGradient`/`destructiveGradient`/`prBadgeColor` public API preserved
- [x] Press-Start-2P Regular TTF + OFL.txt dropped into `assets/fonts/press_start_2p/`
- [x] Press-Start-2P registered in `pubspec.yaml` fonts section
- [x] `AppTextStyles.pixelHero` (32pt, h1.0, ls0) + `AppTextStyles.pixelLabel` (10pt, h1.0, ls0) added

### B. Widget primitives (`lib/shared/widgets/`) — done

- [x] `pixel_image.dart` — required `semanticLabel`, optional `width/height/color`, bakes `filterQuality: FilterQuality.none` + `fit: BoxFit.contain`. Empty `semanticLabel` → `excludeFromSemantics=true` (decorative)
- [x] `pixel_panel.dart` — nested DecoratedBox (1-px black outer + 1-px arcanePurple inner, no rounded corners) + `PixelPanelFill` enum (deepVoid | duskPurple) + padding

### C. Asset registration + exercise-model migration — done

- [x] `pubspec.yaml` — 11 `assets/pixel/**` folders registered (branding, nav, ranks, milestones, stats, quests, celebration, micro, story, muscle, equipment) + fonts folder
- [x] `MuscleGroup`/`EquipmentType` enums: `IconData get icon` removed → `String get iconPath` returning `assets/pixel/muscle/<name>.png` / `assets/pixel/equipment/<name>.png`
- [x] `package:flutter/material.dart` import dropped from `exercise.dart`
- [x] All call sites migrated: `exercise_list_screen.dart`, `create_exercise_screen.dart`, `exercise_detail_screen.dart`, `active_workout_screen.dart`. `ExerciseImage` network-fallback icon stays Material (scope line held)

### D. Three user-visible surface swaps — done

- [x] Splash wordmark: `PixelImage('assets/pixel/branding/repsaga_wordmark.png', width: 256)` on AppColors.deepVoid, progress indicator → glowLavender
- [x] Bottom nav (4 tabs — home/exercises/routines/profile): active/inactive pixel icons via `_PixelNavIcon` helper (48dp). Label text unchanged
- [x] Exercise list rows: 24dp muscle + equipment pixel icons
- [x] Exercise filter chips (muscle meta-buttons + equipment FilterChip): pixel icons at 20–24dp leading
- [x] Create-exercise selectable grids: `iconFor` → `iconPathFor` string, rendered via PixelImage

### E. Lint + existing violations — done

- [x] `scripts/check_hardcoded_colors.sh` — bash, greps `lib/features/` for `Color(0x…)` literals, supports `// ignore: hardcoded_color` opt-out, exits 1 on unapproved hits
- [x] Wired into Makefile `analyze` target (runs after `dart analyze`)
- [x] `routine_chip.dart` — `_doneColor` → AppColors.emeraldGreen, `_cardColor` → AppColors.stoneViolet
- [x] `week_review_section.dart` — `_primaryGreen` → AppColors.emeraldGreen
- [x] Existing routine_chip widget tests updated for palette tokens (3 assertions: done-check color, done-border color, next-state Material fill)

### Tests — done

- [x] `test/unit/core/theme/palette_tokens_test.dart` — 20 palette tokens + pixelHero/pixelLabel exact specs
- [x] `test/widget/shared/widgets/pixel_image_test.dart` — FilterQuality.none forward, semanticLabel propagation, empty-label excludeFromSemantics, width/height/color forwarding
- [x] `test/widget/shared/widgets/pixel_panel_test.dart` — double-border structure + both fill variants + child render
- [x] `test/widget/features/exercises/exercise_list_pixel_icon_test.dart` — all 7 MuscleGroup + 7 EquipmentType enum values → valid asset paths

### Verification gate — passed

- [x] `dart format .` — clean
- [x] `dart analyze --fatal-infos` — No issues found
- [x] `bash scripts/check_hardcoded_colors.sh` — clean (0 hits under lib/features/)
- [x] `flutter test` — **1465 / 1465 passed**
- [x] `flutter build apk --debug --no-shrink` — built

### Explicit deferrals (NOT touched — per PLAN.md scope line)

- Nav active-tab aura animation → polish follow-up
- 37 other pixel assets (ranks, milestones, stats, quests, celebration, micro, story) → registered in pubspec, NOT wired to UI (17a/b/c/d/e/18 will consume them)
- Active-logger typography rework → 17a
- xp/streak/milestone tables or providers → 17b+
- `ExerciseImage` network-fallback icon → stays Material (network-failure state only, not user-visible pixel art)

### ui-ux-critic follow-ups (SHIP verdict, tracked for 17a — 2026-04-23)

Critic flagged three "IMPORTANT" items as out-of-17.0-scope but required before / during 17a. Do NOT fix in this branch; they are tracked as task #5 and must be addressed before 17a ships:

1. **`_ActiveWorkoutBanner` Material icons** — `lib/core/router/app_router.dart` uses `Icons.fitness_center` + `Icons.chevron_right` in the banner that sits inside the shell on every screen during an active workout. Swap `fitness_center` to `assets/pixel/nav/exercises_active.png` via `PixelImage`; chevron → text glyph or small custom pixel arrow.
2. **`_EmptyState` Material icons** — `lib/features/exercises/ui/exercise_list_screen.dart` renders `Icons.search_off_rounded` + `Icons.fitness_center` at 48dp on the empty exercises list (first-launch experience). Replace with `assets/pixel/micro/empty_tavern.png` (already on disk) or similar micro asset for the search-fail state.
3. **Rounded corners contradict pixel aesthetic (theme-wide)** — `_cardTheme` uses `borderRadius: 16`, buttons 12, `FilterChip` 8, `_inputDecorationTheme` rounded. Set to `BorderRadius.zero` (or max 2px chamfer). Systemic change — explicitly a 17a backlog item, not someday-maybe.

Two additional outlier notes from the critic:
- `exercises_inactive.png` has a visible white halo (not transparent BG) — needs an asset regen or transparency pass.
- `cardio` muscle icon is full-gold while siblings are iron-grey + gold-highlight. Defensible (no anatomical target for cardio) but an outlier; not regen-worth.

Regen-candidate verdicts:
- **rank_up crown collision** → must fix before 17d (not 17.0 blocker).
- streak_7 / first_pr missing sparkles → fix-later.
- 100_workouts / quest_streak 4-sparkle count → not worth regen (within visual noise).
- volume plate glyph → fix when 18b wires it.
- muscle/back front-view → acceptable (lat-taper reads), defer.

### Key architectural decisions

1. **PixelImage is the chokepoint.** `FilterQuality.none` is baked in, not optional — future devs cannot accidentally bilinear-blur a pixel asset by forgetting the flag. Single source of truth for the pixel-art rule.
2. **`_PixelNavIcon` is a private helper in `app_router.dart`**, not a shared widget — nav is the only place that needs separate active/inactive asset pairs.
3. **PixelPanel uses nested `DecoratedBox`** instead of `Container` with `BoxDecoration` + `borderRadius` — preserves hard pixel edges (no rounded corners), satisfies the "double-border" visual spec exactly.
4. **`_MuscleGroupButton` takes `Widget icon`** (not `IconData`) so the "All" meta-button can stay on a Material `Icons.apps` while muscle groups use `PixelImage`. Keeps the one heterogeneous row from becoming two separate widget types.
5. **Hardcoded-color lint is bash, not a custom_lint plugin** — zero-dep, instant feedback, works in CI + pre-commit without any Dart analyzer plumbing. Supports per-line opt-out for legitimate branding colors (none needed today).

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
