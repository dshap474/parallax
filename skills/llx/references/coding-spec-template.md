# Coding Spec Template (Stage 1)

One spec per independent coding task. This is the linchpin of the pipeline: the Code engine implements from this spec (often at modest reasoning), so the spec must carry the thinking. If a spec is vague, the code will be weak. Write each spec so a competent coder with no prior context could execute it exactly.

Keep each task small and independent where possible, so Stage 3 can parallelize.

## Required sections

```
### Task
<one sentence: what this task builds>

### Files
- Create: <paths>
- Edit: <paths>
- Do NOT touch: <paths / areas off-limits>

### Interfaces / contracts
<exact signatures, types, API shapes, data structures, names. Be concrete —
no "design an appropriate interface". If it isn't pinned here, the Code engine will guess.>

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

## Quality bar for the spec itself

Before handing a spec to the Code engine, check:

- Could someone implement this **without asking a single question**? If not, it's underspecified — fix it before Stage 3.
- Are all interfaces/types/names pinned, not left to the Code engine's discretion?
- Are the "do not touch" boundaries explicit?
- Are acceptance checks concrete and runnable?

If you cannot make a task this precise, raise the Code engine's reasoning effort for that task or split it further — do not ship a vague spec and lean on the coder to fill the gaps.
