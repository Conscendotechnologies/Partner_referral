# Automation testing

UI test automation for this Salesforce project. **Nothing in this folder is deployed to the org**: it sits outside
`force-app`, so the deploy workflows never pick it up.

| Path | What it is |
|---|---|
| `test-cases/*.sf-tests.yaml` | SF AI Tester suites, one per story. The case id is the designed TC id (`S02-TC-01`) |
| `tests/sf-ai/*.spec.ts` | Playwright specs that SF AI Tester generated from those cases and verified with a clean run |
| `TEST-CASES.md` | Every designed test case (ui, unit and manual) with its Jira key and automation status |
| `expected-failures.json` | `ui` cases waiting on a fix that isn't deployed yet: TC id → defect / PR |
| `scripts/sf-auth.mjs` | Opens a logged-in browser session from a Salesforce CLI login (for CI and local runs) |
| `scripts/build-index.mjs` | Rebuilds `TEST-CASES.md` |
| `playwright.sf-ai.config.ts` | Playwright config used by SF AI Tester, CI and local runs |

The test design (`.specify/specs/<feature>/tests/story_NN.tc.json`), manual scripts and Jira map stay with the spec in
`.specify/`. Precondition data for some suites is seeded by `scripts/apex/pr-demo/7-qa-preconditions.apex`.

## Run the specs

```bash
cd automation-testing
npm ci
npx playwright install chromium
node scripts/sf-auth.mjs <org alias>     # prints SF_INSTANCE_URL=... and SF_STORAGE_STATE=...; export both
npx playwright test --config playwright.sf-ai.config.ts               # all specs
npx playwright test --config playwright.sf-ai.config.ts --grep S06-   # one story
```

Specs run in file order with one worker, because some cases use records an earlier case created (S02-TC-01 creates
the referral that S02-TC-02 and S12-TC-01 check). They create only records whose names start with `AI-TEST`.

In GitHub: **Actions → UI tests → Run workflow** (optionally with a title filter), and automatically at 06:00 Sydney
time on weekdays. It logs in with the `SFDX_AUTH_URL` secret and uploads the Playwright report.

## Add or change a case

1. Design the case in `.specify/specs/<feature>/tests/story_NN.tc.json` and add it to the story's suite in
   `test-cases/`, using the same id.
2. Generate and verify its spec with SF AI Tester in automation mode, from this folder:
   `SF_ALIAS=<org> node <sf-ai-tester>/dist/cli.js run test-cases/<suite>.sf-tests.yaml --mode automation`
   (or **Mission Control → Auto** in VS Code with this folder open as the workspace).
3. Run `node scripts/build-index.mjs` and commit the suite, the spec and `TEST-CASES.md`.

Never weaken an expected result to make a spec pass. If the app is wrong, raise a defect and list the case in
`expected-failures.json` until the fix is deployed.
