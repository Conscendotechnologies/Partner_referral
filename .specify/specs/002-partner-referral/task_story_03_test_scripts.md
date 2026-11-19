# Story 03: State routing, urgent movers and first-contact SLA - manual test scripts

Feature 002-partner-referral. Cases that SF AI Tester or Apex tests cannot prove (emails, schedules, Setup, phone layout).

## S03-TC-04 (AC-03.2): Urgent Lead: queue members get a bell notification and the queue email receives a message

Persona: Sales Rep. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Create the urgent Lead as in S03-TC-03 |  | |
| 2 | Log in as Sam Rep (PR test) and open the bell |  | |
| 3 | Check the PR_NSW_ACT queue mailbox | Sam's bell shows an urgent-mover notification for the Lead<br>The queue email address received the urgent-referral email | |

## S03-TC-06 (AC-03.4): Scheduled check sends the urgent notification at move-in minus 2 days

Persona: Sales Rep. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Create a Partner Referral Lead with move-in 5 days from today and leave it unchanged |  | |
| 2 | On the day 2 days before move-in, after the hourly "PR SLA monitor" run, check Sam Rep's bell and the queue mailbox | The Lead is now Urgent and one notification and one email were sent | |
