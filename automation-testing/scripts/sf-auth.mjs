// Creates a Playwright storage state (logged-in browser session) from a Salesforce CLI org login, so the generated
// specs can run without SF AI Tester (CI, or your own machine).
//
//   node scripts/sf-auth.mjs <org alias> [storage file]
//
// Prints SF_INSTANCE_URL=... and SF_STORAGE_STATE=... lines to add to the environment. The frontdoor URL holds a
// session token and is never printed or written anywhere; only the browser's cookies are saved, to a git-ignored file.
import { spawnSync } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { chromium } from '@playwright/test';

const alias = process.argv[2];
const storageFile = resolve(process.argv[3] || '.sf-ai-tester/auth/storage.json');
if (!alias) {
  console.error('usage: node scripts/sf-auth.mjs <org alias> [storage file]');
  process.exit(2);
}

function sf(args) {
  const r = spawnSync('sf', [...args, '--json'], { encoding: 'utf8', shell: process.platform === 'win32' });
  let out;
  try {
    out = JSON.parse(r.stdout);
  } catch {
    throw new Error(`sf ${args[0]} ${args[1]} returned no JSON (exit ${r.status})`);
  }
  if (out.status !== 0) throw new Error(`sf ${args[0]} ${args[1]} failed: ${out.name}: ${out.message}`);
  return out.result;
}

const { instanceUrl } = sf(['org', 'display', '--target-org', alias]);
const { url } = sf(['org', 'open', '--target-org', alias, '--url-only', '--path', '/lightning/page/home']);

// Playwright puts the full URL (with the session token) into navigation errors and their call logs, so any failure
// from here on is reported with a fixed message and the original error is dropped.
const browser = await chromium.launch();
let failure = null;
try {
  const context = await browser.newContext();
  const page = await context.newPage();
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120_000 });
  // Lightning lives on a second domain; waiting for it to load stores the session cookies for both.
  await page.waitForURL(/\/lightning\//, { timeout: 120_000 });
  await page.waitForLoadState('networkidle', { timeout: 120_000 }).catch(() => {});
  if (/\/login|secur\/frontdoor/i.test(page.url())) failure = 'the frontdoor login did not reach Lightning';
  else {
    mkdirSync(dirname(storageFile), { recursive: true });
    await context.storageState({ path: storageFile });
  }
} catch {
  failure = 'the browser could not open the org from the CLI login (timed out or the page failed to load)';
} finally {
  await browser.close().catch(() => {});
}
if (failure) {
  console.error(`sf-auth: ${failure}. Check the login with: sf org display --target-org ${alias}`);
  process.exit(1);
}

console.log(`SF_INSTANCE_URL=${instanceUrl}`);
console.log(`SF_STORAGE_STATE=${storageFile}`);
