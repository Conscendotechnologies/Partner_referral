# 002 Partner referral: build notes

Design: Confluence "Design: 002 Partner referral" (G1 approved 16 Nov 2026). Jira epic KAN-42, stories KAN-43 to KAN-53.
Target org: SDO `co1778135180529` (alias `salesOrgSDO`). This is a demo build: the Architect's open items were
decided by the builder, as listed below.

## Decisions taken in the build

| Item | Design said | Built |
| --- | --- | --- |
| F1 currency | Undecided (KAN-52) | **AUD added** as an active currency (rate to AED 0.4167). Every partner record (Referral, Lead, Opportunity, Commission, Payout) is stamped AUD. Amounts are totalled in Apex, because `SUM()` on a currency field returns the corporate currency (AED). |
| F10 State/Country picklists | Enable org-wide | **Not enabled**: too risky in a shared SDO. `Referral__c.New_State__c` is a restricted picklist, Lead `State` is set to the code (NSW, VIC...). Routing uses that code. |
| Routing | Lead assignment rules | **Apex + custom metadata** (`PR_State_Route__mdt`), with `PR_Unassigned` as the fallback. Done in the Lead trigger (before insert), so a Partner Referral Lead is routed however it is created (portal, API, data load, by hand), as an assignment rule would. A Lead already owned by a PR queue keeps it. This avoids overwriting the org's existing Lead assignment rules, and routes are editable without a deploy. |
| Queue list views (AC-03.7) | Sorted urgent first, then move-in | One Lead list view per PR queue (`PR - <state> queue`) plus `PR - Urgent movers`, with Urgent and Move-in Date as the first columns. **List view metadata can't store a sort order**, so each rep sets it once: on a PR queue list view, open **Column sort**, add Urgent (`Is_Urgent__c`) descending, then Move-in Date (`Move_In_Date__c`) ascending, and click **Apply**. Salesforce keeps that two-column sort per user until it is changed or reset. The `PR - Urgent movers` view shows only urgent leads. |
| Duplicates (AC-02.8, AC-02.9) | Same mobile and email, open referrals | Same mobile (either 04 or +614 form) and, when both referrals have an email, the same email; only referrals that are not Connected or Closed Lost. A cross-agency match flags **both** referrals (and the existing referral's open Lead) as Possible Duplicate. |
| Payout period (AC-07.1) | Previous month | The run on the first business day creates the batch for the **previous** month (run on 1 Dec 2026 → batch 2026-11, reference 202611-<ABN>). The console's Payout month defaults to the previous month too. |
| Reopened approved commission (AC-06.4) | Finance notified | Pending → Cancelled with reason "Opportunity reopened". Approved or later → flagged Reopened After Approval, and everyone with `PR_Finance` gets one "Partner commission reopened" bell notification per 200-record trigger chunk (one notification covers up to 200 reopened commissions). |
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
- **Reports and dashboards (KAN-51)**: see "Reports, dashboards and access" below.
- **Schedules**: `PR SLA monitor` (hourly at :05) and `PR monthly payout` (daily 06:00, acts on the first business day only).

## Deploy

All `PR_*` Apex, the `pr*` LWCs and the metadata listed in the commit deploy with:

```
sf project deploy start -o <org> --test-level RunSpecifiedTests \
  --tests PR_ReferralServiceTest --tests PR_LeadLifecycleTest --tests PR_CommissionPayoutTest
```

For a fresh org, check the prerequisites in `.github/README.md` ("Org prerequisites") first: Lead statuses (New,
Working, Qualified, Unqualified, and Converted marked as converted), AUD, merged value sets and business hours, a
verified site sender address, and queue staff.

## Reports, dashboards and access (KAN-51)

Four dashboards in the dashboard folder **Partner Referrals**, all run as the **logged-in user** (dynamic, no hard-coded
running user), built on reports in the report folder **Partner Referral Reports**:

| Dashboard | AC | Components | Reports |
| --- | --- | --- | --- |
| Partner Referrals – Volume | AC-08.1 | Referrals per agency per week (stacked column); this month per agency by status (stacked bar) | `PR_Referrals_by_Agency_by_Week`, `PR_Referrals_by_Agency_This_Month` |
| Partner Referrals – Conversion | AC-08.2 | Overall conversion rate and Connected count (metrics); rate by agency (bar); referrals in, Connected and rate per agency (Lightning table) | `PR_Referral_Conversion_by_Agency` (last 90 days) |
| Partner Commission – This Month | AC-08.3 | Pending + Approved total (metric); per agency by status (stacked bar), AUD ex GST | `PR_Commission_This_Month_by_Agency` (report currency AUD) |
| Partner Referrals – SLA | AC-08.4 | Three Lightning tables: past due with no first contact; first contacted late; moved in and not Connected or Closed Lost | `PR_SLA_No_First_Contact`, `PR_SLA_Contacted_Late`, `PR_Moved_In_Not_Connected` |

- **Conversion without a schema change.** `PR_Referral_Conversion_by_Agency` uses a report row-level formula
  (`CDF1 = IF(ISPICKVAL(Partner_Status__c, "Connected"), 1, 0)`) and a summary formula
  (`FORMULA1 = CDF1:SUM / RowCount`). No formula field was added, so nothing needs the Architect.
- **SLA split.** The old `PR_First_Contact_SLA_Breaches` report is replaced by two reports on breached, open (not converted,
  not Unqualified) partner referral leads: `PR_SLA_No_First_Contact` (First Contacted At blank) and
  `PR_SLA_Contacted_Late` (First Contacted At set). The merge deploy deletes the old report.

**Access (AC-08.5).** Both folders are **not Public**. Each is shared with View access only to the public group
**PR_Report_Viewers** (`groups/PR_Report_Viewers.group-meta.xml`). Partner users are never in that group, so they cannot
see the reports or dashboards. Admins keep access as folder managers.

The group deploys with no members. Add the people who should see the reports: **Setup → Public Groups →
PR Report Viewers → Edit**, then add the sales team leads, the Partner Managers and Finance (users, or a role if they
share one). Because the dashboards run as the logged-in user, each viewer sees only the records their own access
allows. The demo script `1-setup-internal.apex` adds the running admin.

## Queue staff

Referrals are routed to five queues by the new address's state: `PR_NSW_ACT`, `PR_VIC_TAS`, `PR_QLD`, `PR_SA_WA_NT`, and
`PR_Unassigned` (fallback). The queues deploy with no members, and a queue without members gets no urgent-mover
emails and its leads wait unassigned. Before referrals arrive:

1. Give each sales rep the `PR_Sales_Rep` permission set (team leads too).
2. Add the reps for each region to that region's queue: **Setup → Queues → (queue) → Edit → Queue Members**. Each rep
   can be in more than one queue.
3. Add at least one team lead to `PR_Unassigned`, which catches referrals with an unknown state.
4. Check: `SELECT Group.DeveloperName, COUNT(Id) FROM GroupMember WHERE Group.DeveloperName LIKE 'PR%' GROUP BY Group.DeveloperName`
   should return all five queues.

The demo script `scripts/apex/pr-demo/1-setup-internal.apex` adds only the running admin to every queue. That is enough
for a demo, not for real routing.

## Currency rule for commissions

Every commission must be in the configured currency (AUD), on both the normal path and the services' bypass path
(`PR_CommissionTriggerHandler.requireCurrency`, which runs before the bypass check):

- A **null** `CurrencyIsoCode` is stamped with the configured currency.
- **Any other non-AUD value is rejected**, on insert and on update. It is never relabelled as AUD, because that would
  silently change what the amount means.

On insert, Salesforce fills a blank currency with the creator's default currency before the trigger runs. A user whose
default currency is not AUD (for example AED, the corporate currency) therefore gets an error if the field is left
blank. **Every manual insert must set `CurrencyIsoCode = 'AUD'` explicitly**: Finance picks AUD in the Currency field
when creating a commission by hand. The services (commission creation, payout) always set it.

## Demo data (S10)

Run in order with `sf apex run -f scripts/apex/pr-demo/<file>`:
1. `1-setup-internal.apex`: role, PR permission sets and queue membership for the running admin
2. `2-agencies-and-products.apex`: AUD utilities price book, 4 agencies, 6 agents
3. `3-portal-users.apex`: partner logins (Priya Shah and Marco Rossi are principals; Tom Nguyen and Chloe Tan are agents)
4. `4-sample-referrals.apex`: 8 referrals across every status, 2 commissions (1 approved)
5. `5-schedule-jobs.apex`: SLA monitor and payout schedules
6. `6-site-passwords.apex`: after the site exists; sets one demo password for all partner users (debug log)

## Bulk acceptance tests

`PR_BulkTest` covers the bulk ACs, each in one transaction:

| Test | AC | Volume |
| --- | --- | --- |
| `twoHundredSubmissionsAndStatusChanges` | AC-02.12, AC-04.8 | 200 referrals through `PR_ReferralService.submitAll`, then 200 Leads to Working |
| `twoHundredLeadsInserted` | AC-03.8 | 200 Partner Referral Leads inserted directly: routing, urgency, SLA due |
| `twoHundredConversions` | AC-05.5 | 200 Leads converted in two `convertLead` calls of 100 (the platform maximum per call) |
| `twoHundredCommissions` | AC-06.10 | 200 Opportunities to Utilities Connected: 200 commissions and principal shares |
| `threeThousandCommissionsAcrossFortyAgencies` | AC-07.7 | 3,000 approved commissions, 40 agencies: 40 lines with exact totals |
| `partnerUsersEnabledTogether` | AC-01.7 | **50**, not 200, partner users: the SDO has 60 Partner Community licences and test users count against them |

## Tests

22 Apex tests, all passing, covering: every form rule, stamping, inactive agency, same-agency duplicate warning and
cross-agency flag, two-agency and agent-vs-principal isolation, routing, urgency both ways, first contact and SLA,
status sync, Person Account conversion with products, commission create/approve/lock/cancel/reopen/rewin, principal
sharing, payout grouping, idempotent re-run, Xero CSV, mark paid, and the first-business-day scheduler.
