---
name: kiss
description: Keep plans and code simple. Run four read-only lanes for reuse, simplification, efficiency, and altitude, then let the host verify and apply the smallest safe improvements. Use while planning, implementing, refactoring, or reviewing; say "report only" to skip fixes.
argument-hint: "<task or scope> [with all Codex|Claude|Grok lanes] [at <effort> effort] [report only]"
disable-model-invocation: true
user-invocable: true
---

# /plx:kiss — keep it simple

Finish or draft the requested work, then improve it with four independent lanes. You are
the Claude host: launch the lanes, verify their claims, revise or fix the work, and test it.

## KISS

Understand the work first. Then stop at the first option that fully works:

1. Remove what need not exist.
2. Reuse the repository.
3. Use the standard library.
4. Use the native platform.
5. Use an installed dependency.
6. Prefer direct code over a new abstraction.
7. Otherwise add the minimum required.

Prefer deletion, root-cause fixes, boring code, and fewer files. Never weaken requirements,
correctness, security, validation, data safety, accessibility, error handling, or testing.

## Run

1. Resolve `<repo>` with `git rev-parse --show-toplevel`; save `git status --short`.
2. Create `<tmp>` with `mktemp -d "${TMPDIR:-/tmp}/plx-kiss.XXXXXX"`; save the request
   to `<tmp>/task.md`.
3. Choose one target:
   - planning: the current draft, included in `<tmp>/brief.md`;
   - otherwise: the explicit scope, or upstream/main/last-commit diff plus working changes.
4. Read config key `kiss`. Run exactly these read-only roles concurrently:

| Role | Rubric |
| --- | --- |
| `kiss-reuse` | `kiss-reuse` |
| `kiss-simplification` | `kiss-simplification` |
| `kiss-efficiency` | `kiss-efficiency` |
| `kiss-altitude` | `kiss-altitude` |

The default is four Grok lanes at `medium`. `with all Codex|Claude|Grok lanes` replaces
the engine for all four. Honor an explicit model or effort; otherwise use Grok `medium`,
Claude `high`, or Codex `xhigh`. Preflight each selected engine once. Write the chosen
shape to `<tmp>/shape.txt` before launch.

Write one neutral `<tmp>/brief.md` beginning with `## KISS brief`, followed by the target
and requested outcome. Launch each lane:

```text
plx-engine --engine <engine> --mode ro --repo <repo> \
  --prompt-file <tmp>/brief.md --rubric <rubric> [--model <model>] \
  --effort <effort> --out <tmp>/<engine>-<role>.md --log <tmp>/<engine>-<role>.log
```

Use packaged tools and named rubrics only. Retry exit `1` once. Exit `2` is usage failure;
exit `3` needs authentication. Continue as `partial` if at least one lane succeeds; never
substitute an explicitly chosen engine.

## Synthesize

Deduplicate findings, inspect their evidence, and try to disprove them. Reject unrelated
debt, style opinions, clever compression, speculative optimization, broad rewrites, and
anything that weakens the KISS boundaries above.

Unless `report only`, revise the draft or apply the smallest confirmed code fixes yourself.
Lanes never write. Re-read the result and run proportionate checks.

Finish the trace before cleanup:

```text
plx-eval finish --skill kiss --host claude --repo <repo> --run-dir <tmp> \
  --host-model <model-or-unknown> --task-file <tmp>/task.md --shape-file <tmp>/shape.txt \
  --outcome <pass|fail|partial|aborted> --verification <pass|fail|not-run>
```

Recorder failure is non-fatal. Report the target, lane shape, accepted/rejected findings,
changes, and verification. Clean only with `plx-clean-temp <tmp>`.

Do not create repository runtime state, commit, publish, or launch writer lanes.

Request:

$ARGUMENTS
