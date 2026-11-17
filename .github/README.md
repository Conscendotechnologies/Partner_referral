# GitHub Actions

| Workflow | When | What it does |
| --- | --- | --- |
| `pr-validate.yml` (PR validation) | A pull request into `main` is opened, updated or reopened | Check-only deploy (dry run) of the metadata the PR changes, with every Apex test class specified, then runs every Apex test class explicitly. |
| `deploy-on-merge.yml` (Deploy on merge) | A pull request is merged into `main` (any push to `main`) | Deploys the metadata changed since the last successful deploy, moves the `deployed/sdo` tag to this commit, then runs every Apex test class against the org. |

Both use [sfdx-git-delta](https://github.com/scolladon/sfdx-git-delta), so only changed metadata is deployed. Deletions are deployed as post-destructive changes, including deletion-only changes.

The merge deploy diffs from the `deployed/sdo` tag, not from the previous push, so a failed deploy's changes are carried into the next run. The tag only moves after a successful deploy and only forwards. A run whose commit is behind the tag stops without deploying. When there is no tag yet (the first deploy, or a first deploy that failed), the delta starts at the fixed baseline in the repository variable `DEPLOY_BASELINE_SHA`, never at the previous push, so a failed first deploy is retried in full.

The PR check diffs against the PR event's fixed base SHA (`github.event.pull_request.base.sha`), so commits that land on `main` after the event are not shown as reversions.
"Every Apex test class" means every class under `force-app` that has test methods (`.github/scripts/apex-test-classes.js`).

Why the explicit test run: the salesOrgSDO org runs no Apex tests during deploys, even with `RunSpecifiedTests` or
`RunLocalTests` (the deploy reports 0 tests). The explicit `sf apex run test` step makes sure the tests really run.
On a PR they run against the code already in the org, because a check-only deploy does not keep the PR's code. After
a merge they run against the merged code.

## Setup (once)

1. Create the secret `SFDX_AUTH_URL` from your logged-in CLI. This pipes the value straight into GitHub without printing it:

   ```
   sf org auth show-sfdx-auth-url -o salesOrgSDO --json | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>process.stdout.write(JSON.parse(s).result.sfdxAuthUrl))" | gh secret set SFDX_AUTH_URL -R Conscendotechnologies/Partner_referral
   ```

   Use `sf org auth show-sfdx-auth-url`, not `sf org display --verbose`: newer CLI versions redact the URL in
   `org display` ("[REDACTED] Use 'sf org auth show-sfdx-auth-url' to view"), and that text is not a valid secret.
   The org must be logged in with the web flow (`sf org login web`), so the auth URL carries a refresh token.
2. Set the repository variable `DEPLOY_BASELINE_SHA` to the full SHA of the commit the org already matches. For salesOrgSDO
   that is the baseline before 002 (already set):

   ```
   gh variable set DEPLOY_BASELINE_SHA -R Conscendotechnologies/Partner_referral --body 62fd50f16b7054c6a2c7a76a4dcc932e378b0ea1
   ```

   It is only used until the first successful deploy creates the `deployed/sdo` tag.
3. Optional: in **Settings → Environments → production**, add required reviewers so merges wait for approval before deploying.
4. Optional: in **Settings → Branches**, protect `main` and require the "Dry-run deploy and Apex tests" check before merging.

## Org prerequisites (fresh org)

Some 002 metadata depends on values that are not in this repo. Check them before the first deploy to any org other
than salesOrgSDO:

- **Lead statuses.** `Partner_Referral_Lead_Process` uses the Lead Status values **New**, **Working**, **Qualified**,
  **Unqualified** and **Converted**. They must already exist (**Setup → Object Manager → Lead → Fields → Lead Status**),
  and **Converted** must be marked as a converted status, because lead conversion uses it. The repo does not deploy the
  Lead Status value set: it is shared with other apps, and deploying it would replace every existing value.
- **Opportunity stages and Lead Source.** `standardValueSets/OpportunityStage` and `standardValueSets/LeadSource` replace
  the whole value set when deployed. Retrieve the target org's value set and merge in the 002 values (Qualification,
  Plans Selected, Connection Requested, Utilities Connected; Partner Referral) before deploying.
- **Currency.** Multi-currency on, with **AUD** active.
- **Business hours.** `settings/BusinessHours` replaces all business hours: merge with the org's own first.
- **Site sender.** Set `emailSenderAddress` in `networks/Connectnow Partners.network-meta.xml` to a verified address
  (the repo has a placeholder).
- **Queue staff.** The five queues (PR_NSW_ACT, PR_VIC_TAS, PR_QLD, PR_SA_WA_NT, PR_Unassigned) deploy with **no
  members**. Add the sales reps as described under "Queue staff" in `.specify/specs/002-partner-referral/BUILD-NOTES.md`
  before referrals arrive.
