import { defineConfig } from '@playwright/test';

// Playwright config for the specs SF AI Tester generates from the suites in ./test-cases.
// SF_INSTANCE_URL / SF_STORAGE_STATE come from the tester, or from `node scripts/sf-auth.mjs <alias>`
// locally and in CI (see README.md). Specs never contain credentials.
// SF_PW_AUTHORING is set only while the AI writes a spec: short timeouts so a wrong locator fails in seconds.
const authoring = !!process.env.SF_PW_AUTHORING;
// One id per run, set when the runner loads this config; workers inherit it. support/run-state.ts only returns
// values noted in the same run.
process.env.SF_RUN_ID ??= `${Date.now()}-${process.pid}`;

export default defineConfig({
  testDir: './tests/sf-ai',
  timeout: authoring ? 90_000 : 180_000,
  expect: { timeout: authoring ? 10_000 : 20_000 },
  retries: 0,
  // The cases share one org and some depend on records an earlier case created, so they run in file order.
  workers: 1,
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }], ['junit', { outputFile: 'test-results/junit.xml' }]] : [['list']],
  outputDir: process.env.SF_PW_OUTPUT_DIR || './.sf-ai-tester/playwright-output',
  use: {
    baseURL: process.env.SF_INSTANCE_URL,
    storageState: process.env.SF_STORAGE_STATE,
    viewport: { width: 1920, height: 1080 },
    actionTimeout: authoring ? 15_000 : 30_000,
    navigationTimeout: authoring ? 30_000 : 60_000,
    screenshot: 'only-on-failure',
    // A trace records request headers and cookies, which hold the Salesforce session. CI uploads its report, so CI
    // keeps no traces (screenshots only); set SF_PW_TRACE=1 to keep them on your own machine.
    trace: !process.env.CI && process.env.SF_PW_TRACE ? 'retain-on-failure' : 'off',
  },
});
