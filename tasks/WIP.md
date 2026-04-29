# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 18d — RPG v1: Stats deep-dive + Vitality nightly job + visual states

**Branch:** `feature/phase18d-stats-deep-dive` (created 2026-04-29 off `84c72c4`).
**Source of truth:** `PLAN.md` §18d (lines 1195-1230) + `docs/superpowers/specs/2026-04-25-rpg-system-v1-design.md` §8 (Vitality), §13.3 (Stats deep-dive screen), §13.5 (visual states).
**Owner:** `tech-lead` implements; `qa-engineer` gate; `ui-ux-critic` review pass on the stats screen; `reviewer` final pass.
**Goal:** Land RPG v1's data-curious user surface (live Vitality numbers + 90-day trend) AND the Vitality nightly EWMA recompute job AND the canonical 4-state rune mapper that the character sheet rebases onto.

### Workstreams (one PR, three internal stages)

#### Stage 1 — Vitality nightly Edge Function + cron + idempotency

- [ ] Migration `supabase/migrations/00042_vitality_cron.sql`: `vitality_runs (user_id uuid, run_date date, primary key (user_id, run_date), inserted_at timestamptz default now())`. Add `pg_cron` job invoking the Edge Function at 03:00 UTC daily.
- [ ] Edge Function `supabase/functions/vitality-nightly/index.ts`. For each user with activity in past 7 days:
  - For each of 6 body parts, compute `weekly_volume[bp]` from `xp_events` past 7d.
  - Apply asymmetric EWMA per spec §8.1: τ_up=2wk → α≈0.393 when `weekly_volume >= prior_EWMA`, τ_down=6wk → α≈0.154 otherwise.
  - Update `vitality_ewma`, bump `vitality_peak = max(peak, ewma)`.
  - Compute `vitality_pct = clamp(ewma / peak, 0, 1)`.
- [ ] Idempotency: skip work if `vitality_runs (user_id, run_date)` row already exists for today (UTC). Insert before computing.
- [ ] Performance: chunk by `user_id % 10` and parallelize 10 worker invocations to stay under Edge Function timeout limits (spec §12.3 — <10min for 100k users; we are nowhere near that yet but the function must scale).

#### Stage 2 — `vitality_state_mapper.dart` single source of truth

- [ ] Create `lib/features/rpg/domain/vitality_state_mapper.dart` exposing:
  - `RuneVitalityState` enum: `dormant / fading / active / radiant`.
  - `VitalityStateColors` — `borderColor`, `haloColor`, `chartLineColor`, `progressBarColor` per state.
  - `Map<BodyPart, Color>` body-part → line color (locked across chart, halo, progress bar — UI critic warning: lock once or color drift across surfaces is inevitable).
  - `RuneVitalityState fromPercent(double pct)` with boundary semantics `0 → dormant`, `(0,30] → fading`, `(30,70] → active`, `(70,100] → radiant`.
  - `String copyKey(state)` returns the `app_localizations` key for the state's marginalia line ("Awaits your first stride", "Conditioning lost — return to the path", "On the path", "Path mastered").
- [ ] Modify `lib/features/rpg/ui/character_sheet_screen.dart` to consume `vitality_state_mapper` for rune halo + progress bars. **Character sheet stays number-free** — no Vitality % renders here.
- [ ] Modify `lib/features/rpg/widgets/rune_sigil.dart` (if exists) and any rune halo painter to read state from the mapper instead of ad-hoc color logic.

#### Stage 3 — Stats deep-dive screen at `/saga/stats`

- [ ] Add route `/saga/stats` in `lib/core/router/app_router.dart`. Discoverable via a tap-target on the character sheet (NOT in primary nav, NOT in onboarding — UX critic: empty charts on day 1 = churn trigger).
- [ ] Create `lib/features/rpg/providers/stats_provider.dart` — Riverpod provider exposing live Vitality table + 90-day trend rows (per body part) + volume/peak per body part + peak loads per exercise.
- [ ] Create `lib/features/rpg/ui/stats_deep_dive_screen.dart`. Layout (top-to-bottom, ledger-not-dashboard register, NO cards, NO elevation, rows separated by `surface2` dividers):
  1. AppBar — "Stats" (l10n key).
  2. **Live Vitality table** (primary content). Each of 6 rows: `[RuneSigil 32dp] [BodyPartName titleSmall] / [stateCopy bodySmall + textDim]` left, `[% value Rajdhani 24sp tabularFigures stateColor] [stateChip 8x8 dot]` right.
  3. **90-Day Vitality Trend chart** (label `labelSmall` + `textDim` "90-Day Vitality Trend"). 200dp height. `fl_chart LineChart`, `FlBorderData(show: false)`, no grid lines, Y-axis labels `0`/`100` only, X-axis labels "90 days ago"/"Today". Six lines drawn at 12-15% opacity by default; tapping a row in the table elevates that body part's line to full opacity + 2.5sp stroke + state-colored + terminal dot with % label. `lineTouchData: LineTouchData(enabled: false)` — selection driven by parent `StatefulWidget`. 200ms ease-out animation between selection states.
  4. **Volume/Peak per body part** — same row pattern as live table, two right columns: weekly volume (sets), peak EWMA.
  5. **Peak Loads per exercise** — `ExpansionTile`s grouped by body part. Default-expanded: highest-ranked body part only. Inside each: exercise name left, `[weight] × [reps]` right (Rajdhani, tabularFigures). "1RM est." label in `textDim` if estimate available.
- [ ] Create child widgets: `widgets/vitality_table.dart`, `widgets/vitality_trend_chart.dart`, `widgets/peak_loads_table.dart`.
- [ ] Add l10n keys (en + pt) for the AppBar title and 4 state copy lines + section headers.
- [ ] Add `Semantics(identifier: 'saga-stats-screen')` etc. for E2E selectors (`statsDeepDive`, `vitalityTable`, `vitalityTrendChart`, `peakLoadsTable`).

### Test plan (per PLAN.md §18d)

- [ ] **Unit:** `vitality_state_mapper_test.dart` — boundary cases at 0%, 0.5%, 30%, 30.5%, 70%, 70.5%, 100%. Body-part-to-color map locked (regression check). `stats_provider_test.dart` — provider returns expected shape from seeded `xp_events`.
- [ ] **Integration:** `test/integration/rpg_vitality_nightly_test.dart` against local Supabase. Seed user with controlled set history across 4 weeks. Run nightly procedure manually 4 times (one per week-end). Assert EWMA trajectory matches Python simulator within 5% per spec §18 acceptance #6.
- [ ] **Widget:** `stats_deep_dive_screen_test.dart` — live numbers render, chart renders 6 lines, tap-to-highlight elevates one line, character sheet still has zero numbers.
- [ ] **E2E:** Extend `specs/rpg-foundation.spec.ts` (or new `specs/saga.spec.ts` if cleaner). Navigate to /saga/stats from character sheet, assert table + chart + peak loads visible. Selectors via `helpers/selectors.ts`.

### Anti-patterns to reject (UX critic input)

- No `Card`s with rounded corners + gradient — that is the generic-AI-stats-screen trap. Rows on `surface` with `Divider(height:1, color: surface2)` only.
- No floating color legend panel. Body-part rows ARE the legend (tap to highlight).
- No horizontal progress bar column beside the % values. The number IS the quantity.
- No gradient fills under chart lines. Lines only.
- No "see your journey" narrative section headers. Sub-labels only, `labelSmall` + `textDim`.
- No global "Overall Vitality" hero ring or summary card. Per-body-part granularity is the design philosophy — averaging would dilute the signal.
- No state copy lines on the character sheet. They live ONLY on the stats screen as marginalia.

### Edge cases to validate (PO input)

- **Returning user with permanent peak ceiling.** Vitality_peak never decays — a user who peaked 18 months ago and is returning from injury sees an unreachable ceiling. Run the simulator on a "6-month layoff → return" trajectory and confirm the rebuild path feels achievable (rebuild-fast τ=2wk should bring them to 79% in ~3 weeks per spec §8.2). If not, flag to design.
- **Untrained body part.** `Vitality_peak = 0` → `dormant` state, copy line "Awaits your first stride". Verify mapper returns `dormant` (not divide-by-zero) for `peak=0`.
- **Day-1 user with empty data.** /saga/stats should not crash with no `xp_events`. All six body parts render as `dormant`, chart shows flat-zero lines, peak loads section reads "No peaks recorded yet" (l10n key).

### Acceptance (mirrors PLAN.md §18d test plan)

- [ ] Migration applied to local Supabase, verified by `supabase db push` and a manual cron-job inspection.
- [ ] Edge Function passes integration test (4-week trajectory within 5% of simulator).
- [ ] Character sheet still renders correctly post-rebase (no Vitality % numbers, rune halo + progress bars now driven by mapper).
- [ ] /saga/stats reachable from character sheet, all four sections render with seeded data.
- [ ] `make ci` green: format + gen + analyze + test + android-debug-build.
- [ ] Full E2E suite green at `--retries=0` on local Supabase (selector impact assessment performed; new e2e test for /saga/stats added per PLAN.md §18d test plan).
- [ ] PR #118 (or next number) opened, reviewer + ui-ux-critic + qa-engineer all green, squash-merged.

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
