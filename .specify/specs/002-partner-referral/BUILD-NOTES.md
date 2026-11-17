# 002 Partner referral: build notes

Design: Confluence "Design: 002 Partner referral" (G1 approved 16 Nov 2026). Jira epic KAN-42, stories KAN-43 to KAN-53.
Target org: SDO `co1778135180529` (alias `salesOrgSDO`). This is a demo build: the Architect's open items were
decided by the builder, as listed below.

## Decisions taken in the build

| Item | Design said | Built |
| --- | --- | --- |
| F1 currency | Undecided (KAN-52) | **AUD added** as an active currency (rate to AED 0.4167). Every partner record (Referral, Lead, Opportunity, Commission, Payout) is stamped AUD. Amounts are totalled in Apex, because `SUM()` on a currency field returns the corporate currency (AED). |
| F10 State/Country picklists | Enable org-wide | **Not enabled**: too risky in a shared SDO. `Referral__c.New_State__c` is a restricted picklist, Lead `State` is set to the code (NSW, VIC...). Routing uses that code. |
| Routing | Lead assignment rules | **Apex + custom metadata** (`PR_State_Route__mdt`), with `PR_Unassigned` as the fallback. This avoids overwriting the org's existing Lead assignment rules, and routes are editable without a deploy. |
| Address on Referral | Compound Address field | Street, Suburb, State, Postcode fields (custom compound address fields need F10). |
| Partner profile | Partner Community profile | **Custom profile `Connectnow Partner User`** (Partner Community licence). Salesforce no longer allows creating users on standard external profiles. All access comes from permission sets. |
| Enable Partner User | Manual role + permission set | `PR_UserTrigger` sets the partner role (Principal = Executive, Agent = Worker) and assigns `PR_Partner_Principal` / `PR_Partner_Agent` from the contact's Portal Role. |
| Lead to Opportunity mapping | Field mapping | `PR_ConversionHandler`: record type, first stage, AUD price book, one product per utility, agency/agent/referral/move-in. |
| Commission recreate | Cancel and recreate | The unique `Opportunity_Key__c` is cleared on cancel, so a reopened-and-rewon Opportunity gets a fresh commission. |
| Q1 to Q8 | Deferred | Build defaults from design section 3. Consent wording is version `1` placeholder text in `Partner_Referral_Setting__mdt.Default`. |

## What is where

- **Portal**: Experience Cloud LWR site "Connectnow Partners", `https://co1778135180529.my.site.com/partners`, login only.
  Home = `c:prPortalHome` (this month's tiles, commission tiles for principals, `prReferralForm`, `prMyReferrals`).
- **Internal app**: "Connectnow Partner Referrals" (Leads, Opportunities, Referrals, Commissions, Payout Batches, Payouts console, Reports).
- **Reports**: folder "Partner Referral Reports" (referrals by agency this month and by week, commission this month by agency,
  first-contact SLA breaches, moved in but not connected).
- **Schedules**: `PR SLA monitor` (hourly at :05) and `PR monthly payout` (daily 06:00, acts on the first business day only).

## Deploy

All `PR_*` Apex, the `pr*` LWCs and the metadata listed in the commit deploy with:

```
sf project deploy start -o <org> --test-level RunSpecifiedTests \
  --tests PR_ReferralServiceTest --tests PR_LeadLifecycleTest --tests PR_CommissionPayoutTest
```

Before deploying `networks/Connectnow Partners.network-meta.xml` to a new org, set `emailSenderAddress` to a verified
address (the repo carries a placeholder). Add AUD to the org first (`CurrencyType`), and remember that
`standardValueSets/` and `settings/BusinessHours` replace the whole value set: retrieve and merge first in another org.

## Demo data (S10)

Run in order with `sf apex run -f scripts/apex/pr-demo/<file>`:
1. `1-setup-internal.apex`: role, PR permission sets and queue membership for the running admin
2. `2-agencies-and-products.apex`: AUD utilities price book, 4 agencies, 6 agents
3. `3-portal-users.apex`: partner logins (Priya Shah and Marco Rossi are principals; Tom Nguyen and Chloe Tan are agents)
4. `4-sample-referrals.apex`: 8 referrals across every status, 2 commissions (1 approved)
5. `5-schedule-jobs.apex`: SLA monitor and payout schedules
6. `6-site-passwords.apex`: after the site exists; sets one demo password for all partner users (debug log)

## Tests

22 Apex tests, all passing, covering: every form rule, stamping, inactive agency, same-agency duplicate warning and
cross-agency flag, two-agency and agent-vs-principal isolation, routing, urgency both ways, first contact and SLA,
status sync, Person Account conversion with products, commission create/approve/lock/cancel/reopen/rewin, principal
sharing, payout grouping, idempotent re-run, Xero CSV, mark paid, and the first-business-day scheduler.
