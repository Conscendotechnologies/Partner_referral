# Story 11: Mark paid at scale and zero-test CI check - manual test scripts

Feature 002-partner-referral. Cases that SF AI Tester or Apex tests cannot prove (emails, schedules, Setup, phone layout).

## S11-TC-04 (AC-11.3): pr-validate fails with a clear message when the Apex test step ran zero tests

Persona: Developer. Type: negative.

> Blocked: the check is not built yet; it needs the Architect's decision.

| Step | Action | Expected | Pass/Fail |
|---|---|---|---|
| 1 | Open a PR that changes only non-Apex files after the zero-test check is built |  | |
| 2 | Look at the pr-validate run | The check fails and says that no Apex tests ran (or passes only with the agreed opt-out label) | |
