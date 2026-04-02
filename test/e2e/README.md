# GymBuddy E2E Tests (Playwright)

Smoke and full end-to-end tests for the GymBuddy Flutter web app.

## Prerequisites

- Node.js 22+
- Flutter SDK (for building / serving the app)
- A Supabase project with test data seeded
- Test user credentials (see "Test user setup" below)

## Quick start

### 1. Install dependencies

```bash
cd test/e2e
npm install
npx playwright install chromium
```

### 2. Serve the Flutter app

Playwright tests talk to a running web server — they do not start Flutter
themselves. Use one of the two options below.

**Option A — production build (recommended for CI):**

```bash
# From the repo root
export PATH="/c/flutter/bin:$PATH"
flutter build web --web-renderer html
cd build/web && python3 -m http.server 8080
```

**Option B — development server with hot-reload:**

```bash
# From the repo root
flutter run -d chrome --web-port 8080 --web-renderer html
```

> The `--web-renderer html` flag is required. The default CanvasKit renderer
> draws to a single `<canvas>` element, which makes DOM-based selectors
> unreliable. The HTML renderer creates real DOM nodes and forwards Flutter
> Semantics as ARIA attributes.

### 3. Set test credentials

Create `test/e2e/.env` (never commit this file):

```
TEST_USER_EMAIL=e2e-test@yourdomain.com
TEST_USER_PASSWORD=YourSecurePassword!
```

Or export them in your shell:

```bash
export TEST_USER_EMAIL=e2e-test@yourdomain.com
export TEST_USER_PASSWORD=YourSecurePassword!
```

### 4. Run tests

```bash
cd test/e2e

# Smoke tests only (fast, ~2 min)
npx playwright test --project=smoke

# All tests
npx playwright test

# With interactive UI (great for debugging)
npx playwright test --project=smoke --ui

# Show the HTML report after a run
npx playwright show-report
```

Or use the npm scripts:

```bash
npm run test:smoke
npm run test:full
npm run test:ui
```

## Test user setup

1. Start the Flutter app locally.
2. Sign up through the in-app flow (creates both the Supabase Auth record and
   the `profiles` row).
3. Confirm the email address using the link sent to your inbox. Alternatively,
   disable email confirmation in your Supabase project's Auth settings for the
   test environment.
4. Store the credentials in `test/e2e/.env` as shown above.

For CI, store `TEST_USER_EMAIL` and `TEST_USER_PASSWORD` as repository secrets
and inject them as environment variables in the workflow step that runs
Playwright.

## Seed data

The exercise-library smoke tests expect exercises to be seeded. Run:

```bash
psql $DATABASE_URL -f supabase/seed.sql
```

Or use `supabase db reset` if you are running a local Supabase stack.

## Why tests are skipped by default

All smoke tests call `test.skip(true, ...)` at the top level. This prevents
them from failing in `flutter test` (which runs Dart tests, not Playwright)
and in CI before the infrastructure is fully configured.

To activate a suite, remove the `test.skip` call from the relevant spec file.

## Directory layout

```
test/e2e/
├── playwright.config.ts       # Project config and baseURL
├── package.json
├── README.md                  # This file
├── helpers/
│   ├── selectors.ts           # Centralised ARIA / text selectors
│   ├── app.ts                 # waitForAppReady, navigateToTab
│   └── auth.ts                # login, logout, getTestCredentials
├── smoke/
│   ├── auth.smoke.spec.ts
│   └── exercise-library.smoke.spec.ts
└── full/                      # Reserved for comprehensive journey tests
```

## Selector strategy

Flutter web with the HTML renderer emits `flt-semantics` elements with proper
ARIA attributes derived from `Semantics` widgets in the Dart code. Key labels
used in the app:

| Widget / element         | Semantics label                        |
|--------------------------|----------------------------------------|
| Muscle group filter btn  | `<Name> muscle group filter`           |
| Equipment filter chip    | `<Name> equipment filter`              |
| Exercise card            | `Exercise: <name>`                     |
| Create exercise FAB      | `Create new exercise`                  |
| Delete exercise button   | `Delete exercise`                      |
| Exercise image (start)   | `<Exercise name> start position`       |
| Exercise image (end)     | `<Exercise name> end position`         |

Screens that do not yet have `Semantics` wrappers (LoginScreen, AppBar items,
NavigationDestination labels) are targeted by visible text content using
Playwright's `text=` selector or by `aria-label` attributes that Flutter infers
automatically from widget properties (e.g., `NavigationDestination.label`).

Adding explicit `Semantics` labels to LoginScreen and other auth screens is
tracked as a follow-up task and will make these selectors more robust.
