---
name: dev
description: Explicit full Parallax pipeline for Codex. Codex plans, delegates implementation to Grok, synthesizes opposite-engine review, applies the confirmed fixes itself, and performs the final gate.
argument-hint: "<coding task>"
---

# $plx:dev

Author the plan, delegate implementation, synthesize independent review, apply confirmed
fixes, and verify the result. This workflow is self-contained; do not invoke standalone
`$plx:build` or `$plx:review`. The host owns planning and post-review fixes; engine
workers own initial implementation.

Resolve `<plugin-root>` from this loaded `SKILL.md` path by removing
`/skills/dev/SKILL.md`. Use the packaged helpers in `<plugin-root>/bin/`.

## Prepare and size

Resolve `<repo>` with `git rev-parse --show-toplevel`. Create `<tmp>` with
`mktemp -d "${TMPDIR:-/tmp}/plx-dev.XXXXXX"`. Save Git status and staged/unstaged diffs
there to preserve pre-existing work. Write the user's request verbatim to `<tmp>/task.md`.
Keep all lane prompts directly in `<tmp>`.

Read `<plugin-root>/bin/plx-config`, key `dev`, and `<plugin-root>/bin/plx-engine --print-rubric engines`.
Defaults are `code: grok`, `code-fallback: codex`, and `claude` for implementation
and system critics and each review dimension. Size the stages to the task:

| Size | Critics | Writers | Review |
| --- | --- | --- | --- |
| Trivial | None | One cheap configured worker | Host verification |
| Small | None | One worker | Correctness |
| Default | Implementation and system | One worker | Correctness, cleanup, structural |
| Large or risky | Implementation and system | File-disjoint workers when useful | Core roles; a second non-writer engine when proportionate |

Declare the selected roles, engines, models, effort, and host-owned fixes before launch;
write the declaration to `<tmp>/shape.txt`. Default review uses `claude` at
`high`; standalone review's Grok routing does not apply.

Resolve writer settings from `code` and `code-fallback`. An explicit engine selection
disables fallback and requires preflight. For explicit Grok, use
`<plugin-root>/bin/plx-preflight --repo <repo> --require-grok --grok-mode rw`.
With shipped defaults, probe `<plugin-root>/bin/plx-preflight --repo <repo> --optional-grok --grok-mode rw`;
select Grok on success, otherwise require Codex preflight before choosing the fallback.
For other configured writers, preflight the selected engine. Never switch writers after
a writer starts or task mutation begins. Require every selected critic/reviewer engine.
If the host sandbox blocks Claude or Grok network/keychain access, request narrowly scoped host approval for that call; keep the engine sandbox active.

## Lane mechanics

Use packaged wrappers and named rubrics in retained background sessions:

```
<plugin-root>/bin/plx-engine --engine <e> --mode <ro|rw> --repo <repo> --prompt-file <brief> \
  --rubric <lane> --model <model> --effort <effort> \
  --out <tmp>/<lane>.md --log <tmp>/<lane>.log
```

Run independent lanes in parallel with unique out/log files. Grok defaults to `grok-4.6`
at `medium`; that model always stays at `medium`. Do not use raw engine commands,
pasted rubrics, or subagents. On exit 1, inspect the log and retry once or escalate a
read-only lane; writer fallback remains limited to preflight. Disclose failed review
lanes and proceed with survivors as a partial round. Correct exit-2 usage errors;
exit 3 requires authentication and stops the run.

## Plan

Ask up to three material clarification questions if needed. Read the repository surfaces
needed for the design and author the plan yourself. When external facts matter, run a
read-only documentation lookup with `<plugin-root>/bin/plx-engine --engine codex --model gpt-5.6-terra
--effort low --mode ro` and a focused brief while reading the repo.

Keep the plan in context unless a multi-session effort warrants a build-thread spec
using `<plugin-root>/bin/plx-skill --ref plan/spec-template`. End with `Done means:` and the commands
or observables that prove completion.

When sized in, give each critic the same `<tmp>/critic-brief.md`:

```markdown
## Draft plan

### Original request
<$ARGUMENTS verbatim>

### Confirmed decisions
<material clarification answers, or none>

### Candidate plan
<plan verbatim>
```

Confirmed decisions resolve conflicts with the original request. Run read-only
`plan-critic-implementation` and `plan-critic-system` for the configured engines in
parallel. Deduplicate, verify material claims, and adopt or reject findings with reasons.
If a finding invalidates the plan, revise once and rerun the sized critics once.

## Implement

Write `<tmp>/spec.md` with `## Spec`, the final plan verbatim, and
`### Pre-existing worktree state` naming dirty paths and relevant baseline diffs.
Instruct workers to preserve that work. Launch `--rubric worker --mode rw` lanes on
the selected writer engine. Use one writer per disjoint path set. Each parallel brief
names its owned paths and the other concurrent work; use one writer when seams overlap.
Do not edit worker-owned files while lanes run.

Workers self-verify. After parallel writers finish, run the combined repository checks.
While they work, prepare only the review brief fields and verification commands already
needed by this task.

## Review and fix

After implementation, write one neutral `<tmp>/review-brief.md` for all reviewers:

```
## Review brief
- Repo: <repo>
- Files touched: <Git status/diff compared with the saved baseline>
- What was implemented / what to scrutinize: <spec and worker report summary>
- Diff basis: <task changes relative to saved status/diffs>
- Task contract: <final plan verbatim>
```

Launch sized read-only `reviewer-correctness`, `reviewer-cleanup`, and
`reviewer-structural` lanes, preferring engines that did not write the code. Add
`reviewer-security` when requested or when scope touches auth, permissions,
secrets/config, shell/subprocess execution, sandboxing, network clients, dependencies,
lockfiles, CI, deserialization, or another trust boundary. Otherwise record
`Security: not run`. If another lane finds a concrete security risk, run security review
or preserve the risk as a named residual.

Deduplicate and verify material findings against code. Let correctness determine scope
before cleanup or structural fixes. Reject false positives, unrelated pre-existing
issues, untouched code without a causal link, linter-only style, generic test wishes,
speculative unreachable cases, and optimizations without material cost.

Fix directly after all lanes stop. Apply confirmed targeted fixes in one bounded round.
Batch questions where behavior or scope needs a user decision. Report leftovers as
residuals. For a build-sized remedy, report the residual or write a fresh spec and return
to implementation. Re-run verification after fixes.

## Gate and finish

Inspect the task-owned diff against the plan and its `Done means:` checks. If a targeted
fix remains within the fix round, apply it and re-verify; otherwise report the residual.
Structural rework needs a fresh spec and delegated implementation.

Update project docs when repository guidance and the change warrant it. Follow repository
instructions for local commits; this skill grants no publication authority. Keep runtime
output out of the repo, including `.parallax/`. Never `uv run` inside a sandbox.

Report the outcome, chosen shape and changes to it, material planning decisions, worker
and review results, fixes, gate evidence, verification commands/results, docs, and residuals.
Use a compact natural format; omit empty sections. Before every handled return, finish
and clean up:

```
<plugin-root>/bin/plx-eval finish --skill dev --host codex --repo <repo> --run-dir <tmp> \
  --host-model <actual host model if known, otherwise unknown> \
  --task-file <tmp>/task.md --shape-file <tmp>/shape.txt \
  --outcome <pass|fail|partial|aborted> --verification <pass|fail|not-run> \
  || echo "plx-eval finish failed (non-fatal)" >&2
<plugin-root>/bin/plx-clean-temp <tmp>
```

Recorder failure is non-fatal; an interrupted run may remain incomplete.

Task:

$ARGUMENTS
