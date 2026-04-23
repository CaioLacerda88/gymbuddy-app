# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 17b — XP & Level System + Retroactive Backfill (2026-04-23)

**Branch:** `feature/phase17b-xp-level-system`
**Source of truth:** PLAN.md §17 Build Order step 2 + §17b (full spec, ~65 lines)
**Dependency:** §17.0 (DONE, PR #101) — palette + `PixelImage` + `PixelPanel` ready for intro overlay.
**Unblocks:** §17a (overlay consumes `GamificationSummary` from `xpProvider`; PR detection triggers PR band).

### Acceptance checklist (from PLAN.md §17b)

- [ ] Migration `0028_user_xp.sql` — `user_xp` + `xp_events` tables, RLS owner-read, `award_xp` RPC `SECURITY DEFINER`
- [ ] Migration `0029_retroactive_xp.sql` — `retro_backfill_xp(uuid)` idempotent procedure (rerunnable, no duplicates via `last_xp_event_id` or `source='retro'` uniqueness guard)
- [ ] `XpCalculator.compute(workout, prs)` → `XpBreakdown{base, volume, intensity, pr, quest, comeback, total}`; formula per spec (base 50, volume floor(totalKg/500), intensity sum((rpe-5)*10) for rpe>5, pr 100 heavy / 50 rep, quest 75, comeback ×2 applied last)
- [ ] Level curve `xpForLevel(n) = floor(300 * pow(n, 1.3))` precomputed to `kXpCurve[1..100]`; LVL 8 ≈ 3_800 XP
- [ ] Ranks: Rookie(0)→Iron(2_500)→Copper(10_000)→Silver(25_000)→Gold(60_000)→Platinum(125_000)→Diamond(250_000)
- [ ] `xpProvider` AsyncNotifier exposes `GamificationSummary{totalXp, currentLevel, xpIntoLevel, xpToNext, rank}`; emits update within 500ms of workout save
- [ ] Workout save path (`workouts_repository.save_workout`) enqueues XP award on success
- [ ] `SagaIntroOverlay` — one-time, 3 screens ("Your training is your character" → "XP from every set, PR, quest" → "LVL N — Rank"), dismiss flips `user_prefs.saga_intro_seen = true`; pixel-art native (uses `PixelImage` + `pixelHero`/`pixelLabel` styles, not Material)
- [ ] Unit: `xp_calculator_test.dart` (20+ cases incl. RPE edges rpe=5→0, rpe=10→50; PR combinations; comeback multiplier ordering), `level_curve_test.dart` (monotonic strictly increasing, LVL 1/8/50 boundaries), `xp_repository_test.dart` (mocked Supabase, retro idempotency)
- [ ] Widget: `saga_intro_overlay_test.dart` (3-step nav, dismiss sets pref, second-launch does not render)
- [ ] E2E: new `specs/gamification-intro.spec.ts` tagged `@smoke` — fresh user onboarding → home → sees overlay → taps through → lands on home with `LVL 1` placeholder. New selectors `sagaIntroNext`/`sagaIntroBegin`/`lvlBadge`. New test user `sagaIntroUser` in `fixtures/test-users.ts` + `global-setup.ts`
- [ ] Migration QA: qa-engineer runs `supabase db push` on local, verifies retro-backfill over seed data, reruns to confirm idempotency; documented in PR description

### Files to create

- `supabase/migrations/0028_user_xp.sql`
- `supabase/migrations/0029_retroactive_xp.sql`
- `lib/features/gamification/domain/xp_calculator.dart`
- `lib/features/gamification/data/xp_repository.dart`
- `lib/features/gamification/providers/xp_provider.dart`
- `lib/features/gamification/models/xp_state.dart`
- `lib/features/gamification/models/xp_breakdown.dart`
- `lib/features/gamification/ui/saga_intro_overlay.dart`
- Tests mirroring the above under `test/unit/features/gamification/` + `test/widget/features/gamification/`
- `test/e2e/specs/gamification-intro.spec.ts`

### Files to modify

- `lib/features/workouts/data/workouts_repository.dart` — enqueue XP award on successful save
- `test/e2e/helpers/selectors.ts` — add `sagaIntroNext`, `sagaIntroBegin`, `lvlBadge`
- `test/e2e/fixtures/test-users.ts` + `test/e2e/global-setup.ts` — new `sagaIntroUser` (fresh, unseen overlay)
- `pubspec.yaml` (if localization needed — check with existing l10n pattern)

### Open design questions (resolve during tech-lead pass)

- Intro overlay copy: keep English-only until 15-style extraction in a follow-up, or extract to `.arb` now? PLAN.md spec is silent — propose EN+PT from the start since l10n infra already exists.
- `award_xp` RPC vs inline insert: PLAN.md says "writes happen via `award_xp` RPC (SECURITY DEFINER)". Confirm the RPC signature: `award_xp(p_user_id uuid, p_workout_id uuid, p_amount int, p_source text, p_breakdown jsonb)` returning the new `total_xp`/`current_level` snapshot.
- Comeback flag: 17b defines `comeback` as an input to the breakdown, but detection lives in 17c. For 17b, accept `comeback: false` always and expose the multiplier path in the calculator for 17c to flip.

### Pipeline

1. tech-lead — migrations + domain + data + provider + minimal intro UI + unit/widget tests (foreground, Opus)
2. ui-ux-critic — review `SagaIntroOverlay` for pixel-art fidelity (read-only, background)
3. qa-engineer — test coverage + new E2E spec + migration QA on local Supabase (foreground)
4. Verification gate — fresh `make ci` + migration dry-run
5. Open PR → reviewer → fix cycle → merge
6. Post-merge: `npx supabase db push` against hosted (two new migrations)
7. Close WIP + condense §17b in PLAN.md

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
