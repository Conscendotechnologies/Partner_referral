# Story 08: Reports and dashboards - manual test scripts

Feature 002-partner-referral. Cases that SF AI Tester or Apex tests cannot prove (emails, schedules, Setup, phone layout).

## S08-TC-05 (AC-08.5): Report and dashboard folders are shared with team leads, Partner Managers and Finance only

Persona: Admin. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Open the Dashboards tab, folder "Partner Referrals", Share |  | |
| 2 | Open the Reports tab, folder "Partner Referral Reports", Share | Both folders are shared only with the public group PR_Report_Viewers (View) and are not shared with All Users or partner roles | |

## S08-TC-06 (AC-08.5): Partner users cannot open the reports or dashboards

Persona: Partner Principal. Type: negative.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Log in to the portal as Priya Shah |  | |
| 2 | Open https://co1778135180529.my.site.com/partners/s/report/Report/Recent and a dashboard URL from the "Partner Referrals" folder | Neither page shows partner referral data; access is refused or the page does not exist | |
