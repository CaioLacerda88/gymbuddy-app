import { defineConfig } from '@playwright/test';
import dotenv from 'dotenv';
import path from 'path';

// Load .env.local so FLUTTER_APP_URL and Supabase credentials are available
// to both the config and the global setup/teardown scripts.
dotenv.config({ path: path.join(__dirname, '.env.local') });

export default defineConfig({
  testDir: '.',
  timeout: 60_000,
  retries: 1,
  globalSetup: './global-setup.ts',
  globalTeardown: './global-teardown.ts',
  use: {
    baseURL: process.env['FLUTTER_APP_URL'] ?? 'http://localhost:8080',
    headless: true,
    screenshot: 'only-on-failure',
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'smoke',
      testMatch: /smoke\/.*\.spec\.ts$/,
    },
    {
      name: 'full',
      testMatch: /full\/.*\.spec\.ts$/,
    },
  ],
});
