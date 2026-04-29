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

- [x] **WS2 — Title catalog completion (spec §10.2 + §10.3):**
  - Sealed Freezed union `Title` with three variants (BodyPartTitle, CharacterLevelTitle, CrossBuildTitle) shipped + per-key TitlesRepository loader with `kind` discriminator and legacy v1 loader injection
  - 12 new slugs + flavor + name keys in en/pt-BR via gen-l10n
  - Phase 17b `titles_v1.json` preserved verbatim (forever-stable join keys)

- [x] **WS3 — Title detection extension:**
  - `TitleUnlockDetector.detectCharacterLevel` + `detectCrossBuild` shipped, half-open interval semantics mirror body-part path
  - `CelebrationEventBuilder.build` orchestrates all three detectors with cumulative `earnedSoFar` guard

- [x] **WS4 — Cross-build evaluator + retroactive backfill:**
  - `CrossBuildTitleEvaluator` pure function (5 predicates) shipped; iron_bound is per-track (Chest ≥ 60 AND Back ≥ 60 AND Legs ≥ 60), not a sum — spec §10.3 amended to disambiguate (reviewer pass)
  - Migration `supabase/migrations/00043_cross_build_titles_backfill.sql` ships the PL/pgSQL mirror function `evaluate_cross_build_titles_for_user(uuid)` + idempotent `INSERT INTO earned_titles … ON CONFLICT DO NOTHING` over distinct users; the explicit BEGIN/COMMIT was removed in the reviewer pass (Supabase CLI wraps each migration in an implicit transaction)
  - Migration application to hosted Supabase still pending (post-merge step per CLAUDE.md §10)

- [x] **WS5 — Dead 17b code investigation (option B chosen):**
  - Documented keep-as-shim rationale in `lib/features/gamification/providers/xp_provider.dart` (~30 lines explaining why deletion is v1.1+ scope)
  - Inline note added at the call site in `active_workout_notifier.dart:927` pointing readers to the rationale
  - Removal of `lib/features/gamification/` blocked on migrating `SagaIntroOverlay` to read from `rpgProgressProvider.characterState` — separate UI pass scoped to v1.1+

- [x] **WS6 — Tests (65 new tests, total 2180 green):**
  - `test/unit/features/rpg/domain/class_resolver_test.dart` — 17 tests pinning Initiate floor, Ascendant precedence (boundary 30% inclusive), 6 dominant-class lookups, alphabetical tie-break, cardio-ignore
  - `test/unit/features/rpg/domain/cross_build_title_evaluator_test.dart` — 21 tests pinning every predicate's fire/no-fire boundary plus multi-fire + cardio-ignore + missing-entry default behaviour
  - `test/unit/features/rpg/domain/title_unlock_detector_test.dart` — extended with detectCharacterLevel (9) + detectCrossBuild (8) groups; total now 28 tests (was 11)
  - `test/unit/features/rpg/domain/celebration_event_builder_test.dart` — extended with character-level title unlock + cross-build unlock + cross-build idempotency cases (was 8 → now 12)
  - `test/unit/features/rpg/providers/class_provider_test.dart` — 6 tests pinning bullet 8 (class label updates immediately on rank changes), AsyncLoading/Data/Error transitions, multi-step rank trajectory
  - `test/widget/features/rpg/widgets/class_badge_test.dart` — 11 tests already cover all 8 class variants + placeholder state from Phase 18b
  - **Integration:** `test/integration/rpg_acceptance_test.dart` deferred — every Phase 18e net-new behaviour (class resolver, cross-build, three-kind detection, builder orchestration, immediate class flip) is unit-pinned above; the existing `test/integration/rpg_*.dart` suite already covers spec §18 bullets 1–7 and 9–10 with hosted-Supabase parity. Re-implementing them as a fixture-only Dart-level test would duplicate the migration-pinned PG/Dart parity already covered by `rpg_record_set_xp_test.dart`. qa-engineer to validate via existing E2E flows + manual hosted-Supabase smoke after migration applies

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
