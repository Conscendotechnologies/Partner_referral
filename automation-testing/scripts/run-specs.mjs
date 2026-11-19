// Runs the ui specs the same way locally and in CI: resets the AI-TEST data (qa-data.mjs), then runs Playwright with
// playwright.sf-ai.config.ts, leaving out the payout-run cases (S07-TC-03/07/09) when the reset says S07 must not run.
//
//   node scripts/run-specs.mjs <org alias> [extra Playwright args, e.g. --grep "S02-"]
//
// Needs SF_INSTANCE_URL and SF_STORAGE_STATE (see README). Exits with Playwright's exit code.
import { spawnSync } from 'node:child_process';

const [alias, ...extra] = process.argv.slice(2);
if (!alias) {
  console.error('usage: node scripts/run-specs.mjs <org alias> [playwright args]');
  process.exit(2);
}

const reset = spawnSync(process.execPath, ['scripts/qa-data.mjs', alias], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'inherit'] });
if (reset.status !== 0) process.exit(reset.status ?? 1);

const args = ['playwright', 'test', '--config', 'playwright.sf-ai.config.ts', ...extra];
// The reset's result alone decides S07: an inherited SF_SKIP_S07 is overwritten either way.
const skipS07 = /^SF_SKIP_S07=1$/m.test(reset.stdout);
process.env.SF_SKIP_S07 = skipS07 ? '1' : '0';
// A fresh run id, so values noted by an earlier run (support/run-state.ts) are never used.
delete process.env.SF_RUN_ID;
if (skipS07) {
  console.error('S07-TC-03/07/09 (payout run) skipped: the reset found payout data that is not AI-TEST alone.');
  args.push('--grep-invert', 'S07-TC-0[379]:');
  // fixtures.ts also skips them when SF_SKIP_S07=1, in case a later filter selects them again.
}
// npx is a .cmd on Windows, so it runs through the shell there and arguments with spaces or quotes are quoted.
const win = process.platform === 'win32';
const shellArgs = win ? args.map((a) => (/[\s"&|<>^]/.test(a) ? `"${a.replace(/"/g, '\\"')}"` : a)) : args;
const run = spawnSync('npx', shellArgs, { stdio: 'inherit', shell: win, env: process.env });
process.exit(run.status ?? 1);
