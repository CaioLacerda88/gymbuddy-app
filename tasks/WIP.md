# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## E2E Flaky-Test Cleanup — QA-led debt burndown

**Branch:** `fix/e2e-flaky-cleanup` (created 2026-04-28 off post-PR-#115 main).
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

**Active (started 2026-04-28).** Branch `fix/e2e-flaky-cleanup` forked from main at commit `2bc5064` (post PR #115). Working order:

1. **Family 2 verify** (in progress) — re-run #14, #16, #17, #18, #19 at `--retries=0`. Phase 18c hardened the celebration→nav handshake so several of these may already be green; mass-discharge what's already fixed.
2. **Family 1 deep work** — personal-records + rpg-foundation (#7, #8, #12). Investigate the PR-detection / post-workout celebration write race.
3. **Family 3 / 4 / 5** — manage-data, offline-sync, locale+decimal, in priority order.

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
