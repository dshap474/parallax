---
name: plan
description: "Fable authors a plan, then parallel implementation and system critics red-team it against the task contract. Defaults: two GPT-5.6 Sol xhigh critics. No code is written."
argument-hint: "<task to plan>"
disable-model-invocation: true
user-invocable: true
---

# /plx:plan

Author the plan yourself. Use two independent read-only critics for implementation
feasibility and system design. Write no code and do not build, commit, or publish.

Use the packaged helpers on PATH.

## Prepare

Resolve `<repo>` with `git rev-parse --show-toplevel` and note existing changes.
Create `<tmp>` with `mktemp -d "${TMPDIR:-/tmp}/plx-plan.XXXXXX"` and write the
user's request verbatim to `<tmp>/task.md`. Keep all lane prompts directly in `<tmp>`.

Read `plx-config`, key `plan`. After current-message overrides, each required
critic dimension must resolve to exactly one supported engine. Stop on missing,
unsupported, or multiple bindings. Skip or substitute a dimension only on explicit
user instruction. Defaults are two `codex` critics. Resolve flags as follows:

- Codex: `--model gpt-5.6-sol --effort xhigh`.
- Claude: configured/default model with `--effort xhigh`.
- Grok: `--model grok-4.6 --effort medium`.

Honor explicit model/effort settings except `grok-4.6` always uses `medium`.
Declare the resolved shape, save it to `<tmp>/shape.txt`, and run
`plx-preflight --repo <repo> --require-<engine>` once per distinct engine.
For Grok calls and preflight, disable the Bash sandbox (`dangerouslyDisableSandbox: true`); keep Grok's kernel sandbox active.

## Author

Ask at most three questions in one round if the answers would materially change the
plan. Read relevant repository guidance, code, callers, and tests. When external facts
matter, run a read-only documentation lookup with `plx-engine --engine codex
--model gpt-5.6-terra --effort low --mode ro` and a focused brief while reading the repo.

Pin intent, success criteria, invariants, suggested path, and validation. Leave local
implementation choices to the builder. End with `Done means:` and concrete commands
or observable behavior that prove completion. Plan in chat by default; persist large,
risky, or multi-session plans in the build thread using
`plx-skill --ref plan/spec-template`. Never edit `.project/VISION.md`.

## Critique and revise

Write one neutral `<tmp>/critic-brief.md` for both critics:

```markdown
## Draft plan

### Original request
<$ARGUMENTS verbatim>

### Confirmed decisions
<material user clarifications, or none>

### Candidate plan
<candidate plan verbatim>
```

Use the request and confirmed decisions as the task contract; confirmed decisions
resolve conflicts. Launch both dimensions in parallel in retained background sessions:

```
plx-engine --engine <e> --mode ro --repo <repo> --prompt-file <tmp>/critic-brief.md \
  --rubric plan-critic-<dimension> <resolved model/effort flags> \
  --out <tmp>/critic-<dimension>.md --log <tmp>/critic-<dimension>.log
```

Use packaged wrappers and named rubrics; no raw engine commands, pasted rubrics, or
subagents. Keep runtime files out of the repository, including `.parallax/`. Never
`uv run` inside a sandbox.

On exit 1, inspect the log and retry once on the same binding. Count a terminated stalled
or repeating lane toward that retry. Correct an exit-2 invocation error once; exit 3
requires authentication and stops the run. If a required critic still has no result,
return `[RED-TEAM INCOMPLETE]` with the diagnosis, provisional plan, and surviving findings.
Degraded completion requires explicit authorization in the current message.

Deduplicate findings, verify material claims against the repo, and adopt or reject each
with a reason. If a finding invalidates the design, revise once and rerun all required
critics once. A failed final pass or unresolved Critical finding is `[RED-TEAM INCOMPLETE]`.

## Finish

Present the final plan, any persisted path, and material critique dispositions. Suggest
`/plx:build` and stop. Use `pass` only for a final fully reviewed plan; verification
passes only when all required critics completed and `Done means:` is concrete.

Before every handled return, finish the run and then clean up:

```
plx-eval finish --skill plan --host claude --repo <repo> --run-dir <tmp> \
  --host-model <actual host model if known, otherwise unknown> \
  --task-file <tmp>/task.md --shape-file <tmp>/shape.txt \
  --outcome <pass|fail|partial|aborted> --verification <pass|fail|not-run> \
  || echo "plx-eval finish failed (non-fatal)" >&2
plx-clean-temp <tmp>
```

Recorder failure is non-fatal; an interrupted run may remain incomplete.

Task to plan:

$ARGUMENTS
