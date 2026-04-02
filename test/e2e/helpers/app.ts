/**
 * App-level helpers: launch, readiness checks, and navigation.
 *
 * The Flutter app must be served BEFORE running tests. Playwright does not
 * start the app server automatically.
 *
 * Serve the app with:
 *   flutter build web --web-renderer html
 *   cd build/web && python3 -m http.server 8080
 *
 * OR during active development (with hot-reload):
 *   flutter run -d chrome --web-port 8080 --web-renderer html
 *
 * The baseURL in playwright.config.ts is set to http://localhost:8080.
 */

import { Page } from '@playwright/test';
import { NAV } from './selectors';

/**
 * Wait for the Flutter app to finish its initial load.
 *
 * The SplashScreen is shown while auth state resolves, then the router
 * redirects to /login or /home. We wait for the splash to disappear by
 * checking that at least one of the known post-splash elements is visible.
 *
 * Flutter web (HTML renderer) mounts a <flutter-view> root. We wait for that
 * first, then for the app content to stabilise.
 */
export async function waitForAppReady(page: Page): Promise<void> {
  // Wait for Flutter to mount its root element.
  await page.waitForSelector('flutter-view, flt-glass-pane', {
    timeout: 30_000,
  });

  // Wait for the splash screen transition to complete. After auth resolves,
  // the router shows either the login screen (GymBuddy title) or the shell
  // nav bar. We poll for either landmark.
  await page.waitForFunction(
    () => {
      const text = document.body.innerText ?? '';
      return text.includes('GymBuddy') || text.includes('Home');
    },
    { timeout: 30_000, polling: 500 },
  );
}

/**
 * Navigate to a bottom navigation tab by its label.
 *
 * Tabs: 'Home' | 'Exercises' | 'History' | 'Profile'
 *
 * The NavigationBar destinations emit aria-label via Flutter Semantics, so we
 * target them with the selector map in NAV.
 */
export async function navigateToTab(
  page: Page,
  tabName: 'Home' | 'Exercises' | 'History' | 'Profile',
): Promise<void> {
  const selectorMap: Record<string, string> = {
    Home: NAV.homeTab,
    Exercises: NAV.exercisesTab,
    History: NAV.historyTab,
    Profile: NAV.profileTab,
  };

  const selector = selectorMap[tabName];
  await page.click(selector);

  // Wait for the tab content heading to appear as a signal that navigation
  // completed. The heading text matches the tab label for placeholder screens.
  if (tabName === 'Exercises') {
    await page.waitForSelector('text=Exercises', { timeout: 15_000 });
  } else {
    // Placeholder screens render the tab name as a centered heading.
    await page.waitForSelector(`text=${tabName}`, { timeout: 15_000 });
  }
}
