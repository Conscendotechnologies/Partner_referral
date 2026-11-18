# Story 00: Foundation: objects, fields, record types, processes, queues, permission sets - manual test scripts

Feature 002-partner-referral. Cases that SF AI Tester or Apex tests cannot prove (emails, schedules, Setup, phone layout).

## S00-TC-06 (AC-00.5): Five Lead queues, "Connectnow Sales" business hours and the settings record match the design

Persona: Admin. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Open Setup > Queues |  | |
| 2 | Open each of PR_NSW_ACT, PR_VIC_TAS, PR_QLD, PR_SA_WA_NT and PR_Unassigned |  | |
| 3 | Open Setup > Business Hours > "Connectnow Sales" |  | |
| 4 | Open Setup > Custom Metadata Types > Partner Referral Setting > Manage Records > Default | All 5 queues exist and list Lead as a supported object<br>Business hours are 08:00 to 20:00 Monday to Saturday, Sunday closed<br>Consent version is 1, urgent window is 48 hours and SLA is 2 business hours | |

## S00-TC-07 (AC-00.6): Permission sets, groups and custom permissions exist; external sharing is Private on the new objects

Persona: Admin. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Open Setup > Permission Sets and Permission Set Groups |  | |
| 2 | Open Setup > Custom Permissions |  | |
| 3 | Open Setup > Sharing Settings and look at Referral, Partner Commission, Payout Batch and Payout Line | PR_Partner_Agent, PR_Partner_Principal, PR_Sales_Rep, PR_Partner_Manager and PR_Finance exist<br>Manage_Partner_Agencies, Approve_Partner_Commission, Manage_Partner_Payouts and the fourth design permission exist<br>Default External Access is Private on all four objects | |

## S00-TC-09 (AC-00.7): Seed script creates the 4 active products in the price book and is idempotent on re-run

Persona: Admin. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Run the seed script from BUILD-NOTES against the org |  | |
| 2 | Open the Price Books tab and open "Partner Referral Utilities" |  | |
| 3 | Run the seed script again |  | |
| 4 | Refresh the price book | The price book lists Electricity, Gas, Water and Internet, all active<br>After the second run there are still exactly 4 entries (no duplicates) | |

## S00-TC-10 (AC-00.8): Commission Rate is tracked in Account field history

Persona: Admin. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Open Setup > Object Manager > Account > Fields & Relationships > Set History Tracking | "Commission Rate" is ticked for history tracking | |
