# Developer review: stories for 001-case-escalation

- **Reviewer persona:** Developer (`cc-dev`)
- **Date:** 2026-11-15
- **Source:** Jira epic KAN-4, stories KAN-5 to KAN-9 (labels `spec-001`). The `task_story_NN.md` files on branch `spec/001-case-escalation` are not in this workspace, so this review was done against the Jira copies.
- **Org checked:** `dev` = SDO co1778135180529, the epic's target org.
- **Out of scope:** KAN-1, KAN-2 and KAN-3 ("Task 1", "Task 2", "Subtask 2.1") are empty placeholder items that are not part of this spec. They should be deleted or moved out of the board.

## Summary

| Story | Verdict | Findings | Estimate |
|---|---|---|---|
| **KAN-5 / S00** Foundation | **BLOCKER** | B1, B2, B3, C1, C2, C3, C4 | 5 pts (was 3) |
| **KAN-6 / S01** Manual escalation | **CHANGES** | C5, C6, C7, C8, N1 | 5 pts |
| **KAN-7 / S02** Auto escalation (4h) | **CHANGES** | C9, C10, N2, N3 | 5 pts |
| **KAN-8 / S03** Escalation history | **CHANGES** | C11, C12 (+ B3, C2) | 2 pts |
| **KAN-9 / S04** "Escalated Cases - Open" list view | **OK** | C13 (answers review note M2) | 1 pt |

**Total:** 18 pts (was 16). No story is above 8 pts, so none needs to be split.

## What the org already has (reuse check, `sf data query` on `dev`)

| Item | What's in the org | Effect on the stories |
|---|---|---|
| `Case.IsEscalated` | Standard field, writable | Reused correctly by S01, S02 and S04. |
| `Case.EscalationDateTime` | Standard field, read only (set only by escalation rules) | It can't be stamped from Apex, so the custom `Escalated_On__c` field is justified. Add a one-line note to S00 so nobody "fixes" it later. |
| `Case.Status` value **"Escalated"** | The picklist is New, On Hold, **Escalated**, Closed. No case uses "Escalated" today. | Conflicts with AC-01.1 "Status unchanged". See C6. |
| Case Apex triggers | None | There is no trigger framework to reuse. The design doesn't need a trigger (the lock is a validation rule). |
| Apex service, selector or test-factory classes | None in the org or in `force-app/` | Everything is new, so the shared pieces have to come from S00. See B1. |
| Case validation rules | None | No conflict with `Escalation_Reason_Locked`. |
| Case Lightning record page | **None** (Case uses the system default page) | Dynamic Actions and the related-list layout need a custom page. See B2. |
| Case queues | `Main_Queue`, `Fallback_queue`, `Flight_Agent_Queue` | `Tier_2_Support` doesn't exist yet. No clash. |
| Record-triggered flows on Case | `dfrCasePrcd` (inactive) | No conflict with `Case_Auto_Escalation`. |
| Case sharing (OWD) | Internal: **Public Read/Write/Transfer**. External: Private. | AC-01.6 and AC-01.7 pass because of OWD. The S04 "sharing" is only list-view visibility (C13). |
| Portal access | `ItsmPortalUserPSG` (contains `ItsmPortalCommunityUser`), `UnifiedCatalogCommunityUserPsl`, plus about 20 portal and partner profiles | AC-00.5 has to cover the profiles too, not only the PSG (C4). |
| Existing Case list views | AllOpenCases, MyOpenCases, queue views | No duplicate of "Escalated Cases - Open". |

## Findings

### Blockers (Story 00 is missing something a later story needs, which breaks parallel work)

- **B1: Shared Apex pieces are missing from S00.** S01, S02 and S03 all need test cases plus users assigned each permission set. S01 and S02 both need the same Case query (open, not escalated, not closed). S02 calls the service that S01 builds. Add these to S00:
  - `CaseEscalationTestFactory`: Cases by priority and status, and users with Tier1, TeamLead, Tier2 or ReadOnly permission sets. It needs to support 300+ records.
  - `CaseSelector.selectEscalationCandidates(Set<Id>)`.
  - A stub `CaseEscalationService` holding the `EscalationRequest` and `EscalationResult` DTOs. The request should already carry `source` and `escalatedById` (see C9).
- **B2: The Case Lightning record page doesn't exist, and S01 and S03 would both create or edit it in parallel.** S01 adds the Dynamic Action and the "Escalated" banner. S03 adds the Escalation History related list. Both are blocked only by S00, so they would hit a merge conflict on the same flexipage XML. Add a `Case_Record_Page` shell to S00, activated as the org default for Case. S01 and S03 then each edit their own region of it.
- **B3: No Create or Read access for the people who need it.** S00 doesn't say who gets Create on `Case_Escalation__c`. It also doesn't say how "any internal user with Case read access" (AC-03.1) gets Read on the object. Only the `Case_Escalation_ReadOnly` permission set grants Read, and there is no assignment plan for it. S00 needs to decide two things:
  - (a) Does the service insert history in system mode? Then no permission set grants Create, which also satisfies AC-03.2. Or does Tier1/TeamLead get Create?
  - (b) Who is assigned `Case_Escalation_ReadOnly`? This could be all internal users through a PSG or a profile, or AC-03.1 could be narrowed.

### Changes

- **C1 (S00):** `Escalation_Reason__c` (Case) and `Reason__c` (history), and likewise `Escalation_Source__c` and `Source__c`, repeat the same values. Use **Global Value Sets** (`Escalation_Reason`, `Escalation_Source`) so the values can't drift apart.
- **C2 (S00):** The "Case_Escalation_Tier2: reason read only" line needs exact field and object permissions per permission set. State Read, Create, Edit and Delete on `Case_Escalation__c` and FLS on each of the 4 Case fields, for all 4 permission sets. Right now S03 (AC-03.2, AC-03.3) would have to edit permission sets that S00 owns. That edit could run in parallel with S01, which has to add Apex class access to the same Tier1 and TeamLead permission sets (merge-conflict risk). S00 should own object and field access. S01 owns only the `classAccesses` entries.
- **C3 (S00):** AC-00.4 says "true **only** for Tier1 and TeamLead". An Apex test can prove this only for the permission sets it assigns. Reword it to: "true for users with Tier1 or TeamLead, false for users with only Tier2 or ReadOnly, and false for a standard user with no escalation permission set."
- **C4 (S00):** For portal protection, also list the portal and partner **profiles** in the org, for example Customer Community Plus User and Partner Community User. New fields deployed without profile FLS are safe by default. Add a line saying deployments must not include profile FLS for these fields, and add a manual AC-00.5 check against one Customer Community Plus user.
- **C5 (S01):** The controller needs class access granted to the Tier1 and TeamLead permission sets in this story. Otherwise AC-01.1 fails for real users. Also, the record page edit depends on B2.
- **C6 (S01):** The `Case.Status` picklist already has **"Escalated"**. AC-01.1 says Status stays unchanged. The Architect should decide one of two things:
  - Deactivate "Escalated", so agents don't set it by hand and create "escalated" cases with `IsEscalated = false`.
  - Or state explicitly that it is unused and excluded from S04's list view and S02's logic.
- **C7 (S01):** The 20-character rule for the note has to be enforced in the **service**, not only in the LWC. AC-01.2 has an Apex test hook, and S02 calls the service with no UI in front of it. Say so in the scope.
- **C8 (S01):** Put the user-facing error strings in **Custom Labels**. That covers "Note must be at least 20 characters", "This case is already with Tier 2", "Closed cases cannot be escalated" and S00's validation-rule message. Then the Apex, Jest and UI tests all assert against one source.
- **C9 (S02):** S02 needs the service to take source = System and `Escalated_By__c` = Automated Process. If S01 defines the request without those fields, S02 has to reopen `CaseEscalationService`. Fix the DTO in S00 (B1), so S02 only adds the invocable and the flow.
- **C10 (S02):** Spell out how `Escalated_By__c` is set. It should be `UserInfo.getUserId()` inside the scheduled path, which runs as Automated Process. Apex tests can't `runAs` the Automated Process user, so the unit tests should check that the invocable passes through the user it was given. AC-02.7 and Escalated_By then get checked in the SDO.
- **C11 (S03):** AC-03.1 depends on B3(b), and AC-03.2 ("no New button") depends on B3(a). As written, S03 can't be built until S00 settles both. S03 should own only the related-list config on the S00 page shell: columns, newest-first sort, and the New button hidden.
- **C12 (S03):** AC-03.3 and AC-03.4 repeat AC-00.2 and AC-00.5. Keep them as regression checks, but point them to the S00 ACs so test cases aren't designed twice.
- **C13 (S04), which answers review note M2:** Yes, **move the public group (`Tier_2_And_Leads`) to S00** and make it the member of the `Tier_2_Support` queue. Because Case OWD is Public Read/Write/Transfer, the group only controls who sees the list view, not who can see the records. Say this in the story so nobody adds sharing rules.

### Notes (no change needed)

- **N1 (S01):** AC-01.6 and AC-01.7 are met by the existing Public Read/Write/Transfer OWD. Keep them as regression checks.
- **N2 (S02):** Scheduled paths can't run in Apex tests. AC-02.2 and AC-02.3 at the unit level actually test the invocable's re-check, so say that in the test hooks. AC-02.5 (a past due time runs immediately) is correctly marked for an SDO check.
- **N3 (S02):** The 300+ case boundary test is fine. Scheduled paths batch up to 200 records per interview set, and the service has to stay bulk-safe across chunks.

## Dependency graph

```
S00 ──► S01 ──► S02
  ├───► S03
  └───► S04
```

- There are **no cycles.**
- **Parallel-edit risks:**
  - S01 and S03 on the Case record page (B2).
  - S01 and S03 on the Tier1 and TeamLead permission sets (C2).
  - S01 and S02 on `CaseEscalationService` (C9).
- All three go away once B1, B2 and C2 move into S00.

## Testability

- The handler, service and selector seams are fine once B1 lands: controller, then service, then selector, with an invocable wrapper.
- Every story states its test-data needs. After B1 they all come from `CaseEscalationTestFactory`.

## Next owner

1. **Architect:** apply B1 to B3 and C1 to C13 to the `task_story_*.md` files and Jira, and decide C6.
2. **Tester:** `qa-design-tests`.
