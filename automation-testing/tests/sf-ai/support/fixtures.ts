// Every spec imports `test` and `expect` from here instead of '@playwright/test'.
//
// A case listed in expected-failures.json (TC id -> the fix it waits for) is marked with test.fail(): while the defect
// is open the run stays green, and once the fix is deployed and the spec passes, Playwright reports it as an
// unexpected pass, so the entry has to be removed. Nothing in a spec changes either way.
//
// When the data reset said S07 must not run (SF_SKIP_S07=1, set by scripts/run-specs.mjs), the payout-run cases are
// skipped here too, so no title filter can select them.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test as base, expect } from '@playwright/test';

const expectedFailures: Record<string, string> = JSON.parse(
  readFileSync(join(__dirname, '..', '..', '..', 'expected-failures.json'), 'utf8')
);

// The cases that run a payout or change its batch (S07-TC-04 only looks).
const PAYOUT_RUN_CASES = ['S07-TC-03', 'S07-TC-07', 'S07-TC-09'];

export const test = base.extend<{ expectedFailure: void }>({
  expectedFailure: [
    async ({}, use, testInfo) => {
      const id = testInfo.title.split(':')[0].trim();
      testInfo.skip(
        process.env.SF_SKIP_S07 === '1' && PAYOUT_RUN_CASES.includes(id),
        'The data reset found payout data that is not AI-TEST alone (SF_SKIP_S07=1)'
      );
      if (expectedFailures[id]) testInfo.fail(true, `Expected to fail until ${expectedFailures[id]}`);
      await use();
    },
    { auto: true }
  ]
});

export { expect };
