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

import { Page, expect } from '@playwright/test';
import { GAMIFICATION, NAV, PR, PROFILE, SAGA } from './selectors';

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

  // 1. Wait for Flutter to render. With --force-renderer-accessibility in the
  //    Playwright launch args, Chrome exposes its accessibility tree and Flutter
  //    auto-enables semantics. We wait for either the placeholder OR any
  //    flt-semantics element (the latter appears when semantics are already on).
  try {
    await page.waitForSelector(
      'flt-semantics-placeholder, flt-semantics',
      { timeout: 60_000 },
    );
  } catch (e) {
    let bodyText = '';
    try {
      bodyText = await page.evaluate(() => document.body?.innerText ?? '');
    } catch {
      // Page already closed — diagnostics unavailable.
    }
    throw new Error(
      `Flutter app failed to render. ` +
        `Body text: "${bodyText.slice(0, 500)}". ` +
        `Console errors: ${JSON.stringify(consoleErrors)}`,
    );
  }

  // 2. Ensure the semantics tree is enabled. With --force-renderer-accessibility,
  //    Flutter usually enables semantics automatically. If not yet active, we
  //    fall back to clicking the placeholder and pressing Tab. Retry up to 3
  //    times to handle timing races during engine initialisation.
  for (let attempt = 0; attempt < 3; attempt++) {
    const semanticsCount = await page.locator('flt-semantics').count();
    if (semanticsCount > 0) break;

    // Fallback: manually trigger semantics via placeholder click + Tab.
    const placeholder = page.locator(
      'flt-semantics-placeholder[aria-label="Enable accessibility"]',
    );
    await placeholder.click({ force: true, timeout: 5_000 }).catch(() => {});
    await page.keyboard.press('Tab');

    // Also try dispatching a pointer event via JS as a last resort — the
    // placeholder may be inside shadow DOM where Playwright's click doesn't
    // trigger Flutter's event handler.
    await page.evaluate(() => {
      const el =
        document.querySelector('flt-semantics-placeholder') ??
        document
          .querySelector('flutter-view')
          ?.shadowRoot?.querySelector('flt-semantics-placeholder');
      if (el) {
        el.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }));
        el.dispatchEvent(new PointerEvent('pointerup', { bubbles: true }));
      }
    });

    await page.waitForTimeout(attempt < 2 ? 2000 : 500);
  }

  // 3. Wait for the router to navigate away from the splash screen.
  //    With the synchronous auth init, the router resolves immediately:
  //    no session → /login, active session → /home, new user → /onboarding,
  //    active workout in Hive → /workout/active.
  //
  //    We use URL-based detection because it's reliable regardless of whether
  //    flt-semantics elements are in light DOM or shadow DOM.
  try {
    await page.waitForURL(
      /\/(login|home|onboarding|workout|exercises|routines|profile|records)/,
      { timeout: 30_000 },
    );
  } catch (e) {
    // Dump diagnostics: what's actually on screen + any console errors.
    const currentUrl = page.url();
    let snapshot = '';
    try {
      snapshot = await page.evaluate(() => {
        // Check both light DOM and shadow DOM for flt-semantics elements.
        // Flutter 3.41.6+ uses AOM — accessible names are set via the
        // ariaLabel JS property, not as a DOM attribute. Try both.
        const getLabel = (el: Element) =>
          (el as any).ariaLabel ?? el.getAttribute('aria-label') ?? '';
        const lightEls = document.querySelectorAll('flt-semantics');
        const labels = Array.from(lightEls)
          .map(getLabel)
          .filter(Boolean);

        // Also check inside flutter-view shadow root.
        const flutterView = document.querySelector('flutter-view');
        if (flutterView?.shadowRoot) {
          const shadowEls = flutterView.shadowRoot.querySelectorAll('flt-semantics');
          labels.push(
            ...Array.from(shadowEls)
              .map(getLabel)
              .filter(Boolean),
          );
        }

        return labels.join(', ');
      });
    } catch {
      // Page already closed — diagnostics unavailable.
    }
    throw new Error(
      `App stuck on splash — router did not navigate away. ` +
        `URL: ${currentUrl}. ` +
        `Visible semantics: [${snapshot}]. ` +
        `Console errors: ${JSON.stringify(consoleErrors)}`,
    );
  }

  // 4. Wait for the destination screen to populate its semantics tree.
  await page.locator('flt-semantics').first().waitFor({ state: 'visible', timeout: 5_000 });
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

  // URL segment for each tab — used to detect navigation completion.
  const urlSegmentMap: Record<string, string> = {
    Home: 'home',
    Exercises: 'exercises',
    Routines: 'routines',
    Profile: 'profile',
  };

  const selector = selectorMap[tabName];
  await page.click(selector);

  // Wait for the URL to contain the tab's route segment. This is more reliable
  // than waiting for `text=${tabName}` because `text=` matches visible text node
  // content, not aria-label attributes (which is what the nav tabs use).
  await page.waitForURL(`**/${urlSegmentMap[tabName]}**`, { timeout: 15_000 });

  // Wait for destination screen semantics tree to populate.
  await page.locator('flt-semantics').first().waitFor({ state: 'visible', timeout: 5_000 });
}

/**
 * Fill a Flutter text field via CanvasKit semantics.
 *
 * Flutter CanvasKit renders to <canvas> — the flt-semantics elements are
 * accessibility overlays (divs), not real <input> elements. Flutter uses a
 * single shared native <input> proxy for text editing. When focus moves
 * between TextFields, values set via Playwright's fill() on this proxy are
 * lost because Flutter doesn't commit the value back to its internal
 * TextEditingController on the focus transition.
 *
 * Instead we click the semantics node to focus the TextField, then use
 * page.keyboard to send real key events at the window level. Flutter
 * captures these and routes them to the focused text field, bypassing the
 * native input proxy entirely.
 */
export async function flutterFill(
  page: Page,
  selector: string,
  value: string,
): Promise<void> {
  // Click the semantics element to focus the Flutter TextField.
  // Flutter 3.41.6 exposes a hidden native <input> proxy with role=textbox,
  // which may match the selector. Using .last() targets the visible semantics
  // overlay (rendered after the proxy in DOM order) rather than the invisible proxy.
  await page.locator(selector).last().click({ timeout: 15_000 });

  // Wait for Flutter's native <input> proxy to appear — this confirms the
  // text editing connection is established and the field is ready for input.
  const input = page.locator('input').last();
  await input.waitFor({ state: 'attached', timeout: 5_000 });
  await page.waitForTimeout(200);

  // Select all existing content (if any) so typing replaces it.
  await page.keyboard.press('Control+a');

  if (value === '') {
    // Clear the field by deleting the selection.
    await page.keyboard.press('Backspace');
  } else {
    // Type the value using real key events — the browser routes these to the
    // focused native <input>, which fires real input events that Flutter
    // processes correctly (unlike fill() which uses synthetic events).
    await page.keyboard.type(value, { delay: 10 });
  }
}

/**
 * Fill a Flutter search/filter text field that may not receive focus from a
 * semantics-node click alone.
 *
 * Some Flutter text fields (notably the exercise search bar) have their
 * underlying HTML <input> element positioned such that clicking the flt-semantics
 * overlay does not reliably transfer focus to the input. This helper targets the
 * underlying <input> element directly using an aria-label substring match.
 *
 * @param page     - Playwright page.
 * @param ariaHint - Substring of the <input aria-label> attribute used to find
 *                   the correct input element (e.g., "Search exercises").
 * @param value    - Text to type.
 */
export async function flutterFillByInput(
  page: Page,
  ariaHint: string,
  value: string,
): Promise<void> {
  const inputEl = page.locator(`input[aria-label*="${ariaHint}"]`);
  await inputEl.waitFor({ state: 'attached', timeout: 5_000 });
  await inputEl.focus();
  await page.waitForTimeout(200);
  await page.keyboard.press('Control+a');
  await page.keyboard.type(value, { delay: 10 });
}

/**
 * Change the active app locale via the Profile → Language sheet.
 *
 * Assumes the user is already logged in and the Profile tab is reachable via
 * the bottom navigation. The helper:
 *   1. Navigates to Profile tab (no-op if already there).
 *   2. Scrolls to / taps the Language row to open LanguagePickerSheet.
 *   3. Taps the option matching `locale`.
 *   4. Waits for the sheet to dismiss.
 *
 * The app persists the locale to Hive and (for logged-in users) Supabase, so
 * the new locale survives page reloads and sign-outs. Callers typically want
 * to reload the page after calling this so deeply-cached widgets rebuild.
 *
 * @param page   - Playwright page.
 * @param locale - Target locale: 'en' for English, 'pt' for Portuguese (Brasil).
 */
export async function setLocale(
  page: Page,
  locale: 'en' | 'pt',
): Promise<void> {
  // Phase 18b: /profile now shows CharacterSheetScreen; the language row is on
  // /profile/settings (ProfileSettingsScreen). Navigate to the Saga tab first,
  // then open settings via the gear icon before tapping the language row.
  await navigateToTab(page, 'Profile');
  await page.locator(SAGA.characterSheet).first().waitFor({ state: 'visible', timeout: 15_000 });
  await page.locator(SAGA.gearIcon).first().click();
  await page.locator(SAGA.profileSettingsScreen).first().waitFor({ state: 'visible', timeout: 10_000 });

  // Open the language picker sheet.
  await page.locator(PROFILE.languageRow).first().click({ timeout: 15_000 });
  await page
    .locator(PROFILE.languagePickerSheet)
    .first()
    .waitFor({ state: 'visible', timeout: 10_000 });

  // Tap the target locale option.
  await page
    .locator(PROFILE.languageOption(locale))
    .first()
    .click({ timeout: 10_000 });

  // Wait for the sheet to dismiss. The sheet is detached from the DOM when
  // Navigator.pop() fires, so we wait for its root semantics node to go away.
  await page
    .locator(PROFILE.languagePickerSheet)
    .first()
    .waitFor({ state: 'detached', timeout: 10_000 });
}

/**
 * Walk the SagaIntroOverlay through its three steps and dismiss it.
 *
 * The overlay appears on first home load for users who haven't yet seen it
 * (gated by Hive `saga_intro_seen` flag). This helper mirrors the real user
 * flow: wait for step 0 → NEXT → step 1 → NEXT → step 2 → BEGIN → gone.
 *
 * Extracted so gamification specs don't duplicate the sequence. The
 * timeouts match the original inline flow — the initial 20s wait
 * accommodates retro_backfill_xp resolving on first login.
 */
export async function dismissSagaIntroOverlay(page: Page): Promise<void> {
  await expect(page.locator(GAMIFICATION.step0)).toBeVisible({
    timeout: 20_000,
  });
  await page.locator(GAMIFICATION.nextButton).click();
  await expect(page.locator(GAMIFICATION.step1)).toBeVisible({
    timeout: 5_000,
  });
  await page.locator(GAMIFICATION.nextButton).click();
  await expect(page.locator(GAMIFICATION.step2)).toBeVisible({
    timeout: 5_000,
  });
  await page.locator(GAMIFICATION.beginButton).click();
  await expect(page.locator(GAMIFICATION.step0)).not.toBeVisible({
    timeout: 5_000,
  });
}

/**
 * Dismiss the PR/first-workout celebration screen if the app navigated to it.
 *
 * Replaces the common racy pattern of checking `PR.firstWorkoutHeading` /
 * `PR.newPRHeading` visibility. Both identifiers are placed on widgets inside
 * a `ScaleTransition` that starts at scale=0 — Flutter removes them from the
 * accessibility tree while the animation runs, so `isVisible()` races against
 * the animation and returns `false` even when the screen IS shown. This causes
 * the test to skip the "Continue" click and then time out waiting for `nav-home`
 * because the PR screen is still blocking.
 *
 * This helper uses waitForURL with a glob pattern that matches the
 * /pr-celebration route, which is immune to the animation state because the
 * URL changes synchronously with the route push. PR.continueButton
 * (pr-continue-btn) is outside the ScaleTransition so it is reliably visible
 * once the URL contains /pr-celebration.
 *
 * @param page    - Playwright page.
 * @param timeout - How long to wait for the celebration URL (ms). Default 20 s.
 */
export async function dismissCelebrationIfPresent(
  page: Page,
  timeout = 20_000,
): Promise<void> {
  const onCelebration = await page
    .waitForURL('**/pr-celebration**', { timeout })
    .then(() => true)
    .catch(() => false);

  if (onCelebration) {
    // The Continue button is outside the ScaleTransition and is always reachable
    // once we are on the /pr-celebration route.
    await expect(page.locator(PR.continueButton)).toBeVisible({ timeout: 10_000 });
    await page.click(PR.continueButton);
    // Wait for the celebration route to leave before the caller continues.
    await page.waitForURL(/\/(home|profile)/, { timeout: 15_000 });
  }
}

/**
 * Simulate a long-press on a Flutter element.
 *
 * Flutter CanvasKit routes semantics `click()` directly to `SemanticsAction.tap`,
 * bypassing the GestureDetector long-press timer. To trigger `onLongPress`, we
 * must send raw pointer events: hover to position the cursor, mouse down, wait
 * for Flutter's long-press threshold (~500ms), then mouse up.
 *
 * @param page     - Playwright page.
 * @param selector - Playwright selector string for the target element.
 * @param duration - How long to hold the pointer down (ms). Default 800ms.
 */
export async function flutterLongPress(
  page: Page,
  selector: string,
  duration = 800,
): Promise<void> {
  const element = page.locator(selector).first();
  await element.hover();
  await page.mouse.down();
  await page.waitForTimeout(duration);
  await page.mouse.up();
}
