# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## W6 — Cleanup direct Supabase access in UI (Sprint C)

**Branch:** `fix/w6-direct-supabase-access`
**Source:** PLAN.md Phase 13, Sprint C — Resilience, row W6 ("Direct Supabase access in UI (bypass repo pattern)")

**Scope:** The literal `.from()` leak scan returns zero hits — all DB access is already inside `data/` repos. The residual bypass is `Supabase.instance.client.auth.currentUser` being read directly from UI and provider code instead of going through the auth layer.

**Sites to fix (5 total):**
- [x] `lib/features/exercises/ui/create_exercise_screen.dart:66` — UI reading `currentUser?.id` directly
- [x] `lib/features/profile/providers/profile_providers.dart:18` — `ProfileNotifier.build`
- [x] `lib/features/profile/providers/profile_providers.dart:29` — `saveOnboardingProfile`
- [x] `lib/features/profile/providers/profile_providers.dart:45` — `updateTrainingFrequency`
- [x] `lib/features/profile/providers/profile_providers.dart:57` — `toggleWeightUnit`

**Out of scope (legitimate uses — do NOT touch):**
- `lib/core/observability/sentry_init.dart:102` — core infra outside feature layers; runs before features are wired up
- `lib/features/auth/data/auth_repository.dart:16` — auth repo itself (not a bypass — this is THE auth layer)
- `*/providers/*.dart` lines that pass `Supabase.instance.client` into a Repo constructor (standard DI)

**Changes to make:**
- [x] Add `currentUserIdProvider` (`Provider<String?>`) to `lib/features/auth/providers/auth_providers.dart` that returns `Supabase.instance.client.auth.currentUser?.id`
- [x] Add one unit test (`test/unit/features/auth/providers/current_user_id_provider_test.dart`) covering signed-in and signed-out branches via a ProviderContainer override
- [x] Refactor the 5 call sites above to `ref.read(currentUserIdProvider)` (or `ref.watch` in `ProfileNotifier.build`)
- [x] Remove the now-unused `import 'package:supabase_flutter/supabase_flutter.dart';` from `profile_providers.dart` and `create_exercise_screen.dart` if they don't need it for other types

**Verification:**
- [x] `grep -r "Supabase.instance.client.auth.currentUser" lib/features/` returns only `auth/` paths (or empty)
- [x] `make ci` green
- [x] No E2E flow changes — visual-only assessment, no new E2E tests required (per CLAUDE.md E2E conventions)

**QA gate:** selector impact assessment only (no navigation/flow change, no text change). Skip full E2E run.
