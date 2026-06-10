# Review & Synthesis (Stages 5 & 6)

Stage 5 runs fresh reviewers that never saw the code being written, in parallel, read-only. Each gets **only neutral context** (the Neutral Context Rule each skill states inline) plus its lane brief. They return findings only; they do not edit.

| Lane | Reviewers | Brief |
|---|---|---|
| **Debug** | the Debug engine(s) selected by the mode | `base-prompts/debug.md` |
| **Correctness** | the Correctness engine(s) selected by the mode | `base-prompts/correctness.md` |
| **Refine advisory** | only when selected by the mode | `base-prompts/refine.md` |

See the active skill's "## Pipeline" section and `config/parallax.yaml` for which engines fill these lanes, and the skill's "Running a lane" section for how to invoke them. Stage 4 owns direct structural cleanup; the ultra pipeline also runs refine as a read-only advisory lane.

For **Stage 2** (plan review, before any code), use the **Correctness** brief against the plan instead of the code.

---

## Lane Brief Template (the handoff)

Build each reviewer's prompt from these labeled sections only. Anything outside these sections does not get passed — this enforces neutral context mechanically. Use `none` where there is nothing to provide.

```
### Lane
<debug | correctness | refine>

### Lane reference
<absolute path to the lane brief — read this before reviewing>

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
- `Stage` — `requirements` (correctness), `delete` / `simplify` (refine), or `fix` (debug)
- `Action` — `delete` | `fix` | `simplify` | `preserve` | `investigate`
- `Severity` — Critical | High | Medium | Low
- `Confidence` — High | Medium | Low
- `Evidence` — concrete code/spec references
- `Why it matters` — the concrete failure, regression, or maintenance cost
- `Main-agent instruction` — what synthesis should do with this finding

If a reviewer finds nothing material, it says so explicitly.

---

## Ordered Synthesis (Stage 6)

Turn the reports into one coherent fix pass. In delegated Fix shapes the orchestrator produces a fix *plan* here and the writer engine applies it; in direct Fix shapes the orchestrator edits. Either way the synthesis order is the same:

1. **Merge the debug reports.** Group by `Object`/`Location`; dedupe overlap. Where two debug engines **disagree** whether a bug is real, read the cited code yourself and decide — agreement raises confidence, but a bug found by only one engine can still be real.
2. **Verify** important claims by reading the referenced code before acting on them.
3. **Correctness first.** For each object, decide required / extra / wrong-scope / missing. Delete or rescope code that shouldn't exist *before* fixing bugs in it.
4. **Then refine/simplify** surviving code only.
5. **Then debug fixes** on surviving code only.
6. Apply these precedence rules:
   - If correctness says a behavior is **extra or wrong-scope**, remove or rescope it even if a debug lane found a bug in it — mention the bug only as supporting context, not a fix step.
   - If correctness says a behavior is **required**, preserve it and fix its debug issues.
   - If refine says to delete an object and no correctness lane proves it required, accept deletion when confidence is high; otherwise investigate.
   - If both debug reviewers agree on a bug in surviving code, fix it. If only one flagged it, verify by reading, then fix or reject with a stated reason.
7. **Apply in a single coherent pass** — not per-finding patches. Resolve everything in one rewrite of the affected surface.
8. Re-run the narrowest existing tests / typecheck / lint the repo already provides. Do not invent new harnesses. If a useful gate exists but can't run, record the exact blocker; if no relevant tooling exists, say so.

Report which findings you accepted and which you rejected, with reasons, ordered by severity (Critical → Low).
