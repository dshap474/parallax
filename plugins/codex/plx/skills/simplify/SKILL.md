---
name: simplify
description: Simplify plans and code. Run four read-only lanes for reuse, simplification, efficiency, and altitude, then let the host verify and apply the smallest safe improvements. Use while planning, implementing, refactoring, or reviewing; say "report only" to skip fixes.
---

# $plx:simplify — simplify plans and code

Finish or draft the requested work, then improve it with four independent lanes. You are
the Codex host: launch the lanes, verify their claims, revise or fix the work, and test it.

## Simplification principles

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
2. Resolve `<plugin-root>` by removing `/skills/simplify/SKILL.md` from this file's path.
3. Create `<tmp>` with `mktemp -d "${TMPDIR:-/tmp}/plx-simplify.XXXXXX"`; save the request
   to `<tmp>/task.md`.
4. Choose one target:
   - planning: the current draft, included in `<tmp>/brief.md`;
   - otherwise: the explicit scope, or upstream/main/last-commit diff plus working changes.
5. Read config key `simplify`. Run exactly these read-only roles concurrently:

| Role | Rubric |
| --- | --- |
| `simplify-reuse` | `simplify-reuse` |
| `simplify-simplification` | `simplify-simplification` |
| `simplify-efficiency` | `simplify-efficiency` |
| `simplify-altitude` | `simplify-altitude` |

The default is four `grok-4.6` lanes at `medium`. `with all Codex|Claude|Grok lanes`
replaces the engine for all four. Honor an explicit model or effort, except that
`grok-4.6` always uses `medium`; otherwise use Grok `medium`, Claude `high`, or Codex
`xhigh`. Preflight each selected engine once. If the host sandbox blocks Claude
network or keychain access, request narrowly scoped host approval for that call; keep
Claude safe mode active. Write the chosen shape to `<tmp>/shape.txt` before launch.

Write one neutral `<tmp>/brief.md` beginning with `## Simplify brief`, containing the
target, constraints, and simplification goal. Keep lane selection, model/effort settings,
and report-only or fix instructions in the host context; lanes only propose changes.
Launch each lane:

```text
<plugin-root>/bin/plx-engine --engine <engine> --mode ro --repo <repo> \
  --prompt-file <tmp>/brief.md --rubric <rubric> --model <model> \
  --effort <effort> --out <tmp>/<engine>-<role>.md --log <tmp>/<engine>-<role>.log
```

Use packaged tools and named rubrics only. Retry exit `1` once. Exit `2` is usage failure;
exit `3` needs authentication. Continue as `partial` if at least one lane succeeds; never
substitute an explicitly chosen engine.

## Synthesize

Deduplicate findings, inspect their evidence, and try to disprove them. Reject unrelated
debt, style opinions, clever compression, speculative optimization, broad rewrites, and
anything that weakens the simplification boundaries above.

Unless `report only`, revise the draft or apply the smallest confirmed code fixes yourself.
Lanes never write. Re-read the result and run proportionate checks.

Finish the trace before cleanup:

```text
<plugin-root>/bin/plx-eval finish --skill simplify --host codex --repo <repo> --run-dir <tmp> \
  --host-model <model-or-unknown> --task-file <tmp>/task.md --shape-file <tmp>/shape.txt \
  --outcome <pass|fail|partial|aborted> --verification <pass|fail|not-run>
```

Recorder failure is non-fatal. Report the target, lane shape, accepted/rejected findings,
changes, and verification. Clean only with `<plugin-root>/bin/plx-clean-temp <tmp>`.

Do not create repository runtime state, commit, publish, or launch writer lanes.

Request:

$ARGUMENTS
