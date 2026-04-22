# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## refactor/rebrand-repsaga — rename GymBuddy → RepSaga across codebase

**Branch:** `refactor/rebrand-repsaga`
**Why:** `com.gymbuddy.app` is taken on Play Store. After a BR-market-aware naming
exercise (see chat history), the brand is now **RepSaga** (package `com.repsaga.app`).
This rename unblocks Play Console app creation, which in turn unblocks Phase 16a
Stages 1.3, 3.4, 4, and 5.3. PO analysis: RepSaga has virgin Play namespace,
strong Phase 17 gamification fit (MMO vocabulary), available domains + handles,
and avoids the VW Jornada namespace collision on BR Play Store.

**Scope:** Everything in the repo. External service renames (GCP display name,
Supabase project name, Play app creation, Pub/Sub topic rename, domain/handle
locking) are handled by the user out-of-band.

### Tasks

- [x] **pubspec.yaml**: `name: gymbuddy_app` → `name: repsaga`; update `description`
- [x] **Dart imports**: global find-replace `package:gymbuddy_app/` → `package:repsaga/` across `lib/` and `test/`
- [x] **Android `applicationId`**: `com.gymbuddy.app` → `com.repsaga.app` in `android/app/build.gradle.kts`
- [x] **Android `namespace`**: `com.gymbuddy.app` → `com.repsaga.app`
- [x] **Android MainActivity**: move `android/app/src/main/kotlin/com/gymbuddy/app/MainActivity.kt` → `com/repsaga/app/MainActivity.kt` and update `package` declaration
- [x] **Android deep-link scheme**: `AndroidManifest.xml` `android:scheme="io.supabase.gymbuddy"` → `io.supabase.repsaga`
- [x] **Android label**: `AndroidManifest.xml` `android:label="GymBuddy"` → `"RepSaga"`
- [x] **Dart auth redirect URL**: `lib/features/auth/data/auth_repository.dart` `io.supabase.gymbuddy://login-callback/` → `io.supabase.repsaga://login-callback/`
- [x] **l10n ARB files**: `lib/l10n/app_en.arb` + `app_pt.arb` — `appName` and any user-facing mentions (`crashReportsSubtitle`)
- [x] **Regenerate l10n**: `flutter gen-l10n` to refresh `app_localizations*.dart`
- [x] **App title in `lib/app.dart`**: `title: 'GymBuddy'` → `'RepSaga'`
- [x] **web/manifest.json**: `name`, `short_name`, `description`
- [x] **supabase/config.toml**: `project_id = "gymbuddy-app"` → `"repsaga"` (Supabase project ref stays; this is the local-dev identifier)
- [x] **Edge Function test fixtures**: `packageName: 'com.gymbuddy.app'` → `'com.repsaga.app'` in `validate-purchase/test.ts`, `rtdn-webhook/test.ts`, `_shared/google_play.test.ts`
- [x] **Subscription product ID**: `gymbuddy_premium` → `repsaga_premium` in the same test files + code comments in `validate-purchase/index.ts`
- [x] **Email templates** (`supabase/email_templates.sql`): brand mentions in comments + HTML samples
- [x] **Seed/migration comments**: update header comments in `supabase/seed.sql`, `migrations/00001_initial_schema.sql`, `email_templates.sql`
- [x] **Docs**: PLAN.md, CLAUDE.md, README.md, `docs/phase-16a-setup.md`, `docs/privacy_policy.md`, `docs/terms_of_service.md`, `docs/index.md`, `docs/_config.yml`, `assets/legal/*`, `tasks/manual-qa-testplan.md`
- [~] **IntelliJ module**: `gymbuddy_app.iml` and `android/gymbuddy_app_android.iml` are gitignored (not tracked). Skipped rename — IDE will regenerate `.iml` files matching the new pubspec name on next project reload. User should close + reopen in IntelliJ/Android Studio to trigger regeneration.
- [x] **E2E helpers**: `test/e2e/helpers/selectors.ts`, `test/e2e/specs/auth.spec.ts`, `test/e2e/README.md` — update any brand string assertions
- [x] **Keystore example**: `android/key.properties.example` — comment updates if brand mentioned
- [x] **Widget tests**: any hardcoded `'GymBuddy'` string assertions in `test/widget/**/*_test.dart`
- [x] **Code generation**: run `make gen` (regenerates freezed/json_serializable artifacts)
- [x] **Clean build**: `flutter clean && flutter pub get`
- [x] **Full `make ci`** — must pass (format, analyze, test, android-debug-build) — passed (format clean, analyze 0 issues, 1449 tests all pass, APK built with applicationId `com.repsaga.app` and deep-link scheme `io.supabase.repsaga` verified)
- [ ] **QA review** — selectors + any flow strings still match
- [ ] **Open PR** — verify all 177 original `gymbuddy` matches are addressed
- [ ] **Merge** — squash merge, delete branch

### Manual follow-ups (user, post-merge)

- [ ] Set `GOOGLE_PLAY_PACKAGE_NAME=com.repsaga.app` via `npx supabase secrets set`
- [ ] Update Supabase Auth redirect URL to `io.supabase.repsaga://login-callback/`
- [ ] Rename Supabase + GCP project display names
- [ ] Rename GitHub repo (optional, auto-redirects)
- [ ] Rename/recreate Pub/Sub topic if current name contains "gymbuddy"

### Acceptance

- `grep -ri "gymbuddy\|GymBuddy" .` returns only intentional historical refs (git log, this WIP, PLAN.md history)
- `make ci` green
- Android build produces APK with `com.repsaga.app` applicationId
- Widget + unit tests pass without brand-string failures
- E2E smoke suite passes locally (selectors + flows unaffected)
