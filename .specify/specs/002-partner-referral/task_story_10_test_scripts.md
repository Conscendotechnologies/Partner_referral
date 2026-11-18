# Story 10: Demo personas and data - manual test scripts

Feature 002-partner-referral. Cases that SF AI Tester or Apex tests cannot prove (emails, schedules, Setup, phone layout).

## S10-TC-02 (AC-10.1): All four partner users are active with the right agency and portal role

Persona: Admin. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Open Setup > Users and filter on profile "Connectnow Partner User" | Priya Shah (Principal) and Tom Nguyen (Agent) belong to Harbour & Co Realty; Marco Rossi (Principal) and Chloe Tan (Agent) to Bayside Property Group; all are active | |

## S10-TC-03 (AC-10.2): Every state queue has a member and each internal persona has its permission set

Persona: Admin. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Open each PR_ queue in Setup > Queues |  | |
| 2 | Open Sam Rep, Maya Manager and Fiona Finance (PR test) in Setup > Users | Every queue lists at least one member<br>Sam has PR_Sales_Rep; Maya has PR_Partner_Manager; Fiona has PR_Finance | |

## S10-TC-04 (AC-10.3): Each queue has an email address that receives the urgent email

Persona: Admin. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Open each PR_ queue in Setup > Queues |  | |
| 2 | Create an urgent Lead for one state and check that queue's mailbox | Every queue has a Queue Email<br>The urgent-referral email arrives | |

## S10-TC-05 (AC-10.4): Two-agency isolation tests run without extra setup

Persona: Tester. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Run S04-TC-04, S04-TC-05, S04-TC-06, S06-TC-15 and S06-TC-16 with no setup beyond their preconditions | None is blocked by missing users, agencies or permissions | |
