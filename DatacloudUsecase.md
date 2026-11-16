# Use Case 1: Predictive Nurse Staffing (Workday + Data Cloud)

## Objective
Predict nurse staffing shortages 7 days ahead per unit and shift, and auto-fill open shifts with qualified, available nurses. Target outcomes: lower agency/travel spend, reduced overtime, better ratio compliance.

## Industry and Region
Multi-hospital healthcare provider network, North America.

## Data Sources
| Source | Data | Ingestion |
|---|---|---|
| Workday HCM | Workers, positions, skills, certifications, time off, schedules | MuleSoft/RaaS to Ingestion API (batch) |
| Epic EHR | Census, admissions, acuity (aggregated, no PHI) | Ingestion API (streaming) |
| UKG/Kronos | Actual hours, overtime | Batch |
| Weather / flu-trend API | External demand signals | Scheduled API pull |

## Data Model (DMOs)
- Employee (Individual), Position, Unit, Shift, Certification, Skill
- Census Snapshot (unit, date, patient count, acuity score)
- Timekeeping Entry (hours, overtime)
- Demand Signal (flu index, weather)

## Identity Resolution
Match Workday Worker ID to UKG employee ID via employee number/email. Unified Employee profile is the join key across schedule, hours, and credentials.

## Calculated Insights
- Required nurses per unit/shift = f(census, acuity, ratio rule)
- Available nurses = scheduled minus time off minus lapsed certifications
- Ratio gap = required minus available
- Overtime hours per nurse (rolling 4 weeks)
- Agency spend per unit (if available)

## Prediction
Data Cloud predictive model (Model Builder) forecasts shortage probability per unit/shift for the next 7 days. Features: historical census, acuity trend, flu index, weather, planned leave, overtime load, day of week.

## Activation
1. Segment: nurses qualified for the short unit (skills, certs), available, not near overtime limits.
2. Data Action / Flow creates an open-shift record in Salesforce.
3. Agentforce agent offers shifts to the segment via SMS or Slack, ranked by qualification, fairness, and seniority.
4. Nurse accepts, and the confirmation is written back to Workday.

## Agentforce Agent
- **Topic:** Shift Fill
- **Actions:** Get open shifts, Check eligibility, Offer shift, Confirm and write back
- **Guardrails:** Respect union seniority rules, max-hours limits, and rest-period rules. Einstein Trust Layer with PII masking.

## Governance
- Aggregate census and acuity only; keep PHI out of Data Cloud.
- Separate data space for HR data with field-level access policies.
- Human review for exceptions and escalations.

## Demo Flow (5 to 7 minutes)
1. Show unified Employee profile and unit dashboard.
2. Show forecasted shortage (ICU, Friday night shift).
3. Show eligible nurse segment.
4. Agentforce offers the shift, and a nurse accepts.
5. Show gap closed and agency cost avoided.

## Success Metrics
- Agency/travel spend reduction (%)
- Overtime hours reduction (%)
- Shift fill time (hours)
- Ratio compliance rate
- Forecast accuracy

## Build Checklist
- [ ] Confirm Workday connector approach (MuleSoft vs native)
- [ ] Create sample data (Workday, census, timekeeping)
- [ ] Ingest and map DMOs
- [ ] Configure Identity Resolution
- [ ] Build Calculated Insights
- [ ] Train prediction model
- [ ] Create segment and Data Action
- [ ] Build Agentforce agent
- [ ] Write demo script and dashboard
