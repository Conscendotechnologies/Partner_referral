# Story 01: Partner agencies and partner users - manual test scripts

Feature 002-partner-referral. Cases that SF AI Tester or Apex tests cannot prove (emails, schedules, Setup, phone layout).

## S01-TC-08 (AC-01.4): Existing principal and agent users carry the right partner role and permission set

Persona: Admin. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Open Setup > Users and open "Priya Shah" |  | |
| 2 | Look at Role and Permission Set Assignments |  | |
| 3 | Open "Tom Nguyen" and look at the same | Priya Shah has role "Harbour & Co Realty Partner Executive" and permission set PR_Partner_Principal<br>Tom Nguyen has role "Harbour & Co Realty Partner User" and permission set PR_Partner_Agent | |

## S01-TC-09 (AC-01.5): A newly enabled partner user receives the welcome email, sets a password and logs in

Persona: Partner Agent. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Create a Contact "AI-TEST Agent" on Harbour & Co Realty with Portal Role Agent and a mailbox you can read |  | |
| 2 | Click "Enable Partner User" and save the user with profile "Connectnow Partner User" |  | |
| 3 | Open the welcome email, follow the link and set a password |  | |
| 4 | Log in at https://co1778135180529.my.site.com/partners |  | |
| 5 | Deactivate the user afterwards (licence count) | The welcome email from "Connectnow Partners" arrives<br>The password can be set and the portal home page opens | |

## S01-TC-10 (AC-01.6): Users of an Inactive agency can still log in to the portal

Persona: Partner Agent. Type: positive.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | As Maya Manager set Bayside Property Group's Partner Status to "Inactive" |  | |
| 2 | As admin, open Contact "Chloe Tan" and click "Log in to Experience as User" |  | |
| 3 | Set the agency back to "Active" | Chloe Tan reaches the portal home page | |
