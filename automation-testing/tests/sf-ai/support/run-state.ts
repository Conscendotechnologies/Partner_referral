// Values one case notes for a later case in the same run ("Note its full name"), e.g. the Lead S03-TC-08 creates for
// S03-TC-09. Kept in .sf-ai-tester/run-state (git-ignored), not in memory: Playwright restarts its worker after a failure.
// Each value is stamped with the run's id (SF_RUN_ID, set once per run by playwright.sf-ai.config.ts), and a value from
// another run is never returned.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const dir = resolve(__dirname, '..', '..', '..', '.sf-ai-tester', 'run-state');

function runId(): string {
  const id = process.env.SF_RUN_ID;
  if (!id) throw new Error('SF_RUN_ID is not set: run the specs with playwright.sf-ai.config.ts');
  return id;
}

export function noteForLaterCase(key: string, value: string) {
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, `${key}.json`), JSON.stringify({ run: runId(), value }), 'utf8');
}

/** The value an earlier case noted in this run. Throws (so the case fails at its precondition) otherwise. */
export function notedByEarlierCase(key: string): string {
  const file = join(dir, `${key}.json`);
  const noted = existsSync(file) ? (JSON.parse(readFileSync(file, 'utf8')) as { run: string; value: string }) : null;
  if (!noted || noted.run !== runId()) {
    throw new Error(`Precondition: the case that notes "${key}" has not passed that step in this run`);
  }
  return noted.value;
}
