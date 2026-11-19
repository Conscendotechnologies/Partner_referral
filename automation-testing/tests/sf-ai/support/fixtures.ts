// Every spec imports `test` and `expect` from here instead of '@playwright/test'.
//
// A case listed in expected-failures.json (TC id -> the fix it waits for) is marked with test.fail(): while the defect
// is open the run stays green, and once the fix is deployed and the spec passes, Playwright reports it as an
// unexpected pass, so the entry has to be removed. Nothing in a spec changes either way.
//
// When the data reset said S07 must not run (SF_SKIP_S07=1, set by scripts/run-specs.mjs), the payout-run cases are
// skipped here too, so no title filter can select them.
//
// Evidence (SF_EVIDENCE=1, see scripts/evidence-pdf.mjs): after each top-level test.step, and at the end, a screenshot
// of the page in front is attached to the result as "evidence: <step>". The "Logged in as <user>" banner stays visible:
// it shows which persona did the step. No password is ever on screen (sessions come from the sf CLI login).
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test as base, expect, type BrowserContext, type Page, type TestInfo } from '@playwright/test';

const expectedFailures: Record<string, string> = JSON.parse(
  readFileSync(join(__dirname, '..', '..', '..', 'expected-failures.json'), 'utf8')
);

// The cases that run a payout or change its batch (S07-TC-04 only looks).
const PAYOUT_RUN_CASES = ['S07-TC-03', 'S07-TC-07', 'S07-TC-09'];

const EVIDENCE = process.env.SF_EVIDENCE === '1';
let current: { context: BrowserContext; testInfo: TestInfo; shots: number } | null = null;
let stepDepth = 0;

/** The page in front: the last one opened that is still open (Login-as opens a new tab). */
function frontPage(context: BrowserContext): Page | undefined {
  return context.pages().filter((p) => !p.isClosed()).at(-1);
}

async function capture(label: string) {
  if (!current) return;
  const page = frontPage(current.context);
  if (!page) return;
  // Evidence is best effort: a page that is closing or navigating must never change the test's result.
  const shot = await page.screenshot({ animations: 'disabled', timeout: 15_000 }).catch(() => null);
  if (!shot) return;
  current.shots++;
  await current.testInfo.attach(`evidence: ${String(current.shots).padStart(2, '0')} ${label}`, { body: shot, contentType: 'image/png' });
}

export const test = base.extend<{ expectedFailure: void; evidence: void }>({
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
  ],
  evidence: [
    async ({ context }, use, testInfo) => {
      if (!EVIDENCE) return use();
      current = { context, testInfo, shots: 0 };
      stepDepth = 0;
      await use();
      await capture(testInfo.status === testInfo.expectedStatus ? 'Final state' : 'Final state (where it failed)');
      current = null;
    },
    { auto: true }
  ]
});

if (EVIDENCE) {
  // A screenshot after every top-level step, whether it passed or failed. Nested steps (inside helpers) are covered by
  // their parent's screenshot.
  const step = test.step.bind(test) as typeof test.step;
  (test as unknown as { step: typeof test.step }).step = (async (title: string, body: () => unknown, options?: object) => {
    stepDepth++;
    try {
      return await step(title, body as never, options as never);
    } finally {
      stepDepth--;
      if (stepDepth === 0) await capture(title);
    }
  }) as typeof test.step;
}

export { expect };
