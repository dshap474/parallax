---
name: simplify
description: Simplify a plan or code with independent reviews. Use "report only" to skip edits.
argument-hint: "<task or scope> [with all Codex|Claude|Grok lanes] [at <effort> effort] [report only]"
disable-model-invocation: true
user-invocable: true
---

# /plx:simplify — simplify plans and code

Review the supplied plan or code through four independent lanes. Resolve the target and
report-only mode before starting. Draft or complete work first only when the request
includes that work. In report-only mode, make no repository edits. The host launches
lanes, verifies their claims, and applies and checks authorized improvements.

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
2. Create `<tmp>` with `mktemp -d "${TMPDIR:-/tmp}/plx-simplify.XXXXXX"`; save the request
   to `<tmp>/task.md`.
3. Choose one target:
   - planning: the current draft, included in `<tmp>/brief.md`;
   - otherwise: the explicit scope, or upstream/main/last-commit diff plus working changes.
4. Read config key `simplify`. Run exactly these read-only roles concurrently:

| Role | Rubric |
| --- | --- |
| `simplify-reuse` | `simplify-reuse` |
| `simplify-simplification` | `simplify-simplification` |
| `simplify-efficiency` | `simplify-efficiency` |
| `simplify-altitude` | `simplify-altitude` |

The default is four `grok-4.6` lanes at `medium`. `with all Codex|Claude|Grok lanes`
replaces the engine for all four. Honor an explicit model or effort, except that
`grok-4.6` always uses `medium`; otherwise use Grok `medium`, Claude `high`, or Codex
`xhigh`. Preflight each selected engine once. Write the chosen
shape to `<tmp>/shape.txt` before launch.

Write one neutral `<tmp>/brief.md` beginning with `## Simplify brief`, containing the
target, constraints, and simplification goal. Keep lane selection, model/effort settings,
and report-only or fix instructions in the host context; lanes only propose changes.
Launch each lane:

```text
plx-engine --engine <engine> --mode ro --repo <repo> \
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
plx-eval finish --skill simplify --host claude --repo <repo> --run-dir <tmp> \
  --host-model <model-or-unknown> --task-file <tmp>/task.md --shape-file <tmp>/shape.txt \
  --outcome <pass|fail|partial|aborted> --verification <pass|fail|not-run>
```

Recorder failure is non-fatal. Report the target, lane shape, accepted/rejected findings,
changes, and verification. Clean only with `plx-clean-temp <tmp>`.

Do not create repository runtime state, commit, publish, or launch writer lanes.

Request:

$ARGUMENTS
