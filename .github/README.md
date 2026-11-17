# GitHub Actions

| Workflow | When | What it does |
| --- | --- | --- |
| `pr-validate.yml` (PR validation) | A pull request into `main` is opened, updated or reopened | Check-only deploy (dry run) of the metadata the PR changes, with every Apex test class specified, then runs every Apex test class explicitly. |
| `deploy-on-merge.yml` (Deploy on merge) | A pull request is merged into `main` (any push to `main`) | Deploys the metadata the merge changed, then runs every Apex test class against the org. |

Both use [sfdx-git-delta](https://github.com/scolladon/sfdx-git-delta), so only changed metadata is deployed. Deletions are deployed as post-destructive changes.
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
2. Optional: in **Settings → Environments → production**, add required reviewers so merges wait for approval before deploying.
3. Optional: in **Settings → Branches**, protect `main` and require the "Dry-run deploy and Apex tests" check before merging.
