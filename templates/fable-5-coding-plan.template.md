# Claude Fable 5 Coding Plan Template

Use this template for Claude Fable 5 worker-agent coding tasks. Fable follows concise instructions well and can over-plan when a task is underspecified; keep the plan outcome-first, minimal, and evidence-driven.

This plan template targets high-effort autonomous workers. For low- and medium-effort code engines that need every interface pinned, use `coding-spec.template.md` instead.

---

## Task

**Task ID:** `<TASK-ID>`  
**Title:** `<short title>`  
**Repo:** `<repo>`  
**Branch:** `<branch>`  
**Issue / PR:** `<link or ID>`  
**Status:** `Draft | Ready | In Progress | Blocked | Done`

---

## Engine Settings

Recommended:

- effort: `high` (default) — `xhigh` for the most capability-sensitive work; `medium`/`low` for routine tasks
- thinking: adaptive

Escalate effort only when task complexity justifies the extra latency and cost.

---

## Worker Instruction

Implement the task below.

Do the simplest general thing that satisfies the success criteria. Prefer existing project patterns over new abstractions. Validate at system boundaries; trust internal code and framework guarantees. Add a dependency only when directly required, and justify it in the final report.

Once you have enough information to act safely, act. Do not re-plan, re-derive established facts, or expand scope.

Before reporting progress or completion, audit each claim against a tool result from this session. Report only work you can point to evidence for; if something is unverified, say so explicitly.

---

## Intent

`<Why this change matters, who it is for, and what it enables. 2–5 sentences.>`

---

## Success Criteria

Binary checks that define completion.

- [ ] `<observable behavior>`
- [ ] `<important edge case>`
- [ ] `<regression that must remain intact>`
- [ ] `<relevant automated check passes>`
- [ ] `<manual or runtime verification, if needed>`

---

## Context

### Relevant files / systems

- `<path>` — `<why it matters>`
- `<path>` — `<why it matters>`
- `<service / API / module>` — `<why it matters>`

### Current behavior

`<Brief description of the current behavior, bug, limitation, or missing capability.>`

### Desired behavior

`<Brief description of target behavior. Include examples only where they reduce ambiguity.>`

### Existing patterns to reuse

- `<helper / component / module / test pattern>`
- `<error-handling / logging / data-access / state-management convention>`

---

## Invariants

The only hard rules. Everything else is judgment within the worker instruction.

- Do not expose, log, or commit secrets.
- Do not run destructive commands or mutate production data.
- Do not change public APIs, schemas, migrations, auth, permissions, or pricing behavior unless listed in scope.
- Do not delete or weaken existing tests to make the task pass.
- Do not modify `<out-of-scope file / module / feature>`.

---

## Delegation

Use subagents for independent discovery, implementation, or verification workstreams that can run in parallel, and keep working while they run. Use a fresh-context verifier subagent for risky or broad changes. Do not delegate merely to create process.

---

## Suggested Path

Non-binding. Use another path if it better satisfies the intent, invariants, and validation.

Likely files or patterns to inspect:

- `<path>`
- `<path>`

Likely implementation shape:

- `<short implementation idea>`
- `<edge case likely worth testing>`

---

## Validation

Run the smallest set of checks that meaningfully proves the task.

```bash
<targeted test command>
<typecheck or lint command>
<build or smoke test command>
```

Implement the general solution. Tests and acceptance checks verify correctness; they do not define it. Do not hard-code to visible tests, fixtures, or checks.

If a bug is being fixed, capture failing-before or reproduction evidence when practical, then passing-after evidence.

If validation cannot be run, report:

- what was not run
- why it could not be run
- what was verified instead
- what the reviewer should run next

---

## Stop Rules

Stop when the success criteria are satisfied and validation has run. Do not keep polishing, broadening, refactoring, or searching after the core request is complete.

Proceed autonomously for local, reversible decisions.

Stop and ask only when:

- requirements conflict
- a missing secret, credential, account, service, dataset, or environment blocks meaningful verification
- baseline failures are unrelated to this task
- the change would require breaking an invariant
- satisfying the task would require substantial scope expansion

Before ending, check your final paragraph. If it is a plan, a question, or a promise about work not yet done, do that work now or state the concrete blocker.

---

## Final Report Format

Write the report for a reader who saw none of the work. Lead with the outcome, in plain language, without working shorthand.

```md
Implemented:
- <summary>

Changed files:
- `<path>` — <change>

Validation:
- `<command or check>` — <pass/fail/not run>

Success criteria:
- [x] <criterion> — <evidence>
- [ ] <criterion> — <why incomplete, if applicable>

Not done:
- <explicitly excluded work or "none">

Risks / failure behavior / privacy-security notes:
- <concrete issue or "none">
```

---

## Optional Sections

Add only when the task justifies them.

### Open Questions

- `<question that materially changes implementation>`
- `<safe assumption if unanswered>`

### Milestones

Use only for multi-session, multi-agent, or high-risk work.

| Milestone | Outcome | Evidence |
|---|---|---|
| `M1` | `<outcome>` | `<check>` |
| `M2` | `<outcome>` | `<check>` |

### Rollback

If this change fails:

1. Revert `<files / commit / migration>`.
2. Restore `<config / schema / data, if applicable>`.
3. Run `<recovery check>`.
4. Report the failure and remaining risk.

### Progress Log

Use only if work will span multiple sessions or agents.

```md
### <YYYY-MM-DD HH:MM> — <agent/session>

Completed:
- <work completed>

Evidence:
- `<command/check>` — <result>

Next:
- <specific next action>
```
