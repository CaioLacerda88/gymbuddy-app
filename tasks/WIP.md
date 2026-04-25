# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Phase 15f — Exercise Content Localization

**Branch:** `feature/phase15f-exercise-content-localization`
**Spec:** `docs/superpowers/specs/2026-04-24-exercise-content-localization-design.md`
**Plan:** PLAN.md → "Phase 15f: Exercise Content Localization"
**Approach:** Subagent-Driven execution (two-stage review per stage: spec compliance → code quality)

### Stage tracker

- [x] **Stage 1** — Foundation migrations (tech-lead) ✅
  - [x] `supabase/migrations/00030_add_exercise_slug.sql` (slug + 150 hardcoded UPDATEs + defensive INSERT trigger)
  - [x] `supabase/migrations/00031_create_exercise_translations.sql` (table + 5 RLS policies + soft-delete guard)
  - [x] `supabase/migrations/00032_backfill_exercise_translations_en.sql`
  - [x] Removed redundant `supabase/seed.sql` (now blocked by unique slug index)
  - [x] Spec compliance review pass
  - [x] Code quality review pass (3 fixes applied: deleted_at guard, diagnostic asserts, comment phrasing)
- [x] **Stage 2** — pt-BR glossary (human-gated) ✅
  - [x] `docs/superpowers/specs/phase15f-pt-glossary.md` drafted (commit 3d80fa7)
  - [x] User approval recorded 2026-04-24
- [x] **Stage 3** — pt-BR seed migration (tech-lead) ✅
  - [x] Read EN content sources (00010 + 00020) and ARB names (`app_pt.arb`)
  - [x] Draft 150 pt-BR `(name, description, form_tips)` tuples per glossary §1 + §5
  - [x] Write `supabase/migrations/00033_seed_exercise_translations_pt.sql`
  - [x] Verify locally: `supabase db reset` clean; pt count = 150; spot-check 5 rows
  - [x] Spec compliance review pass (Critical box_jump conflict + typo fixed in `a14f424`)
  - [x] Code quality review pass (Important assert tightening + Nit JOIN reorder fixed in `8b5bd11`)
  - [x] Commits: `8f6da7c` initial, `a14f424` spec fixes, `8b5bd11` quality fixes
- [ ] **Stage 4** — RPCs + column drop (tech-lead)
  - [x] `supabase/migrations/00034_drop_exercise_name_columns_and_add_rpcs.sql`
  - [x] `scripts/emergency_rollback_15f.sql`
  - [x] Local sanity: db reset clean; 4 RPCs present; 150 default exercises returned; pt/en cascade verified; auth/dup/cap edge cases raise correct SQLSTATEs
  - [x] Rollback round-trip verified (apply → rollback → re-apply clean; 151 rows restored without NULL)
  - [ ] Reviews pass
- [ ] **Stage 5** — CI translation coverage (tech-lead)
  - [ ] `scripts/check_exercise_translation_coverage.sh` + fixtures
  - [ ] `scripts/verify_prod_translation_invariants.sh`
  - [ ] CLAUDE.md section updated
  - [ ] Reviews pass
- [ ] **Stage 6** — Data layer refactor (tech-lead)
  - [ ] `test/fixtures/rpc_fakes.dart`
  - [ ] `ExerciseRepository` rewrite + unit tests
  - [ ] `WorkoutRepository` two-query merge + unit tests
  - [ ] `PRRepository` two-query merge + unit tests
  - [ ] `RoutineRepository` two-query merge + unit tests
  - [ ] Locale-keyed Hive cache + `LocaleNotifier.setLocale` cache-clear
  - [ ] `exercise_l10n.dart` dead code deletion
  - [ ] `exerciseName_*` ARB key deletion + `flutter gen-l10n`
  - [ ] Reviews pass
- [ ] **Stage 7** — Widget + E2E (qa-engineer)
  - [ ] `EXERCISE_NAMES` map in `test/e2e/fixtures/test-exercises.ts`
  - [ ] 4 new pt test users + slug-based global-setup seeds
  - [ ] 14 E2E scenarios A1-G2
  - [ ] Widget tests with localeProvider overrides
  - [ ] Full E2E suite green (145+)
- [ ] **Stage 8** — Staging verify + review + merge
  - [ ] Migrations applied to staging
  - [ ] Invariant queries zero; outputs in PR body
  - [ ] Full E2E on staging
  - [ ] Human pt-BR reviewer skim of 150 rows
  - [ ] Rollback script dry-run on staging clone
  - [ ] Reviewer agent pass
  - [ ] Squash-merge
- [ ] **Stage 9** — Prod cut-over
  - [ ] `npx supabase db push` to hosted
  - [ ] Invariant queries zero on prod
  - [ ] Manual locale smoke passes
  - [ ] Condense Phase 15f in PLAN.md
  - [ ] Update progress table (15f DONE)
  - [ ] Remove this WIP section

### Quality gates

Each of Stages 1, 3, 4, 5, 6 goes through:
1. Implementer (tech-lead) reports DONE
2. Spec compliance review (reviewer agent)
3. Fix + re-review if gaps
4. Code quality review (reviewer agent)
5. Fix + re-review if issues
6. Mark stage complete

Stage 7 goes through qa-engineer's own test gates + reviewer pass.

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
