# Coding Plan / Spec Template

Canonical spec for a **high-effort autonomous worker** — model-agnostic (Claude
Opus / Fable, GPT, Grok, etc.). The orchestrator authors the final plan to this
shape. It is outcome-first: pin intent, success criteria, and invariants hard;
leave the *how* to the worker. State scope explicitly — do not assume the worker
generalizes a rule from one example to the rest; if something applies everywhere,
say so.

Keep ordinary plans short. Expand the optional sections only when the task is
risky, ambiguous, multi-session / multi-agent, or touches public contracts,
security, money movement, permissions, or production data.

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

Recommended (tune to the engine and task):

- effort / reasoning: `high` for coding and agentic work; `xhigh` for the hardest
  or most capability-sensitive tasks; lower (`medium` / `low`) for routine work
- thinking / verbosity: adaptive; keep worker output concise

Escalate effort only when task complexity justifies the extra latency and cost.

---

## Worker Instruction

Implement the task below.

Do the simplest general thing that satisfies the success criteria. Choose the
implementation path yourself unless a constraint requires a specific one. Prefer
existing project patterns over new abstractions. Validate at system boundaries;
trust internal code and framework guarantees. Add a dependency only when directly
required, and justify it in the final report.

Once you have enough information to act safely, act. Do not re-plan, re-derive
established facts, or expand scope.

Do not claim completion without validation evidence, or a clear explanation of what
could not be verified. Before reporting, audit each claim against a result you can
point to; if something is unverified, say so explicitly.

---

## Intent

`<Why this change matters, who it is for, and what it enables. 2–5 sentences.>`

---

## Success Criteria

Binary checks that define completion. Pair each with its **oracle** — the command or
observable that proves it from output the run prints, not from the filesystem. A reviewer
(or an autonomous `/goal`-style evaluator) confirms "done" only from evidence the run
surfaces, so a criterion with no nameable proof is not yet a criterion.

- [ ] `<observable behavior>` — proven by: `<command + the signal in its output>`
- [ ] `<important edge case>` — proven by: `<command / observable>`
- [ ] `<regression that must remain intact>` — proven by: `<command + pass signal>`
- [ ] `<relevant automated check passes>` — proven by: `<command + pass signal>`
- [ ] `<manual or runtime verification, if needed>` — proven by: `<what to do + what to see>`

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
- Do not change public APIs, schemas, migrations, auth, permissions, or pricing
  behavior unless listed in scope.
- Do not delete or weaken existing tests to make the task pass.
- Do not modify `<out-of-scope file / module / feature>`.

---

## Execution

Work directly by default. The Parallax orchestrator may split genuinely independent,
file-disjoint work into headless `plx-engine` lanes before briefing each worker. A worker
executing this spec must work without subagents or recursive delegation.

---

## Suggested Path

Non-binding. Use another path if it better satisfies the intent, invariants, and
validation.

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

Implement the general solution. Tests and acceptance checks verify correctness;
they do not define it. Do not hard-code to visible tests, fixtures, or checks.

For UI work, include a concrete visual or runtime check:

```text
<page / route / component state to inspect>
<expected visible behavior>
```

If a bug is being fixed, capture failing-before or reproduction evidence when
practical, then passing-after evidence.

If validation cannot be run, report: what was not run, why, what was verified
instead, and what the reviewer should run next.

---

## Stop Rules

Stop when the success criteria are satisfied and validation has run. Do not keep
polishing, broadening, refactoring, or searching after the core request is
complete. After each result, ask whether the core request is now satisfied with
evidence; if yes, finish.

Read the smallest set of files sufficient to make a correct change. Expand
exploration only when required by uncertainty, failing validation, or shared
behavior.

Proceed autonomously for local, reversible decisions. Stop and ask only when:

- requirements conflict
- a missing secret, credential, account, service, dataset, or environment blocks
  meaningful verification
- baseline failures are unrelated to this task
- the change would require breaking an invariant
- satisfying the task would require substantial scope expansion

Before ending, check your final paragraph. If it is a plan, a question, or a
promise about work not yet done, do that work now or state the concrete blocker.

---

## Final Report Format

Write the report for a reader who saw none of the work. Lead with the outcome, in
plain language, without working shorthand.

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

Use only if work will span multiple sessions or agents. **Re-read this log at session
start to find where you are, and append a new entry after each milestone or before you
stop.** It is the only memory that survives a new session — an autonomous run resets its
turn and token counters on resume, so the log is the durable anchor.

```md
### <YYYY-MM-DD HH:MM> — <agent / session>

Completed:
- <work completed>

Evidence:
- `<command / check>` — <result>

Next:
- <specific next action>
```

### Visual Direction

Use only for frontend / UI work. Specify a concrete direction rather than generic
adjectives ("clean", "modern") — capable models have a strong default house style
that vague instructions will not override.

- palette: `<hex values or tonal description>`
- typography: `<typeface direction>`
- layout density: `<spacing / structure>`
- motion: `<animation expectations>`
- references: `<examples or inspiration>`
