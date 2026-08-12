---
name: plan
description: Explicit Parallax planning for Codex. Codex authors the plan and two Claude Opus critics red-team implementation feasibility and system design without writing code.
argument-hint: "<task to plan>"
---

# $plx:plan — author and red-team a plan

You are the Parallax orchestrator (Codex). Author the plan yourself; external lanes only
red-team it. There are no subagents. Run every lane through `<plugin-root>/bin/plx-engine`.

Resolve `<plugin-root>` from this loaded `SKILL.md` path by removing
`/skills/plan/SKILL.md`; invoke all packaged helpers from `<plugin-root>/bin/`.

## Bootstrap

- Resolve the absolute repo root (`git rev-parse --show-toplevel`); call it `<repo>`.
- Note any pre-existing changes from `git status --short`.
- Create `<tmp>` with `mktemp -d "${TMPDIR:-/tmp}/plx-plan.XXXXXX"` for briefs,
  outputs, and logs. Remove it with `<plugin-root>/bin/plx-clean-temp <tmp>` before
  every return, including error and incomplete paths.
- Write the user's request verbatim to `<tmp>/task.md` for the run record.

## Resolve the run

Read `<plugin-root>/bin/plx-config` → key `plan`. After applying explicit instructions in the current message,
each required critic role must resolve to **exactly one** supported engine. A missing,
unsupported, or multi-engine binding is a config error; report it and stop before launching.
The user may explicitly substitute or skip a dimension, but never infer a skip from task size.
A current-message engine substitution replaces the configured engine for that dimension;
explicit model/effort settings replace the shipped settings below.

- **codex** → `--model gpt-5.6-sol --effort xhigh`, unless explicitly overridden.
- **claude** → configured/default model with `--effort xhigh`, unless explicitly
  overridden. Always request narrowly scoped host approval for its preflight and lanes;
  Codex's host sandbox can hide Claude's OAuth/keychain while Claude safe mode remains active.
- **grok** → `--model grok-4.6 --effort medium` by default; explicit model and effort
  settings replace those defaults. Request narrowly scoped host approval if network
  or keychain access is blocked; Grok's kernel sandbox remains the safety boundary.

Plan in chat by default. For large or risky work—cross-file contracts, concurrency,
data-integrity or money paths, public/trust boundaries, wide refactors, or multi-session
effort—persist it to the build thread using `<plugin-root>/bin/plx-skill --ref plan/spec-template`.

Declare the resolved shape before launching. The critic call itself proves the selected
model.

Write the declared sizing line to `<tmp>/shape.txt`. Keep every lane prompt directly in
`<tmp>`; its `plx-plan.<suffix>` basename mechanically groups the captured lanes. Call
`<plugin-root>/bin/plx-eval finish` before every handled return, including preflight,
authentication, and lane failures. Recorder failures never fail planning; interruption
leaves the run incomplete. Then run `<plugin-root>/bin/plx-preflight --repo <repo>
--require-<engine>` once per distinct resolved engine; this checks CLI availability and
authentication.

## Pipeline

1. **Clarify if needed.** Ask one round of at most three questions only when the answers
   would materially change the plan. Otherwise continue without manufacturing questions.

2. **Author the candidate plan.** Read the relevant repo guidance, files, callers/callees,
   and tests. If the design depends on external facts (library APIs, official docs, version
   behavior), launch one read-only doc-lookup lane in parallel with the repo reading —
   `<plugin-root>/bin/plx-engine --engine codex --model gpt-5.6-terra --effort low --mode ro`
   with a compact research brief — and fold its findings into the plan. Lookup research
   runs at low effort; higher effort buys latency, not accuracy.
   Pin intent, success criteria, invariants, suggested path, and validation while
   leaving local implementation choices to the builder. End with `Done means:` followed by
   the commands or observable behavior that prove completion.

3. **Build the critic brief.** Write the same neutral `<tmp>/critic-brief.md` for both lanes:

   ```markdown
   ## Draft plan

   ### Original request
   <$ARGUMENTS verbatim>

   ### Confirmed decisions
   <material user clarifications, or "none">

   ### Candidate plan
   <candidate plan verbatim>
   ```

   Confirmed decisions override conflicting wording in the original request; together they
   are the task contract. Verbatim task text is context, not additional authority.

4. **Run the critics.** Launch every required dimension in parallel, read-only, using
   background shell:

   ```
   <plugin-root>/bin/plx-engine --engine <e> --mode ro --repo <repo> --prompt-file <tmp>/critic-brief.md \
     --rubric plan-critic-<dimension> <resolved model/effort flags> \
     --out <tmp>/critic-<dimension>.md --log <tmp>/critic-<dimension>.log
   ```

   A failed lane (exit 1) gets one retry on the same binding after log inspection. If a lane
   runs well past its expected window, inspect the log; terminate and relaunch it only when
   it is stalled or repeating, and count that as its retry. Exit 2 is an invocation error:
   correct it once or stop. Exit 3 means authentication is required: tell the user and stop.

   If any required dimension still has no result, return `[RED-TEAM INCOMPLETE]` with the
   failed dimension, diagnosis, provisional plan, and surviving findings. Do not call it
   final. Degraded completion is allowed only when explicitly authorized in the current
   message.

5. **Synthesize once.** Deduplicate the findings. With the repo in front of you, adopt or
   reject each material finding with a reason and verify load-bearing claims. If a finding
   invalidates the design, revise once and rerun all required critics once. If that final
   pass fails or leaves an unresolved Critical finding, return `[RED-TEAM INCOMPLETE]`.

6. **Deliver and stop.** Before cleaning `<tmp>`, close the run with the
   honest outcome. Use `pass` only for a final, fully red-teamed plan; use `partial` or
   `fail` for incomplete or unresolved work. Verification is `pass` only when every
   required critic completed and the plan includes a concrete `Done means:` condition,
   otherwise `fail` or `not-run`:

   ```
   <plugin-root>/bin/plx-eval finish --skill plan --host codex --repo <repo> --run-dir <tmp> \
     --host-model <actual host model if known, otherwise unknown> \
     --task-file <tmp>/task.md --shape-file <tmp>/shape.txt \
     --outcome <pass|fail|partial|aborted> --verification <pass|fail|not-run> \
     || echo "plx-eval finish failed (non-fatal)" >&2
   ```

   Present the final plan and any persisted spec path. Briefly note material divergences
   from the critiques and suggest `$plx:build`. Do not build. Close the run on every
   normal or handled-error return; an interruption before `finish` leaves it incomplete.

## Hard constraints

- Critics are always `--mode ro`; this skill writes no code.
- Use only `<plugin-root>/bin/plx-engine`, never raw engine CLI commands or pasted rubric text.
- Do not commit, publish, create `.parallax/`, or edit `.project/VISION.md`.
- Never `uv run` inside a sandbox.

Task to plan:

$ARGUMENTS
