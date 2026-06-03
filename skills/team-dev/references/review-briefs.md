# Review & Synthesis (Stages 5 & 6)

Stage 5 runs fresh reviewers that never saw the code being written, in parallel, read-only. Each gets **only neutral context** (Neutral Context Rule in `references/pipeline.md`) plus its lane brief. They return findings only; they do not edit.

| Lane | Reviewers | Brief |
|---|---|---|
| **Debug** | the Debug engine(s) in the combo roster (typically two, cross-model) | `references/debug.md` |
| **Correctness** | the Correctness engine in the combo roster (one) | `references/correctness.md` |

See the combo's **ENGINE ROSTER** for which engines fill these lanes, and `references/engines.md` for how to invoke them. There is **no refine lane** — Stage 4 already handled structural quality and ended with the Structural Verdict self-check.

For **Stage 2** (plan review, before any code), use the **Correctness** brief against the plan instead of the code.

---

## Lane Brief Template (the handoff)

Build each reviewer's prompt from these labeled sections only. Anything outside these sections does not get passed — this enforces neutral context mechanically. Use `none` where there is nothing to provide.

```
### Lane
<debug | correctness>

### Lane reference
<absolute path to references/debug.md or references/correctness.md — read this before reviewing>

### Artifacts
<the code/diff under review — full files or git diff — or, in Stage 2, the plan>

### Task / spec source
<the user's original task statement / spec, verbatim, or "none">

### Repo guidance
<paths to AGENTS.md, CLAUDE.md, or conventions docs to consult, or "none">

### Output shape
<the Finding Schema below>
```

---

## Finding Schema (all reviewers)

Each reviewer returns `Task`, `Findings`, `Rationale`, `Suggested validation`. Each finding includes:

- `Location` — file and symbol / code path
- `Object` — the stable code object, behavior, branch, helper, abstraction, or call path
- `Stage` — `requirements` (correctness) or `fix` (debug)
- `Action` — `delete` | `fix` | `preserve` | `investigate` (debug findings use `fix`/`investigate`; correctness findings may also use `delete`/`preserve`)
- `Severity` — Critical | High | Medium | Low
- `Confidence` — High | Medium | Low
- `Evidence` — concrete code/spec references
- `Why it matters` — the concrete failure, regression, or maintenance cost
- `Main-agent instruction` — what synthesis should do with this finding

If a reviewer finds nothing material, it says so explicitly.

---

## Ordered Synthesis (Stage 6)

Turn the reports into one coherent fix pass. In **delegated** Fix combos the orchestrator produces a fix *plan* here and the writer engine applies it; in **direct** Fix combos the orchestrator edits. Either way the synthesis order is the same:

1. **Merge the debug reports.** Group by `Object`/`Location`; dedupe overlap. Where two debug engines **disagree** whether a bug is real, read the cited code yourself and decide — agreement raises confidence, but a bug found by only one engine can still be real.
2. **Verify** important claims by reading the referenced code before acting on them.
3. **Correctness first.** For each object, decide required / extra / wrong-scope / missing. Delete or rescope code that shouldn't exist *before* fixing bugs in it.
4. **Then debug fixes** on surviving code only.
5. Apply these precedence rules:
   - If correctness says a behavior is **extra or wrong-scope**, remove or rescope it even if a debug lane found a bug in it — mention the bug only as supporting context, not a fix step.
   - If correctness says a behavior is **required**, preserve it and fix its debug issues.
   - If both debug reviewers agree on a bug in surviving code, fix it. If only one flagged it, verify by reading, then fix or reject with a stated reason.
6. **Apply in a single coherent pass** — not per-finding patches. Resolve everything in one rewrite of the affected surface (one fix plan for the writer engine, in delegated combos).
7. Re-run the narrowest existing tests / typecheck / lint the repo already provides. Do not invent new harnesses. If a useful gate exists but can't run, record the exact blocker; if no relevant tooling exists, say so.

Report which findings you accepted and which you rejected, with reasons, ordered by severity (Critical → Low).
