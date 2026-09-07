---
name: goal-spec
description: Lock the goal with the user, author a design, obtain independent implementation and system critiques, and persist one self-contained spec. No implementation code.
argument-hint: "<the goal to plan>"
disable-model-invocation: true
user-invocable: true
---

# /plx:goal-spec

Lock the goal with the user, author a design, obtain independent implementation and
system critiques, and deliver one self-contained spec for `/plx:build` or `/goal`.
Write no implementation code.

Use the packaged helpers on PATH.

## Prepare

Resolve `<repo>` with `git rev-parse --show-toplevel` and note existing changes.
Create `<tmp>` with `mktemp -d "${TMPDIR:-/tmp}/plx-goal-spec.XXXXXX"` and write the
original request to `<tmp>/task.md`. Keep all lane prompts directly in `<tmp>`.
Read `.project/VISION.md` if present and carry its hard constraints into the spec;
never edit it. Continue the existing build thread or choose
`.project/builds/YYYY-MM-DD_<thread-name>/` using `date +%F` and a short goal name.

Read `plx-config`, key `goal-spec`. Defaults are implementation and system
critics on `codex`. Declare the configured shape, save it to `<tmp>/shape.txt`,
and run `plx-preflight --repo <repo> --require-<engine>` once per distinct engine.
If a required engine is unavailable, report `[RED-TEAM INCOMPLETE]` and stop.
For Grok calls and preflight, disable the Bash sandbox (`dangerouslyDisableSandbox: true`); keep Grok's kernel sandbox active.

## Lock the goal

Resolve material ambiguity with `AskUserQuestion` when available, otherwise ask in chat
and wait. Ask up to three questions per round, for about two or three rounds at most.
Offer a recommended option when useful; accept "I don't know" and record the resulting
assumption or open question. Ask only questions whose answers change the plan.

Cover the problem and users, scope and material non-goals, checkable success criteria,
invariants, and open risks. Probe conflicting requirements, missing behavior, and
scenarios that must be allowed or refused. Defer implementation choices to the design.
Skip questions already answered by the request.

Summarize Intent, binary Success Criteria, Invariants, and Non-goals. Ask the user to
confirm or amend this summary and wait for approval before authoring the design. This
lock gate applies even when no interview questions were needed.

## Design and critique

Read the repository surfaces needed to design against the locked goal. If external
facts matter, run a read-only documentation lookup using `plx-engine --engine codex
--model gpt-5.6-terra --effort low --mode ro` and a focused brief while reading the repo.
Author a concrete plan with the recommended path, material alternatives, supporting repo
facts, affected components, and observable validation. Save it to `<tmp>/plan-brief.md`.

Write one neutral `<tmp>/critic-brief.md`:

```markdown
## Draft plan

### Original request
<$ARGUMENTS verbatim>

### Confirmed decisions
<user-approved lock summary verbatim>

### Candidate plan
<candidate plan verbatim>
```

The approved lock resolves conflicts with the original request. Run both configured
critic dimensions in parallel in retained background sessions. Grok uses `medium`;
Codex and Claude use `xhigh`.

```
plx-engine --engine <e> --mode ro --repo <repo> --prompt-file <tmp>/critic-brief.md \
  --rubric plan-critic-<dimension> --effort <resolved-effort> \
  --out <tmp>/critique-<dimension>-<e>.md --log <tmp>/critic-<dimension>-<e>.log
```

Skip a dimension only when configuration explicitly leaves it empty, and disclose the
skip. Inspect failed lanes and retry once on the same binding. Correct an exit-2 usage
error once; exit 3 requires authentication and stops the run. If a required critic still
has no result, return `[RED-TEAM INCOMPLETE]` with the diagnosis and surviving artifacts;
do not persist a final spec.

Use packaged wrappers and named rubrics; no raw engine commands, pasted rubrics, or
subagents. All lanes are read-only. Never `uv run` inside a sandbox.

## Synthesize the spec

Deduplicate findings, verify material claims, and adopt or reject them with reasons.
Load `plx-skill --ref plan/spec-template` and author one final spec:

- Put the locked goal in Intent, Success Criteria, and Invariants, including VISION
  constraints and material non-goals.
- Put the design and critique decisions in Context, Suggested Path, and Validation.
- Keep Stop Rules and include Milestones and a Progress Log for this long-running effort.

Pair each success criterion with a command or observation and its passing signal. Surface
that evidence in the run output. Resolve every validation placeholder to a concrete
command or explicit manual check before handoff. Record unresolved gaps and chosen
assumptions under Open Questions. Explain material departures from the candidate or critiques.

## Persist and hand off

Write the complete spec to `.project/builds/<thread>/PLAN_<slug>.md` and add it to the
thread's `README.md` index, following repository layout guidance. These planning documents
are the only repository writes. Keep runtime state in `<tmp>`, never `.parallax/`.

Return the goal, spec path, approach, material critique dispositions, assumptions or
residuals, and a paste-ready handoff such as:

```
/goal Execute .project/builds/<thread>/PLAN_<slug>.md — done when every
      Success Criterion is satisfied with evidence and its Validation commands pass.
```

Mention `/plx:build` as the alternative and stop without building. Before every handled
return, record the honest outcome and verification status, then clean up:

```
plx-eval finish --skill goal-spec --host claude --repo <repo> --run-dir <tmp> \
  --host-model <actual host model if known, otherwise unknown> \
  --task-file <tmp>/task.md --shape-file <tmp>/shape.txt \
  --outcome <pass|fail|partial|aborted> --verification <pass|fail|not-run> \
  || echo "plx-eval finish failed (non-fatal)" >&2
plx-clean-temp <tmp>
```

Recorder failure is non-fatal; an interrupted run may remain incomplete.

Goal to plan:

$ARGUMENTS
