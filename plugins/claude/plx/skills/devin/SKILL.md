---
name: devin
description: Single-engine Devin CLI passthrough with explicit full host access, SWE-2 High by default, exact model overrides, and validated final-only output. No multi-model review pipeline.
argument-hint: "<question, coding task, or plan request>"
disable-model-invocation: true
user-invocable: true
---

# /plx:devin

Run the request through Devin only. Return its answer without redoing or reviewing the
work. Do not launch other engines or subagents.

Use the packaged helpers on PATH.

## Resolve the model

- Default: `model=swe-2-high`.
- Resolve an explicit SWE-2 medium, high, or max request to `swe-2-medium`,
  `swe-2-high`, or `swe-2-max`.
- Pass any other explicit exact model ID through unchanged. If Devin rejects it,
  surface that error. Do not infer an override from a model name that is only task
  content.
- Devin has no generic effort flag. If the user explicitly supplies `effort` or a
  reasoning level independently of a Devin model variant, stop with an invocation
  error and ask them to choose an exact model variant.

Always pass the resolved value as `--model <model>`. Never pass `--effort`.

## Full-access boundary

This passthrough deliberately gives Devin full host access. Questions, plans, reviews,
and explanations still instruct Devin not to edit, but that intent is not enforced by
a sandbox. Full access does not expand the user's request or authorize publication,
deployment, credential changes, or external-system mutations unless the user explicitly
authorized the exact action and target.

The wrapper disables supported automatic imports, updates, and subagents in a generated
temporary user config. Repository-native Devin hooks, MCP servers, rules, and skills can
still load. Devin retains its own native session history; Parallax cleans only its
temporary prompt, config, export, and output artifacts.

## Execute

Resolve `<repo>` with `git rev-parse --show-toplevel`. Snapshot Git status and relevant
diffs to distinguish existing work. Create `<tmp>` with
`mktemp -d "${TMPDIR:-/tmp}/plx-devin.XXXXXX"`.

Write `<tmp>/prompt.md` with the user's request verbatim. Add `## Context` only for
necessary prior decisions, constraints, paths, and the full-access authority boundary
above. For a question, plan, review, or explanation, add an explicit instruction not to
edit files or mutate external systems. Keep your own proposed solution out of the brief.

Run exactly one fresh process:

```
plx-engine --engine devin --mode full-access --repo <repo> \
  --prompt-file <tmp>/prompt.md --model <model> --stdout
```

Disable the outer Claude Bash sandbox for this wrapper call
(`dangerouslyDisableSandbox: true`) so the chosen Devin transport actually has the full
host access the user requested. Do not add Devin's `--sandbox` flag or a trust bypass.

Use a retained background session for a long call. Save the wrapper exit code and final
output before status checks or cleanup. Trust wrapper exit codes: 0 validated terminal
response, 1 engine/incomplete-output failure, 2 invocation error, 3 unavailable
credentials. A nonzero exit ends this skill. Do not retry, perform the task in the host
session, switch engines, or synthesize a substitute answer. Return
`[PLX:DEVIN FAILED]`, the wrapper diagnostic, relevant log excerpt, and possible partial
changes. For exit 3, direct the user to `devin auth login`.

## Finish

Even on failure, compare final Git status/diffs with the baseline, record the outcome,
and clean up. Do not let recorder or cleanup results replace the engine exit status.
Use `pass` only for wrapper success and `fail` otherwise; this passthrough performs no
independent verification.

```
plx-eval finish --skill devin --host claude --repo <repo> --run-dir <tmp> \
  --task-file <tmp>/prompt.md --outcome <pass|fail> --verification not-run \
  || echo "plx-eval finish failed (non-fatal)" >&2
plx-clean-temp <tmp>
```

On success, emit Devin's validated final output verbatim. If it changed files, append
diff statistics attributable to this run; do not attribute pre-existing edits to Devin.

Request:

$ARGUMENTS
