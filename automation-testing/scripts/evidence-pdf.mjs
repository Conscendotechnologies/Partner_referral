// Builds one evidence PDF per test case from a Playwright JSON report of a run with SF_EVIDENCE=1:
// the verdict, the steps with their timings, the screenshots taken after each step, and the failure line.
//
//   node scripts/evidence-pdf.mjs <report.json> <out dir> [org label]
//
// Org URLs in error text are replaced with "<org>". The screenshots show the "Logged in as <user>" banner (which
// persona did the step); no password is ever on screen.
import { chromium } from '@playwright/test';
import { execSync } from 'node:child_process';
import { mkdirSync, readFileSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';

const [reportFile, outDir, orgLabel = 'QA org'] = process.argv.slice(2);
if (!reportFile || !outDir) {
  console.error('usage: node scripts/evidence-pdf.mjs <report.json> <out dir> [org label]');
  process.exit(2);
}
const report = JSON.parse(readFileSync(reportFile, 'utf8'));
mkdirSync(outDir, { recursive: true });

let commit = '';
try {
  commit = execSync('git rev-parse --short HEAD', { encoding: 'utf8' }).trim();
} catch {
  commit = 'unknown';
}

const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
// eslint-disable-next-line no-control-regex
const clean = (s) => String(s ?? '').replace(/\u001b\[[0-9;]*m/g, '').replace(/https?:\/\/[^\s'"<>)]+/g, '<org>');
const sydney = (iso) =>
  new Date(iso).toLocaleString('en-AU', { timeZone: 'Australia/Sydney', dateStyle: 'medium', timeStyle: 'short' }) + ' (Sydney)';

function* tests(suite) {
  for (const s of suite.suites ?? []) yield* tests(s);
  for (const spec of suite.specs ?? []) for (const t of spec.tests ?? []) yield { spec, t };
}

function verdict(t, r) {
  const reason = (t.annotations ?? []).find((a) => a.type === 'fail' || a.type === 'skip')?.description ?? '';
  if (r.status === 'skipped') return { label: 'NOT RUN', css: 'skip', note: reason };
  // A run that did not complete is neither a pass nor the expected failure.
  if (r.status === 'timedOut') return { label: 'TIMED OUT (did not complete)', css: 'fail', note: reason };
  if (r.status === 'interrupted') return { label: 'INTERRUPTED (did not complete)', css: 'skip', note: reason };
  if (t.expectedStatus === 'failed') {
    if (r.status === 'failed') return { label: 'EXPECTED FAIL (known defect)', css: 'xfail', note: reason };
    if (r.status === 'passed') return { label: 'PASSED, BUT A FAILURE WAS EXPECTED (fix deployed?)', css: 'fail', note: reason };
  }
  return r.status === 'passed' ? { label: 'PASS', css: 'pass', note: '' } : { label: 'FAIL', css: 'fail', note: '' };
}

function html(spec, t, r) {
  const [id, ...rest] = spec.title.split(':');
  const v = verdict(t, r);
  const steps = (r.steps ?? [])
    .map(
      (s, i) =>
        `<tr class="${s.error ? 'bad' : ''}"><td>${i + 1}</td><td>${esc(s.title)}</td><td>${(s.duration / 1000).toFixed(1)} s</td><td>${s.error ? 'failed' : 'ok'}</td></tr>`
    )
    .join('');
  const shots = (r.attachments ?? [])
    // An attachment made from a buffer is inlined in the JSON report (base64 `body`); one made from a file has a `path`.
    .filter((a) => a.name.startsWith('evidence: ') && (a.body || (a.path && existsSync(a.path))))
    .map(
      (a) =>
        `<figure><figcaption>${esc(a.name.replace(/^evidence: /, ''))}</figcaption><img src="data:image/png;base64,${a.body ?? readFileSync(a.path).toString('base64')}"></figure>`
    )
    .join('');
  const error = (r.errors ?? []).map((e) => clean(e.message ?? e.value ?? '')).join('\n\n').split('\n').slice(0, 25).join('\n');
  return `<!doctype html><html><head><meta charset="utf-8"><style>
    body{font:12px/1.45 -apple-system,Segoe UI,Arial,sans-serif;color:#1d1d1f;margin:0}
    h1{font-size:18px;margin:0 0 4px} .sub{color:#555;margin:0 0 12px}
    .v{display:inline-block;padding:4px 10px;border-radius:4px;font-weight:600;color:#fff}
    .pass{background:#2e7d32}.xfail{background:#b26a00}.fail{background:#c62828}.skip{background:#666}
    table{border-collapse:collapse;width:100%;margin:10px 0} td,th{border:1px solid #ddd;padding:4px 6px;text-align:left;vertical-align:top}
    th{background:#f4f4f4} tr.bad td{background:#fdecea}
    dl{display:grid;grid-template-columns:max-content 1fr;gap:2px 12px;margin:10px 0} dt{color:#555}
    pre{white-space:pre-wrap;background:#f7f7f7;border:1px solid #ddd;padding:8px;font-size:10.5px}
    figure{margin:14px 0;page-break-inside:avoid} figcaption{font-weight:600;margin-bottom:4px} img{width:100%;border:1px solid #ccc}
  </style></head><body>
    <h1>${esc(id)}: ${esc(rest.join(':').trim())}</h1>
    <p class="sub">002 Partner referral, automated UI test evidence (Playwright)</p>
    <span class="v ${v.css}">${esc(v.label)}</span>
    <dl>
      <dt>Run</dt><dd>${esc(sydney(r.startTime))}, ${(r.duration / 1000).toFixed(0)} s</dd>
      <dt>Org</dt><dd>${esc(orgLabel)}</dd>
      <dt>Spec</dt><dd>automation-testing/tests/sf-ai/${esc(spec.file?.split(/[\\/]/).pop() ?? id + '.spec.ts')} (commit ${esc(commit)})</dd>
      ${v.note ? `<dt>Note</dt><dd>${esc(v.note)}</dd>` : ''}
    </dl>
    <h2 style="font-size:14px">Steps</h2>
    <table><tr><th>#</th><th>Step</th><th>Time</th><th>Result</th></tr>${steps || '<tr><td colspan="4">No steps recorded</td></tr>'}</table>
    ${error ? `<h2 style="font-size:14px">Failure</h2><pre>${esc(error)}</pre>` : ''}
    <h2 style="font-size:14px">Screenshots (after each step)</h2>${shots || '<p>None</p>'}
  </body></html>`;
}

const browser = await chromium.launch();
const page = await browser.newPage();
let n = 0;
for (const { spec, t } of tests(report)) {
  const r = t.results?.at(-1);
  if (!r) continue;
  const id = spec.title.split(':')[0].trim();
  await page.setContent(html(spec, t, r), { waitUntil: 'load' });
  await page.pdf({ path: join(resolve(outDir), `${id}.pdf`), format: 'A4', printBackground: true, margin: { top: '14mm', bottom: '14mm', left: '12mm', right: '12mm' } });
  n++;
}
await browser.close();
console.log(`${n} evidence PDF(s) in ${outDir}`);
