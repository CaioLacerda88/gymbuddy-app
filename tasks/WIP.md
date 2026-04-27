# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 18b — RPG v1: Character Sheet + Rune Sigils UI

**Branch:** `feature/phase18b-character-sheet` (to be created off main @ 57437e7)
**Reference:** PLAN.md Phase 18b (lines 1171-1196), design spec `docs/superpowers/specs/2026-04-25-rpg-system-v1-design.md` §13.1 + §13.4 + §8.4
**Depends on:** 18a (PR #112, merged) — `character_state`, `body_part_progress`, `rpg_progress_provider`

### Decisions locked from product-owner + ui-ux-critic kickoff

- **Nav placement:** Profile tab → "Saga" (rebrand). `/profile` → `CharacterSheetScreen`. Account/settings → sub-screen reachable from a gear icon in the sheet's app bar. Tab icon stays `AppIcons.hero`.
- **Class badge slot:** Always visible. Day-1 copy: **"The iron will name you."** (en) / pt-BR localized. Class derivation logic lands in 18e — stub provider returns `null` and the slot renders the placeholder copy until then. **Do NOT default to "Initiate" (reads as finished state).**
- **Rune halo glow states (§8.4):** Four states must be distinguishable via shape + motion + color, not just intensity:
  - **Dormant:** sigil at 12% opacity, slow 8s rotation, no glow ring.
  - **Fading:** full sigil, desaturated `primaryViolet` ring, breathing pulse 0.6→1.0 spread, period 3s.
  - **Active:** static `hotViolet` ring, two-layer `boxShadow` (no animation — opens between sets, conserves attention).
  - **Radiant:** `heroGold` ring + sigil 10% larger + sweep highlight via `CustomPainter` once per 4-5s + single haptic on first paint.
- **Body-part layout direction:** Direction B+C hybrid. **Hexagonal radar** (CustomPainter, six vertices = body parts, fill opacity ∝ rank) under the avatar as the identity moment. Below the radar, **codex rows** with rune sigil (24dp, Vitality-state colored) + body-part name + rank stamp (Rajdhani 700 in `surface2` circle, border = Vitality color) + hairline XP-progress marker (NOT a filled bar). Six rows in a single column, NOT split.
- **Day-1 vaporware-risk mitigation:** Asymmetric awakening — body parts the user has trained render at full row size; untrained ones collapse to a compressed secondary zone. After first workout, trained parts expand. Day-0 onboarding still reads "first set awakens this path".
- **Nav chips → codex rows:** "Stats deep-dive / Titles / History" rendered as three full-width tappable rows with Rajdhani label + right-chevron, NOT Material `Chip`s. (Targets are 18d, 18c, History — Stats and Titles will be stub-routed for 18b; History exists already via `/history`.)

### Implementation checklist (tech-lead)

- [ ] Branch `feature/phase18b-character-sheet` from main; verify CI green on main first.
- [ ] **Provider:** `lib/features/rpg/providers/character_sheet_provider.dart` — composes `rpg_progress_provider` + `active_title_provider` (stub returning `null` for now) + `class_provider` (stub returning `null`). Returns immutable `CharacterSheetState` with: lvl, lifetime_xp, six body-part progress entries (rank, vitality_state, xp_in_rank, xp_for_next_rank), active_title (nullable), class (nullable).
- [ ] **Models:** `lib/features/rpg/models/character_sheet_state.dart` (Freezed), `vitality_state.dart` (enum + extension mapping 0-100 → Dormant/Fading/Active/Radiant per §8.4 thresholds).
- [ ] **Widgets (in dependency order):**
  - [ ] `widgets/rune_halo.dart` — 4 glow states, AnimationController per state, lightweight (no Lottie). Single `BoxDecoration` + optional `CustomPainter` for Radiant sweep.
  - [ ] `widgets/vitality_radar.dart` — hexagonal `CustomPainter`, 6 vertices, fill opacity ∝ rank/99. Day-0 = perfect minimum hexagon (looks intentional, not empty).
  - [ ] `widgets/rank_stamp.dart` — circular badge, Rajdhani 700, border in Vitality color.
  - [ ] `widgets/xp_progress_hairline.dart` — 1px line + dot marker at xp_in_rank/xp_for_next_rank.
  - [ ] `widgets/body_part_rank_row.dart` — composes rune sigil + name + rank stamp + hairline. Untrained variant = compressed height.
  - [ ] `widgets/dormant_cardio_row.dart` — separate widget, distinct "coming in v2" treatment.
  - [ ] `widgets/active_title_pill.dart` — reads from provider, hides when null.
  - [ ] `widgets/class_badge.dart` — slot always rendered; day-1 placeholder copy "The iron will name you." (en) + pt-BR.
  - [ ] `widgets/codex_nav_row.dart` — full-width tappable row replacing nav chips. Three instances on the screen.
- [ ] **Screen:** `lib/features/rpg/ui/character_sheet_screen.dart` — composes header (rune halo + lvl + class badge + active title pill) → vitality radar → six body-part rows (asymmetric: trained expanded, untrained compressed) → dormant Cardio row → three codex nav rows. App bar gear icon → `/profile/settings` sub-route.
- [ ] **Profile sub-screen:** Move existing profile content (display name, locale switcher, sign-out, etc.) to `lib/features/profile/ui/profile_settings_screen.dart`. Route: `/profile/settings`.
- [ ] **Router:** `lib/core/router/app_router.dart` — `/profile` now resolves to `CharacterSheetScreen`; `/profile/settings` to `ProfileSettingsScreen`. Tab label changes to "Saga" (en) / "Saga" (pt-BR — same word). Tab icon unchanged.
- [ ] **Delete:** `_LvlBadge` placeholder from 17b (now superseded by full character sheet).
- [ ] **l10n:** Add to `app_en.arb` + `app_pt.arb`: `sagaTabLabel`, `classSlotPlaceholder` ("The iron will name you." / pt-BR equivalent), `dormantCardioCopy`, `firstSetAwakensCopy` (zero-history body-part hint), `statsDeepDiveLabel`, `titlesLabel`, `historyLabel`. Run `make gen` after adding.
- [ ] **make ci** must pass: format + analyze + test + android build.

### Test plan (qa-engineer)

- [ ] **Widget tests:**
  - [ ] `character_sheet_screen_test.dart` — six body-part rows render; dormant zero-history state shows compressed rows + first-set-awakens copy; full-vitality state shows Radiant halo.
  - [ ] `rune_halo_test.dart` — 4 visual states (each renders distinct widgets/colors; pump animation frame to assert motion).
  - [ ] `body_part_rank_row_test.dart` — rank stamp, hairline progress, untrained-collapse variant.
  - [ ] `vitality_radar_test.dart` — golden test of perfect-min hexagon (day-0) + a skewed shape (mock state).
  - [ ] `class_badge_test.dart` — placeholder copy shows when class is null; class name shows when set (use a manual override).
- [ ] **Selectors:** Add to `test/e2e/helpers/selectors.ts`: `characterSheet`, `runeHalo`, `vitalityRadar`, `bodyPartRow.{chest,back,legs,shoulders,arms,core}`, `rankStamp`, `classBadge`, `activeTitlePill`, `dormantCardioRow`, `codexNav.{stats,titles,history}`, `sagaTab`.
- [ ] **E2E `test/e2e/specs/saga.spec.ts` (`@smoke`):**
  - [ ] login as `rpgFreshUser` → navigate via Saga tab → assert `characterSheet` visible, `runeHalo` visible, six body-part rows visible, class badge shows placeholder copy.
  - [ ] login as `rpgFoundationUser` → assert at least one body-part row shows non-zero rank, radar hexagon is non-uniform.
  - [ ] tap "Stats deep-dive" codex nav → asserts route attempt (will land on stub for 18b — accept any non-error state).
  - [ ] gear icon in app bar → settings sub-screen → display name visible (was on /profile before).
- [ ] **Update `auth.spec.ts`** if onboarding lands on /saga: re-verify final destination after sign-up.
- [ ] **Full e2e regression** — navigation change is a flow change. All 190+ tests must pass. (Replace stale `_LvlBadge` selectors if any tests referenced them.)
- [ ] **Removed from suite:** any test asserting `_LvlBadge` text/role.

### Acceptance (orchestrator gate)

- [ ] `make ci` green
- [ ] Full e2e green locally (`FLUTTER_APP_URL= npx playwright test`)
- [ ] Reviewer signs off (no Blockers, all Important addressed in same cycle per "no deferring" rule)
- [ ] PR squash-merged
- [ ] PLAN.md Phase 18b row → DONE + PR number; Phase 18b detailed spec condensed to 5-7 bullets
- [ ] WIP.md Phase 18b section removed

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
