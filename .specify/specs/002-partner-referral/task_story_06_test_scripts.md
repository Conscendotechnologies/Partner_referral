# Story 06: Commission creation, approval, locking and principal view - manual test scripts

Feature 002-partner-referral. Cases that SF AI Tester or Apex tests cannot prove (emails, schedules, Setup, phone layout).

## S06-TC-07 (AC-06.4): Finance receives the reopened-after-approval bell notification

Persona: Finance. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Approve a commission as Maya Manager |  | |
| 2 | As Sam Rep move its Opportunity from Utilities Connected back to Connection Requested |  | |
| 3 | Log in as Fiona Finance (PR test) and open the bell | Fiona sees a notification about the reopened Opportunity<br>The commission shows "Reopened After Approval" ticked and its status is unchanged | |
