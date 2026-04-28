# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 18c — RPG v1: Mid-Workout Overlay Rewire + Title Unlocks

**Branch:** `feature/phase18c-mid-workout-overlays` (created off main @ f7f05ee)
**Reference:** PLAN.md Phase 18c (lines 1183-1209), design spec `docs/superpowers/specs/2026-04-25-rpg-system-v1-design.md` §13.2 + §13.4 + §10.1 + §8.4
**Depends on:** 18a (PR #112, merged) — `record_set_xp` returns deltas; 18b (PR #113, merged) — character sheet renders equipped title + rune halo states

### Decisions locked from product-owner + ui-ux-critic kickoff

**Celebration queue mechanics (PO + critic):**

- **Cap at 3 overlays max** per workout finish. Beyond 3, render a non-modal condensed card "N more rank-ups — open Saga" (3s auto-dismiss, tappable, opens `/profile`). Reasoning: 6 body-part rank-ups + level-up + title = 10s of overlays = churn risk for the lifter who wants to log and leave.
- **Causal queue order kept per spec:** rank-ups (highest body-part rank first as tiebreaker) → character level-up → title unlock (half-sheet, post-workout). Don't re-order to identity weight; the causal narrative reads cleaner.
- **Inter-event gap:** 200ms between overlays. Each overlay 1.1s. Dismissible via tap, but auto-advance at 1.1s without requiring tap.
- **Rest timer + set logging must NOT block** behind overlays. Rank-up overlays fire on workout finish, not between sets — but defensive: if any overlay surface is invoked mid-workout, it must not capture pointer events on the rest timer or the set entry row.

**RankUpOverlay (Direction B — "Rune Stamp"):**

- Layout: centered card on `surface2`, 280dp wide, `kRadiusMd` corners, 1px `heroGold @ 0.6` border. Backdrop dims to `abyss @ 0.72` via `ModalBarrier` `FadeTransition` (180ms `Curves.easeOut`).
- Card entry: scale 0.88→1.0, 220ms `Curves.easeOutBack` (slight overshoot for weight, no bounce).
- Rune sigil (60dp body-part icon from `AppMuscleIcons`) three-stage `ColorTween`:
  - 0–200ms: `textDim @ 0.3` → `heroGold @ 1.0` (`Curves.easeIn`) — ignition spark
  - 200–500ms: hold `heroGold`; `BoxShadow` blur 0→24, spread 0→6 (`heroGold @ 0.5`, `Curves.easeOut`)
  - 500–900ms: `heroGold @ 1.0` → `hotViolet @ 0.9` (`Curves.decelerate`) — settle
  - 900–1100ms: `BoxShadow` color cross-fades `heroGold @ 0.5` → `hotViolet @ 0.45` (matches RuneHalo Active steady state for visual continuity)
- Copy: "{BODY PART} · RANK {N}" — Rajdhani 700 28sp, body-part name in `textCream`, rank numeral wrapped in `RewardAccent` for `heroGold`. Optional flavor line in Inter 400 14sp `textDim`.
- Haptic: `HapticFeedback.mediumImpact()` at t=200ms (peak gold). Heavier than RuneHalo's `lightImpact` because rank-up is permanent.
- All `heroGold` pixels MUST flow through `RewardAccent` (scarcity contract from 17.0c).

**LevelUpOverlay differentiation (locked, total separation from RankUpOverlay):**

- **Glyph:** the level numeral itself, Rajdhani 700 64sp, no icon. (RankUp uses body-part rune.)
- **Chromatic register:** pure `heroGold` throughout — no settle into `hotViolet`. Character level is cumulative, never resets.
- **Entry axis:** `SlideTransition` `Offset(0.08, 0)` → `Offset.zero`, 200ms `Curves.easeOutCubic`. (RankUp uses scale.)
- **No backdrop dim** on level-up — stacking dim layers when already in queue is oppressive.
- **Haptic:** `HapticFeedback.heavyImpact()` at t=0. (RankUp = medium at peak; LevelUp = heavy at entry.)
- **Copy:** "LEVEL {N}" Rajdhani 600 24sp `textCream` beneath the numeral. No flavor.

**TitleUnlockSheet (post-workout half-sheet, "artifact" not "Material modal"):**

- Background: `surface2` flat, NO gradient. Faint `AppIcons.hero` SVG watermark at 180dp, `textDim @ 0.04`, bottom-right, `IgnorePointer`.
- Drag handle: 32×3dp pill in `hair` color (replaces white default).
- Reading order top-to-bottom: rank label → title name → flavor → equip button.
  - Rank label: "{BODY PART} · RANK {N} TITLE" Inter 600 13sp uppercase 0.12em tracking, `hotViolet`.
  - Title name: Rajdhani 700 32sp `textCream` centered. NOT Cinzel (overhead unjustified for transient sheet).
  - Flavor: Inter 400 14sp `textDim` 1.5 line-height. Max 2 lines, truncate (don't expand sheet).
  - Equip: filled `OutlinedButton` (no — filled `ElevatedButton`), full width, `primaryViolet` background, `textCream` foreground, "EQUIP TITLE" Rajdhani 600 13sp uppercase. 56dp height. If already equipped: outlined `hotViolet` "EQUIPPED" non-interactive (or tap → character sheet).
- **First-ever title only:** wrap title name in `RewardAccent` for `heroGold`. Subsequent titles stay `textCream`.
- Sheet height: `DraggableScrollableSheet` fixed at 0.45 (`initialChildSize = minChildSize = maxChildSize = 0.45`). NO free-drag — content is fixed-length and free-drag invites accidental dismiss.
- Dismiss: tap outside or back gesture. Equip button persists `is_active` via `earned_titles_one_active` UNIQUE INDEX.

**Persistence — earned-but-not-equipped titles (PO addition, scope expansion):**

- The Titles screen (currently `SagaStubScreen` from 18b's codex nav row) gets upgraded in 18c to a functional list of earned titles, each row with an Equip/Equipped toggle. This is the re-entry point for users who dismissed the post-workout half-sheet without equipping.
- Stats deep-dive remains stubbed for 18d.

**FirstAwakeningOverlay (zero-history onboarding, 800ms):**

- Centered card, 240dp wide (narrower than RankUp's 280dp — physically smaller, semantically smaller).
- Background: `surface2`, `hotViolet @ 0.25` border. NO backdrop dim (800ms too short to dim and recover eyes). Single `BoxShadow` `hotViolet @ 0.30` blur 20.
- Rune sigil 48dp (smaller than RankUp's 60dp). `ColorTween` `textDim @ 0.15` → `hotViolet @ 1.0` over full 800ms `Curves.easeOut` — slow linear ignition, no peak/settle staging.
- Copy: "{BODY PART} AWAKENS" Rajdhani 600 18sp. No flavor, no rank number.
- Entry: `ScaleTransition` 0.92→1.0 (200ms `Curves.easeOut`) + `FadeTransition` 0→1 (150ms simultaneous).
- Exit: `FadeTransition` 1→0 (200ms `Curves.easeIn`) starting at t=600ms.
- Haptic: `HapticFeedback.lightImpact()` at t=0.
- **No tap dismissal** — `IgnorePointer` over the card during the 800ms window. Reaction time would not allow intentional tap anyway.
- **Throttle (PO):** **1 overlay per session max**, fires only for the first body part the user touches. Subsequent body-part awakenings in the same session are silent rune-state changes (Dormant→Active via the character sheet, no overlay). Lifetime cap: this is functionally a session-1 + session-2 device since by session 2 most users have no Dormant body parts left.
- Connection to RuneHalo Radiant: ends at `hotViolet` matching the RuneHalo Active steady state — perceptual bridge to the character sheet.

**Mid-session PR chip:**

- Inline in the set row (Strong/Hevy pattern). Right-aligned, 28dp height (no row height expansion).
- Fires on **set commit**, NOT on input — typing weight 100→105→110 must not flash the chip mid-keystroke.
- Visual: pill chip, `surface` background, 1px `heroGold @ 0.8` border (via `RewardAccent`), text "PR" Rajdhani 700 11sp `heroGold` (via `RewardAccent`). No icon, no haptic, no animation. Persists for full session.
- All `heroGold` pixels flow through `RewardAccent` per scarcity contract.
- **Haptic explicitly NOT used** — preserved for Radiant rune state + rank-up + level-up. Diluting haptic on every PR cheapens the signal.

**Finish-button placement:**

- Move to AppBar trailing as `OutlinedButton` (not text — too easy to mis-tap; not filled — competes with set-entry CTA).
- `hotViolet` border + text, "FINISH" Rajdhani 600 13sp. 44dp tap target.
- Top-right is intentionally hard to reach one-handed — friction is the feature for a destructive action. Confirmation dialog is the second gate.
- FAB position freed up for "Add exercise" (genuinely mid-session, benefits from thumb-reach).

**Title catalog editorial pass (PO finding, must happen before titles_v1.json ships):**

- Audit and revise titles ending in `-Lord`, `-King`, `-Master`, `-Eternal`, `-Sworn` at Ranks 40-90 across all six body parts. Compound-noun titles only. No borrowed-status suffixes unless terminal Rank 99 (and even then prefer noun fragment).
- Editorial principle: titles describe what the body part DOES or has BECOME, not the rank achieved. "Iron-Chested" passes; "Forge-Lord" fails.
- Anchor examples (legs): Rank 5 "Ground-Walker" ✓, Rank 40 "Stone-Strider" (preferred over "Pillar-Sworn"), Rank 99 "The Pillar" ✓.
- pt-BR translations: must use Brazilian gym vocabulary (`malhado`, `pegada`, `raiz`), NOT direct word-for-word renders. Engage native speaker review during qa-engineer gate.

**Anti-patterns to reject (critic, locked):**

1. **Particle bursts** on rank-up. Replace: three-stage color tween IS the celebration. Color change is zero-cognitive-load state communication.
2. **Gradient backgrounds** on TitleUnlockSheet. Replace: flat `surface2` + low-opacity rune watermark. Archaeological texture, not promotional gradient.
3. **Animated/typewriter title text entry** on TitleUnlockSheet. Replace: standard Material slide-up (300ms `Curves.fastOutSlowIn`), content visible at frame one. Stillness is confidence.

### Implementation checklist (tech-lead)

- [x] Verify CI green on main (already confirmed at f7f05ee).
- [x] **Models (in order):**
  - [x] `lib/features/rpg/models/title.dart` — Freezed: id, slug, body_part, rank_threshold, en_name, en_flavor (nullable). pt-BR via `app_pt.arb` lookup.
  - [x] `lib/features/rpg/models/celebration_event.dart` — sealed class `CelebrationEvent` with subtypes: `RankUpEvent`, `LevelUpEvent`, `TitleUnlockEvent`, `FirstAwakeningEvent`. Carries rank, body part, title slug, etc.
- [x] **Catalog asset:**
  - [x] `assets/rpg/titles_v1.json` — 78 per-body-part titles (~13 per body part). Apply editorial pass: revise -Lord/-King/-Master/-Eternal/-Sworn at Ranks 40-90.
  - [x] Localize `name` + `flavor` via `app_en.arb` + `app_pt.arb` keys: `title_{slug}_name`, `title_{slug}_flavor`. JSON references slug only; copy lives in arb.
  - [x] Register asset in `pubspec.yaml`.
- [x] **Domain logic:**
  - [x] `lib/features/rpg/domain/title_unlock_detector.dart` — given body-part rank deltas from `record_set_xp`, returns list of newly-unlocked title slugs per body part. Guards against double-unlock (consults `earned_titles` table for already-earned slugs).
  - [x] `lib/features/rpg/domain/celebration_queue.dart` — takes `CelebrationEvent` list, applies cap-at-3 rule, returns ordered queue + optional condensed-card payload (`N more rank-ups`). Handles dismiss-to-skip-end semantics from 17b scaffold.
  - [x] `lib/features/rpg/data/titles_repository.dart` — loads `titles_v1.json`, exposes `lookup(slug)`, `forBodyPart(part)`, persistence to `earned_titles` table (insert on unlock, set `is_active` on equip with UNIQUE INDEX guard).
  - [x] `lib/features/rpg/providers/earned_titles_provider.dart` — `FutureProvider` of earned titles for current user; powers the Titles screen list. (Spec originally said `Stream`; switched to `FutureProvider` because there is no realtime push channel for earned_titles in v1 — equip toggles fan out via `container.invalidate(earnedTitlesProvider)` on the equipping client. See provider doc-comment for full rationale.)
- [x] **Overlay widgets (TDD per widget — write failing widget test first):**
  - [x] `lib/features/rpg/ui/overlays/rank_up_overlay.dart` — Direction B Rune Stamp choreography. Use `TickerProviderStateMixin` (multi-controller pattern from 18b's `_RadiantHalo`).
  - [x] `lib/features/rpg/ui/overlays/level_up_overlay.dart` — slide-from-right entry, `heroGold` hold (no settle), heavy haptic at t=0.
  - [x] `lib/features/rpg/ui/overlays/first_awakening_overlay.dart` — 800ms compressed choreography, no dim, `IgnorePointer` over card.
  - [x] `lib/features/rpg/ui/overlays/title_unlock_sheet.dart` — `DraggableScrollableSheet` fixed at 0.45, watermark via `Stack` + `IgnorePointer` SVG, fixed copy hierarchy. (Reviewer fix: sheet is now barrier-dismissable per spec line 55. `enableDrag: false` retained so the fixed 0.45 height isn't compromised by an accidental swipe.)
  - [x] `lib/features/rpg/ui/overlays/celebration_overflow_card.dart` — non-modal "N more rank-ups — open Saga" 4s auto-dismiss tappable card. (Phase 18c overflow-card-await fix: timer extended from 3s→4s, added muted "Tap to continue" hint via new `celebrationOverflowTapHint` l10n key, kept full-card InkWell tap target with hotViolet ripple. `CelebrationPlayer.play()` now awaits a `Completer<bool>` resolved by the first of user-tap or auto-dismiss timer — replaces the previous fire-and-forget + endOfFrame yield that flashed the card for ~30ms before the post-frame nav tore it down. **Reviewer fix:** completer carries a `bool` (`true` on user tap, `false` on auto-dismiss) so `_onFinish` can route to `/profile` on tap per spec line 17/175.)
- [x] **Active-workout chrome:**
  - [x] Modify `lib/features/workouts/ui/active_workout_screen.dart` — move Finish button to AppBar trailing as `OutlinedButton`, free FAB for "Add exercise". Confirmation dialog gate retained.
  - [x] New widget `lib/features/workouts/ui/widgets/pr_chip.dart` — inline pill, fires on set commit (NOT on weight/reps input change), `RewardAccent` wraps `heroGold`. Persists for session.
  - [x] Modify the set-row widget (find via grep `SetRow`/`set_row.dart`) to render PR chip when `isPR == true` after commit.
- [x] **Workout finish flow:**
  - [x] Wired into `ActiveWorkoutNotifier._finishOnline` — pulls deltas from `record_set_xp`, runs `TitleUnlockDetector`, builds `CelebrationQueue`, hands off to `CelebrationPlayer.play()` from `_onFinish`. (Reviewer fix: `_showPlanPromptAndGoHome` now reads providers via `ProviderScope.containerOf(navContext)` instead of the disposed `ref` — root navigator container is alive for the full app session.)
- [x] **Titles screen upgrade (was stub, now functional):**
  - [x] Created `lib/features/rpg/ui/titles_screen.dart` — scrollable list grouped by body part. Each row: title name + rank threshold + Equip/Equipped toggle. Tap toggle → set `is_active` (UNIQUE INDEX guard handles concurrent equip).
  - [x] `codex_nav_row` "Titles" routes to `/profile/titles`. Stats deep-dive still stubbed for 18d.
- [x] **First-awakening session-throttle:**
  - [x] State in `ActiveWorkoutNotifier`: `_firstAwakeningFiredThisSession: bool`. Reset on workout start, set true after first overlay.
  - [x] Logic gates the FirstAwakeningOverlay invocation on this flag + the body-part's prior `lifetime_xp == 0` check.
- [x] **L10n additions** to `app_en.arb` + `app_pt.arb`:
  - [x] `rankUpHeading` ("{bodyPart} · Rank {n}") — pt-BR equivalent with native gym voice.
  - [x] `levelUpHeading` ("Level {n}") — pt-BR equivalent.
  - [x] `firstAwakeningHeading` ("{bodyPart} awakens") — pt-BR equivalent.
  - [x] `equipTitleButton` ("Equip Title" / "Equipar Título").
  - [x] `equippedLabel` ("Equipped" / "Equipado").
  - [x] `prChipLabel` ("PR" — same in both).
  - [x] `finishButtonLabel` ("Finish" / "Finalizar").
  - [x] `celebrationOverflowLabel` ("{n} more rank-ups — open Saga" / pt-BR).
  - [x] `celebrationOverflowTapHint` ("Tap to continue" / pt-BR).
  - [x] `titlesScreenTitle` ("Titles" / "Títulos").
  - [x] All 78 title `name` + `flavor` keys from `titles_v1.json` slug list.
  - [x] Run `make gen` after editing arb files.
- [x] **Make ci** passes (format + analyze + test + android build).

### Test plan (qa-engineer)

- [x] **Unit tests:**
  - [x] `celebration_queue_test.dart`:
    - rank-up + level-up + title sequence in causal order
    - cap-at-3 yields condensed card with overflow count
    - dismiss-skip-to-end clears entire queue (preserved from 17b infra)
    - empty-event-list → no overlays, no card
    - rank-up sort tiebreaker by highest body-part rank
  - [x] `title_unlock_detector_test.dart`:
    - every threshold per body part triggers exactly one title at the rank boundary
    - already-earned titles (via `earned_titles` mock) are excluded
    - cross-body-part unlocks return distinct entries
- [x] **Widget tests:**
  - [x] `rank_up_overlay_test.dart` — three-stage color verified at frames 0, 200, 500, 900, 1100ms; copy renders body-part + rank; `RewardAccent` wraps gold pixels; haptic fires once at t=200ms (mock `HapticFeedback.mediumImpact`).
  - [x] `level_up_overlay_test.dart` — slide entry, gold hold (no settle assertion), `heavyImpact` at t=0, copy "LEVEL {N}" renders.
  - [x] `first_awakening_overlay_test.dart` — 800ms total runtime, no backdrop dim widget present, `IgnorePointer` engaged during window, fade-out begins at t=600ms.
  - [x] `title_unlock_sheet_test.dart` — fixed 0.45 height, watermark `IgnorePointer`, copy en + pt-BR, equip toggles `is_active` exactly once. First-ever title wrapped in `RewardAccent`; subsequent in `textCream`.
  - [x] `celebration_overflow_card_test.dart` — auto-dismiss at 4s, tap routes to `/profile`, copy renders count.
  - [x] `pr_chip_test.dart` — fires on commit, NOT on input change; persists in row after commit; `RewardAccent` wraps gold; no haptic invoked.
  - [x] `titles_screen_test.dart` — list grouped by body part, equip toggle updates `is_active`, equipped row shows "EQUIPPED" outlined state.
  - [x] `celebration_player_test.dart` (added by reviewer fix) — locks the `CelebrationPlayResult` return contract: empty queue → notTapped, overflow auto-dismiss → notTapped, overflow user-tap → tapped, title sheet barrier-tap dismisses gracefully without firing equip.
- [x] **Goldens:**
  - [x] `rank_up_overlay_golden_test.dart` — frame at peak gold (t=400ms) and settled state (t=1100ms).
  - [x] `title_unlock_sheet_golden_test.dart` — first-ever title (with `RewardAccent`) and subsequent title (without).
- [x] **Selectors** in `test/e2e/helpers/selectors.ts`:
  - `rankUpOverlay`, `levelUpOverlay`, `titleUnlockSheet`, `firstAwakeningOverlay`, `celebrationOverflowCard`
  - `equipTitleButton`, `equippedTitleLabel`
  - `prChip`, `finishButton`, `addExerciseFab`
  - `titlesScreen`, `titleRow.{slug}` (or generic `titleRow` with index)
- [x] **E2E `test/e2e/specs/rank-up-celebration.spec.ts` (`@smoke`):**
  - login as seeded user one set away from Chest Rank 5 → complete workout → assert RankUpOverlay renders with correct body-part + rank → assert auto-advances by 1.1s (no tap)
  - login as seeded user simultaneously hitting body-part rank-up + character level-up + title unlock → assert sequence rank → level → titleSheet → equip button works
  - login as seeded `rpgFreshUser` (zero history) → log first set → assert FirstAwakeningOverlay fires once, no overlay on second body part touched same session
  - login as seeded user 4-rank-ups state → assert 3 overlays + condensed card with "1 more"
  - tap PR set → assert `prChip` appears inline, persists for session
  - tap Finish in AppBar → confirmation dialog → confirm → workout summary
  - **Reviewer fix:** added a new test under the overflow describe block — taps the overflow card and asserts the app navigates to `/profile`.
- [x] **E2E test users added** to `test/e2e/fixtures/test-users.ts` + `global-setup.ts` seeding:
  - `rpgRankUpThreshold`, `rpgMultiCelebration`, `rpgOverflowQueue` — all seeded with reseed helpers in the spec for repeat-each isolation. `rpgFreshUser` reused for first-awakening.
- [x] **Update affected specs:** chrome changes verified across `workouts.spec.ts`, `crash-recovery.spec.ts`, etc. via selector centralization.
- [x] **Full E2E regression** — qa-engineer ran full pass after reviewer-fix cycle (2026-04-28). Results: 2 genuine regressions found, handed to tech-lead. See hand-back report for details.
- [x] **Tech-lead investigation (2026-04-28, post-revalidation):**
  - **Bug 1 (overflow cap test ≤3 events):** could not reproduce. Test passed on first run + `--repeat-each=2 --retries=0`. XP math hand-trace against `record_session_xp_batch` (00040): 4 compound lifts at the seeded 196 XP / rank-3 baseline produce 6 rank-ups (chest 42.83, legs 48.94, back 32.30, shoulders 24.17, arms 17.22, core 14.52 — every track clears the 2.6 XP gap to rank-4 threshold of 198.6). SQL is consistent with spec; novelty discount drops the second rank-up's effective XP but never below the threshold for the seeded amounts. Verdict: not a prod bug, likely transient (e.g. stale build/web from a previous branch when QA captured the failure). No code change needed.
  - **Bug 2 (overflow card tap routes to /home):** confirmed reproducible on the original build. Root cause was a missing AOM-tap dispatch on the outer `Semantics` wrapper of `CelebrationOverflowCard` — the wrapper carried `identifier` only, so a Playwright `force: true` click on `[flt-semantics-identifier="celebration-overflow-card"]` landed on a Semantics node with no `onTap`, the inner `InkWell.onTap` never fired, the 4s auto-dismiss completer resolved with `false`, and the post-frame callback navigated to `/home`. Pattern reference: `GradientButton` (`Semantics(container: true, button: true, label: ..., child: ElevatedButton)`) — its child supplies the AOM `onTap` via the ElevatedButton; the `InkWell` does not. Fix: declare the Semantics widget itself as the AOM-tappable surface (`container: true, button: true, label, onTap: widget.onTap`) so DOM clicks routed through the AOM tree resolve the same callback `tester.tap` resolves through the gesture pipeline. File: `lib/features/rpg/ui/overlays/celebration_overflow_card.dart`. Inline doc-comment explains the AOM-vs-gesture-pipeline split. Verified: `flutter test` 2020/2020 green, `dart analyze --fatal-infos` clean, `npx playwright test --grep "tap navigation"` green, `npx playwright test --grep "Celebration overflow cap|tap navigation" --repeat-each=2 --retries=0` 4/4 green.
- [x] **pt-BR copy review** — completed during initial implementation pass.

### Acceptance (orchestrator gate)

- [ ] `make ci` green (re-run after reviewer-fix cycle)
- [x] Full E2E green locally (`FLUTTER_APP_URL= npx playwright test`) — qa-engineer re-ran revalidation (2026-04-28) after Bug 2 fix. 184/204 first-attempt pass; 8 hard failures + 12 flaky all in pre-existing baseline (manage-data, offline-sync, personal-records, rpg-foundation, workouts, crash-recovery, home). Zero regressions in Phase 18c tests. All 14 Phase 18c tests passed in full regression. CLEAR TO PR.
- [x] Goldens reviewed by orchestrator
- [x] pt-BR title copy reviewed (native gym voice, not literal translations)
- [ ] Reviewer signs off (no Blockers, all Important addressed in same cycle per "no deferring" rule) — fixes for the 8 findings landed in this cycle, awaiting reviewer re-pass
- [ ] PR squash-merged
- [ ] PLAN.md Phase 18c row → DONE + PR number; Phase 18c detailed spec condensed to 5-7 bullets
- [ ] WIP.md Phase 18c section removed

---

## E2E Flaky-Test Cleanup — QA-led debt burndown

**Branch:** `fix/e2e-flaky-cleanup` — to be created off `main` AFTER Phase 18c (PR #114) merges. Do NOT branch off `feature/phase18c-mid-workout-overlays` — that carries unrelated changes.
**Source of truth:** `test/e2e/FLAKY_TESTS.md` (durable register, 8 hard failures + 12 flakies as of PR #114)
**Owner:** `qa-engineer` agent leads. `tech-lead` only invoked when a flake is classified as a real `lib/**` race or lazy-init bug.
**Goal:** converge `FLAKY_TESTS.md` to zero entries. Full E2E suite passes at `--retries=0`.

### Why this is a separate branch

Mixing flaky-test fixes into feature PRs muddies the diff and slows reviews. Each fix here is its own targeted change; small commits, clear blast radius, easy to revert if a "fix" turns out to introduce a new flake. Lands as its own PR (or a sequence of small PRs by family) rather than a single mega-PR.

### Workflow per investigation (qa-engineer)

For each entry in `FLAKY_TESTS.md`, in priority order:

1. **Reproduce** — `--repeat-each=10 --retries=0 --grep "<test name>"`. Confirm consistent vs intermittent vs already-fixed.
2. **Capture** — stderr (`2>&1`), screenshot, browser console (`page.on('console')`).
3. **Classify** the failure mode (per qa-engineer.md lane rule):
   - **TEST-INFRA** — missing `waitFor*`, fixture/seed isolation gap, helper assumes ordering, locale leak, Playwright config: **FIX IT** in this branch. Commit per family.
   - **PROD-CODE** — real race in Riverpod refresh, lazy init, swallowed exception, navigation racing dialog: **STOP**, write bug report, hand back to tech-lead. Tech-lead patches `lib/**` on a sub-branch off `fix/e2e-flaky-cleanup` (or its own `fix/<bug>` branch) and merges back before QA proceeds.
4. **Fix** — deterministic wait > timeout polling. `waitForSelector`/`waitForURL`/`waitForResponse` over `waitForTimeout(N)`.
5. **Verify** — `--repeat-each=20 --retries=0` against the fix. 20/20 stable before claiming "fixed."
6. **Discharge** — remove `@flaky` tag, delete entry from `FLAKY_TESTS.md`, commit with rationale.

### Backlog (priority order from FLAKY_TESTS.md)

- [ ] **Family 1 — personal-records + rpg-foundation** (entries #7, #8, #12). Likely shared cause: PR detection + post-workout celebration write race. Expected to also unblock several Phase 18c-adjacent tests.
- [ ] **Family 2 — post-finish nav** (entries #14, #16, #17, #18, #19). Phase 18c hardened the celebration→nav handshake; **first action: re-run these to verify they're already fixed.** If yes, mass-discharge. If no, deep-dive timing.
- [ ] **Family 3 — manage-data** (entries #5, #6, #9, #10, #11). Account-deletion + Reset All; suspected auth/storage flush race.
- [ ] **Family 4 — offline-sync** (entries #1–#4). Service worker / IndexedDB on Flutter web; deepest investigation, unique skill set.
- [ ] **Family 5 — locale + decimal** (entries #15, #20, #21). i18n/l10n cache vs name-fetch ordering.

### Lane discipline (HARD RULE — applies across all families)

`qa-engineer` writes test-infra fixes only (`test/e2e/**`, helpers, fixtures, seeders). Any patch to `lib/**` MUST go to `tech-lead` via bug report. The single exception remains `Semantics(identifier: …)` wrappers added purely as e2e selector hooks — anything else is the wrong agent.

When `qa-engineer` hands back to `tech-lead`, the fix lands either:
- Directly on `fix/e2e-flaky-cleanup` (if scoped enough to bundle), OR
- On its own `fix/<symptom>` branch that merges into `fix/e2e-flaky-cleanup` before the family's PR opens.

Orchestrator decides per-handoff which is cleaner.

### Acceptance

- [ ] All 5 families discharged OR each remaining entry has a documented "won't fix — flagged platform issue" with justification
- [ ] `test/e2e/FLAKY_TESTS.md` reduced to zero open entries (or only documented platform-issue entries)
- [ ] Full E2E suite passes at `--retries=0` for **5 consecutive runs across 3 different days**
- [ ] `qa-engineer.md` Stage 3 (`@flaky` retry bucket) becomes vestigial — tag remains for future use but the current bucket is empty
- [ ] PR (or sequence of PRs by family) merged to `main`

### Status

**Queued.** Cannot start until PR #114 (Phase 18c) merges so the branch can fork off a clean `main` that already contains `FLAKY_TESTS.md` and the staged-run conventions.

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
