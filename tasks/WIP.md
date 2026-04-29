# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 18e — Class system + cross-build titles + final RPG v1 QA pass (2026-04-29)

**Branch:** `feature/phase18e-class-system`
**Spec:** `docs/superpowers/specs/2026-04-25-rpg-system-v1-design.md` §9 (classes), §10 (titles), §18 (acceptance criteria)
**PLAN:** PLAN.md §18e

### Workstreams

- [x] **WS1 — Class system (spec §9):**
  - Create `lib/features/rpg/models/character_class.dart` — Freezed enum/sealed-class with 8 variants (Initiate, Berserker, Bulwark, Sentinel, Pathfinder, Atlas, Anchor, Ascendant) + slug + l10n key
  - Create `lib/features/rpg/domain/class_resolver.dart` — pure `resolveClass(Map<BodyPart, int>) → CharacterClass` per §9.2 ordering: `if max < 5 → Initiate; else if (max-min)/max ≤ 0.30 AND min ≥ 5 → Ascendant; else dominant lookup`
  - Replace `lib/features/rpg/providers/class_provider.dart` stub: watch `rpgProgressProvider`, build rank map from `progressFor(bp).rank` for all `activeBodyParts`, resolve class, return its **slug** (mirrors active-title pattern; UI resolves to localized label)
  - Update `lib/features/rpg/ui/widgets/class_badge.dart` to take a class slug and resolve `class_{slug}` from `AppLocalizations` (instead of receiving a pre-localized string)
  - Add l10n keys `class_initiate`, `class_berserker`, `class_bulwark`, `class_sentinel`, `class_pathfinder`, `class_atlas`, `class_anchor`, `class_ascendant` (en + pt-BR)

- [ ] **WS2 — Title catalog completion (spec §10.2 + §10.3):**
  - Existing `Title` model is `(slug, body_part, rank_threshold)` — character-level + cross-build titles don't fit. Restructure as a sealed Freezed union: `BodyPartTitle | CharacterLevelTitle | CrossBuildTitle`. Update `titles_repository.dart` JSON loader to dispatch by a `kind` discriminator field
  - Create `assets/rpg/titles_character_level.json` (7 entries: lvl 10 Wanderer, 25 Path-Trodden, 50 Path-Sworn, 75 Path-Forged, 100 Saga-Scribed, 125 Saga-Bound, 148 Saga-Eternal)
  - Create `assets/rpg/titles_cross_build.json` (5 entries with trigger metadata; the actual predicate lives in Dart since JSON can't express it. JSON stores: slug + display name key + flavor key + `trigger_id` enum)
  - Add 7 + 5 = 12 title slugs × (`_name` + `_flavor`) × 2 locales = 48 new `.arb` keys
  - Bump `assets/rpg/titles_v1.json` to add `"kind": "body_part"` to every existing entry (or wrap them in a versioned envelope) — preserve every existing slug verbatim (forever-stable join key with `earned_titles.title_id`)

- [ ] **WS3 — Title detection extension:**
  - Extend `lib/features/rpg/domain/title_unlock_detector.dart`:
    - `detectCharacterLevel({oldLvl, newLvl, alreadyEarnedSlugs, catalog})` — half-open interval `(oldLvl, newLvl]` mirroring body-part semantics
    - `detectCrossBuild({rankMap, alreadyEarnedSlugs, catalog})` — runs every workout-finish; predicate is the same trigger fn used in WS4. Idempotent via `alreadyEarnedSlugs` skip
  - Extend `active_workout_notifier._finishOnline` to call all three detectors and merge into the celebration queue
  - Note: `oldLvl/newLvl` available from `rpgProgressSnapshot.characterState.characterLevel` before/after the save

- [ ] **WS4 — Cross-build evaluator + retroactive backfill:**
  - Create `lib/features/rpg/domain/cross_build_title_evaluator.dart` — pure `evaluateCrossBuildTitles(Map<BodyPart, int> rankMap) → List<String> slugs`. Five triggers:
    - `Pillar-Walker`: legs ≥ 40 AND legs ≥ 2 × arms
    - `Broad-Shouldered`: chest+back+shoulders ≥ 2 × (legs+core) AND chest ≥ 30 AND back ≥ 30 AND shoulders ≥ 30
    - `Even-Handed`: all 6 within 30% of max AND min ≥ 30
    - `Iron-Bound`: chest+back+legs ≥ 60 (AND low cardio in v2 — v1 ignores cardio condition since cardio doesn't earn XP yet)
    - `Saga-Forged`: all 6 ranks ≥ 60
  - Migration `supabase/migrations/00043_cross_build_titles_backfill.sql` — one-time procedure that, for every user with `body_part_progress` rows, computes the rank map and INSERTs cross-build slugs into `earned_titles` with `is_active = false` and `earned_at = now()`. Idempotent: `ON CONFLICT (user_id, title_id) DO NOTHING`. SQL must mirror the Dart predicates exactly (re-state them as PL/pgSQL for parity)
  - Apply migration to hosted Supabase post-merge per CLAUDE.md step 10

- [ ] **WS5 — Dead 17b code investigation:**
  - PLAN.md §18e flags `XpCalculator` / `xpForLevel` / placeholder unit tests for deletion ("flagged in 18a")
  - **Reality check:** `lib/features/gamification/domain/xp_calculator.dart` is still referenced from `active_workout_notifier.dart:933` (`XpCalculator.compute(...)`) and the LVL badge UI / saga intro overlay
  - Tech-lead judgment call: either (a) replace `gamification/XpCalculator.compute` consumers with the RPG v1 character-level math from `rpgProgressProvider.characterState.characterLevel` and delete the gamification feature dir entirely, OR (b) document why `gamification/` stays alive in v1 and push deletion to v1.1+. Whichever path: leave the codebase consistent, no half-deletions

- [ ] **WS6 — Tests:**
  - **Unit:** `test/unit/features/rpg/domain/class_resolver_test.dart` (every class trigger + Ascendant precedence + Initiate floor + boundary at exactly rank 5/exactly 30%)
  - **Unit:** `test/unit/features/rpg/domain/cross_build_title_evaluator_test.dart` (each of the 5 triggers + boundary cases like exact-equality at thresholds)
  - **Unit:** Extend `test/unit/features/rpg/domain/title_unlock_detector_test.dart` with character-level + cross-build detection paths
  - **Widget:** Extend `test/widget/features/rpg/ui/widgets/class_badge_test.dart` for each of 8 class slugs rendering correctly
  - **Integration:** `test/integration/rpg_acceptance_test.dart` — synthetic fixture user with controlled rank distribution; assert each spec §18 acceptance bullet 1–10 (bullets 11/12 = CI/migration are out of scope for this test). Use SupabaseClient mock or in-memory fake to avoid hosted DB dependency

### Acceptance (spec §18)

1. Schema migrated; backfill computes correct Ranks for all existing users from historical workout_sets — covered by Phase 18a, re-verified
2. Per-set XP computed live in workout-logging path with <50ms p95 overhead — qa-engineer captures benchmark
3. Character sheet renders for all users including zero-history — re-verified
4. Stats deep-dive renders accurate live numbers for active users — re-verified
5. Mid-workout rank-up overlay fires correctly on real Phase 18 XP math — re-verified
6. Vitality updates daily via scheduled job; trajectory matches simulation within 5% tolerance — re-verified
7. Title unlocks fire correctly on Rank threshold crossings during workout — re-verified + new char-lvl/cross-build paths
8. **Class label updates immediately on Rank changes** — net-new this phase
9. Strength_mult correctly applied — re-verified
10. Permanent peak invariant — re-verified
11. CI green: format, analyze, unit, widget, full E2E suite (with new RPG flows including class label cross + title-equip)
12. Migration applied to hosted Supabase; verified end-to-end with manually replayed user history

### Pipeline

1. tech-lead — WS1–WS6 implementation, run `make ci` after each workstream
2. ui-ux-critic — review class label rendering on character sheet (typography, transitions, anti-generic-AI)
3. qa-engineer — final RPG v1 acceptance pass per spec §18, E2E (class cross + title-equip + full regression), perf benchmark
4. reviewer — full PR review, fix all findings same-cycle (no deferral per memory rule)
5. PR open → CI green → squash-merge → migration `00043` applied to hosted Supabase → close WIP + condense PLAN.md §18e

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
