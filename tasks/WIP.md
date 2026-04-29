# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 18d.2 — RPG v1 Stats deep-dive screen at /saga/stats

**Branch:** `feature/phase18d2-stats-deep-dive` (created 2026-04-29 off `e5d1850` post-PR-#118).
**Source of truth:** `PLAN.md` §18d.2 + `docs/superpowers/specs/2026-04-25-rpg-system-v1-design.md` §13.3.
**Owner:** `tech-lead` implements; `ui-ux-critic` review pass post-implementation; `qa-engineer` gate; `reviewer` final.
**Goal:** Land the data-curious user surface at `/saga/stats` — the only place in the app where Vitality % shows as a number. Backend foundation (mapper + nightly EWMA + state copy l10n) shipped in PR #118; this PR is pure UI + provider wiring.

### Spec amendments from PO + UX critic pass (2026-04-29)

These three deltas override the literal text in PLAN.md §18d.2. Tech-lead implements per the deltas, not the original spec lines.

1. **No activity gate on `/saga/stats` entry** (PO). The character sheet already requires prior workout activity to reach the Saga tab in any meaningful state, so the empty-chart-day-1 churn risk does not actually exist on the access path. Ship ungated.
2. **Hybrid X-axis on the 90-day trend chart** (PO). When the user's earliest `xp_event` is <30 days old, render `X = (first_activity_date, today)`. Once history crosses 30 days, switch to the rolling 90-day window per spec. Avoids 80+ days of flat-zero lines reading as "broken chart" to first-month users. Keep the heading copy "90-Day Vitality Trend" only when in 90-day mode; switch to "Vitality Trend" (no day count) when in narrow mode. Add l10n key `vitalityTrendHeadingShort`.
3. **Unselected lines + selected line styling** (UX critic — overrides spec §13.3 "six lines at 12-15% opacity, selected line state-colored"):
   - **Unselected (5 lines):** flat `textDim` at 30% opacity, 1sp stroke. Single ghost color, NOT multi-color body-part palette at low opacity. Reads as "intentional silence", not "rendering failure".
   - **Selected (1 line):** `bodyPartColor` (always vivid), 2.5sp stroke, terminal dot with % label. Ignore the body part's current Vitality state when picking the selected color — the state copy + % number already render in the table row directly above the chart, so the chart's job at tap time is to announce "this is the line you chose", not to re-encode state.

Also from UX critic — **layout primitive choice**: build rows as raw `Row` inside `Padding(EdgeInsets.symmetric(horizontal: 16, vertical: 12))` inside a `Column` with `Divider(height: 1, color: AppTheme.surface2)` between them. Do NOT use `ListTile` — its `minVerticalPadding` (4dp), 72dp min-height, and injected `MergeSemantics` leak Material defaults that drift toward stock-Material register and away from the ledger aesthetic.

### Workstreams

- [ ] Add route `/saga/stats` to `lib/core/router/app_router.dart`. Discoverable via a tap-target on the existing character sheet "Stats" codex nav row (already routes to `SagaStubScreen` per Phase 18b — replace with `StatsDeepDiveScreen`).
- [ ] Create `lib/features/rpg/providers/stats_provider.dart` exposing:
  - Live Vitality table rows: `List<({BodyPart bp, double pct, VitalityState state, int rank})>`.
  - 90-day trend rows: `Map<BodyPart, List<({DateTime date, double pct})>>` — one entry per body part, daily granularity, derived from `body_part_progress` (current EWMA) + `vitality_runs` history if available, OR fall back to constructing the trace from `xp_events` aggregated by week + interpolated daily for body parts without `vitality_runs` rows.
  - Volume/peak per body part: `Map<BodyPart, ({int weeklyVolumeSets, double peakEwma})>`.
  - Peak loads per exercise: `Map<BodyPart, List<({String exerciseName, double peakWeight, int peakReps, double? estimated1RM})>>` — sourced from `exercise_peak_loads`.
  - Earliest activity date (for hybrid X-axis decision): `DateTime? earliestActivity`.
- [ ] Create `lib/features/rpg/ui/stats_deep_dive_screen.dart`. Layout:
  1. AppBar with localized "Stats" title.
  2. Live Vitality table (6 rows). Per-row: `[RuneSigil 32dp] [BodyPartName titleSmall] / [stateCopy bodySmall + textDim]` left, `[% Rajdhani 24sp tabularFigures stateColor] [stateChip 8x8 dot]` right. Tappable row drives the trend chart selection.
  3. 90-Day Vitality Trend section. Heading uses `vitalityTrendHeading` (90-day mode) or `vitalityTrendHeadingShort` (narrow mode) per the hybrid X-axis rule above. 200dp height. `fl_chart LineChart`, `FlBorderData(show: false)`, no grid lines. Y-axis labels `0`/`100`. X-axis labels: 90-day mode = "90 days ago"/"Today", narrow mode = `<earliest activity formatted>` / "Today". `LineTouchData(enabled: false)` — selection driven by parent `StatefulWidget` listening to a `selectedBodyPart` `StateProvider` or local `_selected` field. 200ms ease-out animation between selection states (use `AnimatedSwitcher` or rebuild with `AnimatedOpacity` per line).
  4. Volume/Peak per body part section. Same row primitive (`Row` in `Padding` in `Column` w/ dividers). Right columns: weekly volume (sets, last 7 days, integer), peak EWMA (Rajdhani tabularFigures with Vitality color).
  5. Peak Loads per exercise section. `ExpansionTile`s grouped by body part, **default-expanded body part is the highest-ranked** (or first if all tied at 1). Each tile contents: row per exercise — name left, `[weight] × [reps]` right (Rajdhani tabularFigures), "1RM est." label `textDim` `labelSmall` if `estimated1RM != null`.
  6. Empty-state per section: "No peaks recorded yet" (l10n `peakLoadsEmpty`) when `exercise_peak_loads` returns 0 rows for the user.
- [ ] Create child widgets so the screen file stays under ~250 lines:
  - `lib/features/rpg/ui/widgets/vitality_table.dart`
  - `lib/features/rpg/ui/widgets/vitality_trend_chart.dart`
  - `lib/features/rpg/ui/widgets/peak_loads_table.dart`
- [ ] Add l10n keys (en + pt) — confirm exact spelling against `app_en.arb` after adding:
  - `statsDeepDiveTitle` ("Stats" / "Estatísticas")
  - `vitalityTrendHeading` ("90-Day Vitality Trend" / "Tendência de Vitalidade — 90 dias")
  - `vitalityTrendHeadingShort` ("Vitality Trend" / "Tendência de Vitalidade")
  - `volumePeakSectionHeading` ("Volume & Peak" / "Volume e Pico")
  - `peakLoadsSectionHeading` ("Peak Loads" / "Cargas Máximas")
  - `peakLoadsEmpty` ("No peaks recorded yet." / "Nenhum pico registrado ainda.")
  - `weeklyVolumeUnit` ("sets" / "séries")
  - `oneRmEstimateLabel` ("1RM est." / "1RM est.")
  - X-axis labels: `chartXLabelToday` ("Today" / "Hoje"), `chartXLabel90DaysAgo` ("90 days ago" / "há 90 dias")
- [ ] Add Semantics identifiers for E2E selectors: `saga-stats-screen`, `vitality-table`, `vitality-trend-chart`, `peak-loads-table`. Add corresponding entries to `test/e2e/helpers/selectors.ts`.

### Test plan

- [ ] **Widget:** `test/widget/features/rpg/ui/stats_deep_dive_screen_test.dart` — render with seeded `stats_provider` override:
  - 6 vitality table rows present, each with state copy + % number rendered in correct font + correct state color.
  - Chart renders 6 `LineChartBarData` entries.
  - Tapping a vitality table row sets the selected body part (verify by reading the chart's painted state — assert exactly one line drawn at full opacity + state-vivid color, others at flat textDim 30%).
  - Hybrid X-axis: when `earliestActivity` is 10 days ago, X-axis labels are "10 days ago" / "Today" and heading is `vitalityTrendHeadingShort`. When 100 days ago, labels are "90 days ago" / "Today" and heading is `vitalityTrendHeading`.
  - Empty peak loads (`peakLoadsByBp == {}`) renders the "No peaks recorded yet" empty state.
  - Default-expanded ExpansionTile is the highest-ranked body part.
- [ ] **Widget (sentinel):** `character_sheet_screen_test.dart` regression — verify the character sheet still renders no Vitality % numbers after this PR.
- [ ] **Provider:** `test/unit/features/rpg/providers/stats_provider_test.dart` — fixture-backed assertions for table assembly, trend assembly with both 90-day-mode and narrow-mode windows, peak loads grouping/sorting, earliest-activity computation.
- [ ] **E2E:** Extend `test/e2e/specs/saga.spec.ts` (existing file from Phase 18b) with `Saga > stats deep-dive` describe block:
  - Navigate from character sheet → tap Stats codex row → /saga/stats opens.
  - Vitality table visible, 6 rows present.
  - Trend chart visible.
  - Tap on a body part row → chart updates (assert selector visible / aria-selected state).
  - Peak loads section visible (or empty-state for fresh seed users).
- [ ] All E2E selectors registered in `helpers/selectors.ts` — no inline magic strings.

### Anti-patterns to reject (locked from spec §13.3 + UX critic round)

- No `Card`s with rounded corners + gradient (generic-AI-stats trap).
- No floating color legend panel — table rows ARE the legend.
- No horizontal progress bar column beside % values — the number IS the quantity.
- No gradient fills under chart lines, lines only.
- No narrative section headers ("see your journey") — `labelSmall` + `textDim` only.
- No global "Overall Vitality" hero ring or summary card — averaging dilutes per-body-part signal.
- No copy lines on the character sheet — state copy lives ONLY here as marginalia.
- **No `ListTile`** (UX critic addition) — raw `Row` + `Padding` only for the ledger register.

### Edge cases to validate

- **Returning user with permanent peak ceiling.** EWMA already trained against the rebuild trajectory in PR #118 integration tests; verify the stats screen renders the rebuilt-but-still-low % accurately for a user whose `vitality_peak` was set 18 months ago.
- **Untrained body part.** `vitality_peak == 0` → state `dormant`, copy "Awaits your first stride", chart line flat at 0. Verify mapper does not divide by zero (already guarded in `VitalityStateMapper.fromVitality`, but exercise the path through the provider too).
- **Day-1 user.** Just registered, zero `xp_events`. Screen must render: 6 dormant rows + chart with 6 flat-zero lines + peak loads empty state. No layout overflow / no null-deref.
- **First-week user (history < 30 days).** Hybrid X-axis kicks in. Chart heading reads "Vitality Trend" (short variant). Line origins start from earliest activity date, not 90 days ago.
- **Exactly 30-day-old user.** Boundary — confirm the switch from short to 90-day mode is clean (no jitter at the threshold; pick `>= 30` or `> 30` and document).

### Acceptance

- [ ] /saga/stats reachable from the existing Stats codex row on the character sheet (replace `SagaStubScreen` mount).
- [ ] All 5 layout sections render with seeded data per spec §13.3 + spec amendments above.
- [ ] Vitality % is the only numerical Vitality readout in the entire app (character sheet remains number-free — sentinel test passes).
- [ ] Hybrid X-axis works: <30-day-old user sees narrow-mode chart; ≥30-day-old user sees 90-day window.
- [ ] Selected trend line uses `bodyPartColor` (always vivid), unselected lines flat `textDim` 30% opacity 1sp.
- [ ] Tap-to-highlight: tapping a vitality table row selects + animates that body part's line. 200ms ease-out.
- [ ] Tests: 2028 → ~2028+N unit/widget pass (N = new widget + provider tests). Existing 9/9 integration still green.
- [ ] E2E: full regression suite green at `--retries=0` on local Supabase, `specs/saga.spec.ts` extended with the new describe block (all `@smoke`-tagged where appropriate).
- [ ] CI green — `dart format`, `dart analyze --fatal-infos`, `make test`, e2e, exercise-translation-coverage-check, build.
- [ ] PR opened, reviewer + qa-engineer + ui-ux-critic post-implementation pass all green, squash-merged.

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
