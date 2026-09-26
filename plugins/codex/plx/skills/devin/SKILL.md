---
name: devin
description: Single-engine Devin CLI passthrough with explicit full host access, SWE-2 High by default, exact model overrides, and validated final-only output. No multi-model review pipeline.
argument-hint: "<question, coding task, or plan request>"
---

# $plx:devin

Run the request through Devin only. Return its answer without redoing or reviewing the
work. Do not launch other engines or subagents.

Resolve `<plugin-root>` from this loaded `SKILL.md` path by removing
`/skills/devin/SKILL.md`. Use its packaged helpers in `<plugin-root>/bin/`.

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

Write the task to `<tmp>/prompt.md`, preserving its wording and constraints. Omit host
routing such as this skill invocation or "use a Devin agent to ...". In `## Context`,
tell Devin it is the requested agent and should perform the task directly. Include only
necessary prior decisions, paths, and the full-access boundary above, without your own
proposed solution. For questions, plans, reviews, and explanations, explicitly prohibit
file edits and external mutations.

Run one fresh process per attempt (at most three attempts total):

```
<plugin-root>/bin/plx-engine --engine devin --mode full-access --repo <repo> \
  --prompt-file <tmp>/prompt.md --model <model> \
  --out <tmp>/attempt-1.out --log <tmp>/attempt-1.log
```

If the host sandbox blocks Devin's network, credentials, or requested filesystem access,
request narrowly scoped host approval for this explicit full-access wrapper call. Do not
add Devin's `--sandbox` flag or a trust bypass.

Use a retained background session for a long call. Keep separate `--out <tmp>/attempt-N.out`
and `--log <tmp>/attempt-N.log` files for each attempt. Do not combine these with
`--stdout`, which uses disposable internal paths. Read the validated answer from the
successful attempt output file. Save each wrapper exit code before status checks or cleanup.
Trust wrapper exit codes: 0 validated terminal response, 1 engine/incomplete-output
failure, 2 invocation error, 3 unavailable credentials, 4 explicitly retryable internal
protocol failure. Exit 4 is limited to the observed `invalid_argument` diagnostic
with `errorKind=internal` and boolean `retryable=true`. Other provider error kinds
(including quota and unavailability) remain exit 1 even if marked retryable.
The wrapper never retries by itself.

## Bounded recovery

Only exit 4 allows automatic recovery: at most two retries after the initial attempt,
waiting 2 seconds before the first retry and 5 seconds before the second. No extra user
approval is needed within the original task authority. Never infer retryability from
quoted model output, a generic nonzero exit, or a missing terminal export.

Perform reconciliation and retry as separate tool calls; inspect the reconciliation
result before launching another process. A failed reconciliation command stops recovery.
Never chain a retry after a check that might fail.

Before every retry, compare Git status and relevant diffs with the original baseline
(including untracked files), inspect the failed attempt log, and reconcile possible
partial work. For a read-only task, stop if any unexpected edits occurred. For a
write task, identify completed edits and verify any possible side effects before
continuing; a clean Git diff alone cannot establish that an external action did not
happen. If a side effect is ambiguous or replay could duplicate an action, stop and
report what needs reconciliation instead of replaying it. Do not undo partial changes.

Reuse the task and context from the first prompt and keep the same model. Append the
attempt number, failure diagnostic, and observed partial work; instruct Devin to inspect
that work and continue only the remaining task without repeating completed mutations.
Use a fresh process, never an implicit latest-session resume. Keep all attempt evidence
until recording and cleanup. A recovered run passes only after exit 0 and validated
terminal output; partial output is never a completed answer or review approval.

After exhausted exit-4 attempts, or immediately for any other nonzero exit, end the
skill. Do not perform the task in the host session, switch engines, or synthesize a
substitute answer. Return `[PLX:DEVIN FAILED]`, attempt count, wrapper diagnostic,
relevant log excerpt, and possible partial changes. For exit 3, direct the user to
`devin auth login`.

## Finish

Even on failure, compare final Git status/diffs with the baseline, record the outcome,
and clean up. Do not let recorder or cleanup results replace the engine exit status.
Use `pass` only for wrapper success and `fail` otherwise; this passthrough performs no
independent verification.

```
<plugin-root>/bin/plx-eval finish --skill devin --host codex --repo <repo> --run-dir <tmp> \
  --task-file <tmp>/prompt.md --outcome <pass|fail> --verification not-run \
  || echo "plx-eval finish failed (non-fatal)" >&2
<plugin-root>/bin/plx-clean-temp <tmp>
```

On success, emit Devin's validated final output verbatim. If it changed files, append
diff statistics attributable to this run; do not attribute pre-existing edits to Devin.

Request:

$ARGUMENTS
