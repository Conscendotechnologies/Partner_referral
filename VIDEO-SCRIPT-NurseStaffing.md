# Video Script: Predictive Nurse Staffing

**Workday + Salesforce Data Cloud + Agentforce in Slack**
Target length: 5 to 6 minutes. Narration is about 800 words (roughly 140 words per minute).

Recording notes for the editor:
- The data is synthetic except for the six Workday hires dated 10/01/2026. Show the on-screen disclosure card in scene 8.
- The Workday write-back is simulated. The agent writes the assignment through the demo's write-back action; no live Workday shift record is changed. Say so on camera (scene 6) and keep the lower-third visible.
- Dollar figures for agency cost avoided come from the demo's rate fields. Read the number shown on screen; do not add one that is not shown.

Recorded clips (in Downloads), in scene order:

| Scene | Clip | Trim notes |
|---|---|---|
| 2 | nurse-01-workday.gif | Cut the mistyped "Noah OkaforNoah Okafor" search frame and the "Claude is active" banner frame. |
| 2 to 3 | nurse-02-salesforce-data.gif | |
| 3 | nurse-03-datacloud-ingest.gif | |
| 3 | nurse-04-datacloud-ir.gif | |
| 3 | nurse-05-datacloud-insight-segment.gif | Home Unit shows as a record ID; add a caption "= ICU". |
| 4 | nurse-06-forecast-flow.gif | Cut about 15 frames of scrolling the Flows list. |
| 5 | nurse-07-command-center.gif | Short clip (4 frames); hold each frame longer. |
| 5 to 6 | nurse-08-agent-builder.gif | |
| 6 | nurse-09-slack.gif | |
| 7 | nurse-10-results.gif | |

---

## Title card

| Time | On screen | Narration |
|---|---|---|
| 0:00 - 0:08 | Title card: "Predictive Nurse Staffing. Workday, Data Cloud, Agentforce." Subtitle: "St. Mercy General (demo)". | (music only) |

---

## Scene 1: Hook and problem

| Time | On screen | Narration |
|---|---|---|
| 0:08 - 0:50 | Slow push-in on a hospital-style schedule grid with red empty cells on an ICU night shift. Overlay text: "Agency spend. Overtime. Burnout." | It is Wednesday, and the ICU is short on Friday night. Today, someone finds that out on Thursday, and spends the evening on the phone. The shift gets filled with agency staff at premium rates, or with your own nurses on overtime. Either way you pay twice: once in cost, and again in burnout among the people you most want to keep. The information to prevent this already exists. It is just in different systems. This demo connects them, so the gap is found a week early and filled by the right person. Four systems, one workflow, and a human making each final decision. Let me show you how it works, starting with where the data begins. |

---

## Scene 2: Workday as the source of truth

| Time | On screen | Narration |
|---|---|---|
| 0:50 - 1:25 | Workday: Workers report filtered to hire date 10/01/2026. Highlight Ava Reyes, Liam Chen, Maya Patel, Noah Okafor, Zoe Novak (ICU Registered Nurses) and Jordan Ellis (HR Staffing Coordinator). Open one worker's Certifications tab: CCRN, RN license. Zoom on Noah Okafor's CCRN, expiry 09/19/2026. | Workday holds the facts about our people. Here are six real hires from October first: five ICU registered nurses and an HR staffing coordinator. Each nurse's certifications live here, the CCRN and the RN license. Look at Noah Okafor. His CCRN lapsed on September nineteenth. That one field matters later, because a nurse without a current certification should not be offered an ICU shift. |

---

## Scene 3: Data Cloud

| Time | On screen | Narration |
|---|---|---|
| 1:25 - 2:25 | First the Salesforce nurse record for Ava Reyes, keyed to her Workday worker ID, with certifications and shift schedules. Then Data Cloud, Data Streams: the native Workday connector stream (119 workers) and the Salesforce streams for nurses, schedules, timekeeping, forecasts and demand signals. The Workday stream's mapping to Individual and Party Identification. Identity Resolution ruleset "Nurse Workforce Unification": rules Workday ID or Email; summary 170 source profiles to 165 unified. Calculated Insight "Nurse Overtime 4 Weeks" with its SQL. Segment "Eligible ICU Nurses": ICU, certification current, overtime under 24 hours; population 6. | In Salesforce, each nurse record carries the Workday worker ID, so both systems point at the same person. Data Cloud pulls it all together. Workers come in through the native Workday connector, and alongside them we ingest nurses, schedules, timekeeping, forecasts and demand signals such as the flu trend. Each source is mapped to the same data model, with the Workday worker ID as a shared party identifier. Identity resolution then matches on that ID, or on email, and merges each nurse into one profile. A calculated insight sums every nurse's overtime over the last four weeks. And a segment keeps the ICU nurses who are certified and under the overtime limit, which today is six people. |

---

## Scene 4: Forecast and auto-raised open shift

| Time | On screen | Narration |
|---|---|---|
| 2:25 - 3:05 | Forecast view for the next seven days. Highlight ICU, Friday 30 October, Night: need 5, have 2, gap 3, 97% shortage probability. Cut to the record-triggered Flow "Create Open Shift From Forecast" (entry conditions: Shortage Probability >= 70 and Ratio Gap > 0), then the new record: Open Shift OS-00000, Open, 3 needed, 0 filled. | The forecast looks seven days ahead for every unit and shift. Here it flags the ICU, Friday the thirtieth of October, night shift. We need five nurses and have two. The gap is three, and the shortage probability is ninety-seven percent. Nobody had to notice this. When a forecast crosses seventy percent with a real gap, a Flow raises an open shift automatically, OS-00000, sized to the gap. |

---

## Scene 5: Staffing Command Center

| Time | On screen | Narration |
|---|---|---|
| 3:05 - 3:55 | Staffing Command Center in Salesforce: KPI tiles, the 7-day heatmap with the ICU Friday night cell highlighted, the open shifts table with OS-00000. Click "Eligible nurses". Show the ranked list (home unit, least overtime, union seniority). Scroll to the excluded list (46 excluded by guardrails). Zoom on Noah Okafor: "Certification lapsed on 9/19/2026; Already scheduled that day (Night); Overtime: 24.0h in last 4 weeks (limit 24h)". Then Agentforce Builder: Shift Fill Agent, its 4 actions (Get Open Shifts, Check Eligibility, Offer Shift, Confirm Shift and Write Back with "Require user confirmation"), and the Slack connection. | This is the Staffing Command Center, for the coordinator. Key numbers at the top, a seven-day heatmap, and the open shifts below it. For OS-00000, it checks all fifty-one nurses and finds five who are eligible. They are ranked in a fixed order: nurses whose home unit is the ICU come first, then the least recent overtime, which keeps the load fair, then union seniority. The excluded nurses are listed with their reasons. Noah is out for three: his lapsed certification, the rest-period rule, and the overtime limit. The coordinator can see why, not just who. That matters for trust. When a nurse asks why they were or were not offered a shift, the answer is on the screen, and it traces back to a rule the hospital already has. The same logic powers an Agentforce employee agent with four actions. The booking action requires the user to confirm first, and the agent is connected to Slack. |

---

## Scene 6: Shift Fill Agent in Slack

| Time | On screen | Narration |
|---|---|---|
| 3:55 - 5:00 | Slack, DM with Shift Fill Agent. "What shifts are open in ICU?" Agent: OS-00000, Intensive Care Unit, 10/30/2026 Night (12h), 3 of 3 still needed. "Who can take OS-00000?" Agent: Zoe Novak (ICU, 18h overtime), Yusuf Okoro, Rina Castillo, Theo Lindqvist (float pool), Chloe Dubois. "Can noah.okafor@stmercy.example take OS-00000?" Agent: cannot, with the lapsed certification, same-night shift and overtime limit. "Zoe Novak accepted. Book OS-00000 for zoe.novak@stmercy.example." Agent shows a confirmation card (Cancel / Confirm); click Confirm. Agent: "Zoe Novak is now booked for OS-00000 ... 2 of 3 nurses are still needed ... Agency cost avoided: $996.00". Lower-third: "Workday write-back is simulated in this demo." | Now the work moves into Slack, where people already are. The coordinator asks the Shift Fill agent what is open in the ICU, and it answers with OS-00000. Who can take it? It ranks the eligible nurses and shows why: Zoe Novak first, because the ICU is her home unit. What about Noah? The agent says no, and gives the same three reasons as the command center. The rules live in the actions, so the agent cannot be talked around them. Zoe accepts. Before booking, the agent asks the coordinator to confirm, and checks eligibility again. Once confirmed, Zoe is booked, two spots remain, and nine hundred ninety-six dollars of agency cost is avoided. |

---

## Scene 7: Results

| Time | On screen | Narration |
|---|---|---|
| 5:00 - 5:30 | Command Center after Refresh: Nurses short 3 to 2, Agency cost avoided $0 to $996, the ICU Friday night cell 97% to 89%. OS-00000: 1 of 3 filled, Booked Zoe Novak, Workday write-back "Simulated: Workday schedule assignment sent for 642345377abe1001555d4df56b790000 (ICU 2026-10-30 Night)". Then a simple text slide: "Agency spend. Overtime hours. Fill time. Ratio compliance. Forecast accuracy." | Back in the command center, the forecast has rerun. The ICU risk drops from ninety-seven to eighty-nine percent, one of three spots is filled, and the agency cost avoided is recorded against the shift. The write-back to Workday uses Zoe's real Workday worker ID; in this demo it is simulated. These are the measures to track in a real rollout: agency spend, overtime hours, time to fill, ratio compliance and forecast accuracy. We are not claiming results from this demo. It shows the mechanism, and your own data would supply the numbers. What the demo does show is the time saved: from a forecast on Wednesday to a confirmed, rule-checked booking in a few messages, with no phone calls. |

---

## Scene 8: Close

| Time | On screen | Narration |
|---|---|---|
| 5:30 - 5:50 | Architecture recap: Workday, Data Cloud, Flow, Command Center, Agentforce in Slack. Disclosure card: "Synthetic data, except the six Workday hires dated 10/01/2026. Workday write-back simulated." Closing card with contact details. | One flow: Workday for the facts, Data Cloud to unify and predict, a Flow to raise the shift, and Agentforce in Slack to fill it, with people confirming each booking. A note on what you saw: the data is synthetic except for the six hires, and the Workday write-back was simulated. If you want to see this with your own scheduling and certification data, we can set up a working session. |

---

## Word count check

Narration totals roughly 780 words across scenes 1 to 8, which fits 5 to 6 minutes at a calm pace. If the cut runs long, trim scene 3 first, then scene 7.

## Honesty checklist

- Synthetic: all nurses, schedules, timekeeping, census, demand signals and rates, except the six Workday hires (Ava Reyes, Liam Chen, Maya Patel, Noah Okafor, Zoe Novak, Jordan Ellis).
- Simulated: the Workday write-back after booking.
- Do not state forecast accuracy, savings percentages or dollar totals that are not visible on screen.
