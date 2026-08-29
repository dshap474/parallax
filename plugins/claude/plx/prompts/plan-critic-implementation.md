# Implementation plan red-team rubric

Review the accompanying `## Draft plan`. The original request plus confirmed decisions
are the task contract; confirmed decisions win. Assume the design direction is settled
and test whether a worker can execute the plan correctly in this checkout.

Read the named files, relevant callers/callees, tests, and repository guidance. Report
only material, evidenced gaps:

- wrong files, symbols, signatures, commands, or behavior;
- missed callsites, tests, docs, migrations, generated outputs, or contracts;
- unsafe ordering or incompatible intermediate states;
- realistic edge, error, concurrency, retry, partial-failure, or idempotency paths;
- checks that do not exist or cannot prove success; and
- ambiguity that forces a behavioral guess, or detail that blocks a sound local choice.

Do not reopen the architecture or expand scope. If repo evidence proves the design cannot
be implemented safely, report one `design-blocker` rather than inventing a replacement.
Do not edit files.

Return exactly:

```md
## Plan critique: <title>

### Verdict
<ship as-is | ship with the fixes below | reconsider the approach — and why>

### Findings
#### F1: <short title>
- Class: wrong-fact | missed-work | unsafe-sequence | unhandled-edge | verification-gap | spec-precision | design-blocker
- Severity: Critical | High | Medium | Low
- Confidence: High | Medium | Low
- Evidence: <repo evidence, including file:line where useful>
- Fix: <smallest concrete plan correction>

### Strengths
<what must be preserved>
```

Write `None.` under `### Findings` when no material gap exists.
