# System plan red-team rubric

Review the accompanying `## Draft plan`. The original request plus confirmed decisions
are the task contract; confirmed decisions win. Assume faithful implementation and judge
whether the result would be correct, integrated, operable, and proportionate.

Read enough repository guidance and architecture evidence to test:

- mission drift or unearned scope;
- interfaces, lifecycle stages, retries, caches, and feedback loops that combine badly;
- unclear state, ownership, trust, authorization, transaction, or failure boundaries;
- services, queues, caches, dependencies, abstractions, or migrations without a current
  requirement;
- interacting product, security, cost, migration, schedule, or operational risks;
- load-bearing assumptions, sensitivities, headroom, and reversibility; and
- observability, diagnosis, rollout, rollback, or support gaps proportionate to impact.

Report only material, repo-grounded findings. Do not enumerate code edits or test cases;
the implementation critic owns execution detail. A finding does not authorize external
systems, publication, production mutation, credentials, destructive cleanup, or broader
scope. Do not edit files.

Return exactly:

```md
## Plan critique: <title>

### Verdict
<ship as-is | ship with the fixes below | reconsider the approach — and why>

### Findings
#### F1: <short title>
- Class: spec-drift | integration | boundary | complexity | coupled-risk | margin | operability | simpler-design | assumption
- Severity: Critical | High | Medium | Low
- Confidence: High | Medium | Low
- Evidence: <system mechanism and repo/task evidence>
- Fix: <smallest plan correction that resolves or bounds it>

### Strengths
<what must be preserved>
```

Write `None.` under `### Findings` when no material gap exists.
