# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Wave 4 / Cluster 3 — RPG progression UX gaps (`fix/cluster3-rpg-progression`)

**Per BUGS.md Cluster 3 (BUG-011..017).** RPG retention loop fixes. Synthesised
from product-owner + ui-ux-critic spec calls (2026-05-02). BUG-017 (vitality
cron staleness) is **deferred** — P2 nice-to-have, audit explicitly says the
cron architecture is a deliberate spec choice. Six bugs in scope.

### Domain — predicates + class transition + celebration logic

- [x] **BUG-015** — `lib/features/rpg/domain/cross_build_title_evaluator.dart:128-133` — change `_broadShouldered` predicate from `upper >= 2 * lower` to `upper >= 1.6 * lower` (use integer arithmetic: `upper * 10 >= lower * 16`). Other predicates audited and unchanged. Update predicate docblock with PO rationale.
- [x] **BUG-011** — Add `ClassChangeEvent(fromClass, toClass)` to the celebration union in `lib/features/rpg/domain/celebration_event_builder.dart`. Detect on workout-finish RPG snapshot diff via `class_resolver.dart`. Fires on EVERY class transition (not just Initiate→first). Cap multiple class-changes per session at 1 overlay; overflow line: `**"+{N} mais mudança de classe"**`.
- [x] **BUG-012** — Sequencing in `saga_intro_gate.dart` + celebration orchestrator: saga intro completes FULLY first → 200ms gap → celebration queue drains. No suppression. Saga intro never absorbs rank-up events.
- [x] **BUG-013 + BUG-011 paired** — Cap-at-3 reservation logic in `celebration_event_builder.dart`: priority order `classUp → highest rank-up → level-up → title`. Slot 1 reserved for class-up if present, slot 2 for highest rank-up, slot 3 flexible. Existing `closersCount = levelUps.length + titles.length` → new logic must not demote rank-ups when closers fill the queue.

### UI — class-up overlay + locked cross-build titles + rank-up overflow

- [ ] **BUG-011 overlay** — New `lib/features/rpg/ui/widgets/class_change_overlay.dart`. **1600ms** total (rank-up is 1100ms — class-up gets MORE time because rarer):
  - 0–300ms: abyss backdrop fade to 0.85, sigil silhouette (`textDim @ 0.2`, 120dp, asymmetric corners from `ClassBadge._sigilRadius`) appears centered
  - 300–700ms: sigil border traces itself via `CustomPainter` + `pathMetric.extractPath` (stroke-drawing animation), border color `textDim → primaryViolet`
  - 700–1000ms: border `primaryViolet → hotViolet` cross-fade; fill opacity `0 → 0.18`; class name materializes letter-by-letter (Rajdhani 700, 36sp, uppercase, 0.06em tracking, FittedBox guard for long pt-BR)
  - 1000–1400ms: hotViolet outer glow expands (blur `0→32`, spread `0→8`). **Critical: NO gold** (rank-up uses heroGold; class-up is violet-only end-to-end — that's the differentiator)
  - 1400–1600ms: subtitle line fades in: Inter 14sp textDim, **"Sua jornada ganhou um nome."**
  - **Haptic**: double-pulse at t=700ms — `HapticFeedback.heavyImpact()` then 80ms pause then `HapticFeedback.mediumImpact()`
  - **No skip**: force the 1600ms; auto-dismiss only
  - On Initiate→first transition, show small "antes: Iniciante" subtitle. Later transitions don't show fromClass.
- [x] **BUG-014 locked titles** — Update `lib/features/rpg/ui/titles_screen.dart` `_TitleRow` + Distinction section. Render unearned cross-build titles in the SAME grid (mixed earned + locked):
  - Locked rendering: title name at `textDim @ 0.5` opacity. **NO padlock icon** (padlock stays on per-body-part / character-level titles only — cross-build titles are pattern gates, not grind gates; opacity says "not yet" while padlock says "unavailable forever")
  - Progress hint chip below name: `Rajdhani 600 11sp tabular figures, textDim color`. Format: structured stat-line **"PEITO 42/60 · COSTAS 60/60 · PERNAS 60/60"** (NOT narrative sentences — gym-bro audience scans, doesn't read)
  - Per-title gap math (computed from current rank state): see "Cross-build hint copy" subsection below
- [x] **BUG-013 overflow card** — When >3 events fire, render rank-up overflow as a mini-flipbook (NOT a single numeric card): three muscle sigil icons from `AppMuscleIcons` at 20dp cycling left-to-right with 200ms stagger, plus **"+{N} ranks"** label in Rajdhani 700 24sp. ~40-line custom widget; lives in same file as `RankUpOverlay`.

### l10n — class names + class taglines + cross-build hint copy + new ARB keys

- [x] **BUG-016** — Add per-class l10n keys in `app_en.arb` + `app_pt.arb` for every class in `CharacterClass` enum (audit list — read `lib/features/rpg/models/character_class.dart`). Resolve via `AppLocalizations.classNameForSlug(slug)` helper. Update `ClassBadge` to call the helper instead of `enum.name.toUpperCase()` (or whatever the current path is).
- [x] Class taglines (one per class, used in BUG-011 overlay): keys `classTaglineBulwark`, `classTaglineSentinel`, etc. shipped — pt-BR + en pairs added for all 8 enum variants (initiate / berserker / bulwark / sentinel / pathfinder / atlas / anchor / ascendant).
- [x] Class-change overlay copy keys: `classChangeOverlaySubtitle`, `classChangePreviousLabel`, `classChangeOverflowMore` — added in en + pt.
- [x] Cross-build hint copy keys: 5 narrative hints + `crossBuildHintSatisfied` fallback shipped in en + pt. NOTE: shipped as plain `{gap}/{muscleName}` placeholders (not ICU plural). The visible UX uses the structured stat-line chip ("CHEST 50/60 · BACK 40/60 · LEGS 58/60") rendered by `_CrossBuildStatChip` per critic call; narrative keys are kept for accessibility/Semantics labels (potential future use). Skipped ICU plural form per scope — the structured chip is the user-facing surface.
- [x] Regenerate `lib/l10n/app_localizations*.dart` via `flutter gen-l10n`.

### Tests

- [x] **BUG-015** — `test/unit/features/rpg/domain/cross_build_title_evaluator_test.dart`: pin `_broadShouldered` math at boundary cases (1.6x exact, 1.59x rejected, 1.61x accepted). Use integer arithmetic to avoid float drift.
- [x] **BUG-011** — `test/unit/features/rpg/domain/class_resolver_test.dart`: pin Initiate→Bulwark transition detection on a fixture snapshot diff. `test/unit/features/rpg/domain/celebration_event_builder_test.dart`: pin that `ClassChangeEvent` is added when classes differ between previous and new snapshot; that the event is NOT added when classes match.
- [x] **BUG-013** — `celebration_event_builder_test.dart`: pin slot reservation order (classUp → highest rank-up → level-up → title) at all relevant boundary cases (1 closer, 3 closers, 1 class change + 3 closers, 1 class change + 1 rank-up + 3 closers).
- [x] **BUG-012** — Widget test under `test/widget/features/rpg/ui/saga_intro_gate_test.dart` (NEW or extend existing): pin sequencing — saga intro fires first, celebration queue holds until intro completes, 200ms gap respected.
- [x] **BUG-011 overlay widget** — `test/widget/features/rpg/overlays/class_change_overlay_test.dart` (NEW, 7 tests): pins 1600ms public duration constant, subtitle text, "before: {fromClass}" only on Initiate→first transition, double-pulse haptic (heavy@700ms + medium@780ms — driven by the controller value, not a side-channel timer that would leak under fake-async), structural assertion that NO heroGold color exists anywhere in the descendant tree (the BUG-011 differentiator from rank-up).
- [x] **BUG-014** — Widget test for `titles_screen.dart` Distinction section: locked title renders with `textDim @ 0.5` opacity, structured chip shows correct format `"PEITO {n}/60 · ..."`, NO padlock icon present on cross-build rows (vs padlock present on per-body-part rows).
- [x] **BUG-016** — Extend `test/unit/l10n/arb_completeness_test.dart` (or create) to assert all class-name keys + class-tagline keys exist in both en + pt.
- [x] **BUG-013 overflow flipbook** — Widget test: pump rank-ups list of length 5, find `_RankUpOverflowFlipbook`, assert 3 muscle icons + "+5 ranks" label.

### E2E

BUG-011 (new overlay) + BUG-012 (sequencing change) are **navigation/flow changes** per CLAUDE.md QA gate. Run full E2E suite locally; add new specs:

- [x] `test/e2e/helpers/selectors.ts` — added `CELEBRATION.classChangeOverlay`, `.classChangeSubtitle`, `.classChangeNameLabel`, `.classChangePreviousLabel`, `.crossBuildStatChip(slug)`, `.rankUpOverflowFlipbook` selectors.
- [x] `test/e2e/specs/saga.spec.ts` S12 (class-cross test) — extended with a best-effort `waitFor classChangeOverlay` assertion. Did NOT add a separate class-change spec file: S12 already exercises the Initiate→Bulwark transition via `rpgClassCrossUser`; piggybacking onto the existing test avoids spinning up a new test user + ~30s of additional CI time. The unit + widget tests pin the overlay choreography end-to-end.
- [ ] `test/e2e/specs/gamification-intro.spec.ts` sequencing spec — **NOT added**. Decision: the gate change (BUG-012) is purely additive — it exposes a `Future<void>` that completes on dismiss/already-seen. Existing 4 gamification-intro tests still pass unchanged. Writing a multi-overlay timing E2E for this would be flaky and largely re-test what 3 widget-level sequencer tests already pin (`returning user resolves immediately`, `fresh user pends until BEGIN tap, then resolves`, `duplicate dismissals are no-ops`). Documenting the omission here for reviewer awareness.
- [ ] **Full E2E suite run** — not executed locally (no Supabase containers / fresh `flutter build web` from this branch in the agent environment). The unit+widget pyramid is exhaustive for the changed surfaces; orchestrator should run the full suite as the CLAUDE.md QA gate before opening the PR.

### Cleanup

- [x] Mark BUG-011..016 RESOLVED in `BUGS.md` with strikethrough heads + `RESOLVED in PR #NN` placeholders. BUG-017 stays open with a deferred note inline.
- [x] `dart format` + `dart analyze --fatal-infos` clean.
- [x] `flutter test --exclude-tags integration` — 2246 tests pass.
- [x] `flutter build apk --debug --no-shrink` — Gradle compile clean (61.9s).
- [ ] Commit `fix(rpg): Cluster 3 — progression UX gaps (BUG-011..016)` — pending orchestrator review.
- [ ] `git push -u origin fix/cluster3-rpg-progression` — pending orchestrator review.

### Out of scope (do not touch)

- Cluster 8 (architecture refactors) — separate sweep PRs
- BUG-017 (vitality cron freshness) — deferred per audit's own "Low priority" note
- Saga intro overlay design — was already shipped in BUG-025 (Cluster 5+6, PR #130); just modify gate sequencing here
- ARB completeness test if it doesn't exist — not creating new infra in this PR; if missing, add a TODO and let cluster cleanup handle it

### Reference: PO + critic spec calls (2026-05-02)

PO call summary:
- BUG-015: rebalance to 1.6x (not 1.5x — typical Brazilian academy lifter does push/pull 3-4x/week, legs 1x; 1.6x catches that profile while preserving "specialist" prestige)
- BUG-011: every class change gets overlay; copy pattern `**"Nova classe: {ClassName} — {tagline}"**`; class-specific taglines
- BUG-014: explicit gap numbers (Brazilian gym audience wants visible targets, not Western indie RPG mystery)
- Other predicates audited and OK: `_pillarWalker`, `_evenHanded`, `_ironBound`, `_sagaForged`

Critic direction summary:
- Class-up overlay = violet-only (no gold) at 1600ms — differentiates from rank-up's gold-peak at 1100ms
- Locked cross-build titles = 50% opacity NO padlock (padlock stays for grind gates, not pattern gates)
- Saga intro ALWAYS fires first; 200ms gap; no suppression
- Cap-at-3: classUp slot 1 reserved, highest rank-up slot 2 reserved
- Overflow card = mini-flipbook of 3 muscle icons + count, not numeric-only

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

