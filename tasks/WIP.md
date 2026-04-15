# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## W3b — Input length limits (TextField + server CHECK) (Sprint C)

**Branch:** `feature/w3b-input-length-limits`
**Source:** PLAN.md Phase 13, Sprint C — Resilience, row W3b ("Input length limits (TextField + server CHECK)")
**Intent:** Prevent DB bloat and UI overflow on long free-text inputs. Defense in depth — UI `maxLength` blocks casual over-entry, DB `CHECK` blocks API-level abuse (anyone bypassing the client).

### Sizing rationale

UI limits are ergonomic (what fits on screen); DB limits are generous ceilings just to stop 10MB strings. UI < DB leaves headroom so legacy rows that were entered before this change don't break subsequent updates.

Seeded content max lengths observed on hosted Supabase:
- `exercises.description` max in seeds = 128 chars → DB 500 is ample
- `exercises.form_tips` max in seeds = 246 chars → DB 2000 is ample

### UI changes (add `maxLength`)

- [x] `lib/shared/widgets/app_text_field.dart` — add `maxLength` param (pass-through to `TextFormField`). Keep counter visible (Flutter default). Optional: `maxLengthEnforcement: MaxLengthEnforcement.enforced`.
- [x] `lib/features/auth/ui/onboarding_screen.dart:267` — display name → **50**
- [x] `lib/features/profile/ui/profile_screen.dart:191` — display name edit → **50**
- [x] `lib/features/exercises/ui/create_exercise_screen.dart` — exercise name → **80** (keep description 300, form_tips 500)
- [x] `lib/features/routines/ui/create_routine_screen.dart:142` — routine name → **80**
- [x] `lib/features/workouts/ui/active_workout_screen.dart:332` — workout name inline edit → **80**
- [x] `lib/features/workouts/ui/widgets/finish_workout_dialog.dart:76` — workout notes → **1000**

### DB CHECK constraints — new migration `supabase/migrations/00021_input_length_limits.sql`

- [x] `profiles.username` — `char_length(username) <= 50`
- [x] `profiles.display_name` — `char_length(display_name) <= 100`
- [x] `exercises.name` — `char_length(name) <= 100`
- [x] `exercises.description` — `char_length(description) <= 500`
- [x] `exercises.form_tips` — `char_length(form_tips) <= 2000`
- [x] `workouts.name` — `char_length(name) <= 100`
- [x] `workouts.notes` — `char_length(notes) <= 2000`
- [x] `workout_templates.name` — `char_length(name) <= 100`
- [x] `sets.notes` — `char_length(notes) <= 1000` (no UI input today, but DB-level guard)

Each constraint should allow NULL where the column is nullable (standard `CHECK` semantics already do this). Name each constraint predictably, e.g. `valid_workouts_name_length`.

### Out of scope

- Not touching email/password fields (already RFC-bounded / bcrypt-bounded).
- Not touching transient search fields (`exercise_list_screen.dart`, `exercise_picker_sheet.dart`) — no DB write.
- Not touching DELETE confirmation input in `manage_data_screen.dart` — must match a magic string, not free-text.
- Not touching numeric stepper fields (`weight_stepper`, `reps_stepper`).

### Tests

- [x] Widget test for `AppTextField` with `maxLength` — typing over the limit clamps input, counter shows `N/M`.
- [x] One widget test per real UI site would be excessive; add ONE integration-style widget test on `create_exercise_screen` verifying the name field enforces 80. The other sites use the same `AppTextField` / `TextField` with `maxLength`, so they're covered by transitivity.
- [x] No Supabase integration test for CHECK constraints — `mocktail` mocks don't round-trip to a real DB. Add a comment in the migration file documenting the rationale for each limit.

### Migration application

- [x] **Before merge:** Run `SELECT max(char_length(col))` for each affected column on hosted Supabase to confirm no existing row would violate a new constraint. Document results in PR body. *(Done by orchestrator — see PR body table.)*
- [ ] **After merge:** `npx supabase db push` (per CLAUDE.md step 10). *(Post-merge orchestrator task.)*

### Verification

- [x] `make ci` green (includes the new widget test).
- [x] No E2E flow change — visual-only assessment (counter text appears, but no navigation/logic change). Selector impact review + skip full E2E run per CLAUDE.md conventions.
- [x] Grep `TextField\(` and `TextFormField\(` in `lib/features/` confirms every DB-bound free-text input has `maxLength` set (or is explicitly out-of-scope above).

### QA gate

Selector impact only. The counter renders as `N/80` — if any E2E test matches text that could conflict with a counter, update `helpers/selectors.ts`. (Very unlikely, since counters render in a styled subtree below the field.)
