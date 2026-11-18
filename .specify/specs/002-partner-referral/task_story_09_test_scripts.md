# Story 09: Org preparation: currency, state and country picklists, Experience Cloud - manual test scripts

Feature 002-partner-referral. Cases that SF AI Tester or Apex tests cannot prove (emails, schedules, Setup, phone layout).

## S09-TC-01 (AC-09.1): Currency decision is recorded and AUD is active

Persona: Admin. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Open the Confluence design page section on currency |  | |
| 2 | Open Setup > Company Information > Currencies | The decision is recorded on the page<br>Australian Dollar is active | |

## S09-TC-02 (AC-09.2): State and Country picklists are enabled with the 8 Australian states and territories

Persona: Admin. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Open Setup > State and Country/Territory Picklists |  | |
| 2 | Run or review the latest conversion scan |  | |
| 3 | Open Configure States for Australia | The scan reports no unconverted values<br>NSW, VIC, QLD, SA, WA, TAS, ACT and NT are active and visible | |

## S09-TC-03 (AC-09.3): Custom Address fields, Digital Experiences and enough Partner Community licences

Persona: Admin. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Open Setup > User Interface and look for custom address fields |  | |
| 2 | Open Setup > Digital Experiences > Settings |  | |
| 3 | Open Setup > Company Information > User Licenses | Custom address fields are enabled<br>Digital Experiences is enabled<br>Partner Community has at least 4 licences free for the demo personas | |

## S09-TC-04 (AC-09.4): Existing Account, Contact and Lead records of other demos still save

Persona: Admin. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Open an existing non-partner Account, edit any field and save |  | |
| 2 | Do the same for a Contact and a Lead | All three save with no address validation error | |
