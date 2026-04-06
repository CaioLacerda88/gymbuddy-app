/**
 * App-level helpers: launch, readiness checks, and navigation.
 *
 * The Flutter app is served automatically by Playwright's webServer config
 * during local dev (port 4200 by default). In CI the FLUTTER_APP_URL env var
 * is set by the workflow and Playwright connects to the pre-running server.
 *
 * To start the server manually for debugging:
 *   flutter build web
 *   npx serve -s build/web -l 4200
 *
 * OR during active development (with hot-reload):
 *   flutter run -d chrome --web-port 4200
 */

import { Page } from '@playwright/test';
import { NAV } from './selectors';

/**
 * Wait for the Flutter app to finish its initial load.
 *
 * Flutter web (CanvasKit) renders to <canvas> and does NOT enable the
 * accessibility/semantics tree by default. It shows a hidden
 * "Enable accessibility" placeholder button instead. We must activate it
 * so that flt-semantics elements are generated for Playwright to interact with.
 *
 * After enabling semantics and waiting for auth to resolve, the router
 * redirects to /login, /home, or /onboarding.
 *
 * Timeout is generous (60s) to accommodate CanvasKit WASM download.
 */
export async function waitForAppReady(page: Page): Promise<void> {
  // Collect console errors for diagnostics if the app hangs.
  const consoleErrors: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      consoleErrors.push(`[console.error] ${msg.text()}`);
    }
  });
  page.on('pageerror', (err) => {
    consoleErrors.push(`[page error] ${String(err)}`);
  });

  // 1. Wait for Flutter to render and show the accessibility placeholder.
  try {
    await page.waitForSelector(
      'flt-semantics-placeholder[aria-label="Enable accessibility"]',
      { timeout: 60_000 },
    );
  } catch (e) {
    const bodyText = await page.evaluate(() => document.body?.innerText ?? '');
    throw new Error(
      `Flutter app failed to render. ` +
        `Body text: "${bodyText.slice(0, 500)}". ` +
        `Console errors: ${JSON.stringify(consoleErrors)}`,
    );
  }

  // 2. Enable the full semantics tree. Flutter web activates semantics in
  //    response to real user interaction. We dispatch a focused click sequence
  //    on the placeholder element AND press Tab as a fallback.
  await page.evaluate(() => {
    const btn = document.querySelector(
      'flt-semantics-placeholder[aria-label="Enable accessibility"]',
    ) as HTMLElement | null;
    if (btn) {
      btn.focus();
      btn.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }));
      btn.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
      btn.dispatchEvent(new MouseEvent('mouseup', { bubbles: true }));
      btn.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    }
  });

  // Tab key is an additional signal that Flutter uses to enable semantics.
  await page.keyboard.press('Tab');

  // 3. Wait for a known post-splash landmark to confirm the app is ready.
  //    The auth stream has a 10-second timeout fallback, so the splash screen
  //    will resolve within ~12 seconds even if Supabase is unreachable.
  try {
    await page.waitForSelector(
      [
        '[aria-label="LOG IN"]',
        '[aria-label="Home"]',
        '[aria-label="GET STARTED"]',
      ].join(', '),
      { timeout: 30_000 },
    );
  } catch (e) {
    // Dump diagnostics: what's actually on screen + any console errors.
    const snapshot = await page.evaluate(() => {
      const els = document.querySelectorAll('flt-semantics');
      return Array.from(els)
        .map((el) => el.getAttribute('aria-label'))
        .filter(Boolean)
        .join(', ');
    });
    throw new Error(
      `App stuck on splash — auth stream may not have emitted. ` +
        `Visible semantics: [${snapshot}]. ` +
        `Console errors: ${JSON.stringify(consoleErrors)}`,
    );
  }
}

/**
 * Navigate to a bottom navigation tab by its label.
 *
 * Tabs: 'Home' | 'Exercises' | 'Routines' | 'Profile'
 *
 * The NavigationBar destinations emit aria-label via Flutter Semantics, so we
 * target them with the selector map in NAV.
 */
export async function navigateToTab(
  page: Page,
  tabName: 'Home' | 'Exercises' | 'Routines' | 'Profile',
): Promise<void> {
  const selectorMap: Record<string, string> = {
    Home: NAV.homeTab,
    Exercises: NAV.exercisesTab,
    Routines: NAV.routinesTab,
    Profile: NAV.profileTab,
  };

  const selector = selectorMap[tabName];
  await page.click(selector);

  // Wait for the tab content heading to appear as a signal that navigation
  // completed. The heading text matches the tab label for most screens.
  await page.waitForSelector(`text=${tabName}`, { timeout: 15_000 });
}

/**
 * Fill a Flutter text field via CanvasKit semantics.
 *
 * Flutter CanvasKit renders to <canvas> — the flt-semantics elements are
 * accessibility overlays (divs), not real <input> elements. Playwright's
 * `page.fill()` only works on native inputs, so we click the semantics
 * node to focus the Flutter TextField, then type via the keyboard.
 *
 * If the field already has text, triple-click to select all before typing
 * so the new value replaces the old one (mirroring page.fill() behavior).
 */
export async function flutterFill(
  page: Page,
  selector: string,
  value: string,
): Promise<void> {
  // Focus the Flutter TextField via its semantics element.
  await page.click(selector);
  // Select all existing text (triple-click) and replace.
  await page.keyboard.press('Control+a');
  if (value === '') {
    await page.keyboard.press('Backspace');
  } else {
    await page.keyboard.type(value);
  }
}
