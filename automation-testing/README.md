# Automation testing

UI test automation for this Salesforce project. **Nothing in this folder is deployed to the org**: it sits outside
`force-app`, so the deploy workflows never pick it up.

| Path | What it is |
|---|---|
| `test-cases/*.sf-tests.yaml` | SF AI Tester suites, one per story. The case id is the designed TC id (`S02-TC-01`) |
| `tests/sf-ai/*.spec.ts` | One Playwright spec per `ui` case, verified against the org (see "What a spec must do") |
| `tests/sf-ai/support/` | `salesforce.ts`: shared steps (Login-as, list search, portal login). `fixtures.ts`: the `test` every spec imports |
| `TEST-CASES.md` | Every designed test case (ui, unit and manual) with its Jira key and automation status |
| `expected-failures.json` | `ui` cases waiting on a fix that isn't deployed yet: TC id → defect / PR. Those specs run with `test.fail()` |
| `scripts/sf-auth.mjs` | Opens a logged-in browser session from a Salesforce CLI login (for CI and local runs) |
| `scripts/qa-data.mjs` | Puts the AI-TEST data into its starting state (`scripts/apex/pr-demo/8-`, `9-` and `7-*.apex`) |
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
node scripts/qa-data.mjs <org alias>     # reset the AI-TEST data; prints SF_SKIP_S07=1 if S07 must not run
npx playwright test --config playwright.sf-ai.config.ts               # all specs
npx playwright test --config playwright.sf-ai.config.ts --grep S06-   # one story
```

Specs run in file order with one worker, because some cases use records an earlier case created (S02-TC-01 creates
the referral that S02-TC-02 and S12-TC-01 check). They create only records whose names start with `AI-TEST`.

**Test data.** Run `scripts/qa-data.mjs` before every full run (CI does). It changes AI-TEST records only:
- `8-qa-reset-referrals.apex` closes the AI-TEST referrals earlier runs left open, so S02's fixed mobiles don't
  raise a duplicate warning.
- `9-qa-reset-commissions.apex` retires a used "AI-TEST Commission QA" Opportunity and the AI-TEST payout batch of
  the payout month.
- `7-qa-preconditions.apex` seeds the fixtures S05, S06 and S07 start from.

The payout cases (S07) run a real payout of every Approved commission in the org. The reset therefore allows them
only when the payout month and the waiting commissions are all AI-TEST. Otherwise it prints `PR-QA S07: SKIP`, and
CI leaves S07 out. In the SDO this is the case for November 2026: its 2026-10 batch is the org's own demo data.

**Expected failures.** A case listed in `expected-failures.json` is marked `test.fail()` by `support/fixtures.ts`.
While the defect is open, the run stays green. When the fix is deployed and the spec passes, Playwright reports an
unexpected pass and the run goes red, so remove the entry then.

**No traces in CI.** A Playwright trace records cookies, which hold the Salesforce session, so CI keeps
screenshots only. Locally, `SF_PW_TRACE=1` keeps traces of failed tests.

In GitHub: **Actions → UI tests → Run workflow** (optionally with a title filter), and automatically at 06:00 Sydney
time on weekdays. It logs in with the `SFDX_AUTH_URL` secret and uploads the Playwright report.

## What a spec must do

- Import `test` and `expect` from `./support/fixtures`, and title the test `<TC id>: <case title>`.
- Perform every step of the case as written, as the persona it names. Use `loginAs` / `logInToPortalAs`, which
  assert that the switch worked.
- Assert every expected result, exactly, on the element it is about. Never assert on the whole page.
- Don't use `expect(true)`, swallowed failures (`.catch(() => …)`, try/catch around assertions), if/else fallbacks,
  `waitForTimeout`, hard-coded record Ids, org URLs or absolute paths.

A spec that SF AI Tester generates is a draft. Review it against these rules before you commit it.

## Add or change a case

1. Design the case in `.specify/specs/<feature>/tests/story_NN.tc.json` and add it to the story's suite in
   `test-cases/`, using the same id.
2. Generate a draft spec with SF AI Tester in automation mode, from this folder, then review it against the rules above:
   `SF_ALIAS=<org> node <sf-ai-tester>/dist/cli.js run test-cases/<suite>.sf-tests.yaml --mode automation`
   (or **Mission Control → Auto** in VS Code with this folder open as the workspace).
3. Run `node scripts/build-index.mjs` and commit the suite, the spec and `TEST-CASES.md`.

Never weaken an expected result to make a spec pass. If the app is wrong, raise a defect and list the case in
`expected-failures.json` until the fix is deployed.
