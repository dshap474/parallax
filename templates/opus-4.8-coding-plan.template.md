# Claude Opus 4.8 Coding Plan Template

Use this template for Claude Opus 4.8 worker-agent coding tasks. Opus benefits from clear intent, explicit scope, and strong validation — not procedural micromanagement.

This plan template targets high-effort autonomous workers. For low- and medium-effort code engines that need every interface pinned, use `coding-spec.template.md` instead.

> **Author note:** Opus 4.8 follows instructions literally and will not generalize a rule from one file or section to others. State scope explicitly ("apply to every endpoint, not just the first").

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

- effort: `xhigh` for coding and agentic work; minimum `high` for intelligence-sensitive work
- thinking: `adaptive`
- max output tokens: start at 64k for `xhigh`/`max`, then tune

---

## Worker Instruction

Implement the task below.

Prioritize correctness, minimality, and consistency with the existing codebase. Do the simplest general thing that satisfies the success criteria. Prefer existing project patterns over new abstractions. Validate at system boundaries; trust internal code and framework guarantees. Add a dependency only when directly required, and justify it in the final report.

Do not claim completion without evidence from tests, checks, or runtime behavior, or a clear explanation of what could not be verified.

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

Work directly by default. Use subagents only when independent workstreams can run in parallel, a risky area needs fresh-context review, or parallel file discovery materially helps in a large codebase. Do not delegate merely to create process.

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

For UI work, include a concrete visual or runtime check:

```text
<page / route / component state to inspect>
<expected visible behavior>
```

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

---

## Final Report Format

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

### Visual Direction

Use only for frontend/UI work. Opus 4.8 has a persistent default house style (cream backgrounds, serif display type, terracotta accents); generic instructions like "clean" or "modern" will not break it. Specify a concrete direction, or ask the model to propose distinct options before building.

- palette: `<hex values or tonal description>`
- typography: `<typeface direction>`
- layout density: `<spacing / structure>`
- motion: `<animation expectations>`
- references: `<examples or inspiration>`
