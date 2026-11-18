# Story 02: Submit a referral from the partner portal - manual test scripts

Feature 002-partner-referral. Cases that SF AI Tester or Apex tests cannot prove (emails, schedules, Setup, phone layout).

## S02-TC-22 (AC-02.1): The referral form fits a 375 px phone with no horizontal scrolling

Persona: Partner Agent. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Open Chrome DevTools device toolbar at 375 x 812 |  | |
| 2 | Log in to the portal as Tom Nguyen (Contact > "Log in to Experience as User") |  | |
| 3 | Click "Refer a mover" and scroll the whole form | Every field and the "Send referral" button are reachable by vertical scrolling only<br>There is no horizontal scroll bar and no text is cut off | |
