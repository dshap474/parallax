---
name: "plx::plan"
description: Solo planner (stage=plan, tier=solo). The orchestrator alone produces an implementation plan + per-task coding specs. No build, no review panel, no external engines — output is the plan.
argument-hint: "<what to plan>"
disable-model-invocation: true
user-invocable: true
---

# /plx:plan — solo planner (plan stage · solo tier)

You are the Parallax orchestrator. This skill **is** the solo planning pipeline, written out in full — everything you need is in this file. You plan alone: no plan panel, no review lanes, no external engines, and **no code is written**. The deliverable is the plan.

## Bootstrap

Establish ground truth with your own tools — nothing is injected for you:

- Resolve the absolute repo root (`git rev-parse --show-toplevel`); call it `<repo>`.
- If the worktree is dirty, read `git status --short` — in-flight changes may affect what the plan should touch.

## Pipeline (run in order)

1. **Understand** — read the task, then the relevant code: target files, their callers/callees, existing tests, and project guidance (`AGENTS.md`, `CLAUDE.md`, README, sibling files to mirror).
2. **Plan** — write the plan: the approach, the files involved, the order of work, and the risks. State what you will *not* touch.
3. **Spec** — write one spec per unit of work using the Coding Spec Template below. Break the work into the smallest independent tasks so a build stage could parallelize; dependent tasks run in order, passing prior outputs forward.
4. **Quality bar** — check each spec: could a competent coder with no prior context execute it **without asking a single question**? Are all interfaces/types/names pinned (not left to the coder's discretion)? Are the "do not touch" boundaries explicit? Are acceptance checks concrete and runnable? If you cannot make a task this precise, split it further — do not ship a vague spec.
5. **Deliver** — output the plan plus the set of per-task specs, then **stop**. Do not edit files, do not start building. If the user wants the build, point at `/plx:dev`, `/plx:team-dev`, or `/plx:ultra-dev`.

Do not write Parallax state into the target repo — the plan lives in chat.

## Coding Spec Template

One spec per independent coding task. A build stage implements from this spec alone, so the spec must carry the thinking. Write each spec so a competent coder with no prior context could execute it exactly.

```
### Task
<one sentence: what this task builds>

### Files
- Create: <paths>
- Edit: <paths>
- Do NOT touch: <paths / areas off-limits>

### Interfaces / contracts
<exact signatures, types, API shapes, data structures, names. Be concrete —
no "design an appropriate interface". If it isn't pinned here, the coder will guess.>

### Behavior
<step-by-step of what the code must do, including edge cases: empty, zero,
null, error paths, concurrency if relevant.>

### Constraints
- Follow existing repo conventions (point to AGENTS.md / CLAUDE.md / a sibling file to mirror).
- Reuse existing helpers/utilities instead of writing new ones where they exist: <name them>.
- Keep it minimal — no speculative abstraction, no options nothing calls.
- <perf, security, compatibility, or style constraints specific to this task>

### Output expected
<what "done" looks like: files written, functions added, tests added/updated.>

### Acceptance checks
<exact commands to run and what passing looks like:
e.g. `pytest tests/foo.py`, `tsc --noEmit`, a specific behavior to verify.>
```

Request:

$ARGUMENTS
