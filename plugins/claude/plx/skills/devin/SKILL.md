---
name: devin
description: Send a task directly to Devin with full host access. The request determines which actions are authorized.
argument-hint: "<question, coding task, or plan request>"
disable-model-invocation: true
user-invocable: true
---

# /plx:devin

Run the request through Devin only. Return its answer without redoing or reviewing the
work. Do not launch other engines or subagents.

Use the packaged helpers on PATH.

## Model

- Default: `model=swe-2-high`. SWE-2 medium, high, or max resolve to `swe-2-medium`,
  `swe-2-high`, or `swe-2-max`; pass any other explicit model ID unchanged. Ignore model
  names that are only task content.
- Devin has no effort setting. If the user asks for one apart from a model variant,
  ask them to choose an exact variant instead.

Always pass `--model <model>`. Never pass `--effort`.

## Full-access boundary

This passthrough deliberately gives Devin full host access. Full access does not expand
the user's request or authorize publication, deployment, credential changes, or
external-system mutations the user did not explicitly authorize.

Repository-native Devin hooks, MCP servers, rules, and skills can still load.

## Execute

Note `git status` first so you can attribute changes afterwards. In a fresh temp
directory `<tmp>`, write `<tmp>/prompt.md` with the task, preserving its wording and
constraints. Drop routing wording such as "use a Devin agent to ..."; in `## Context`,
tell Devin it is the requested agent and should do the task directly. Include only
necessary prior decisions, paths, and the boundary above, not your proposed solution.
For questions, plans, reviews, and explanations, explicitly prohibit file edits and
external mutations.

Run it in the background for long calls, one fresh process per attempt:

```
plx-engine --engine devin --mode full-access --repo <repo> \
  --prompt-file <tmp>/prompt.md --model <model> \
  --out <tmp>/attempt-1.out --log <tmp>/attempt-1.log
```

Disable the Claude Bash sandbox for this call (`dangerouslyDisableSandbox: true`) so
Devin actually has the requested access. Do not add Devin's `--sandbox` flag or a trust bypass.

## Recovery

Only exit 4 allows automatic recovery: at most two retries after the initial attempt,
using `attempt-N` files. Before retrying, follow [the recovery procedure](references/recovery.md).
A failed reconciliation command stops recovery.
If a side effect is ambiguous or replay could duplicate an action, stop and report what
needs reconciliation.

On any other failure, or after the retries run out, stop. Do not perform the task in
the host session, switch engines, or synthesize a substitute answer. Return
`[PLX:DEVIN FAILED]` with the attempt count, diagnostic, and any partial changes; for
exit 3, direct the user to `devin auth login`.

## Finish

On success, emit Devin's final output verbatim. If it changed files, append diff
statistics for this run only, not pre-existing edits. Delete `<tmp>`.

Request:

$ARGUMENTS
