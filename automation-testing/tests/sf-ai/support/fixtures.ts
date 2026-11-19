// Every spec imports `test` and `expect` from here instead of '@playwright/test'.
//
// A case listed in expected-failures.json (TC id -> the fix it waits for) is marked with test.fail(): while the defect
// is open the run stays green, and once the fix is deployed and the spec passes, Playwright reports it as an
// unexpected pass, so the entry has to be removed. Nothing in a spec changes either way.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test as base, expect } from '@playwright/test';

const expectedFailures: Record<string, string> = JSON.parse(
  readFileSync(join(__dirname, '..', '..', '..', 'expected-failures.json'), 'utf8')
);

export const test = base.extend<{ expectedFailure: void }>({
  expectedFailure: [
    async ({}, use, testInfo) => {
      const id = testInfo.title.split(':')[0].trim();
      if (expectedFailures[id]) testInfo.fail(true, `Expected to fail until ${expectedFailures[id]}`);
      await use();
    },
    { auto: true }
  ]
});

export { expect };
