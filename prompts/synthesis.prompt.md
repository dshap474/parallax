# Review & synthesis

Two review lanes run in parallel, read-only, on the code just built. Each is a fresh
reviewer that never saw the code being written; each gets **only neutral context** — the
same review brief, no analysis and no steer — and re-derives judgment from the repo
itself. They return findings only; they do not edit. You then synthesize as the
**pseudo-third reviewer**.

| Lane | Reviewer | Reference |
|---|---|---|
| **Correctness** | the engine assigned to the correctness role | `prompts/review-correctness.prompt.md` |
| **Refine** | the engine assigned to the refine role | `prompts/review-refine.prompt.md` |

The correctness lane owns both halves of "is it right" — the right thing was built (spec
match) and the thing was built right (bugs, robustness, failure paths). The refine lane
owns over-engineering, simplification, and structure. See the active skill's "## Pipeline"
section for which engines fill these lanes and how to invoke them.

## Review brief (the handoff)

Hand each lane the same compact brief and nothing else — no analysis, no suspicions, no
steer toward a verdict. Neutral context is enforced by what you pass.

```
## Review brief
- Repo: <absolute repo path>
- Files touched: <the scope list>
- What was implemented / what to scrutinize: <what was built and why, verbatim where possible>
- Spec source: <the plan, task statement, or doc the work should match, or "derive from code and tests">
```

## Finding schema (both lanes)

Each lane returns `Task`, `Findings`, and a short `Rationale`. Each finding uses:

- `Location` — file and symbol / code path
- `Object` — the stable code object, behavior, branch, helper, abstraction, or call path
- `Action` — `delete` | `fix` | `preserve` | `investigate`
- `Severity` — Critical | High | Medium | Low
- `Confidence` — High | Medium | Low
- `Evidence` — concrete code/spec references
- `Why it matters` — the concrete failure, regression, or maintenance cost
- `Main-agent instruction` — what synthesis should do with this finding

If a lane finds nothing material, it says so explicitly.

## Ordered synthesis

Turn the two reports into one coherent repair pass. You are the pseudo-third reviewer:
you don't re-review from scratch, you dedupe, rank, resolve conflicts, and verify.

1. **Dedupe and rank across lanes.** Group by `Object`/`Location`; merge overlap.
2. **Verify before trusting.** Read the cited code surgically before acting on any
   finding — kill false positives. A finding raised by only one lane can still be real.
3. **Correctness governs first.** For each object, decide required / extra / wrong-scope
   / missing. Delete or rescope code that shouldn't exist *before* fixing bugs in it —
   bug findings arrive through the correctness lane, so a bug on an object correctness
   wants removed is supporting context, not a fix step.
4. **Refine applies to survivors only.** Apply refine's structure and simplification
   findings only to code that survives the correctness pass; don't polish what's being
   deleted or rewritten.
5. **Smell what's missing.** Use the reports as pointers to what a lane might have missed
   — adjacent paths, error patterns suggesting a deeper cause — and read those spots.
   Targeted, not a full re-review.

Precedence:

- Correctness says **extra or wrong-scope** → remove or rescope it, even if a bug was
  found in it; cite the bug as context only.
- Correctness says **required** → preserve it and fix its issues.
- Refine says **delete** and no correctness verdict proves the object required → accept
  deletion when confidence is high; otherwise investigate.

## Output

The **repair plan** — each item with location, what to change, why, and which findings it
resolves (or "won't fix" with the reason), ordered by severity (Critical → Low). The fix
is applied in a single coherent pass over the affected surface, then re-verified with the
narrowest existing tests / typecheck / lint the repo already provides — never `uv run` in
a sandbox, never a new harness. If a useful gate can't run, record the exact blocker; if
no relevant tooling exists, say so.
