# Automation testing

UI test automation for this Salesforce project. **Nothing in this folder is deployed to the org**: it sits outside
`force-app`, so the deploy workflows never pick it up.

| Path | What it is |
|---|---|
| `test-cases/*.sf-tests.yaml` | SF AI Tester suites, one per story. The case id is the designed TC id (`S02-TC-01`) |
| `tests/sf-ai/*.spec.ts` | One Playwright spec per `ui` case, verified against the org (see "What a spec must do") |
| `tests/sf-ai/support/` | `salesforce.ts`: shared steps (Login-as, list search, portal login). `fixtures.ts`: the `test` every spec imports. `groupA.ts` (stories 00, 01, 03, 08, 10), `B.ts` (02, 04, 12 referral pages), `C.ts` (05, 06, 07, 12 commission and payout pages): page helpers. `run-state.ts`: a value one case notes for a later one in the same run |
| `TEST-CASES.md` | Every designed test case (ui, unit and manual) with its Jira key and automation status |
| `expected-failures.json` | `ui` cases waiting on a fix that isn't deployed yet: TC id → defect / PR. Those specs run with `test.fail()` |
| `scripts/sf-auth.mjs` | Opens a logged-in browser session from a Salesforce CLI login (for CI and local runs) |
| `scripts/run-specs.mjs` | Resets the data, then runs the specs (leaving out the payout-run cases when the reset says so). CI uses it too |
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
node scripts/run-specs.mjs <org alias>                  # reset the AI-TEST data, then run all specs
node scripts/run-specs.mjs <org alias> --grep "S06-"    # reset, then one story
```

Always run through `run-specs.mjs`: it applies the S07 rule below, as CI does. A filter must include the cases a
selected case depends on: S02-TC-15 and S02-TC-17 need S02-TC-01 (`--grep "S02-TC-(01|15|17):"`), S03-TC-09 needs
S03-TC-08, S06-TC-10/11/13 and S12-TC-02 need S06-TC-02.

Specs run in file order with one worker, because some cases use records an earlier case created (S02-TC-01 creates
the referral that S02-TC-02 and S12-TC-01 check). They create only records whose names start with `AI-TEST`.

**Test data.** Run `scripts/qa-data.mjs` before every full run (CI does). It changes AI-TEST records only:
- `8-qa-reset-referrals.apex` closes the AI-TEST referrals earlier runs left open, so S02's fixed mobiles don't
  raise a duplicate warning.
- `9-qa-reset-commissions.apex` retires the used "AI-TEST Commission QA", "AI-TEST Payout QA" and "AI-TEST Convert…"
  Opportunities (and "AI-TEST Commission Pending QA" once it no longer has one Pending commission), and removes the
  payout month's batch when it holds only AI-TEST commissions.
- `7-qa-preconditions.apex` seeds the fixtures S05, S06 and S07 start from.

The payout cases (S07) run a real payout of every Approved commission in the org. The reset therefore allows them
only when the payout month and the waiting commissions are all AI-TEST. Otherwise it prints `PR-QA S07: SKIP`, changes no
payout data, seeds no payout fixture, and `run-specs.mjs` leaves out the cases that run or change a payout (S07-TC-03,
07 and 09; `fixtures.ts` also skips them when `SF_SKIP_S07=1`). The read-only S07-TC-04 still runs. In the SDO this is
the case for November 2026: its 2026-10 batch is the org's own demo data. The check runs just before the specs; a
non-test commission approved during a run could still be picked up, so run S07 only in an org where nobody else
approves commissions at the same time (a dedicated QA sandbox for a shared org).

**Expected failures.** A case listed in `expected-failures.json` is marked `test.fail()` by `support/fixtures.ts`.
While the defect is open, the run stays green. When the fix is deployed and the spec passes, Playwright reports an
unexpected pass and the run goes red, so remove the entry then. An expected failure passes the run whatever
breaks it (a dead session too), so check the failing line in its report before trusting it.

**When PR #8 is deployed**, remove the D1 to D4 entries. S06-TC-11 has its own fixture ("AI-TEST Commission Pending
QA"), so it doesn't depend on what S06-TC-10 approves.

**Values passed between cases** (`run-state.ts`: S03-TC-08's Lead for S03-TC-09, S07-TC-03's month for S07-TC-07/09)
carry the run's id, so a later case never uses a value from an earlier run.

**Finding new records.** The list search box uses the search index, which finds a new record only minutes later. Specs
that open a record created earlier in the same run sort an "All" view by Created Date instead (`openNewestLead`), or
retry the search (`S03-TC-09`).

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
