---
name: simplify
description: Review changed code or a plan for reuse, simplification, efficiency, and altitude with four parallel engine lanes, then apply the fixes. Use "report only" to skip edits.
---

# $plx:simplify

`$plx:simplify → 4 cleanup lanes in parallel → apply the fixes`

You are improving the quality of the changed code, not hunting for bugs. Review
it for reuse, simplification, efficiency, and altitude issues, then fix what you
find. Do not look for correctness bugs — that is what `$plx:review` is for. If the
target is a plan instead of code, review the plan and revise it the same way.

Resolve `<plugin-root>` by removing `/skills/simplify/SKILL.md` from this file's path.

## Phase 0 — Gather the diff

Run `git diff @{upstream}...HEAD` (or `git diff main...HEAD` / `git diff HEAD~1`
if there's no upstream) to get the unified diff under review. If there are
uncommitted changes, or the range diff is empty, also run `git diff HEAD` and
include the working-tree changes in scope. If a PR number, branch name, file path,
or plan was passed as an argument, review that target instead.

Create `<tmp>` with `mktemp -d "${TMPDIR:-/tmp}/plx-simplify.XXXXXX"` and write the
target and any user constraints to `<tmp>/brief.md` under `## Simplify brief`.

## Phase 1 — Review (4 cleanup lanes in parallel)

Launch **4 independent read-only lanes** concurrently in the background, one per
rubric: `simplify-reuse`, `simplify-simplification`, `simplify-efficiency`,
`simplify-altitude`.
The default is four Claude `claude-opus-5-5` lanes at `medium`, matching `$plx:claude`.
`with all Codex|Claude|Grok lanes`, or an explicit model or effort, replaces it for all four.
If the host sandbox blocks Claude network or keychain access, request narrowly scoped host approval for that call; keep Claude safe mode active.

```text
<plugin-root>/bin/plx-engine --engine <engine> --mode ro --repo <repo> --prompt-file <tmp>/brief.md \
  --rubric <rubric> --model <model> --effort <effort> \
  --out <tmp>/<rubric>.md --log <tmp>/<rubric>.log
```

Each lane returns findings with `file`, `line`, a one-line `summary`, and the
concrete cost. If a lane fails, continue with the others and note it.

## Phase 2 — Apply the fixes

Wait for all four lanes to complete, dedup findings that point at the same
line or mechanism, and fix each remaining one directly. Skip any finding whose
fix would change intended behavior, require changes well outside the reviewed
diff, or that you judge to be a false positive — note the skip rather than
arguing with it. With `report only`, list the findings instead of fixing them.
Finish with a brief summary of what was fixed and what was skipped (or confirm
the code was already clean).

Then record the run and clean up:

```text
<plugin-root>/bin/plx-eval finish --skill simplify --host codex --repo <repo> --run-dir <tmp> \
  --outcome <pass|fail|partial|aborted> --verification <pass|fail|not-run> \
  || echo "plx-eval finish failed (non-fatal)" >&2
<plugin-root>/bin/plx-clean-temp <tmp>
```

Request:

$ARGUMENTS
