# GymBuddy E2E Tests (Playwright)

End-to-end regression tests for the GymBuddy Flutter web app.

## Prerequisites

- Node.js 20+
- Flutter SDK (for building the app)
- A Supabase project with test data seeded
- Test credentials in `test/e2e/.env.local` (see below)

## Quick start

### 1. Install dependencies

```bash
cd test/e2e
npm install
npx playwright install chromium
```

### 2. Build the Flutter app

Playwright auto-starts the web server for local dev using the pre-built assets.
You must build the app first:

```bash
# From the repo root
export PATH="/c/flutter/bin:$PATH"
flutter build web
```

### 3. Set up credentials

Create `test/e2e/.env.local` (never commit this file):

```
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=<your-anon-key>
SUPABASE_SERVICE_ROLE_KEY=<your-service-role-key>
TEST_USER_PASSWORD=TestPassword123!
```

All other configuration (app URL, test user emails) is handled automatically.

### 4. Run tests

```bash
cd test/e2e

# Full regression suite (all tests)
npx playwright test

# Smoke tests only (faster subset, @smoke tagged)
npx playwright test --grep @smoke

# Regression-only tests (everything except smoke)
npx playwright test --grep-invert @smoke

# Single feature file
npx playwright test specs/auth.spec.ts

# With interactive UI (great for debugging)
npx playwright test --ui

# Show the HTML report after a run
npx playwright show-report
```

Or use the npm scripts:

```bash
npm run test           # full regression suite
npm run test:smoke     # @smoke tagged tests only
npm run test:full      # non-smoke tests only
npm run test:ui        # interactive UI mode
```

## Port configuration

| Environment  | How the server is started            | Port |
|--------------|--------------------------------------|------|
| Local dev    | Playwright `webServer` auto-start (`static-server.cjs`) | 4200 |
| CI           | Workflow step (`static-server.cjs`), `FLUTTER_APP_URL` env var set | 8080 |

To use a custom port or a dev server locally, set `FLUTTER_APP_URL` in your
shell before running Playwright and start the server yourself:

```bash
export FLUTTER_APP_URL=http://localhost:9000
node static-server.cjs ../../build/web 9000 &
cd test/e2e && npx playwright test
```

When `FLUTTER_APP_URL` is set, Playwright skips the `webServer` auto-start.

> **CanvasKit note**: Flutter web uses CanvasKit by default. Playwright targets
> `flt-semantics` elements that Flutter generates for accessibility (ARIA
> attributes from `Semantics` widgets). These elements are present regardless
> of the renderer. Playwright must first click the hidden accessibility
> placeholder to activate the semantics tree — `waitForAppReady()` handles this.

## Test user setup

Test users are created automatically in `global-setup.ts` using the Supabase
Admin Auth API (requires `SUPABASE_SERVICE_ROLE_KEY` in `.env.local`). No
manual user creation is required.

Each spec file uses a dedicated isolated user to prevent shared mutable state.
User definitions are in `test/e2e/fixtures/test-users.ts`.

## Seed data

The exercise-library and workout tests expect exercises seeded from
`supabase/seed.sql`. Run:

```bash
supabase db reset
```

Or for a local Supabase stack, `supabase start` will apply migrations and seed
data automatically.

## Directory layout

```
test/e2e/
├── playwright.config.ts       # Project config, baseURL, webServer auto-start
├── package.json
├── README.md                  # This file
├── global-setup.ts            # Creates test users via Supabase Admin API
├── global-teardown.ts         # Deletes test users after the run
├── fixtures/
│   ├── test-users.ts          # Dedicated test user credentials per spec file
│   └── test-exercises.ts      # Known exercise names from seed.sql
├── helpers/
│   ├── selectors.ts           # Centralised ARIA / text selectors
│   ├── app.ts                 # waitForAppReady, navigateToTab
│   ├── auth.ts                # login, logout
│   └── workout.ts             # startEmptyWorkout, addExercise, setWeight, setReps, completeSet, finishWorkout
└── specs/                         # Feature-based test files (@smoke tagged for CI gate)
    ├── auth.spec.ts
    ├── crash-recovery.spec.ts
    ├── exercises.spec.ts
    ├── home.spec.ts
    ├── manage-data.spec.ts
    ├── onboarding.spec.ts
    ├── personal-records.spec.ts
    ├── profile.spec.ts
    ├── routines.spec.ts
    ├── weekly-plan.spec.ts
    └── workouts.spec.ts
```

## Selector strategy

Flutter web emits `flt-semantics` elements with proper ARIA attributes derived
from `Semantics` widgets in the Dart code. Key labels used in the app:

| Widget / element         | Semantics label                        |
|--------------------------|----------------------------------------|
| Muscle group filter btn  | `<Name> muscle group filter`           |
| Equipment filter chip    | `<Name> equipment filter`              |
| Exercise card            | `Exercise: <name>`                     |
| Create exercise FAB      | `Create new exercise`                  |
| Delete exercise button   | `Delete exercise`                      |
| Exercise picker tile     | `Add <name>`                           |
| Set done checkbox        | `Mark set as done` / `Set completed`   |
| Add exercise FAB         | `Add exercise to workout`              |

Screens that do not yet have `Semantics` wrappers (LoginScreen, AppBar items)
are targeted by visible text content using Playwright's `text=` selector or by
`aria-label` attributes that Flutter infers automatically from widget properties
(e.g., `NavigationDestination.label`).

## Weight and reps entry

The weight and reps steppers use `GestureDetector.onTap` on the value text
(e.g. "0") to open an `AlertDialog` with a `TextField`. Flutter CanvasKit
injects a hidden `<input>` overlay into the DOM for focused text fields.
The `setWeight()` and `setReps()` helpers in `helpers/workout.ts` encapsulate
this interaction pattern:

1. Click the first visible "0" text (the value in the set row)
2. Wait for the dialog title ("Enter weight" / "Enter reps") to confirm
3. Fill the hidden `<input>` overlay with the new value
4. Click "OK" to confirm and dismiss the dialog
