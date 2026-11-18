# Story 04: Referral tracker and partner status - manual test scripts

Feature 002-partner-referral. Cases that SF AI Tester or Apex tests cannot prove (emails, schedules, Setup, phone layout).

## S04-TC-08 (AC-04.5): Partner user is refused a Lead or another agency's Referral by direct URL

Persona: Partner Agent. Type: negative.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Log in to the portal as Chloe Tan |  | |
| 2 | Open https://co1778135180529.my.site.com/partners/s/detail/<Id of Tom's Referral> |  | |
| 3 | Open the same path with the Id of a Partner Referral Lead | Both show an error or "no access" page, never the record | |

## S04-TC-12 (AC-04.9): Tracker and home page fit a 375 px phone

Persona: Partner Agent. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Open Chrome DevTools device toolbar at 375 x 812 |  | |
| 2 | Log in to the portal as Tom Nguyen |  | |
| 3 | Scroll the home page and the tracker | There is no horizontal scroll bar on the page; tiles and rows stack vertically | |
