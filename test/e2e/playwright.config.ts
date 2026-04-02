import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: '.',
  timeout: 60_000,
  retries: 1,
  use: {
    baseURL: 'http://localhost:8080',
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
