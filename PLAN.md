# GymBuddy App - Implementation Plan

## Context

Building a gym training app from scratch where users can log workouts, track personal records, and browse/manage exercises. Built with Flutter + Supabase with Riverpod for state management.

**Platform strategy:** Android-first development. iOS infrastructure is not available, so Android is the source of truth for all development, testing, and QA. The codebase remains cross-platform (Flutter) — iOS support will be validated when the infrastructure is available. No iOS-specific features or testing until then.

**Market context:** Fitness app market is $12B+ (2025) growing at 13.4% CAGR. 70% of fitness apps are abandoned within 90 days — the #1 killer is friction in the core logging loop. GymBuddy must be fast, offline-capable, and opinionated about UX to survive.

**Design for the gym floor:** Users have sweaty hands, are between sets, glancing at their phone for 10 seconds. Every interaction must respect that context.

## Tech Stack

- **Frontend:** Flutter (Android-first, iOS later), SDK `^3.11.4`
- **Backend:** Supabase (Postgres, Auth, Storage)
- **Auth:** Supabase Auth with Google and email/password — using `AuthFlowType.pkce` (Apple sign-in deferred until iOS infrastructure is available)
- **State Management:** Riverpod `^2.4.0` (AsyncNotifier pattern — stable, production-tested)
- **Local Storage:** Hive (active workout cache, offline queue)
- **UI:** Dark & bold theme with strong accent colors
- **Code Generation:** Freezed `^2.5.0` + json_serializable via build_runner

## Database Schema (Supabase / Postgres)

### Tables

- **profiles** — `id (FK auth.users)`, `username`, `display_name`, `avatar_url`, `fitness_level` (beginner/intermediate/advanced), `created_at`
- **exercises** — `id`, `name`, `muscle_group` (enum: chest, back, legs, shoulders, arms, core), `equipment_type` (enum: barbell, dumbbell, cable, machine, bodyweight, bands, kettlebell), `is_default`, `user_id` (null for defaults), `deleted_at` (soft delete), `created_at`
- **workouts** — `id`, `user_id`, `name`, `started_at`, `finished_at`, `duration_seconds`, `is_active` (flag for crash recovery), `notes`, `created_at`
- **workout_exercises** — `id`, `workout_id`, `exercise_id`, `order`, `rest_seconds` (target rest between sets)
- **sets** — `id`, `workout_exercise_id`, `set_number`, `reps`, `weight`, `rpe` (1-10, rate of perceived exertion), `notes`, `is_completed`, `created_at`
- **personal_records** — `id`, `user_id`, `exercise_id`, `record_type` (max_weight, max_reps, max_volume), `value`, `achieved_at`, `set_id`
- **workout_templates** — `id`, `user_id`, `name`, `is_default` (for starter templates), `exercises` (jsonb array: `[{exercise_id, set_configs: [{target_reps, target_weight, rest_seconds}]}]`), `created_at`

### Indexes

```sql
CREATE INDEX idx_workouts_user_finished ON workouts(user_id, finished_at DESC);
CREATE INDEX idx_workout_exercises_workout ON workout_exercises(workout_id);
CREATE INDEX idx_sets_workout_exercise ON sets(workout_exercise_id);
CREATE INDEX idx_personal_records_user_exercise ON personal_records(user_id, exercise_id);
CREATE INDEX idx_exercises_user ON exercises(user_id) WHERE deleted_at IS NULL;
```

### Row-Level Security
- All user data scoped by `user_id = auth.uid()`
- Default exercises (`is_default = true`) readable by all
- Custom exercises only by creator
- Soft-deleted exercises hidden from library but visible in historical workouts
- Default templates (`is_default = true`) readable by all

## Architecture Decisions

- **Repository pattern**: All Supabase access goes through repository classes. No direct `supabase.from()` in providers or UI.
- **Feature isolation**: Features never import other features' providers. Cross-feature communication goes through Supabase (source of truth).
- **Provider organization**: Each feature has `providers/{notifiers/, repositories.dart}`. Repositories are singletons, Notifiers are feature-scoped.
- **Sealed exceptions**: All Supabase errors mapped to `AppException` subtypes in the repository layer. Raw exceptions never reach UI.
- **Offline sync strategy**: Server is source of truth for reads. Active workouts use optimistic local writes (Hive) with sync-on-save. Conflict resolution: last-write-wins with timestamp comparison.
- **Hive boxes**: `active_workout` (current session), `offline_queue` (pending syncs), `user_prefs` (local settings).
- **Deep-linking**: Use `AuthFlowType.pkce` (not fragment-based) to avoid Android token conflicts. Subscribe to `uriLinkStream` before `runApp()`.

## Project Structure

```
lib/
├── main.dart
├── app.dart                    # MaterialApp, theme, router
├── core/
│   ├── theme/                  # Dark bold theme, colors, typography
│   ├── router/                 # GoRouter configuration + auth redirect
│   ├── data/                   # Base repository class
│   ├── constants/              # App-wide constants
│   ├── exceptions/             # Sealed AppException types, Supabase error mapping
│   ├── local_storage/          # Hive service, box initialization
│   └── utils/                  # Date formatting, weight conversions
├── features/
│   ├── auth/
│   │   ├── data/               # Supabase auth repository
│   │   ├── providers/          # Auth state providers (AsyncNotifier)
│   │   └── ui/                 # Login, signup, onboarding screens
│   ├── exercises/
│   │   ├── data/               # Exercise repository
│   │   ├── models/             # Exercise model, MuscleGroup enum, EquipmentType enum
│   │   ├── providers/          # Exercise list/filter providers
│   │   └── ui/                 # Exercise list, detail, create screens
│   ├── workouts/
│   │   ├── data/               # Workout repository, local workout cache
│   │   ├── models/             # Workout, WorkoutExercise, ExerciseSet models
│   │   ├── providers/          # Active workout, history, rest timer providers
│   │   └── ui/                 # Workout logging, history, rest timer screens
│   ├── progress/
│   │   ├── data/               # PR repository
│   │   ├── models/             # PersonalRecord model
│   │   ├── providers/          # PR providers
│   │   └── ui/                 # PR list, notification
│   └── profile/
│       ├── data/               # Profile repository
│       ├── providers/          # Profile providers
│       └── ui/                 # Profile screen
└── shared/
    └── widgets/                # AsyncValueBuilder, error overlay, themed buttons, form inputs

supabase/
├── migrations/                 # Timestamped SQL migrations
└── seed.sql                    # Default exercises + starter templates

test/
├── unit/                       # Unit tests (repositories, models, business logic)
├── widget/                     # Widget tests (screens, components)
├── e2e/                        # Playwright e2e test scripts
└── fixtures/                   # Test factories (TestWorkoutFactory, etc.)

Makefile                        # gen, gen-watch, analyze, format, test, ci targets
```

## Implementation Steps

### Step 1: Project Setup, Architecture Foundation & CI

**Tech lead builds:**
- Initialize Flutter project with `flutter create`, pin SDK `^3.11.4`
- Add dependencies with pinned versions:
  - Core: `supabase_flutter ^2.5.0`, `flutter_riverpod ^2.4.0`, `go_router ^13.0.0`, `freezed ^2.5.0`, `json_serializable ^6.8.0`
  - Local storage: `hive ^2.2.0`, `hive_flutter ^1.1.0`
  - Environment: `flutter_dotenv ^5.1.0`
  - Utilities: `intl ^0.20.0`
  - Dev: `build_runner ^2.4.0`, `freezed_annotation`, `json_annotation`, `mocktail ^1.0.0`
- Environment setup:
  - Create `.env.example` with placeholders (SUPABASE_URL, SUPABASE_ANON_KEY)
  - Add `.env` to `.gitignore`
  - Initialize Supabase with `AuthFlowType.pkce` in `main.dart`, subscribe to `uriLinkStream` before `runApp()`
- Architecture scaffolding:
  - `core/data/base_repository.dart` — base class with error mapping, all repos extend this
  - `core/exceptions/app_exception.dart` — sealed exception hierarchy (AuthException, DatabaseException, NetworkException, ValidationException)
  - `core/exceptions/error_mapper.dart` — PostgrestException/AuthException → AppException mapping
  - `core/router/app_router.dart` — GoRouter skeleton with auth redirect (splash → login → home), shell route for bottom nav
  - `core/local_storage/hive_service.dart` — box names, initialization, adapter registration
- Shared widgets foundation:
  - `shared/widgets/async_value_builder.dart` — standard loading/error/data pattern for all screens
  - `shared/widgets/error_overlay.dart` — consistent error UI with retry button
  - `shared/widgets/themed_button.dart`, `shared/widgets/form_input.dart` — reusable styled components
- Configure dark bold theme (ThemeData, ColorScheme) in `core/theme/`
- `Makefile` with targets: `gen`, `gen-watch`, `analyze`, `format`, `test`, `ci`
- `analysis_options.yaml` with strict lint rules (exclude `*.g.dart`, `*.freezed.dart`)

**Delegated:**
- `qa-engineer`: Set up test directory structure, `MockSupabaseClient`, test data factories (`TestUserFactory`, `TestExerciseFactory`, `TestWorkoutFactory`), Riverpod `ProviderContainer` test overrides

**CI/CD pipeline (GitHub Actions):**
- `ci.yml`: `dart format --set-exit-if-changed .` → `dart analyze --fatal-infos` → `dart run build_runner build` → `flutter test --coverage`
- Branch protection on `main`: require `ci` status check to pass

**Tests:** Unit tests for base repository error mapping, exception hierarchy

### Step 2: Database Schema, Migrations & Seed Data
- Create Supabase project, obtain URL + anon key, store in `.env`
- Write initial migration: `supabase/migrations/00001_initial_schema.sql`
  - All tables, enums, indexes as defined in schema above
  - Enable RLS on every table
  - Write RLS policies (user-scoped reads/writes, public read for default exercises and templates)
- Write seed script: `supabase/seed.sql`
  - ~60 common exercises across all muscle groups with equipment types
  - 3-4 starter workout templates (Push/Pull/Legs, Upper/Lower, Full Body) with `is_default = true`
- Test RLS policies: verify user A cannot read user B's data
- Document migration workflow in README

**CI evolution:** Add RLS integration test job to `ci.yml` (runs against test Supabase instance)

**Tests:** Integration tests for RLS policies (user isolation, default exercise visibility)

### Step 3: Authentication & Onboarding
- Configure Supabase Auth (enable Google provider, set PKCE redirect URLs; Apple deferred to iOS phase)
- Build auth repository extending base repository
- Auth state provider (AsyncNotifier watching `onAuthStateChange` stream)
- Router redirect: unauthenticated → login, authenticated → home, loading → splash
- Build screens:
  - **Splash** — loading state while auth resolves
  - **Login/Signup** — email + Google sign-in
  - **Onboarding** (post-signup, 3 screens):
    1. Welcome + value prop ("Track every rep, every time")
    2. Profile setup (name, fitness level)
    3. First workout choice (start with a starter template like "Full Body", start blank, or browse exercises)
- Create profile on first login (database trigger)
- Handle auth edge cases: token refresh, expired sessions, revoked social login

**E2E smoke test:** Playwright test for signup → onboarding → land on home → logout → login

**Tests:**
- Unit: auth repository (signup, login, logout, token refresh, error mapping)
- Widget: login screen (form validation, button states), onboarding flow (screen transitions)

### Step 4: Exercise Library
- Exercise model with Freezed (includes MuscleGroup enum, EquipmentType enum)
- Exercise repository extending base repository (CRUD + filter by muscle group + filter by equipment)
- Exercise list screen:
  - Muscle group filter chips
  - Search with recent exercises first
  - Equipment type filter
- Add custom exercise screen
- Exercise detail view (usage history, PRs for this exercise)
- Soft delete: hide from library, preserve in historical workouts. Warn if template references a soft-deleted exercise.

**Tests:**
- Unit: exercise repository (CRUD, filters, soft delete behavior), model serialization
- Widget: exercise list (filter chips, search, empty state), create exercise form (validation)

### Step 5: Workout Logging
- Models for Workout, WorkoutExercise, ExerciseSet with Freezed
- **Active workout state** (Riverpod AsyncNotifier managing nested state):
  - Workout → WorkoutExercise[] → Set[]
  - Auto-save to Hive after every state change (fire-and-forget, don't block UI)
  - On app startup: check Hive for unfinished workout → show "Resume or discard?" dialog
  - Hive corruption fallback: if Hive data is unreadable, log error and start fresh (don't crash)
  - Only one active workout allowed per user — check `is_active` flag before starting
- **Last workout reference**: query previous weight/reps for each exercise and display inline while logging
- **Rest timer**: countdown timer per exercise (configurable rest_seconds), notification when rest is over
- Workout screen UX priorities:
  - Add exercises from library (recent exercises first, searchable)
  - Log sets: reps + weight input, optional RPE — target 2-3 taps per set
  - Reorder exercises mid-workout
  - One-handed operation: key actions reachable by thumb, large tap targets
- Finish workout: save to Supabase, calculate duration, clear Hive cache, set `is_active = false`

**E2E smoke test:** Playwright test for start workout → add exercises → log sets → finish → verify in history

**Tests:**
- Unit: active workout state transitions, Hive persistence/recovery, last-workout query, rest timer logic, concurrent session prevention
- Widget: set logging (reps/weight input), exercise reorder, rest timer UI, crash recovery dialog

### Step 6: Workout Templates
- Save current workout as template (captures exercises + set configs)
- "Start from template" option: pre-fills exercises and target reps/weight from template
- Template list screen (view and select, delete)
- Starter templates (seeded in Step 2) shown alongside user templates

**Deferred to v1.1:** Template edit screen (for MVP, delete and re-create)

**Tests:**
- Unit: template-to-workout conversion, template repository CRUD
- Widget: template list, start-from-template flow

### Step 7: Personal Records
- PR detection logic: after completing a workout, compare each exercise's sets against existing PRs
- Record types:
  - Max weight (heaviest single set)
  - Max reps (most reps at any weight)
  - Max volume (weight × reps for a single set)
- Edge cases: handle 0 weight (bodyweight exercises), first-ever workout (no prior data), 0 reps (skip)
- PR celebration: distinctive feedback when a record is broken (not generic confetti)
- PR list screen showing all-time records per exercise

**Deferred to v1.1:** PR badges/indicators on workout history and exercise detail screens

**E2E smoke test:** Playwright test for log workout → log heavier workout → verify PR appears in list

**Tests:**
- Unit: PR detection algorithm (max weight, max reps, volume), edge cases (0 weight, 0 reps, first workout, very large numbers 999kg), race condition prevention (idempotent PR creation)
- Widget: PR celebration feedback, PR list screen

### Step 8: Home Screen & Navigation
- Bottom navigation: Home, Exercises, History, Profile
- Home screen:
  - Quick "Start Workout" button (prominent, thumb-reachable)
  - Resume unfinished workout banner (if crash recovery detected)
  - Recent workouts summary
  - Recent PRs
- Profile screen: user info, fitness level, logout
- Smart defaults: when starting a workout, suggest pre-filling from last session's weights

**Deferred to v1.1:** Muscle group coverage insight ("You haven't trained back in 8 days") — calculation: query last 30 days of workouts, group by exercise.muscle_group, find MAX(finished_at), flag if >7 days

**Tests:**
- Widget: home screen (start workout button, resume banner, recent workouts/PRs), profile screen (logout), navigation (tab switching)

### Step 9: E2E Testing, Release Pipeline & Final QA
- Full Playwright e2e suite for all critical journeys:
  1. Auth flow: signup → onboarding → land on home → logout → login
  2. Complete workout: start → add exercises → log sets with rest timer → finish → verify in history
  3. PR detection: log workout → log heavier workout → verify PR appears
  4. Template flow: finish workout → save as template → start from template → verify pre-filled
  5. Crash recovery: start workout → force close → reopen → verify resume dialog
- Add `e2e.yml` GitHub Actions workflow: build web → serve → run Playwright tests
- Add `release.yml` GitHub Actions workflow: build APK on version tags (`v*`), create GitHub release with artifacts (iOS build added when infrastructure is available)
- Final manual QA pass on physical devices

## Verification

### Automated (CI — every push/PR)
- `dart format --set-exit-if-changed .` — formatting enforced
- `dart analyze --fatal-infos` — zero warnings
- `dart run build_runner build` — code generation up to date
- `flutter test --coverage` — all tests pass, coverage threshold met

### CI Pipeline Evolution
- **Step 1**: Unit + widget tests
- **Step 2**: Add RLS integration tests
- **Step 3+**: Add e2e smoke tests incrementally per feature
- **Step 9**: Full e2e Playwright suite

### Unit Tests (target 80%+ coverage on business logic)
- Base repository: error mapping, exception hierarchy
- Repositories: all CRUD operations, error handling, data mapping
- PR detection: max weight, max reps, volume calculations, idempotent creation
- PR edge cases: 0 weight (bodyweight), first workout, 0 reps, very large numbers (999kg)
- Auth providers: login/logout, token refresh, state transitions
- Active workout: state transitions, Hive persistence, crash recovery, concurrent session prevention
- Models: serialization/deserialization, equality, edge cases

### Widget Tests
- Screen states: loading, data, error, empty for all screens
- User interactions: add set, delete set, reorder exercises
- Form validation: invalid weight, negative reps, empty fields
- Conditional UI: PR notification shows only when record is broken
- Rest timer: countdown, notification trigger
- Crash recovery dialog: resume vs discard

### Integration Tests
- RLS enforcement: verify user A cannot access user B's data
- Workout save → PR calculation chain (no data loss between steps)
- Default exercises and templates readable by all, custom ones private
- Soft delete: exercise hidden from library, visible in past workouts and templates warned

### E2E Tests (Playwright — incremental)
- Step 3: Auth flow smoke test
- Step 5: Workout logging smoke test
- Step 7: PR detection smoke test
- Step 9: Full journey suite + crash recovery

### Conflict & Resilience Tests
- Network failure mid-workout → local Hive cache preserves data → syncs on reconnect
- App crash during workout → restart → resume dialog → data intact
- Hive corruption → app rebuilds from server state, doesn't crash
- Concurrent sessions: user cannot start two active workouts (check `is_active` flag)
- Token expiration during long workout (2+ hours) → transparent refresh
- Exercise soft delete → hidden from library, visible in past workouts, template warns user
- Offline edits conflict → last-write-wins with timestamp comparison
- Duplicate PR prevention → idempotent creation with exercise_id + record_type constraint

### Manual QA Checklist
- Auth on all providers (Google, email)
- Test on physical Android device + Android emulator
- Test on Chrome (Flutter web) for Playwright e2e
- Dark theme renders correctly on all screens
- One-handed usability check: can core actions be done with thumb?
- Logging speed: can a set be logged in under 3 taps?
- Deep-linking: email verification link works on Android
