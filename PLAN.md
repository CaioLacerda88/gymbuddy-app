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

- **profiles** — `id (FK auth.users)`, `username`, `display_name`, `avatar_url`, `fitness_level` (beginner/intermediate/advanced), `weight_unit` (kg/lbs, default kg), `created_at`
- **exercises** — `id`, `name`, `muscle_group` (enum: chest, back, legs, shoulders, arms, core), `equipment_type` (enum: barbell, dumbbell, cable, machine, bodyweight, bands, kettlebell), `is_default`, `user_id` (null for defaults), `deleted_at` (soft delete), `created_at`
- **workouts** — `id`, `user_id`, `name`, `started_at`, `finished_at`, `duration_seconds`, `is_active` (flag for crash recovery), `notes`, `created_at`
- **workout_exercises** — `id`, `workout_id`, `exercise_id`, `order`, `rest_seconds` (target rest between sets)
- **sets** — `id`, `workout_exercise_id`, `set_number`, `reps`, `weight` (numeric, supports decimals e.g. 22.5), `rpe` (1-10, rate of perceived exertion), `set_type` (working/warmup/dropset/failure, default working), `notes`, `is_completed`, `created_at`
- **personal_records** — `id`, `user_id`, `exercise_id`, `record_type` (max_weight, max_reps, max_volume), `value`, `achieved_at`, `set_id`
- **workout_templates** — `id`, `user_id`, `name`, `is_default` (for starter templates), `exercises` (jsonb array: `[{exercise_id, set_configs: [{target_reps, target_weight, rest_seconds}]}]`), `created_at`

### Indexes

```sql
CREATE INDEX idx_workouts_user_finished ON workouts(user_id, finished_at DESC);
CREATE INDEX idx_workout_exercises_workout ON workout_exercises(workout_id);
CREATE INDEX idx_sets_workout_exercise ON sets(workout_exercise_id);
CREATE INDEX idx_personal_records_user_exercise ON personal_records(user_id, exercise_id);
CREATE INDEX idx_exercises_user ON exercises(user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_workouts_active ON workouts(user_id) WHERE is_active = true;

-- Constraints
CREATE UNIQUE INDEX idx_exercises_unique_name
  ON exercises(user_id, LOWER(name), muscle_group, equipment_type)
  WHERE deleted_at IS NULL;
ALTER TABLE sets ADD CONSTRAINT unique_set_per_exercise
  UNIQUE (workout_exercise_id, set_number);
ALTER TABLE workout_templates ADD CONSTRAINT valid_exercises_json
  CHECK (jsonb_typeof(exercises) = 'array');
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
- **Weight units**: Store all weights in user's chosen unit (kg or lbs). `weight_unit` preference in profile. Convert on display if user switches. Weight input supports one decimal place (e.g., 22.5).
- **Atomic workout save**: Use a Postgres RPC function (`save_workout`) to insert workout + exercises + sets in a single transaction. No partial data on network failure.
- **Hive schema versioning**: Store a `schemaVersion` int alongside workout data in Hive. On version mismatch, discard stale data and log (don't crash).
- **Route tree**: Active workout screen sits outside the shell (full-screen). Exercise detail and workout detail are sub-routes inside the shell.

### Route Tree (GoRouter)

```
/splash, /login, /onboarding, /email-confirmation  (no shell)
/workout/active                                      (no shell, full-screen)
ShellRoute:
  /home
  /exercises
  /exercises/:id
  /history
  /history/:workoutId
  /profile
```

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

### Step 3b: Auth UX Polish & Email Templates
- **Post-signup feedback**: After email signup, show a confirmation screen/state informing the user that a verification email was sent, with instructions to check their inbox and a resend option
- **Email confirmation flow**: Detect when user returns after confirming email and transition them seamlessly into onboarding
- **Auth error feedback**: Clear, user-friendly error messages for all auth failures (wrong password, account exists, network error, etc.)
- **Loading states**: Proper loading indicators during all auth operations (signup, login, Google OAuth)
- **Custom Supabase email templates**: Replace default Supabase auth emails (confirmation, password reset, magic link) with GymBuddy-branded templates matching the app's identity
- **General auth UX audit**: ui-ux-critic reviews the entire auth flow end-to-end for usability issues (gym-floor context, one-handed use, glanceability)

**Tests:**
- Widget: post-signup confirmation screen, email resend, error states

**E2E smoke test:** Playwright test for signup → onboarding → land on home → logout → login

**Tests (Step 3):**
- Unit: auth repository (signup, login, logout, token refresh, error mapping)
- Widget: login screen (form validation, button states), onboarding flow (screen transitions)

### Step 4: Exercise Library

**Database migration** (new migration file):
- Add `idx_exercises_unique_name` unique index on `(user_id, LOWER(name), muscle_group, equipment_type) WHERE deleted_at IS NULL`
- Add `idx_workouts_active` partial index on `workouts(user_id) WHERE is_active = true`
- Add `set_type` column to `sets` table (default 'working')
- Add `weight_unit` column to `profiles` table (default 'kg')
- Add `unique_set_per_exercise` constraint on `sets(workout_exercise_id, set_number)`
- Add `valid_exercises_json` CHECK constraint on `workout_templates`

**Exercise model & repository:**
- Exercise model with Freezed (includes MuscleGroup enum, EquipmentType enum)
- Exercise repository extending base repository (CRUD + filter by muscle group + filter by equipment)
- Validate exercise name uniqueness (case-insensitive) before insert
- Exercise detail view shows usage history; PR section renders conditionally (placeholder until Step 7 wires PR provider)

**Exercise list screen:**
- Muscle group category buttons as primary nav (large touch targets, icon + label, min 64dp tall)
- Search as secondary fallback (avoid relying on keyboard input during workouts)
- Equipment type filter
- Recent exercises surfaced first
- Empty states with clear CTAs: "No exercises match your filters" with "Clear filters" action
- Custom exercises empty state: "Your exercises will appear here" with "Create Exercise" button
- Filter combination zero-results handling

**Exercise picker (shared contract for Step 5):**
- Extract exercise search/filter logic into repository layer (shared via provider)
- Step 4 builds the full exercise list screen
- Step 5 will build an `ExercisePickerSheet` (bottom sheet) calling the same repository methods
- Repository must support: `searchExercises(query, muscleGroup?, equipmentType?)` and `recentExercises(userId, limit)`

**Add custom exercise screen:**
- Name, muscle group, equipment type inputs
- Validation: no duplicate names (case-insensitive per user)

**Soft delete:**
- Hide from library and search, preserve in historical workouts
- Warn if template references a soft-deleted exercise
- Search must NOT return soft-deleted exercises (even by exact name)

**Tests:**
- Unit: exercise repository (CRUD, filters, soft delete behavior, duplicate name prevention), model serialization
- Widget: exercise list (filter chips, search, empty state, zero-results state), create exercise form (validation, duplicate name error)

#### Step 4b: Exercise Demonstration Images (DONE)

**Source:** [Free Exercise DB (yuhonas)](https://github.com/yuhonas/free-exercise-db) — Unlicense (public domain), 800+ exercises, static JPGs (start + end position per exercise). $0 cost.

**Data model:**
- Migration `00003_exercise_images.sql`: Added `image_start_url TEXT` and `image_end_url TEXT` columns to `exercises`
- Migration `00004_seed_exercise_images.sql`: Seed URLs for 30 default exercises pointing to GitHub-hosted images
- Supabase Storage bucket `exercise-media` (public read, service-role write) with UPDATE/DELETE RLS policies

**UX decisions:**
- Exercise list: NO thumbnails (keeps card density, users recognize exercises by name)
- Exercise detail: Start/end images side-by-side in 160dp row, tap for fullscreen overlay with close button
- Exercise picker (Step 5): NO thumbnails (speed-critical search-and-tap flow)
- Error/missing images: collapse section entirely (no broken placeholders)

**Implementation:**
- `lib/shared/widgets/exercise_image.dart` — Shared `ExerciseImage` widget wrapping `cached_network_image`, with loading indicator, fallback icon, error collapse, and `devicePixelRatio`-aware `memCacheWidth`
- Exercise detail screen: `_ExerciseImageRow` + `_TappableImage` with fullscreen dialog (AppBar close button + tap-to-dismiss)
- No images bundled in APK — cached on first load, 30-day disk cache

**Future upgrade path:** Replace static JPGs with animated demos from Exercise Animatic ($499) or WorkoutLabs API if budget allows.

**Tests:** 31 tests covering ExerciseImage widget (null/empty/provided URL, fallback sizing, borderRadius), detail screen (image row, single image, collapse, semantics, fullscreen open/close, loading, error states), and model serialization with image fields.

### Step 5: Workout Logging

**Architecture decisions (resolve before coding):**
- Use a single `ActiveWorkoutNotifier` holding the full workout state as a Freezed model. For ~5-8 exercises with ~4 sets each, rebuild cost is negligible.
- Serialize to Hive as JSON (`jsonEncode` the Freezed model's `toJson()`). No custom Hive adapters needed.
- Store `schemaVersion` int in the Hive box alongside workout data. On version mismatch, discard and log.
- Final save: use a Postgres RPC function (`save_workout`) for atomic insert of workout + exercises + sets in a single transaction.

**Database migration** (new migration file):
- Create `save_workout(p_workout jsonb, p_exercises jsonb, p_sets jsonb)` Postgres RPC function (SECURITY DEFINER, single transaction)

**Models** for Workout, WorkoutExercise, ExerciseSet with Freezed:
- ExerciseSet includes `set_type` (working/warmup/dropset/failure, default working)
- Weight field accepts decimals (one decimal place, e.g., 22.5)
- Validation: weight non-negative, max 999.9, reps non-negative

**Active workout state** (Riverpod AsyncNotifier managing nested state):
- Workout → WorkoutExercise[] → Set[]
- Auto-save to Hive as JSON after every state change (fire-and-forget, don't block UI)
- On app startup: check Hive for unfinished workout → show "Resume or discard?" dialog
- Hive corruption fallback: if Hive data is unreadable or schema version mismatch, log error and start fresh (don't crash)
- Only one active workout allowed per user — check `is_active` flag before starting
- Auth expiry handling: listen to auth state during active workout. On `signedOut`, persist to Hive and show "Session expired" banner. Don't silently lose data.

**Last workout reference:**
- Batch query for all exercises in one call (avoid N+1): single query with `exercise_id = ANY($ids)` grouped by exercise, ordered by `finished_at DESC`
- Display inline while logging (previous weight/reps per exercise)

**Weight unit support:**
- Display and input in user's chosen unit (kg/lbs from profile `weight_unit`)
- Weight input stepper with configurable increment (default 2.5kg / 5lbs)

**Rest timer:**
- Countdown timer per exercise (configurable rest_seconds)
- Full-screen takeover with large countdown numbers (72sp+), circular progress ring
- Screen stays awake during timer (`wakelock` package)
- Timer completion: device vibration (3 short pulses) + optional sound alert
- Timer preserved when navigating between exercises (don't reset on exercise switch)
- After timer ends, auto-focus next set input

**Set logging UX:**
- Use scroll-wheel/stepper pickers for weight and reps (NOT text fields)
- Pre-fill from last workout's values for each exercise
- "Copy last set" button: duplicates previous set's weight/reps into current set
- "Fill remaining sets" long-press: fills all empty sets with same values
- Set type selector: working (default), warmup, dropset, failure — warmup sets excluded from PR calculations
- RPE input: hidden by default, tap icon to expand per set (reduce clutter)
- Swipe right on set row = mark as complete; swipe left = delete with 5-second undo snackbar
- Minimum touch targets: 48x48dp interactive, 56x56dp for primary actions

**Exercise picker** (bottom sheet, 70% screen height):
- `ExercisePickerSheet` calling exercise repository methods (shared from Step 4)
- Recent exercises shown first, search bar at top of sheet
- "Swap exercise" action: replaces exercise but preserves set structure

**Reorder exercises:** Dedicated reorder mode with large up/down arrow buttons (56dp), NOT freeform drag

**Elapsed timer:** Show in workout screen header. Format: "47m" for <1h, "1h 23m" for 1h+

**Haptic feedback:**
- Set completed: `HapticFeedback.mediumImpact()`
- Destructive actions: `HapticFeedback.lightImpact()`

**Discard workout:** Require confirmation dialog showing workout duration

**Finish workout:**
- Save via `save_workout` RPC (atomic transaction)
- Confirm if sets are incomplete: "You have 3 incomplete sets — finish anyway?"
- Calculate duration, clear Hive cache, set `is_active = false`
- `finishWorkout()` returns saved workout data for future PR detection. Leave `// TODO: PR detection (Step 7)` placeholder.
- Notes field on finish screen (workout-level notes)

**Empty workout state:** Full-screen prompt "Add your first exercise" with picker accessible

**Active workout nav indicator:** Persistent mini-bar above bottom nav when active: workout duration + "Return to Workout" (56dp tall)

**Workout history list** (basic version, ships with Step 5):
- List of past workouts: date, name, exercise count, duration, total volume
- Tappable for full workout detail (exercises, sets, weights)
- Empty state: "Start your first workout" with CTA
- Pull-to-refresh

**E2E smoke test:** Playwright test for start workout → add exercises → log sets → finish → verify in history

**Tests:**
- Unit: active workout state transitions, Hive persistence/recovery (including schema version mismatch), last-workout batch query, rest timer logic, concurrent session prevention, atomic save RPC, set type filtering, weight unit display
- Widget: set logging (stepper/wheel input, copy set, fill remaining), exercise reorder (arrow buttons), rest timer UI (full-screen, vibration), crash recovery dialog, discard confirmation, finish confirmation with incomplete sets, empty workout state, active workout nav indicator

### Step 6: Workout Templates
- Save current workout as template: `WorkoutTemplate.fromWorkout(Workout)` factory maps workout exercises to JSONB structure
- "Start from template" option: pre-fills exercises and target reps/weight from template
- Template list screen:
  - "Starter Templates" and "My Templates" sections clearly labeled
  - Template cards: large "Start" action (entire card tappable or large right-side button)
  - Zero templates state: "Finish a workout to save it as a template" (show only starters for new users)
- Starter templates (seeded in Step 2) shown alongside user templates
- Template with deleted exercise: load-time check joins exercise IDs against `exercises` table. Deleted exercise shown grayed out with warning badge and substitution option.
- Auto-generate template name from exercises ("Chest & Back — 5 exercises") but allow rename
- Basic template editing: add/remove/reorder exercises within a template

**Deferred to v1.1:** Full template edit screen with set config editing

**Tests:**
- Unit: template-to-workout conversion (`WorkoutTemplate.fromWorkout` factory), template repository CRUD, deleted exercise detection
- Widget: template list (starter vs user sections, empty state), start-from-template flow, deleted exercise warning UX

### Step 7: Personal Records

**PR detection logic:**
- Wired into `finishWorkout()` from Step 5. Compare each exercise's working sets against existing PRs.
- Batch-fetch existing PRs: single query with `exercise_id = ANY($ids)` (not one per exercise)
- Only count sets with `set_type = 'working'` — warmup/dropset/failure sets excluded
- PRs only detected on finished workouts (discarded workouts don't count)
- PRs must be strictly greater than previous value (ties are NOT new PRs)

**Record types:**
- Max weight (heaviest single set)
- Max reps (most reps at any weight)
- Max volume (weight x reps for a single set)

**Bodyweight exercise PR logic:**
- If `equipment_type == bodyweight` AND `weight == 0`: track only `max_reps`
- If bodyweight exercise has added weight (e.g., weighted pull-ups): track all three PR types
- PR detail screen should NOT show empty "Max Weight" cards for bodyweight exercises

**First workout handling:**
- Don't fire individual celebrations for every set. Show one consolidated message: "First workout logged! These are your starting benchmarks."

**Multiple PRs in one workout:**
- Batch celebrations: one summary screen at workout completion listing all PRs broken

**PR celebration (NOT confetti):**
- Brief screen flash (green overlay at 30% opacity, 200ms)
- Number scales up with spring animation
- Bold banner: "NEW PR" with improvement delta ("+5kg")
- Heavy haptic feedback
- Feel like a scoreboard update, not a birthday party

**PR list screen:**
- All-time records per exercise
- Empty state: "Complete a workout to start tracking records" with CTA

**Wire into exercise detail (Step 4):** Connect PR provider to exercise detail screen's conditional PR section

**Deferred to v1.1:** PR badges/indicators on workout history and exercise detail screens

**E2E smoke test:** Playwright test for log workout → log heavier workout → verify PR appears in list

**Tests:**
- Unit: PR detection (max weight, max reps, volume), edge cases (0 weight bodyweight, 0 reps skip, first workout consolidated, 999kg, PR ties not counted, warmup sets excluded), idempotent creation, batch query
- Widget: PR celebration (flash, banner, haptic), PR list (empty state, bodyweight display), first workout message, multi-PR summary

### Step 8: Home Screen & Navigation

**Bottom navigation:** Home, Exercises, History, Profile

**Home screen:**
- Quick "Start Workout" button: min 72dp tall, full-width or 80% width, bottom third of screen, fixed-position, always visible
- "Repeat Last Workout" shortcut: creates workout pre-filled from most recent workout's exercises and weights
- Resume unfinished workout banner: MOST prominent element when present — full-width, pulsing border, above everything
- Recent workouts summary (via `recentWorkouts(limit: 5)` repository method)
- Recent PRs
- First-time user: "Ready for your first workout?" with Start button and starter templates. No blank screen.
- Edge case: empty workouts (started and immediately finished) filtered out or shown muted

**Workout history detail screen:** Full workout detail (exercises, sets, weights, duration, total volume). Extends basic history from Step 5.

**Profile screen:** User info, fitness level, weight unit toggle (kg/lbs), logout

**Smart defaults:** Suggest pre-filling from last session's weights when starting a workout

**Deferred to v1.1:** Muscle group coverage insight ("You haven't trained back in 8 days")

**Tests:**
- Widget: home screen (start workout button sizing/position, resume banner prominence, recent workouts/PRs, empty state, repeat last workout), profile screen (logout, weight unit toggle), navigation (tab switching), workout history detail

### Step 9: E2E Testing, Release Pipeline & Final QA

**Playwright test suite structure:**
```
test/e2e/
├── playwright.config.ts          # baseURL, timeouts, smoke/full projects
├── global-setup.ts               # Seed test users via Supabase admin API
├── global-teardown.ts            # Cleanup test users
├── helpers/
│   ├── auth.ts                   # loginAs(), signup(), logout()
│   ├── workout.ts                # startWorkout(), addExercise(), logSet(), finishWorkout()
│   ├── navigation.ts             # goToTab(), waitForRoute()
│   └── selectors.ts              # Centralized Semantics label constants
├── smoke/                        # Fast tests — every PR (<3 min)
│   ├── auth.smoke.spec.ts
│   ├── workout.smoke.spec.ts
│   └── pr.smoke.spec.ts
├── full/                         # Slower tests — merge to main (<10 min)
│   ├── auth.full.spec.ts
│   ├── exercise-library.spec.ts
│   ├── workout-logging.spec.ts
│   ├── templates.spec.ts
│   ├── personal-records.spec.ts
│   ├── home-navigation.spec.ts
│   └── crash-recovery.spec.ts
└── fixtures/
    ├── test-users.ts             # Test user credentials
    └── test-exercises.ts         # Known exercise IDs from seed data
```

**Test environment:** Real Supabase test project (not mocked) — e2e tests catch integration bugs, RLS policies, and database triggers that mocks would hide. Test isolation via unique users per test.

**Test data strategy:**
- `global-setup.ts` creates test users via Supabase Admin API (service role key)
- Each test uses a unique user (e.g., `e2e-smokeA@test.gymbuddy.local`)
- Signup flow tests use timestamped emails
- `global-teardown.ts` cleans up all `e2e-*` users
- No shared mutable state between tests — parallel-safe

**Smoke tests (every PR, <3 min):**
1. Auth: signup → onboarding → home → logout → login
2. Core workout: start → add exercise → log set → finish → verify in history
3. PR detection: workout A → heavier workout B → PR celebration + PR list

**Full suite (merge to main, <10 min):**
4. Exercise library: filter, search, create custom, soft delete
5. Workout logging: multi-exercise, reorder, rest timer, set types
6. Templates: save as template → start from template → verify pre-filled
7. Personal records: bodyweight PRs, multiple PRs, first workout handling
8. Home & navigation: tabs, resume banner, quick start, repeat last workout
9. Crash recovery: close mid-workout → reopen → resume → sets intact
10. Auth edge cases: wrong password, existing email, error messages

**Extra risk areas for e2e:**
- Network failure during workout finish (simulate with `page.route()`)
- Double-tap "Finish Workout" idempotency
- Active workout singleton (second tab blocked)
- Rest timer state across exercise switches
- Hive corruption → clear message, not crash

**`e2e.yml` workflow:** Separate from `ci.yml`. Build Flutter web (HTML renderer) → serve on port 8080 → run Playwright (Chromium headless). Upload playwright-report on failure. Smoke on PRs, full on merge.

**`release.yml` workflow:** Triggered by `v*` tags. Build split APKs (arm64, armeabi-v7a, x86_64) → GitHub Release via softprops/action-gh-release. No code signing for MVP. Alpha/beta tags → pre-release.

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
- Step 3: Auth flow smoke test (signup → onboarding → home → logout → login)
- Step 5: Workout logging smoke test (start → add exercise → log set → finish → history)
- Step 7: PR detection smoke test (workout A → heavier workout B → PR celebration + list)
- Step 9: Full journey suite (exercise CRUD, templates, crash recovery, home, multi-exercise, edge cases)

### E2E Smoke vs Full Split
- **Smoke (every PR, <3 min):** 3 spec files, ~8-10 test cases — auth, core workout, PR detection
- **Full (merge to main, <10 min):** 7 additional spec files, ~20 more cases — all features + edge cases
- **Separation:** `test/e2e/smoke/` and `test/e2e/full/` directories, configured as Playwright projects
- **Test environment:** Real Supabase test project, unique users per test, global setup/teardown

### Conflict & Resilience Tests
- Network failure mid-workout → local Hive cache preserves data → syncs on reconnect
- Network failure during finish → error state shown → retry succeeds when network returns
- App crash during workout → restart → resume dialog → data intact
- Hive corruption → app logs error and starts fresh, doesn't crash (user sees clear message)
- Hive schema version mismatch → discard stale data, start fresh
- Concurrent sessions: user cannot start two active workouts (`is_active` flag + partial index)
- Token expiration during long workout → transparent refresh; on failure, persist to Hive and show "Session expired" banner
- Exercise soft delete → hidden from library AND search, visible in past workouts, template warns with substitution option
- Offline edits conflict → last-write-wins with timestamp comparison
- Duplicate PR prevention → idempotent creation with exercise_id + record_type constraint
- Double-tap "Finish Workout" → only one workout saved (idempotent)
- Atomic workout save → no partial data on network failure (Postgres RPC)

### Manual QA Checklist
- Auth on all providers (Google, email)
- Test on physical Android device + Android emulator
- Test on Chrome (Flutter web) for Playwright e2e
- Dark theme renders correctly on all screens
- Contrast: primary green (#00E676) never used as body text on cards — only for headings (20sp+), icons, buttons
- Touch targets: minimum 48x48dp interactive, 56x56dp for workout logging primary actions
- One-handed usability: core actions reachable by thumb (filter chips, exercise picker from bottom)
- Logging speed: set logged in under 3 taps (pre-filled values + stepper/wheel input)
- Haptic feedback present: set completion, PR celebration, rest timer end, destructive actions
- Rest timer: vibration works, screen stays awake, countdown visible at glance
- Weight input: accepts decimals (22.5), respects unit preference (kg/lbs)
- Deep-linking: email verification link works on Android
- Empty states: all screens have clear CTAs when empty (exercises, history, PRs, home)

### UX Design Direction
- **Typography:** Body text at w500 (sturdy feel). Consider condensed font (Barlow Condensed / Oswald) for numeric displays.
- **Colors:** Gradient accents for primary actions (#00E676 → #00BFA5), not flat fills. Destructive gradient (#FF5252 → #D32F2F).
- **Cards:** Subtle 1px top border with primary green at 15% opacity fading to transparent.
- **Numbers:** Weight/reps/timer at 48-64sp with subtle green glow shadow. These are the hero content.
- **Border radii:** Mixed — 16px cards, 8px chips, 24px FABs, 0px active workout header (sharp = urgency).
- **Spacing:** Tight within set rows (8dp), generous between exercises (24dp). Not uniform.
- **Icons:** Filled/bold variants (Material Symbols weight 600+), not thin-line.
- **Anti-patterns:** No pastel colors, no thin-line icons, no uniform padding, no generic Material Design.
