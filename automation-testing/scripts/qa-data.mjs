// Puts the AI-TEST test data into its starting state before a run, with the scripts in scripts/apex/pr-demo:
// 8-qa-reset-referrals, 9-qa-reset-commissions, then 7-qa-preconditions. Data only; nothing is deployed.
//
//   node scripts/qa-data.mjs <org alias> [referrals|commissions]
//
// "referrals" runs only 8 (S02 / S04 / S12-TC-01 data); "commissions" runs only 9 and 7 (S05 / S06 / S07 / S12).
//
// Progress goes to stderr. Stdout gets SF_SKIP_S07=1 when the reset found payout data that is not AI-TEST (the S07
// payout cases must not run then), so CI can append stdout to $GITHUB_ENV.
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

const alias = process.argv[2];
if (!alias) {
  console.error('usage: node scripts/qa-data.mjs <org alias>');
  process.exit(2);
}

const part = process.argv[3] || 'all';
const scripts = {
  all: ['8-qa-reset-referrals', '9-qa-reset-commissions', '7-qa-preconditions'],
  referrals: ['8-qa-reset-referrals'],
  commissions: ['9-qa-reset-commissions', '7-qa-preconditions']
}[part];
if (!scripts) {
  console.error(`unknown part "${part}": use referrals or commissions, or leave it out for both`);
  process.exit(2);
}

let skipS07 = false;
for (const name of scripts) {
  const file = resolve('..', 'scripts', 'apex', 'pr-demo', `${name}.apex`);
  // shell: true on Windows (sf is a .cmd), so the path is quoted there.
  const fileArg = process.platform === 'win32' ? `"${file}"` : file;
  const r = spawnSync('sf', ['apex', 'run', '--file', fileArg, '--target-org', alias, '--json'], {
    encoding: 'utf8',
    shell: process.platform === 'win32',
    maxBuffer: 64 * 1024 * 1024
  });
  let out;
  try {
    out = JSON.parse(r.stdout);
  } catch {
    console.error(`${name}: sf apex run returned no JSON (exit ${r.status})`);
    process.exit(1);
  }
  const result = out.result || {};
  // Only USER_DEBUG lines: the log also echoes the script source, which contains the same marker text.
  const debug = String(result.logs || '')
    .split('\n')
    .filter((l) => l.includes('|USER_DEBUG|') && l.includes('PR-QA'))
    .map((l) => l.slice(l.indexOf('PR-QA')));
  debug.forEach((l) => console.error(`${name}: ${l}`));
  if (!result.success) {
    console.error(`${name} failed: ${result.compileProblem || result.exceptionMessage || out.message || 'unknown error'}`);
    process.exit(1);
  }
  if (debug.some((l) => l.startsWith('PR-QA S07: SKIP'))) skipS07 = true;
}
if (skipS07) console.log('SF_SKIP_S07=1');
