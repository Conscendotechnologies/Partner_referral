// Values one case notes for a later case in the same run ("Note its full name"), e.g. the Lead S03-TC-08 creates for
// S03-TC-09. Kept in .sf-ai-tester/run-state (git-ignored), not in memory: Playwright restarts its worker after a failure.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const dir = resolve(__dirname, '..', '..', '..', '.sf-ai-tester', 'run-state');

export function noteForLaterCase(key: string, value: string) {
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, `${key}.txt`), value, 'utf8');
}

/** The value an earlier case noted. Throws (so the case fails at its precondition) if that case has not run. */
export function notedByEarlierCase(key: string): string {
  const file = join(dir, `${key}.txt`);
  if (!existsSync(file)) throw new Error(`Precondition: ${key} has not run on this machine (nothing noted in ${file})`);
  return readFileSync(file, 'utf8').trim();
}
