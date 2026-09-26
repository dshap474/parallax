---
name: plan
description: Author a plan in the host and review it once with gpt-6-astra. Write no code.
argument-hint: "<task to plan>"
disable-model-invocation: true
user-invocable: true
---

# /plx:plan

Use the packaged helpers on PATH.

The host authors the plan: Astra in Codex, Fable 5.1 in Claude Code.
Use one read-only opposite-host reviewer. Do not build, commit, or publish.

Resolve `<repo>` with `git rev-parse --show-toplevel` and note existing changes.
Create `<tmp>` with `mktemp -d "${TMPDIR:-/tmp}/plx-plan.XXXXXX"`.
Save the original request to `<tmp>/task.md` and the author/reviewer model choices to
`<tmp>/shape.txt`. Run `plx-preflight --repo <repo> --require-codex --model gpt-6-astra`.

Read relevant repository guidance, code, and tests. Ask only questions that materially
change the plan. State scope, the proposed approach, and concrete `Done means:` checks.
Keep the plan in the conversation unless persistence is useful; for a persisted spec,
use `plx-skill --ref plan/spec-template`. Never edit `.project/VISION.md`.

Write `<tmp>/critic-brief.md` with:

```markdown
## Draft plan
### Original request
<original request verbatim>
### Confirmed decisions
<user clarifications, or none>
### Candidate plan
<draft plan verbatim>
```

Run the reviewer and wait for its result:

```
plx-engine --engine codex --mode ro --repo <repo> \
  --prompt-file <tmp>/critic-brief.md --rubric plan-critic \
  --model gpt-6-astra --effort high \
  --out <tmp>/critic.md --log <tmp>/critic.log
```

Use packaged wrappers and named rubrics; no raw engine commands, pasted rubrics, or
subagents. If the host sandbox blocks the reviewer's network or keychain access,
request narrowly scoped host approval for the wrapper call; keep its sandbox active.

Verify material findings against the repository and revise the plan. Report unresolved
issues or a failed reviewer as incomplete; do not silently substitute a model.
Present the final plan and material review dispositions. Standalone Plan stops here.
When called by Dev, return the plan and completion status to Dev.

Before every handled return, record the outcome and clean up:

```
plx-eval finish --skill plan --host claude --repo <repo> --run-dir <tmp> \
  --host-model <actual host model if known, otherwise unknown> \
  --task-file <tmp>/task.md --shape-file <tmp>/shape.txt \
  --outcome <pass|fail|partial|aborted> --verification <pass|fail|not-run> \
  || echo "plx-eval finish failed (non-fatal)" >&2
plx-clean-temp <tmp>
```

Recorder failure is non-fatal. Keep runtime files outside the repository.

Request:

$ARGUMENTS
